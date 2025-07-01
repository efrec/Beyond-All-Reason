--------------------------------------------------------------------------------
-- Common configuration data and functions for processing RecoilEngine commands.
local Commands = {}

-- Depending on our environment/init:
if not Spring or not CMD or not Game or not Game.CustomCommands then return end

local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMD = CMD
local GameCMD = Game.CustomCommands.GameCMD

local paramsType -- fix for lexical scope; see below

--------------------------------------------------------------------------------
-- Module configuration --------------------------------------------------------

-- Edit this and nothing else. The configuration table is consumed during init.
-- Ideally, really, this would exist in its own, untouchable configuration file.

---Maps every command to its accepted parameter counts.
---@type table<CMD, table<(0|1|2|3|4|5|6|7|8), true>>
local commandToParamsTypeConfig = {
	[CMD.INSERT]          = paramsType.Insert, -- special
	[CMD.REMOVE]          = paramsType.Remove, -- special

	[CMD.STOP]            = paramsType.NoParameters,
	[CMD.GATHERWAIT]      = paramsType.NoParameters,
	[CMD.GROUPADD]        = paramsType.NoParameters,
	[CMD.GROUPCLEAR]      = paramsType.NoParameters,
	[CMD.GROUPSELECT]     = paramsType.NoParameters,
	[CMD.SELFD]           = paramsType.NoParameters,
	[CMD.STOCKPILE]       = paramsType.NoParameters,

	[CMD.FIRE_STATE]      = paramsType.Mode,
	[CMD.MOVE_STATE]      = paramsType.Mode,
	[CMD.AUTOREPAIRLEVEL] = paramsType.Mode,
	[CMD.CLOAK]           = paramsType.Mode,
	[CMD.IDLEMODE]        = paramsType.Mode,
	[CMD.ONOFF]           = paramsType.Mode,
	[CMD.REPEAT]          = paramsType.Mode,
	[CMD.TRAJECTORY]      = paramsType.Mode,

	[CMD.WAIT]            = paramsType.ModeOrCycle,

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

	-- While we won't *receive* CMD_FIGHT with a target, we
	-- can issue it with no problems (casts to CMD_ATTACK):
	[CMD.FIGHT]           = paramsType.TargetOrFront,

	-- Seems to allow waiting until an area has been cleared of enemies?
	-- I did the reading but moved on quickly so I do not remember.
	[CMD.DEATHWAIT]       = paramsType.TargetOrRectangle,

	[CMD.CAPTURE]         = paramsType.WorkerTask,
	[CMD.RECLAIM]         = paramsType.WorkerTask,
	[CMD.REPAIR]          = paramsType.WorkerTask,
	[CMD.RESURRECT]       = paramsType.WorkerTask,
}

--------------------------------------------------------------------------------
-- Command introspection (non-configuration) -----------------------------------

-- Do not edit any of this except to reflect engine changes.

local COMMAND_PARAM_COUNT = 5
local COMMAND_PARAM_COUNT_MAX = 8

---@return table<(0|1|2|3|4|5|6|7|8), true>
local function rangeSet(min, max)
	min = math.max(min, 0)
	max = math.min(max, COMMAND_PARAM_COUNT_MAX)

	local tbl = table.new(max - min + 1, 0)

	for i = min, max do
		tbl[i] = true
	end

	return tbl
end

local any = rangeSet(0, COMMAND_PARAM_COUNT_MAX)
local none = {}

-- Parameter types and counts --------------------------------------------------

---Combinations of parameter counts, types, and additional context.
--
-- These `paramsType` values extend the engine's `CMDTYPE`s to include any extra
-- parameter counts that certain commands can accept and to add extra context.
--
-- Some commands can receive more param counts (via lua) than they ordinarily
-- will issue themselves via the engine; e.g., CMD_FIGHT can receive 1 param.
--
-- Extra param count example:
-- - `CMD_FIGHT` is type `CMD_ICON_FRONT`, which accepts #params = 3 or 6.
--    However, it also can accept #params = 1.
--
-- Context example:
-- - `WorkerTask` uses the *build radius* to check range.
---@type table<string, table<(0|1|2|3|4|5|6|7|8), true>>
paramsType = {
	Insert            = rangeSet(3, 3 + COMMAND_PARAM_COUNT),
	Remove            = rangeSet(1, COMMAND_PARAM_COUNT_MAX),

	NoParameters      = { [0] = true },

	Mode              = { [1] = true },
	ModeOrCycle       = { [0] = true, [1] = true }, -- vroom vroom
	Number            = { [1] = true },

	MapPoint          = { [3] = true },
	MapArea           = { [4] = true },
	MapPointOrArea    = { [3] = true, [4] = true }, -- [3] := point, [4] := area
	MapPointFacing    = { [3] = true, [4] = true }, -- [3] := point, [4] := point, facing
	MapPointLeash     = { [3] = true, [4] = true }, -- [3] := point, [4] := point, leash radius
	MapPointFront     = { [3] = true, [6] = true }, -- [3] := point, [6] := middle point, right point

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

-- speedup:
local PRMTYPE_MAP_POINT_FACING = paramsType.MapPointFacing

-- With commands mapped to parameter counts and types (context slightly useless),
-- we can set up automatic tables to use as lookups for the values we might want:
-- - target coordinates in params (and their base index)
-- - target coordinate pairs in params (and their base index)
-- - target object id in params (and its index)

-- Target parameter index ------------------------------------------------------

---Contains the parameter index position of the command's target id.
---@type table<string, table<(1|2|3|4|5|6|7|8), (1|2|3|4|5|6|7|8)>>
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

-- Position parameter index ----------------------------------------------------

---Contains the parameter index position of the command's x coordinate.
---@type table<string, table<(1|2|3|4|5|6|7|8), (1|2|3|4|5|6|7|8)>>
local paramsPositionIndex = {
	MapPoint       = { [3] = 1 },
	MapArea        = { [4] = 1 },
	MapPointOrArea = { [3] = 1, [4] = 1 },
	MapPointLeash  = { [3] = 1, [4] = 1 },
	MapPointFront  = { [3] = 1, [6] = 1 }, -- [3] := point, [6] := middle point, right point
	MapPointFacing = { [3] = 1, [4] = 1 },

	TargetOrPoint  = { [3] = 1 },
	TargetOrArea   = { [4] = 1 },
	TargetOrFront  = { [3] = 1, [6] = 1 }, -- [3] := point, [6] := middle point, right point
	-- TargetOrRectangle = { [3] = 1 }, -- Does not represent a "target" point.

	WorkerTask     = { [4] = 1, [5] = 2 }, -- [4] := area, [5] := id, point, leash radius
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

-- Point pair parameter index --------------------------------------------------

---Contains the parameter index positions of the command's two x coordinates.
---@type table<string, table<(1|2|3|4|5|6|7|8), (1|2|3|4|5|6|7|8)[]>>
local paramsPointPairIndex = {
	MapPointFront     = { [6] = { 1, 4 } },
	TargetOrFront     = { [6] = { 1, 4 } },
	TargetOrRectangle = { [6] = { 1, 4 } },
}

paramsPointPairIndex = setmetatable(paramsPointPairIndex, {
	__index = function(self, key)
		return none
	end
})

---Maps commands and their param counts to the index positions of two x coordinates.
---@type table<CMD, table<integer, integer[]>>
local commandParamsPointPairIndex = {}

commandParamsPointPairIndex = setmetatable(commandParamsPointPairIndex, {
	__index = function(self, key)
		return none
	end
})

-- Use an intermediate table to populate the target param index lookup:
local paramCountsToPointPairIndex = {}

for typeName, indexMap in pairs(paramsPointPairIndex) do
	paramCountsToPointPairIndex[paramsType[typeName]] = indexMap
end

-- Radius parameter index ------------------------------------------------------

---Contains the parameter index position of the command's target radius.
---@type table<string, table<(1|2|3|4|5|6|7|8), (1|2|3|4|5|6|7|8)>>
local paramsRadiusIndex = {
	MapArea        = { [4] = 4 },
	MapPointOrArea = { [4] = 4 },
	TargetOrArea   = { [4] = 4 },
}

paramsRadiusIndex = setmetatable(paramsRadiusIndex, {
	__index = function(self, key)
		return none
	end
})

---Maps commands and their param counts to the index position of a target radius.
---@type table<CMD, table<integer, integer>>
local commandParamsRadiusIndex = {}

commandParamsRadiusIndex = setmetatable(commandParamsRadiusIndex, {
	__index = function(self, key)
		return none
	end
})

-- Use an intermediate table to populate the target param index lookup:
local paramCountsToRadiusIndex = {}

for typeName, indexMap in pairs(paramsRadiusIndex) do
	paramCountsToRadiusIndex[paramsType[typeName]] = indexMap
end

-- Leash radius parameter index ------------------------------------------------

---Contains the index position of the leash radius around the command's target.
---@type table<string, table<(1|2|3|4|5|6|7|8), (1|2|3|4|5|6|7|8)>>
local paramsLeashIndex = {
	MapPointLeash = { [4] = 4 },
	WorkerTask    = { [4] = 4, [5] = 5 },
}

paramsLeashIndex = setmetatable(paramsLeashIndex, {
	__index = function(self, key)
		return none
	end
})

---Maps commands and their param counts to the index position of a target radius.
---@type table<CMD, table<integer, integer>>
local commandParamsLeashIndex = {}

commandParamsLeashIndex = setmetatable(commandParamsLeashIndex, {
	__index = function(self, key)
		return none
	end
})

-- Use an intermediate table to populate the target param index lookup:
local paramCountsToLeashIndex = {}

for typeName, indexMap in pairs(paramsLeashIndex) do
	paramCountsToLeashIndex[paramsType[typeName]] = indexMap
end

--------------------------------------------------------------------------------
-- Command auto configuration --------------------------------------------------

-- Allows new commands to be added to the configs via GameCMD and receive their
-- appropriate parameter counts, types, and indexes.

---Maps every command to its accepted parameter counts.
---@type table<CMD, table<(0|1|2|3|4|5|6|7|8), true>>
local commandParamsType = setmetatable({}, {
	__newindex = function(self, command, paramsCounts)
		commandParamsTargetIndex[command] = paramCountsToTargetIndex[paramsCounts]
		commandParamsPositionIndex[command] = paramCountsToPositionIndex[paramsCounts]
		commandParamsPointPairIndex[command] = paramCountsToPointPairIndex[paramsCounts]
		commandParamsRadiusIndex[command] = paramCountsToRadiusIndex[paramsCounts]
		commandParamsLeashIndex[command] = paramCountsToLeashIndex[paramsCounts]
	end,

	__index = function(self, command)
		return command < 0 and PRMTYPE_MAP_POINT_FACING or none
	end
})

-- Populate the params index tables.
for command, paramsCounts in pairs(commandToParamsTypeConfig) do
	commandParamsType[command] = paramsCounts
end

-- Command categories ----------------------------------------------------------

-- todo: dunno

local friendlyCommands = {
	[CMD.RESTORE]      = true,
	[CMD.RESURRECT]    = true,
	[CMD.LOAD_UNITS]   = true,
	[CMD.UNLOAD_UNIT]  = true,
	[CMD.UNLOAD_UNITS] = true,
	[CMD.GUARD]        = true,
}

friendlyCommands = setmetatable(friendlyCommands, {
	__index = function(self, command)
		if command < 0 then return true end
	end
})

local hostileCommands = {
	[CMD.MOVE]        = true,
	[CMD.ATTACK]      = true,
	[CMD.MANUALFIRE]  = true,
	[CMD.CAPTURE]     = true,
	[CMD.RECLAIM]     = true,
	[CMD.AREA_ATTACK] = true,
	[CMD.FIGHT]       = true,
	[CMD.PATROL]      = true,
}

local moveCommands = {
	[CMD.MOVE]         = true,
	[CMD.ATTACK]       = true,
	[CMD.MANUALFIRE]   = true,
	[CMD.CAPTURE]      = true,
	[CMD.RECLAIM]      = true,
	[CMD.RESTORE]      = true,
	[CMD.RESURRECT]    = true,
	[CMD.LOAD_UNITS]   = true,
	[CMD.UNLOAD_UNIT]  = true,
	[CMD.UNLOAD_UNITS] = true,
	[CMD.AREA_ATTACK]  = true,
	[CMD.FIGHT]        = true,
	[CMD.GUARD]        = true,
	[CMD.PATROL]       = true,
}

moveCommands = setmetatable(moveCommands, {
	__index = function(self, command)
		if command < 0 then return true end
	end
})

--------------------------------------------------------------------------------
-- Module interfacing ----------------------------------------------------------

local type_ = type -- fix clobber so we can have nice arg names

---Configures a new command description with very basic error detection.
--
-- Call this once at initialization per each game command that you implement.
---@todo: move to customcommands?
---@param code string
---@param type CMDTYPE
---@param params string[]?
---@param prmTypeName string? name of paramsType set, see commands.lua
---@param name string?
---@param action string?
---@param cursor string?
---@param texture string?
---@param tooltip string?
---@param disabled boolean?
---@param hidden boolean? important to set `true` for non-player-facing orders
---@param onlyTexture boolean?
---@param showUnique boolean?
---@param queueing boolean? important to set `false` for non-queued commands
---@return CommandDescription?
Commands.NewCommandDescription = function(code, type, params, prmTypeName,
										  name, action, cursor, texture, tooltip,
										  disabled, hidden, onlyTexture, showUnique, queueing)
	-- Game commands should be configured already in modules/customcommands.lua.
	code = code:gsub("^CMD_", "")
	local command = GameCMD[code]
	local cmdType = type_(type) == "string" and CMDTYPE[type] or type

	-- Errors should be loud enough to prevent being ignored but not testing.
	if not GameCMD[code:gsub("^CMD_", "")] then
		Spring.Log('CMD', LOG.ERROR, "Game commands must be configured in modules/customcommands.lua: " .. tostring(code))
		return
	elseif CMD[code] then
		Spring.Log('CMD', LOG.ERROR, "Game command code conflicts with an engine CMD code: " .. tostring(code))
		return
	elseif not CMDTYPE[type] then
		Spring.Log('CMD', LOG.ERROR, "Game command's cmdType not recognized: " .. tostring(type))
		return
	end

	if prmTypeName ~= nil then
		local paramsCounts = paramsType[prmTypeName]

		if paramsCounts == none then
			Spring.Log('CMD', LOG.ERROR, "Game command's prmType not recognized: " .. tostring(prmTypeName))
		else
			-- Add this command to the configurations in commands.lua:
			commandParamsType[command] = paramsCounts

			-- Some behaviors should be detected rather than configured
			-- so the behaviors are consistent in-game; but hard to say:
			if queueing and (
					commandParamsPositionIndex[command] ~= none or
					commandParamsPointPairIndex[command] ~= none)
			then
				moveCommands[command] = true
			end
		end
	end

	return {
		id          = command,
		type        = cmdType,
		params      = params,

		disabled    = disabled,
		hidden      = hidden,
		showUnique  = showUnique,
		queueing    = queueing,

		name        = name,
		action      = action,
		cursor      = cursor,
		tooltip     = tooltip,

		texture     = texture,
		onlyTexture = onlyTexture,
	}
end

---@diagnostic disable:duplicate-set-field -- ! overriding Spring functions

local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc

Spring.InsertUnitCmdDesc = function(unitID, cmdDesc, index)
	if not table.getKeyOf(GameCMD, cmdDesc.id) then
		Spring.Log('CMD', LOG.ERROR,
			"CmdDesc not recognized. Configure game commands in modules/customcommands.lua.")
		return
	end

	spInsertUnitCmdDesc(unitID, index or cmdDesc, index or nil)
end

---@diagnostic enable:duplicate-set-field -- ! overriding Spring functions

--------------------------------------------------------------------------------
-- Module internals ------------------------------------------------------------

local CMD_INSERT = CMD.INSERT
local CMD_REMOVE = CMD.REMOVE
local CMD_GUARD = CMD.GUARD
local CMD_UNLOAD_UNIT = CMD.UNLOAD_UNIT
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_WAIT = CMD.WAIT

local OPT_INTERNAL = CMD.OPT_INTERNAL

local FEATURE_BASE_INDEX = Game.maxUnits or 32000

---This kind of blind equality testing should be avoided in regular usage.
-- It makes sense in a lib where we cannot be sure what we are processing.
---@param params1 number|number[]?
---@param params2 number|number[]?
local function equalParams(params1, params2)
	if params1 == params2 then
		return true
	elseif type(params1) == "table" and type(params2) == "table" then
		return
			params1[1] == params2[1] and
			params1[2] == params2[2] and
			params1[3] == params2[3] and
			params1[4] == params2[4] and
			params1[5] == params2[5]
	else
		return false
	end
end

local repackParams
do
	local params = table.new(5, 0)

	repackParams = function(p1, p2, p3, p4, p5)
		local p = params
		p[1], p[2], p[3], p[4], p[5] = p1, p2, p3, p4, p5
		return p
	end
end

local bit_and = math.bit_and

local function isInternal(options)
	return bit_and(options, OPT_INTERNAL) ~= 0
end

local function getObjectPosition(objectID)
	if objectID < FEATURE_BASE_INDEX then
		return Spring.GetUnitPosition(objectID)
	else
		return Spring.GetFeaturePosition(objectID - FEATURE_BASE_INDEX)
	end
end

--------------------------------------------------------------------------------
-- Order functions -------------------------------------------------------------

-- Orders are commands as they are issued to units and before they are accepted.

-- Various widgets will need to issue pseudo-orders during pregame placement:
local pregame = Spring and Spring.GetGameFrame and Spring.GetGameFrame() <= 0

---Retrieve the command info from the params of a CMD_INSERT.
---@param params number[]|number
---@return CMD command
---@return number[]|number? commandParams
---@return integer commandOptions
---@return integer insertIndex
Commands.GetInsertedCommand = function(params)
	return
		params[2], ---@diagnostic disable-line: return-type-mismatch -- CMD/integer
		#params < 5 and params[4] or { params[4], params[5], params[6], params[7], params[8] },
		params[3],
		params[1]
end

local getInsertedCommand = Commands.GetInsertedCommand

---Retrieve the actual command from an order, resolving any meta-commands passed.
---@param command CMD
---@param params number[]|number?
---@return CMD? command
---@return number[]|number? commandParams
---@return integer? commandOptions
---@return integer? insertIndex
Commands.ResolveCommand = function(command, params)
	if command == CMD_INSERT then
		---@diagnostic disable-next-line: param-type-mismatch -- Should throw on nil.
		return getInsertedCommand(params)
	else
		return command, params
	end
end

---Push the orders sent to a unit to its command queue through blockers like CMD_WAIT.
---@param unitID integer
Commands.FlushOrders = function(unitID)
	-- todo: Are there other commands that do this? CMD.TIMEWAIT?
	spGiveOrderToUnit(unitID, CMD_WAIT) -- toggle once
	spGiveOrderToUnit(unitID, CMD_WAIT) -- toggle twice
end

local flushOrders = Commands.FlushOrders

--------------------------------------------------------------------------------
-- Command functions -----------------------------------------------------------

-- Commands are orders that have been accepted by the unit, actively or not.

---Check if the unit is executing a given command, including no command.
---@param unitID integer
---@param cmdID CMD?
---@param params number[]|number?
---@param index integer? default = 0 (start of command queue)
---@return boolean
Commands.isInCommand = function(unitID, cmdID, params, index)
	if index == nil then
		index = 0
	end

	-- The engine and other gadgets can reject or modify the orders we issue.
	-- The only way to know is through checking and verifying the new result.
	local command, options, _, p1, p2, p3, p4, p5 = spGetUnitCurrentCommand(unitID, index)

	while true do
		if cmdID == command and equalParams(params, repackParams(p1, p2, p3, p4, p5)) then
			return true
		elseif command == nil or isInternal(options) then
			return false
		else
			-- Orders can be inserted internally in front of a valid command;
			-- e.g., reclaiming a feature that is blocking a new build order.
			index = index + 1 -- so keep looking
			command, options, _, p1, p2, p3, p4, p5 = spGetUnitCurrentCommand(unitID, index)
		end
	end
end

local isInCommand = Commands.isInCommand

---Issue an order and test if the command was accepted.
--
-- __Note:__ This does not handle enqueued commands. It checks only the front of the command queue.
---@param unitID integer
---@param command CMD
---@param params number[]|number?
---@param options CommandOptions|integer?
Commands.TryGiveOrder = function(unitID, command, params, options)
	return spGiveOrderToUnit(unitID, command, params, options) and
		isInCommand(unitID, command, params)
end

---Get the unitID of the target of CMD_GUARD, if any.
---@param unitID integer
---@param commandIndex integer? default = 1
---@return integer? guardeeID
Commands.GetGuardeeID = function(unitID, commandIndex)
	while true do
		local command, options, _, maybeUnitID = spGetUnitCurrentCommand(unitID, commandIndex)

		if command == CMD_GUARD then
			return maybeUnitID
		elseif command ~= nil and isInternal(options) then
			commandIndex = commandIndex + 1
		else
			return
		end
	end
end

---Gets the xyz coordinates of a command's target, whether a position or object.
---@param command CMD
---@param params number[]
---@return number? x
---@return number? y
---@return number? z
Commands.GetCommandPosition = function(command, params, ignoreTargets)
	if not ignoreTargets then
		-- There is only one way to have a target id, so try that first.
		local targetIndex = commandParamsTargetIndex[command][#params]

		if targetIndex ~= nil then
			return getObjectPosition(params[targetIndex])
		end
	end

	-- Then, check if the params contain the position already.
	local coordsIndex = commandParamsPositionIndex[command][#params]

	if coordsIndex == nil then
		local pair = commandParamsPointPairIndex[command][#params]

		if pair ~= nil then
			coordsIndex = pair[1]
		end
	end

	if coordsIndex ~= nil then
		return params[coordsIndex], params[coordsIndex + 1], params[coordsIndex + 2]
	end
end

local getCommandPosition = Commands.GetCommandPosition

---Gets the xyzw coordinates of a command's target, where w is an area radius.
---@param command CMD
---@param params number[]
---@return number? x
---@return number? y
---@return number? z
---@return number? w [nil] := command has no area param
Commands.GetCommandArea = function(command, params)
	local x, y, z = getCommandPosition(command, params)

	local paramsRadius = commandParamsRadiusIndex[command]

	if paramsRadius ~= none then
		local index = paramsRadius[#params]
		return x, y, z, (index ~= nil and params[index] or 0)
	else
		return x, y, z
	end
end

local getCommandArea = Commands.GetCommandArea

---Gets the xyzw coordinates of a command's target, where w is a leash radius.
---@param command CMD
---@param params number[]
---@return number? x
---@return number? y
---@return number? z
---@return number? w [nil] := command has no area param
Commands.GetCommandLeash = function(command, params)
	local x, y, z = getCommandPosition(command, params)

	local paramsLeash = commandParamsLeashIndex[command]

	if paramsLeash ~= none then
		local index = paramsLeash[#params]
		return x, y, z, (index ~= nil and params[index] or 0)
	else
		return x, y, z
	end
end

local getCommandLeash = Commands.GetCommandLeash

---Gets the xyzw coordinates of a command's target, where w is a leash radius.
---@param command CMD
---@param params number[]
---@return number? x
---@return number? y
---@return number? z
---@return number? w [nil] := command has no area param
---@return boolean? leashed [true] := radius is a leash radius, not an area radius
Commands.GetCommandPositionAndRadius = function(command, params)
	local x, y, z = getCommandPosition(command, params)

	local paramsRadius = commandParamsRadiusIndex[command]

	if paramsRadius ~= none then
		local index = paramsRadius[#params]
		return x, y, z, (index ~= nil and params[index] or 0), false
	end

	local paramsLeash = commandParamsLeashIndex[command]

	if paramsLeash ~= none then
		local index = paramsLeash[#params]
		return x, y, z, (index ~= nil and params[index] or 0), true
	end

	return x, y, z
end

local getCommandPositionAndRadius = Commands.GetCommandPositionAndRadius

---comment
---@param command any
---@param params any
---@param x any
---@param y any
---@param z any
---@param range any
---@param all any
---@return any
---@return any
---@return any
Commands.GetNextMoveGoal = function(command, params, x, y, z, range, all)
	if command ~= nil and (all or moveCommands[command]) then
		-- Move goals with an area radius have to cover the entire area (potentially)
		-- vs a leash radius which only requires reaching the nearest point (usually)
		local x2, y2, z2, radius, leashed = getCommandPositionAndRadius(command, params)

		if x2 ~= nil then
			if radius == nil then
				radius = range
			end

			if radius == nil or radius <= 10 then
				-- Close enough.
				x, y, z = x2, y2, z2
			else
				local dx = x2 - x
				local dy = y2 - y
				local dz = z2 - z
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

				if leashed then
					-- Get the nearest point on the sphere.
					if distance <= radius + 10 then
						-- Already inside the leash radius.
						x, y, z = x2, y2, z2
					else
						x = x + dx * distance / radius
						y = y + dy * distance / radius -- todo: air, ship, etc. y-heights
						z = z + dz * distance / radius
					end
				else
					-- Get the furthest point on the sphere.
					if distance > 10 then
						x = x + dx + radius * dx / distance
						y = y + dy + radius * dy / distance -- todo: air, ship, etc. y-heights
						z = z + dz + radius * dz / distance
					end
				end
			end
		end
	end

	return x, y, z
end

local getNextMoveGoal = Commands.GetNextMoveGoal

--------------------------------------------------------------------------------
-- Command queue functions -----------------------------------------------------

---Skip the next `count` commands in the queue. Skips the current order by default.
--
-- __Can not__ be used to clear the build queue during pregame placement.
---@param unitID integer
---@param current boolean? default = true
---@param count integer? default = 1
---@see WG.pregame-build
Commands.SkipCommand = function(unitID, current, count)
	if count == nil then
		count = 1
	end

	if current ~= false then
		count = count + 1
	end

	local index = 1

	for _ = 1, count do
		local command, options, tag = spGetUnitCurrentCommand(unitID, index)
		local tags = {}

		repeat
			if command ~= nil then
				tags[#tags + 1] = tag

				if isInternal(options) then
					index = index + 1
					command, options, tag = spGetUnitCurrentCommand(unitID, index)
				else
					break
				end
			else
				break
			end
		until false

		if tags[1] ~= nil then
			if current ~= false then
				spGiveOrderToUnit(unitID, CMD_REMOVE, tags)
			else
				current = false
			end

			index = index + 1
		else
			return
		end
	end
end

-- `SkipCommand` has to handle the pregame build phase, as well.
-- Probably though, this should be an override used in commandq.
if pregame and WG then
	-- Temporary local that lasts until `pregame` ends:
	local function doSkipCommandPregame(current, count)
		pregame = Spring.GetGameFrame() <= 0

		if count == nil then
			count = 1
		end

		if current == nil then
			current = true
		end

		if pregame and WG["pregame-build"] then
			if count >= 1 and WG["pregame-build"] then
				local queue = WG["pregame-build"].getBuildQueue()
				local result = {}

				if not current then
					result[1] = queue[1]
				end

				local start = current and 2 or 1

				for i = start, math.min(start + count - 1, #queue) do
					result[#result + 1] = queue[i]
				end

				WG["pregame-build"].setBuildQueue(result)
			end

			return true
		else
			return false
		end
	end

	---Skip the next `count` commands in the build queue during pregame placement.
	---@see WG.pregame-build
	---@param current boolean? default = true
	---@param count integer? default = 1
	Commands.SkipCommandPregame = function(current, count)
		if pregame then
			return doSkipCommandPregame(current, count)
		else
			return false -- and you should unregister this fn
		end
	end
end

---Get the position of the unit's queued move commands (or all commands).
---@param unitID integer
---@param all boolean?
---@param count integer?
---@return xyz[] coords
---@return integer count
Commands.GetUnitPositionQueue = function(unitID, all, count)
	if all == nil then
		all = false
	end

	local moves = {}
	local num = 0

	if count == nil then
		count = all and 64 or 32
	elseif count < 1 and count ~= -1 then
		return moves, num
	end

	local queue = Spring.GetUnitCommands(unitID, count)

	for _, cmdInfo in ipairs(queue) do
		if all or moveCommands[cmdInfo.id] then
			local x, y, z = getCommandPosition(cmdInfo.id, cmdInfo.params)

			if x ~= nil then
				num = num + 1
				moves[num] = { x, y, z }
			end
		end
	end

	return moves, num
end

---Get the destination position of a unit's queued move commands (or all commands).
---@param unitID integer
---@param all boolean? default = false
---@return number x
---@return number y
---@return number z
Commands.GetUnitEndPosition = function(unitID, all)
	if all == nil then
		all = false
	end

	local index = -1

	repeat
		local command, _, _, p1, p2, p3, p4, p5 = spGetUnitCurrentCommand(unitID, index)
		local params = repackParams(p1, p2, p3, p4, p5)

		if command == nil then
			break
		elseif all or moveCommands[command] then
			local x, y, z = getCommandPosition(command, params)

			if x ~= nil then
				return x, y, z
			end
		end

		index = index - 1
	until false

	return Spring.GetUnitPosition(unitID)
end

---Get the position of the unit's queued move commands (or all commands) and the
-- radius within which those commands' move goals would be achieved. This allows
-- you to plot a shorter course through the commands or to combine overlaps etc.
---@param unitID integer
---@param all boolean?
---@param count integer?
---@return table coords <x, y, z, radius, leashed> where a leash radius is -radius
---@return integer count
Commands.GetUnitMoveGoalQueue = function(unitID, all, count)
	if all == nil then
		all = false
	end

	local moves = {}
	local num = 0

	if count == nil then
		count = all and 64 or 32
	elseif count < 1 and count ~= -1 then
		return moves, num
	end

	local queue = Spring.GetUnitCommands(unitID, count)

	for _, cmdInfo in ipairs(queue) do
		if all or moveCommands[cmdInfo.id] then
			local x, y, z, w, leashed = getCommandPositionAndRadius(cmdInfo.id, cmdInfo.params)

			if x ~= nil then
				num = num + 1
				moves[num] = { x, y, z, w, leashed }
			end
		end
	end

	return moves, num
end

---Get the destination position of a unit's move goals from its queued commands.
--
-- Does not test pathfinding, etc., so follows only the shortest possible paths.
--
-- However, this *does* respect the different types of goals and the radii used to
-- test them; e.g.: the area radius (distance++), leash radius (distance--), and
-- unit ability radius (distance--) are accounted for in each move goal step.
---@param unitID integer
---@param range number the unit's engage distance, build range, etc.
---@param all boolean? whether to include non-move commands (default = false)
---@return number x
---@return number y
---@return number z
Commands.GetUnitEndMoveGoal = function(unitID, range, all)
	local x, y, z = Spring.GetUnitPosition(unitID)

	for _, command in ipairs(Spring.GetUnitCommands(unitID, -1)) do
		x, y, z = getNextMoveGoal(command.id, command.params, x, y, z, range, all)
	end

	return x, y, z
end

--------------------------------------------------------------------------------
-- Factory queue functions -----------------------------------------------------

local FACTORY_DEQUEUE = CMD.OPT_RIGHT
local FACTORY_QUEUE_5 = CMD.OPT_SHIFT
local FACTORY_QUEUE_20 = CMD.OPT_CTRL
local FACTORY_QUEUE_100 = FACTORY_QUEUE_5 + FACTORY_QUEUE_20

Commands.GetNextBuildOrder = function(factoryID)
	return Spring.GetFactoryCommands(factoryID, 1)[1]
end

local getNextBuildOrder = Commands.GetNextBuildOrder

---Decrease the given build order by a fixed amount as efficiently as possible.
---@param factoryID integer
---@param buildDefID integer
---@param count integer? the number of orders to remove (default = 1)
---@param flush boolean? forces updates through CMD_WAIT (default = true)
Commands.RemoveBuildQueue = function(factoryID, buildDefID, count, flush)
	if count == nil then
		count = 1
	end

	while count > 0 do
		local opts = FACTORY_DEQUEUE

		if count >= 100 then
			opts = opts + FACTORY_QUEUE_100
			count = count - 100
		elseif count >= 20 then
			opts = opts + FACTORY_QUEUE_20
			count = count - 20
		elseif count >= 5 then
			opts = opts + FACTORY_QUEUE_5
			count = count - 5
		else
			count = count - 1
		end

		spGiveOrderToUnit(factoryID, -buildDefID, nil, opts)
	end

	if flush ~= false then flushOrders(factoryID) end
end

local removeBuildQueue = Commands.RemoveBuildQueue

---Empty out a factory's build queue.
---@param factoryID integer
---@param current boolean? whether to clear the current order (default = true)
Commands.ClearBuildQueue = function(factoryID, current)
	local queue = Spring.GetRealBuildQueue(factoryID)

	if current ~= false then
		for _, build in ipairs(queue) do
			removeBuildQueue(factoryID, next(build))
		end
	else
		local command = getNextBuildOrder(factoryID)

		if command ~= nil then
			local currentDefID = -command.id

			for _, build in ipairs(queue) do
				local buildDefID, count = next(build)

				if buildDefID == currentDefID then
					count = count - 1
				end

				removeBuildQueue(factoryID, buildDefID, count, false)
			end
		end
	end

	flushOrders(factoryID)
end

--------------------------------------------------------------------------------
-- Command options functions ---------------------------------------------------

---Some notes on command options:
--
-- These are far from universal. Each command, especially game commands, might
-- change one or more conventions that the others follow.
--
-- For example, the CMD_STOCKPILE command uses its command options to determine
-- how to change the stockpile target value, rather than issuing a +/- value in
-- the command params. Whether this is good or bad... well.
--
-- tldr: The commands that make exceptions to META/ALT/SHIFT are *not* handled.

---Remove command options that would place the command later in the queue.
--
-- When changing options within a callin, eg `AllowCommand`, pass `copyOnChange`.
---@param options CommandOptions
---@param copyOnChange boolean? copies the `options` table only if it is altered
---@return CommandOptions
Commands.RemoveEnqueueOptions = function(options, copyOnChange)
	if not options.meta and (not options.alt) ~= (not options.shift) then
		if copyOnChange then options = table.copy(options) end
		options.alt = nil
		options.shift = nil
	end

	return options
end

---Remove command options that would place the command in front of the queue.
--
-- When changing options within a callin, eg `AllowCommand`, pass `copyOnChange`.
---@param options CommandOptions
---@param copyOnChange boolean? copies the `options` table only if it is altered
---@return CommandOptions
Commands.RemoveInsertOptions = function(options, copyOnChange)
	if options.meta then
		if copyOnChange then options = table.copy(options) end
		options.meta = nil
	end

	return options
end

---Remove trivial command options (only modify the command's place in the queue).
--
-- When changing options within a callin, like `AllowCommand`, set the `copy` flag.
---@param options CommandOptions
---@param copy boolean?
---@return CommandOptions
Commands.ResetCommandOptions = function(options, copy)
	if copy then options = table.copy(options) end

	options.meta = nil

	if options.alt ~= options.shift then
		options.alt = nil
		options.shift = nil
	end

	return options
end

--------------------------------------------------------------------------------
-- Unit abilities and states ---------------------------------------------------

local STATE_ENABLED = "1"

---Get the description for the given command id, if any.
---@param unitID integer
---@param command CMD
---@return CommandDescription?
Commands.GetUnitCommandDescription = function(unitID, command)
	local index = Spring.FindUnitCmdDesc(unitID, command)

	if index ~= nil then
		return Spring.GetUnitCmdDescs(unitID, index, index)[1]
	end
end

local getUnitCommandDescription = Commands.GetUnitCommandDescription

---Determine whether an order given to a unit will occupy its command queue.
---@param unitID integer
---@param command CMD
---@return boolean? [nil] := the unit has no command description
Commands.GetUnitCommandIsQueuing = function(unitID, command)
	local description = getUnitCommandDescription(unitID, command)

	if description ~= nil then
		return description.queueing
	end
end

---Determine whether the unit has a stateful command and its current state, if any.
---@param unitID integer
---@param command CMD
---@return string[]|false params [false] := unit does not have command description
Commands.GetUnitState = function(unitID, command)
	local description = getUnitCommandDescription(unitID, command)

	if description ~= nil then
		return description.params
	else
		return false
	end
end

---Determine whether the unit has a stateful command and if it is enabled/on/etc.
---@param unitID integer
---@param command CMD
Commands.GetUnitStateEnabled = function(unitID, command)
	local description = getUnitCommandDescription(unitID, command)

	if description ~= nil then
		return description.params[1] == STATE_ENABLED
	end

	return false
end

---Determine whether the unit can accept a given command. Includes toggles, etc.
---@param unitID integer
---@param command CMD
Commands.GetUnitCanExecute = function(unitID, command)
	if command == CMD_UNLOAD_UNIT or command == CMD_UNLOAD_UNITS then
		local transportees = Spring.GetUnitIsTransporting(unitID)
		return transportees ~= nil and transportees[1] ~= nil
	else
		return Spring.FindUnitCmdDesc(unitID, command) ~= nil
	end
end

--------------------------------------------------------------------------------
-- Module security -------------------------------------------------------------

---Make tables safe to share to custom widgets.
--
-- This module maintains acceptable access times via the backing table, `tbl`,
-- while the user space can access only the proxy table, `proxy`. This allows
-- user widgets to configure themselves at init for low overall performance cost
-- without over-exposing our configuration tables to unsafe changes.
local function protect(tbl)
	local proxy = {}
	local mt = {
		__index = tbl,
		__newindex = function(t, k, v) return end,
		__metatable = true,
	}
	return setmetatable(proxy, mt), tbl
end

if WG and not Spring.GetModOptions().allowuserwidgets then
	-- todo: protect a bunch of stuff
	-- todo: if you're going to show it to widgets
	-- todo: because users can replace official widgets with custom ones
end

--------------------------------------------------------------------------------
-- Export module ---------------------------------------------------------------

return Commands
