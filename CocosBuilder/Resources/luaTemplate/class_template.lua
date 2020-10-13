local CCBLoader = require("CCB.Loader")
local Oop = require("Oop.init")

--[[
Callbacks:
    __FUNC_NAMES__

Members:
    __MEMBERS__
]]
local __CLASS_NAME__ = Oop.class("__CLASS_NAME__", function(owner)
    -- @param "UI.ccb" => code root
    -- @param "ccb/"   => ccbi folder
    CCBLoader:setRootPath("UI", "__CCBI_FOLDER__")
    return CCBLoader:load("__CLASS_NAME__", owner)
end)

function __CLASS_NAME__:ctor()
    -- @TODO: constructor
end

__FUNC_IMPLEMENTS__

return __CLASS_NAME__