-- COMMANDS --------------------------------------------------------------------
-- Common configuration data and functions for processing RecoilEngine commands.
--------------------------------------------------------------------------------

local Commands = {}

--------------------------------------------------------------------------------
-- Exported functions ----------------------------------------------------------
-- # RegisterCommand       ::  Add a (non-engine) game command to the module  --
-- # RegisterParamsType    ::  Add a parameter set and its configuration      --
-- # IsQueueCommand        ::  Does the command occupy the command queue      --
-- # IsWaitCommand         ::  Does the command suspend the command queue     --
-- # HasObjectCommand      ::  Can the command target units or features       --
-- # HasPositionCommand    ::  Can the command target a map position          --
-- # IsObjectCommand       ::  Does the command target a unit or feature      --
-- # IsPositionCommand     ::  Does the command target a map position         --
-- # GetObjectIndex        ::  Get the parameter index of the object target   --
-- # GetObjectID           ::  Get the object id of the command target        --
-- # GetGuardeeID          ::  Get the guardee target id of the guarding unit --
-- # GetPositionIndex      ::  Get the parameter index of the position target --
-- # GetPosition           ::  Get the xyz coordinates of the command target  --
-- # GetInsertedCommand    ::  Get the command inside of a CMD_INSERT         --
-- # RemoveEnqueueOptions  ::  Replace command options that would enqueue it  --
-- # RemoveInsertOptions   ::  Replace command optoins that would insert it   --
--------------------------------------------------------------------------------

local COMMAND_PARAM_COUNT = 5
local COMMAND_PARAM_COUNT_MAX = 8

--------------------------------------------------------------------------------
-- CMD and CMDTYPE -------------------------------------------------------------

-- mmk rewrite this in a comprehensible order
-- 1. game cmd and cmdtype stuff
-- 2. add more into to the cmdtype, get our paramsType
-- 3. the rest

---Map CMD onto CMDTYPE.
---@type table<CMD, CMDTYPE>
local commandToCmdType = {

}

--------------------------------------------------------------------------------
-- Parameter types and counts --------------------------------------------------

local function rangeSet(min, max)
	local tbl = {}
	for i = min, max do tbl[i] = true end
	return tbl
end

local any = rangeSet(0, COMMAND_PARAM_COUNT_MAX)
local none = {}

---Allowed parameter counts per command parameter type.
--
-- For example, a command that accepts unit id's or map positions accepts counts
-- of either 1 or 3, like so:
--
-- `ExampleType = { [1] = true, [3] = true }`
--
-- #### Note:
--
-- These parameter counts don't match the engine's `CMDTYPE` parameter counts,
-- since the engine is actually more permissive than it advertises. For example,
-- CMD_FIGHT says it accepts only 3 or 6 params, but can also accept 1 param.
--
-- Since we are not stuck using those counts, though, we can add more informtion
-- to our parameter sets by specifying more than just the data type.
--
-- For example, the paramsType entry `WorkerTask` helps to specify what kind of
-- units can accept that order (builders in general) and what kind of radius
-- test we should use to validate the target (buildRadius + modelRadius) without
-- also checking the command id.
---@type table<string, table<0|1|2|3|4|5|6|7|8, true>>
local paramsType = {
	Insert            = rangeSet(3, 3 + COMMAND_PARAM_COUNT),
	Remove            = rangeSet(0, COMMAND_PARAM_COUNT_MAX),

	NoParameters      = { [0] = true },

	Mode              = { [1] = true },
	Number            = { [1] = true },

	MapPoint          = { [3] = true },
	MapArea           = { [4] = true },
	MapPointOrArea    = { [3] = true, [4] = true }, -- [3] := point, [4] := area
	MapPointLeash     = { [3] = true, [4] = true }, -- [3] := point, [4] := point, leash radius
	MapPointFront     = { [3] = true, [6] = true }, -- [3] := point, [6] := middle point, right point
	MapPointFacing    = { [3] = true, [4] = true }, -- [3] := point, [4] := point, facing

	TargetObject      = { [1] = true },
	TargetAllyUnit    = { [1] = true },
	TargetEnemyUnit   = { [1] = true },

	TargetOrPoint     = { [1] = true, [3] = true },          -- [1] := id, [3] := point
	TargetOrArea      = { [1] = true, [4] = true },          -- [1] := id, [4] := area
	TargetOrFront     = { [1] = true, [3] = true, [6] = true }, -- [1] := id, [3] := point, [6] := middle point, right point
	TargetOrRectangle = { [1] = true, [3] = true, [6] = true }, -- [1] := id, [6] := rectangle

	WorkerTask        = { [1] = true, [4] = true, [5] = true }, -- [1] := id, [4] := area, [5] := id, point, leash radius
}

paramsType = setmetatable(paramsType, {
	-- Unregistered commands have no restrictions
	-- except that they obey the max param count.
	__index = function(self, key)
		return any
	end
})

---Maps every command to its accepted parameter counts.
---@type table<CMD, table<0|1|2|3|4|5|6|7|8, true>>
local commandParamsType = {
	[CMD.INSERT]          = paramsType.Insert,
	[CMD.REMOVE]          = paramsType.Remove,

	[CMD.STOP]            = paramsType.NoParameters,
	[CMD.GATHERWAIT]      = paramsType.NoParameters,
	[CMD.GROUPADD]        = paramsType.NoParameters,
	[CMD.GROUPCLEAR]      = paramsType.NoParameters,
	[CMD.GROUPSELECT]     = paramsType.NoParameters,
	[CMD.SELFD]           = paramsType.NoParameters,
	[CMD.STOCKPILE]       = paramsType.NoParameters, -- uses options
	[CMD.WAIT]            = paramsType.NoParameters,

	[CMD.FIRE_STATE]      = paramsType.Mode,
	[CMD.MOVE_STATE]      = paramsType.Mode,
	[CMD.AUTOREPAIRLEVEL] = paramsType.Mode,
	[CMD.CLOAK]           = paramsType.Mode,
	[CMD.IDLEMODE]        = paramsType.Mode,
	[CMD.ONOFF]           = paramsType.Mode,
	[CMD.REPEAT]          = paramsType.Mode,
	[CMD.TRAJECTORY]      = paramsType.Mode,

	[CMD.SQUADWAIT]       = paramsType.Number,
	[CMD.TIMEWAIT]        = paramsType.Number,

	[CMD.MANUALFIRE]      = paramsType.MapPoint,
	[CMD.PATROL]          = paramsType.MapPoint,
	[CMD.RESTORE]         = paramsType.MapPoint,
	[CMD.SETBASE]         = paramsType.MapPoint,
	[CMD.UNLOAD_UNIT]     = paramsType.MapPoint,

	[CMD.MOVE]            = paramsType.MapPointFront,

	[CMD.AREA_ATTACK]     = paramsType.MapArea,
	[CMD.UNLOAD_UNITS]    = paramsType.MapArea,

	[CMD.GUARD]           = paramsType.TargetAllyUnit,
	[CMD.LOAD_ONTO]       = paramsType.TargetAllyUnit,

	[CMD.ATTACK]          = paramsType.TargetOrPoint,

	[CMD.LOAD_UNITS]      = paramsType.TargetOrArea,

	[CMD.CAPTURE]         = paramsType.WorkerTask,
	[CMD.RECLAIM]         = paramsType.WorkerTask,
	[CMD.REPAIR]          = paramsType.WorkerTask,
	[CMD.RESURRECT]       = paramsType.WorkerTask,

	-- While we won't *receive* CMD_FIGHT with a target, we
	-- can issue it with no problems (gets cast to ATTACK):
	[CMD.FIGHT]           = paramsType.TargetOrFront,

	[CMD.DEATHWAIT]       = paramsType.TargetOrRectangle,
}

commandParamsType = setmetatable(commandParamsType, {
	__index = function(self, key)
		-- Build orders use negative unitDefID as commandID:
		return key < 0 and paramsType.MapPointFacing or none
	end
})

--------------------------------------------------------------------------------
-- Target parameter index ------------------------------------------------------

---Contains the parameter index position of the command's target id.
---
---Used only for processing engine commands and registering game commands.
---@type table<string, table<1|2|3|4|5|6|7|8, 1|2|3|4|5|6|7|8>>
local paramsTargetIndex = {
	TargetObject      = { [1] = 1 },
	TargetAllyUnit    = { [1] = 1 },
	TargetEnemyUnit   = { [1] = 1 },

	TargetOrPoint     = { [1] = 1 },
	TargetOrArea      = { [1] = 1 },
	TargetOrFront     = { [1] = 1 },
	TargetOrRectangle = { [1] = 1 },

	WorkerTask        = { [1] = 1, [5] = 1 },
}

paramsTargetIndex = setmetatable(paramsTargetIndex, {
	__index = function(self, key)
		return none
	end
})

---Maps commands and their param counts to the index position of a target id.
---@type table<CMD, table<integer, integer>>
local commandParamsTargetIndex = {}

commandParamsTargetIndex = setmetatable(commandParamsTargetIndex, {
	__index = function(self, key)
		return none
	end
})

-- Use an intermediate table to populate the target param index lookup:
local paramCountsToTargetIndex = {}
for typeName, indexMap in pairs(paramsTargetIndex) do
	paramCountsToTargetIndex[paramsType[typeName]] = indexMap
end

for command, paramCounts in pairs(commandParamsType) do
	commandParamsTargetIndex[command] = paramCountsToTargetIndex[paramCounts]
end

--------------------------------------------------------------------------------
-- Position parameter index ----------------------------------------------------

---Contains the parameter index position of the command's x coordinate.
---
---Used only for processing engine commands and registering game commands.
---@type table<string, table<1|2|3|4|5|6|7|8, 1|2|3|4|5|6|7|8>>
local paramsPositionIndex = {
	MapPoint          = { [3] = 1 },
	MapArea           = { [4] = 1 },
	MapPointOrArea    = { [3] = 1, [4] = 1 },
	MapPointLeash     = { [3] = 1, [4] = 1 },
	MapPointFront     = { [3] = 1, [6] = 1 },
	MapPointFacing    = { [3] = 1, [4] = 1 },

	TargetOrPoint     = { [3] = 1 },
	TargetOrArea      = { [1] = 1, [4] = 1 },
	TargetOrFront     = { [1] = 1, [3] = 1, [6] = 1 },
	TargetOrRectangle = { [3] = 1, [6] = 1 },

	WorkerTask        = { [4] = 1 },
}

paramsPositionIndex = setmetatable(paramsPositionIndex, {
	__index = function(self, key)
		return none
	end
})

---Maps commands and their param counts to the index position of an x coordinate.
---@type table<CMD, table<integer, integer>>
local commandParamsPositionIndex = {}

commandParamsPositionIndex = setmetatable(commandParamsPositionIndex, {
	__index = function(self, key)
		return none
	end
})

-- Use an intermediate table to populate the target param index lookup:
local paramCountsToPositionIndex = {}
for typeName, indexMap in pairs(paramsPositionIndex) do
	paramCountsToPositionIndex[paramsType[typeName]] = indexMap
end

for command, paramCounts in pairs(commandParamsType) do
	commandParamsPositionIndex[command] = paramCountsToPositionIndex[paramCounts]
end

--------------------------------------------------------------------------------
-- Command categories ----------------------------------------------------------

local queuingCommand = {}

local waitingCommand = {
	[CMD.WAIT]      = true,
	[CMD.DEATHWAIT] = true,
	[CMD.SQUADWAIT] = true,
	[CMD.TIMEWAIT]  = true,
}

do
	local isNonQueuing = {
		-- Much shorter list:
		[CMD.STOP]            = true,
		[CMD.REMOVE]          = true,
		[CMD.SELFD]           = true,

		[CMD.FIRE_STATE]      = true,
		[CMD.MOVE_STATE]      = true,
		[CMD.AUTOREPAIRLEVEL] = true,
		[CMD.CLOAK]           = true,
		[CMD.IDLEMODE]        = true,
		[CMD.ONOFF]           = true,
		[CMD.REPEAT]          = true,
		[CMD.STOCKPILE]       = true,
		[CMD.TRAJECTORY]      = true,

		[CMD.GROUPADD]        = true,
		[CMD.GROUPCLEAR]      = true,
		[CMD.GROUPSELECT]     = true,
	}

	for command in pairs(commandParamsType) do
		if not isNonQueuing[command] then
			queuingCommand[command] = true
		end
	end

	isNonQueuing = nil
end

--------------------------------------------------------------------------------
-- Engine type mapping ---------------------------------------------------------

-- This is partly a check on the above, partly because it's often preferable to
-- use the same terminology as the engine when working on the game-side code.

---Map paramsType onto CMDTYPE.
---@type table<string, CMDTYPE>
local paramsTypeToCmdType = {
	NoParameters      = CMDTYPE.ICON,

	Mode              = CMDTYPE.ICON_MODE,
	Number            = CMDTYPE.NUMBER,

	MapPoint          = CMDTYPE.ICON_MAP,
	MapArea           = CMDTYPE.ICON_AREA,
	MapPointOrArea    = CMDTYPE.ICON_AREA, -- idk
	MapPointLeash     = CMDTYPE.ICON_AREA, -- idk
	MapPointFront     = CMDTYPE.ICON_FRONT,
	MapPointFacing    = CMDTYPE.ICON_BUILDING, -- idk

	TargetObject      = CMDTYPE.ICON_UNIT,
	TargetAllyUnit    = CMDTYPE.ICON_UNIT,
	TargetEnemyUnit   = CMDTYPE.ICON_UNIT,

	TargetOrPoint     = CMDTYPE.ICON_UNIT_OR_MAP,
	TargetOrArea      = CMDTYPE.ICON_UNIT_FEATURE_OR_AREA, -- or ICON_OR_AREA
	-- TargetOrFront     = CMDTYPE.ICON_UNIT_OR_RECTANGLE, -- no map
	TargetOrRectangle = CMDTYPE.ICON_UNIT_OR_RECTANGLE,

	WorkerTask        = CMDTYPE.ICON_UNIT_FEATURE_OR_AREA,
}

--------------------------------------------------------------------------------
-- Command management ----------------------------------------------------------

local CMD = CMD
local GameCMD = GameCMD ---@diagnostic disable-line

---Add a game command to the GameCMD global table and configure its usage.
---
---Example:
---`RegisterCommand(33333, 'DANCE_PARTY', 'TargetOrRectangle', true, false)`
---@param command integer
---@param name string
---@param paramsTypeName string?
---@param queues boolean?
---@param waits boolean?
---@return boolean registered
---@return integer? commandID
Commands.RegisterCommand = function(command, name, paramsTypeName, queues, waits)
	---@diagnostic disable-next-line: cast-local-type
	name, command = tostring(name), tonumber(command)

	if name == nil or command == nil or command < 30000 then
		return false
	end

	for _, c in ipairs { CMD, GameCMD } do
		if c[name] ~= nil or c[command] ~= nil or table.getKeyOf(c, command) ~= nil then
			return false
		end
	end

	GameCMD[name] = command
	GameCMD[command] = name

	-- todo: This is supposed to help integrate existing gadgets,
	-- todo: but it really does defeat the purpose of *this* code:
	if paramsTypeName ~= nil and paramsType[paramsTypeName] then
		commandParamsType[command] = paramsType[paramsTypeName]
	else
		local m = ('Registered command without param info: %s (%d)'):format(name, command)
		Spring.Echo(m)
	end

	if queues == true then
		queuingCommand[command] = true
	end

	if waits == true then
		waitingCommand[command] = true
	end

	return true, command
end

---Add a parameter set to the Commands module and configure its usage.
---
---Example:
---`RegisterParamsType('RoundedRectangle', {[6]=true, [7]=true}, nil, {[6]=1, [7]=5})`
---@param name string requires a unique name
---@param counts table<integer,true> hash set of valid parameter counts (at least one)
---@param targetIndex table<integer,integer> map of valid parameter counts to targetID param index
---@param positionIndex table<integer,integer> map of valid parameter counts to x-coord param index
---@return boolean
Commands.RegisterParamsType = function(name, counts, targetIndex, positionIndex)
	if paramsType[name] or type(counts) ~= "table" or next(counts) == nil then
		return false
	end

	local numParameterSets = 0

	for index, value in pairs(counts) do
		if type(index) ~= "number" or math.round(index) ~= index or value ~= true then
			return false
		else
			numParameterSets = numParameterSets + 1
		end
	end

	if numParameterSets == 0 then
		return false
	end

	paramsType[name] = counts

	if targetIndex ~= nil and next(targetIndex) ~= nil then
		local ti = {}

		for paramCount, index in pairs(targetIndex) do
			if index > paramCount then
				paramsType[name] = nil
				return false
			end

			ti[paramCount] = index
		end

		paramsTargetIndex[name] = ti
		paramCountsToTargetIndex[paramsType[name]] = ti
	end

	if positionIndex ~= nil and next(positionIndex) ~= nil then
		local pi = {}

		for paramCount, index in pairs(positionIndex) do
			if index > paramCount then
				paramsType[name] = nil
				return false
			end

			pi[paramCount] = index
		end

		paramsPositionIndex[name] = pi
		paramCountsToPositionIndex[paramsType[name]] = pi
	end

	return true
end

--------------------------------------------------------------------------------
-- Command processing ----------------------------------------------------------

---@param command CMD?
Commands.IsQueueCommand = function(command)
	return queuingCommand[command] ~= nil
end

---@param command CMD?
Commands.IsWaitCommand = function(command)
	return waitingCommand[command] ~= nil
end

---@param command CMD?
Commands.HasObjectCommand = function(command)
	return commandParamsTargetIndex[command] ~= none
end

---@param command CMD?
---@param params number[]
Commands.IsObjectCommand = function(command, params)
	return commandParamsTargetIndex[command][#params] ~= nil
end

---@param command CMD?
Commands.HasPositionCommand = function(command)
	return commandParamsPositionIndex[command] ~= none
end

---@param command CMD?
---@param params number[]
Commands.IsPositionCommand = function(command, params)
	return commandParamsPositionIndex[command][#params] ~= nil
end

---Get the params index of the command's target, if any.
---@param command CMD?
---@param params number[]
---@return integer?
Commands.GetObjectIndex = function(command, params)
	return commandParamsTargetIndex[command][#params]
end

---Get the target id of a command, if any.
---@param command CMD?
---@param params number[]
---@return integer?
Commands.GetObjectID = function(command, params)
	local index = commandParamsTargetIndex[command][#params]

	if index ~= nil then
		return params[index]
	end
end

---Get the unitID of the target of CMD_GUARD, if any.
---@param unitID integer
---@param index integer?
---@return integer?
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

---Get the params index of the command's target coordinates, if any.
---@param command CMD?
---@param params number[]
---@return integer?
Commands.GetPositionIndex = function(command, params)
	return commandParamsPositionIndex[command][#params]
end

---Get the target coordinates of a command, if any.
---@param command CMD?
---@param params number[]
---@return number? xpos
---@return number? ypos
---@return number? zpos
Commands.GetPosition = function(command, params)
	local index = commandParamsPositionIndex[command][#params]

	if index ~= nil then
		return params[index], params[index + 1], params[index + 2]
	end
end

---Retrieve the command info inside of CMD_INSERT.
---@param params number[]
---@return CMD command
---@return number|number[] commandParams
---@return integer insertIndex
Commands.GetInsertedCommand = function(params)
	if #params < 5 then
		return p[2], p[4], p[1] -- avoid tables
	else
		return p[2], { p[4], p[5], p[6], p[7], p[8] }, p[1]
	end
end

---Remove command options that would place the command later in the queue.
---
---When changing options within a callin, like AllowCommand, set the `copy` flag.
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
---
---When changing options within a callin, like AllowCommand, set the `copy` flag.
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

return Commands
