--[[
    Minecalc Server
    usage: minecalc [database-file]


]]
local fs = require("fs")
local textutils = require("textutils")
local term = require("term")

local database_file = ...
database_file = database_file or "./database.json"
local modem = peripheral.find("modem") or error("no modem attached", 0)
local modem_channel = 65535

modem.open(modem_channel)



local database = {}
if fs.exists(database_file) then
    local file = fs.open(database_file, "r")
    database = textutils.unserializeJSON(file.readAll())
    file.close()
else
    local file = fs.open(database_file, "w")
    file.write(textutils.serializeJSON(database))
    file.close()
end


local function update_database()
    local file = fs.open(database_file, "w")
    file.write(textutils.serializeJSON(database))
    file.close()
end

local function make_terminal(name, emc_cost)
    database["name"] = {
        ["type"] = "TERMINAL",
        ["emc"] = emc_cost
    }
    update_database()
end


-- Child nodes is a list of child * count pairs
local function make_node(name, child_nodes)
    database["name"] = {
        ["type"] = "NODE",
        ["child_nodes"] = child_nodes
    }
    update_database()
end

local function log(message, level)
    level = level or "log"
    local currentColor = term.getTextColor
    term.write("[")
    if level == "error" then
        term.setTextColor(colors.red)
    elseif level == "warn" then
        term.setTextColor(colors.yellow)
    elseif level == "log" then
        term.setTextColor(colors.green)
    end
    term.write(level)
    term.setTextColor(currentColor)
    term.write("] ")
    print(message)
end

-- This doesn't give a summary of the total count of each item, because that should be done by the receiever
local function make_summary(name, count, depth)
    depth = depth or 0
    if database[name] ~= nil and depth < 100 then
        local current = database[name]
        if current.type == "TERMINAL" then
            return {
                ["name"] = name,
                ["count"] = count,
                ["type"] = "TERMINAL",
                ["total_emc"] = current.emc * count
            }
        else
            local summaries = {}
            local emc = 0
            for value in current.child_nodes do
                local summary = make_summary(value[1],value[2]*count,depth+1)
                summaries[#summaries+1] = summary
                emc = emc + summary["total_emc"]
            end

            return {
                ["name"] = name,
                ["count"] = count,
                ["type"] = "NODE",
                ["summaries"] = summaries,
                ["total_emc"] = emc,
            }
        end
    else
        if depth >= 100 then 
            log("summary depth limit reached at: " .. name, "error")
        else
            log("unknown item: " .. name, "warn")
        end
        return {
            ["name"] = name,
            ["count"] = count,
            ["type"] = "TERMINAL",
            ["total_emc"] = 0
        }
    end
end

local function get_keys(t)
    local keys={}
    for key,_ in pairs(t) do
      table.insert(keys, key)
    end
    return keys
  end

local function generate_message_response(message)
    if message.type == "summarize" then
        return make_summary(message.name, message.count)
    elseif message.type == "info" then
        return database[message.name]
    elseif message.type == "delete" then
        if database[message.name] then
            database[message.name] = nil
            return "ack"
        else
            error("attempting to delete non-extant node")
        end
    elseif message.type == "make-node" then
        make_node(message.name, message.children)
        return "ack"
    elseif message.type == "make-terminal" then
        make_terminal(message.name, message.emc)
        return "ack"
    elseif message.type == "list-nodes" then
        return get_keys(database)
    elseif message.type == "ping" then
        return "pong"
    end
end

local function server()
    log("Minecalc Server Booted!")
    while true do
        local event, side, channel, replyChannel, message, distance
        repeat
            event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        until channel == modem_channel
        log("received message: " ..textutils.serializeJSON(message))
        local status, response = pcall(generate_message_response, message)
        if status then
            log("responded to message successfully")
            modem.transmit(replyChannel, modem_channel,{
                ["status"] = "ok",
                ["result"] = response
            })
        else
            log(response, "error")
            modem.transmit(replyChannel, modem_channel,{
                ["status"] = "failed",
                ["error"] = response
            })
        end
    end
end


server()