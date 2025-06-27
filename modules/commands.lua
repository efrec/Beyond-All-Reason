--------------------------------------------------------------------------------
-- Common configuration data and functions for processing RecoilEngine commands.
local Commands = {}

--------------------------------------------------------------------------------

local CMD = CMD
local GameCMD = Game.CustomCommands.GameCMD

--------------------------------------------------------------------------------
-- Command information ---------------------------------------------------------

-- Commands that take up a position in the command queue or factory queue.
local queuingCommand = {}

-- Commands that freeze the command queue (and may prevent some actions).
local waitingCommand = {
    [CMD.WAIT]      = true,
    [CMD.DEATHWAIT] = true,
    [CMD.SQUADWAIT] = true,
    [CMD.TIMEWAIT]  = true,
}

do
    -- Much shorter list:
    local isNonQueuing = {
        -- Engine commands
        CMD.STOP,
        CMD.REMOVE,
        CMD.SELFD,

        CMD.FIRE_STATE,
        CMD.MOVE_STATE,
        CMD.AUTOREPAIRLEVEL,
        CMD.CLOAK,
        CMD.IDLEMODE,
        CMD.ONOFF,
        CMD.REPEAT,
        CMD.STOCKPILE,
        CMD.TRAJECTORY,

        CMD.GROUPADD,
        CMD.GROUPCLEAR,
        CMD.GROUPSELECT,

        -- Custom commands
        GameCMD.AIR_REPAIR,
        GameCMD.BLUEPRINT_CREATE,
        GameCMD.BLUEPRINT_PLACE,
        GameCMD.CARRIER_SPAWN_ONOFF,
        GameCMD.HOUND_WEAPON_TOGGLE,
        GameCMD.LAND_AT,
        GameCMD.PRIORITY,
        GameCMD.QUOTA_BUILD_TOGGLE,
        GameCMD.SELL_UNIT,
        GameCMD.SMART_TOGGLE,
        GameCMD.STOP_PRODUCTION,
        GameCMD.UNIT_CANCEL_TARGET,
        GameCMD.UNIT_SET_TARGET_NO_GROUND,
        GameCMD.UNIT_SET_TARGET_RECTANGLE,
        GameCMD.UNIT_SET_TARGET,
        GameCMD.WANT_CLOAK,
    }

    -- Note: Must not be ipairs in case a GameCMD is removed.
    for command in pairs(GameCMD) do
        if not table.getKeyOf(isNonQueuing, command) then
            queuingCommand[command] = true
        end
    end

    isNonQueuing = nil
end

---@param command CMD?
Commands.IsQueueCommand = function(command)
    return queuingCommand[command] ~= nil
end

---@param command CMD?
Commands.IsWaitCommand = function(command)
    return waitingCommand[command] ~= nil
end

--------------------------------------------------------------------------------
-- Command processing and helpers ----------------------------------------------

---Get the unitID of the target of CMD_GUARD, if any.
---@param unitID integer
---@param commandIndex integer? default = 1
---@return integer? guardeeID
Commands.GetGuardeeID = function(unitID, commandIndex)
    while true do
        local command, options, _, maybeUnitID = Spring.GetUnitCurrentCommand(unitID, commandIndex)

        if command == CMD.GUARD then
            return maybeUnitID
        elseif command ~= nil and math.bit_and(options, CMD.INTERNAL) ~= 0 then
            commandIndex = commandIndex + 1
        else
            return
        end
    end
end

---Retrieve the command info from the command params of a CMD_INSERT.
---@param params number[]
---@return CMD command
---@return number|number[] commandParams
---@return integer insertIndex
Commands.GetInsertedCommand = function(params)
    if #params < 5 then
        return params[2], params[4], params[1]
    else
        return params[2], { params[4], params[5], params[6], params[7], params[8] }, params[1]
    end
end

---Remove command options that would place the command later in the queue.
--
-- When changing options within a callin, like AllowCommand, set the `copy` flag.
---@param options CommandOptions
---@param copy boolean?
---@return CommandOptions
Commands.RemoveEnqueueOptions = function(options, copy)
    if copy then options = table.copy(options) end

    if not options.meta and (not options.alt) ~= (not options.shift) then
        options.alt = nil
        options.shift = nil
    end

    return options
end

---Remove command options that would place the command in front of the queue.
--
-- When changing options within a callin, like AllowCommand, set the `copy` flag.
---@param options CommandOptions
---@param copy boolean?
---@return CommandOptions
Commands.RemoveInsertOptions = function(options, copy)
    if copy then options = table.copy(options) end

    options.meta = nil

    return options
end

--------------------------------------------------------------------------------
-- Export module ---------------------------------------------------------------

return {
    Commands = Commands,
}
