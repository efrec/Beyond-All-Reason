-- COMMANDS --------------------------------------------------------------------
-- Common configuration data and functions for processing RecoilEngine commands.

local Commands = {}

--------------------------------------------------------------------------------

local COMMAND_PARAM_COUNT = 5
local COMMAND_PARAM_COUNT_MAX = 8

--------------------------------------------------------------------------------
-- Parameter types and counts --------------------------------------------------

local function rangeSet(min, max)
	local tbl = {}
	for i = min, max do tbl[i] = true end
	return tbl
end

local any = rangeSet(0, COMMAND_PARAM_COUNT_MAX)
local none = {}

--------------------------------------------------------------------------------
-- Parameter types and counts --------------------------------------------------

---Contains the allowed parameter counts per set of command parameter types.
---
---For example, commands can accept a unit ID or map position (TargetOrPoint).
---
---Used only for processing engine commands and registering game commands.
---@type table<string, table<integer, true>>
local paramsType = {
	NoParameters = { [0] = true },
}

paramsType = setmetatable(paramsType, {
	-- Unregistered commands have no restrictions
	-- except that they obey the max param count.
	__index = function(self, key)
		return any
	end
})

---Maps every command to its accepted parameter counts.
---@type table<CMD, table<integer, true>>
local commandParamsType = {
	[CMD.STOP] = paramsType.NoParameters,
}

--------------------------------------------------------------------------------
-- Target parameter index positions --------------------------------------------

---Contains the parameter index position of the command's target ID (if any).
---
---Used only for processing engine commands and registering game commands.
---@type table<string, table<integer, integer>>
local paramsTargetIndex = {
	TargetObject = { [1] = 1 },
}

paramsTargetIndex = setmetatable(paramsTargetIndex, {
	__index = function(self, key)
		return none
	end
})


local paramsTypeCountsToIndex = {}
for typeName, indexMap in pairs(paramsTargetIndex) do
	paramsTypeCountsToIndex[paramsType[typeName]] = indexMap
end

---Maps commands and their param counts to the index position of a target id.
---@type table<CMD, table<integer, integer>>
local commandParamsTargetIndex = {}

for command, paramCounts in pairs(commandParamsType) do
	commandParamsTargetIndex[command] = paramsTypeCountsToIndex[paramCounts]
end

commandParamsTargetIndex = setmetatable(commandParamsTargetIndex, {
	__index = function(self, key)
		return none
	end
})

--------------------------------------------------------------------------------
-- Command categories ----------------------------------------------------------

local queuingCommand = {}
local waitingCommand = {}

--------------------------------------------------------------------------------
-- Command functions -----------------------------------------------------------

local CMD = CMD
local GameCMD = GameCMD

Commands.RegisterCommand = function(command, name, paramsTypeName, queues, waits)
	-- do whatever
end

Commands.RegisterParamsType = function(name, counts, targetIndex)
	-- do whatever
end

--------------------------------------------------------------------------------
-- Command functions -----------------------------------------------------------

Commands.IsQueueCommand = function(command)
	return queuingCommand[command] ~= nil
end

Commands.IsWaitCommand = function(command)
	return waitingCommand[command] ~= nil
end

Commands.IsObjectCommand = function(command, params)
	return commandParamsTargetIndex[command][#params] ~= nil
end

Commands.GetObjectIndex = function(command, params)
	return commandParamsTargetIndex[command][#params]
end

Commands.GetObjectID = function(command, params)
	-- NB: Can throw. You should be sure you will get an ID.
	return params[commandParamsTargetIndex[command][#params]]
end

Commands.GetGuardeeID = function(unitID, index)
	if index == nil then
		index = 1
	end

	while true do
		local command, options, _, guardeeID = Spring.GetUnitCurrentCommand(unitID, index)

		if command == CMD.GUARD then
			return guardeeID
		elseif command ~= nil and math.bit_and(options, CMD.INTERNAL) ~= 0 then
			index = index + 1
		else
			return
		end
	end
end

---@param params table
---@return CMD? command
---@return number|number[]? commandParams
---@return integer? insertIndex
Commands.GetInsertedCommand = function(params)
	if #params < 5 then
		return p[2], p[4], p[1] -- avoid tables
	else
		return p[2], { p[4], p[5], p[6], p[7], p[8] }, p[1]
	end
end

Commands.RemoveEnqueueOptions = function(options, copy)
	if copy then options = table.copy(options) end
	if not options.meta and (not options.alt) ~= (not options.shift) then
		options.alt = nil
		options.shift = nil
	end
	return options
end

Commands.RemoveInsertOptions = function(options, copy)
	if copy then options = table.copy(options) end
	options.meta = nil
	return options
end

--------------------------------------------------------------------------------
-- Export module ---------------------------------------------------------------

return Commands
