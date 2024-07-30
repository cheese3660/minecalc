local modem = peripheral.find("modem")
local my_channel = os.getComputerID()
local target_channel = 0
modem.open(my_channel)
if not fs.exists("basalt.lua") then
    print("Basalt does not seem to be installed!\nInstall it via the following command:\nwget run https://basalt.madefor.cc/install.lua release latest.lua")
end
local basalt = require("basalt")

local main = basalt.createFrame()
local INIT = "init"
local LIST = "list"
local ADD_TERMINAL = "add_terminal"
local ADD_NODE = "add_node"
local ERROR = "error"
local state = ""


local frames = {
    [INIT] = main:addFrame():setSize("parent.w","parent.h"):hide(),
    [LIST] = main:addFrame():setSize("parent.w","parent.h"):hide(),
    [ADD_TERMINAL] = main:addFrame():setSize("parent.w","parent.h"):hide(),
    [ADD_NODE] = main:addFrame():setSize("parent.w","parent.h"):hide(),
    [ERROR] = main:addFrame():setSize("parent.w","parent.h"):hide(),
}

local state_info = {
    [INIT] = {
        ["init"] = function(self)
            self.title = self.frame:addLabel():setText("Mine Calc Client"):setPosition(1,1)
            self.flexbox = self.frame:addFlexbox():setDirection("row"):setPosition(1,2)
            self.label = self.flexbox:addLabel():setText("Channel")
            self.input = self.flexbox:addInput():setInputType("number"):setDefaultText("65535"):setInputLimit(5)
            self.connect = self.frame:addButton():setText("Connect"):setPositon(1,3):onClick(
                function()
                    self:onConnect()
                end
            )
        end,
        ["connect"] = function (self)
            if self.connect:getText() == "Connect" then
                self.connect:setText("No")
            else
                self.connect:setText("Connect")
            end
        end,
        ["entry"] = function(self)
        end,
    },


    [ERROR] = {
        ["init"] = function (self)
            
        end,
        ["entry"] = function(self)
        end,
        ["show"] = function (self, message, return_state)
            self.previous = return_state
            self.message = message
        end
    }
}
local function update_state(new_state)
    if state_info[state] then
        state_info[state].frame:hide()
    end
    state = new_state
    state_info[state]:entry()
    state_info[state].frame:show()
end

for k,v in pairs(state_info) do
    v.frame = main:addFrame():hide()
    v:init()
    v.goto_frame = function()
        update_state(k)
    end
end

state_info["init"]:goto_frame()


basalt.autoUpdate()