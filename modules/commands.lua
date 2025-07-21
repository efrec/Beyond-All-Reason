--------------------------------------------------------------------------------
-- Common configuration data and functions for processing RecoilEngine commands.

if not Spring or not CMD or not Game or not GameCMD then
	return
end

local CMD = CMD
local GameCMD = GameCMD

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

-- Edit this and nothing else. The configuration table is consumed during init.
-- Ideally, really, this would exist in its own, untouchable configuration file.

---Maps every command to its accepted parameter counts.
--
-- @see `paramsType` for the names of parameter count sets used here.
---@type table<CMD, string>
local commandToParamsTypeConfig = {
	-- Meta-commands and other special cases

	[CMD.INSERT]          = "Insert",
	[CMD.REMOVE]          = "Remove",
	[CMD.WAIT]            = "Wait",

	-- Commands with a single parameter count

	[CMD.STOP]            = "None",
	[CMD.GATHERWAIT]      = "None",
	[CMD.GROUPADD]        = "None",
	[CMD.GROUPCLEAR]      = "None",
	[CMD.GROUPSELECT]     = "None",
	[CMD.SELFD]           = "None",
	[CMD.STOCKPILE]       = "None",

	[CMD.FIRE_STATE]      = "Mode",
	[CMD.MOVE_STATE]      = "Mode",
	[CMD.AUTOREPAIRLEVEL] = "Mode",
	[CMD.CLOAK]           = "Mode",
	[CMD.IDLEMODE]        = "Mode",
	[CMD.ONOFF]           = "Mode",
	[CMD.REPEAT]          = "Mode",
	[CMD.TRAJECTORY]      = "Mode",

	[CMD.SQUADWAIT]       = "Number",
	[CMD.TIMEWAIT]        = "Number",

	[CMD.GUARD]           = "ObjectAlly",
	[CMD.LOAD_ONTO]       = "ObjectAlly",

	[CMD.PATROL]          = "Point",
	[CMD.RESTORE]         = "Point",
	[CMD.SETBASE]         = "Point",
	[CMD.UNLOAD_UNIT]     = "Point",

	[CMD.AREA_ATTACK]     = "Area",

	-- Commands with multiple parameter counts

	[CMD.ATTACK]          = "ObjectOrPoint",
	[CMD.MANUALFIRE]      = "ObjectOrPoint",
	[CMD.LOAD_UNITS]      = "ObjectOrArea",
	[CMD.FIGHT]           = "ObjectOrFront",
	[CMD.DEATHWAIT]       = "ObjectOrRectangle",

	[CMD.MOVE]            = "PointOrFront",

	[CMD.UNLOAD_UNITS]    = "UnloadTask",

	[CMD.CAPTURE]         = "WorkerTask",
	[CMD.RECLAIM]         = "WorkerTask",
	[CMD.REPAIR]          = "WorkerTask",
	[CMD.RESURRECT]       = "WorkerTask",
}

---Whether a command takes up a slot on the command queue.
--
-- Determines whether a command with a target object or position is a move command.
---@type table<CMD, true>
local queueingCommands = {
	[CMD.WAIT]         = true,
	[CMD.GATHERWAIT]   = true,
	[CMD.SQUADWAIT]    = true,
	[CMD.TIMEWAIT]     = true,
	[CMD.DEATHWAIT]    = true,

	[CMD.MOVE]         = true,
	[CMD.FIGHT]        = true,
	[CMD.PATROL]       = true,
	[CMD.GUARD]        = true,

	[CMD.ATTACK]       = true,
	[CMD.MANUALFIRE]   = true,
	[CMD.AREA_ATTACK]  = true,

	[CMD.CAPTURE]      = true,
	[CMD.RECLAIM]      = true,
	[CMD.REPAIR]       = true,
	[CMD.RESURRECT]    = true,
	[CMD.RESTORE]      = true,

	[CMD.LOAD_ONTO]    = true,
	[CMD.LOAD_UNITS]   = true,
	[CMD.UNLOAD_UNIT]  = true,
	[CMD.UNLOAD_UNITS] = true,
}

--------------------------------------------------------------------------------
-- Module internals ------------------------------------------------------------

---Functions and utilities for common tasks using RecoilEngine commands.
---@module Commands
local Commands = {}

local math_sqrt = math.sqrt
local bit_and = math.bit_and

local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitPosition = Spring.GetUnitPosition
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMD_INSERT = CMD.INSERT
local CMD_REMOVE = CMD.REMOVE
local CMD_ATTACK = CMD.ATTACK
local CMD_FIGHT = CMD.FIGHT
local CMD_GUARD = CMD.GUARD
local CMD_PATROL = CMD.PATROL
local CMD_STOP = CMD.STOP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNIT = CMD.UNLOAD_UNIT
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_WAIT = CMD.WAIT
local OPT_INTERNAL = CMD.OPT_INTERNAL
local OPT_ALT = CMD.OPT_ALT
local OPT_CTRL = CMD.OPT_CTRL
local OPT_META = CMD.OPT_META
local OPT_SHIFT = CMD.OPT_SHIFT
local OPT_RIGHT = CMD.OPT_RIGHT

local FEATURE_BASE_INDEX = Game.maxUnits or 32000
local MOVE_GOAL_RESOLUTION = Game.squareSize or 10

local CMD_INSERT_SIZE = 3 -- The extra #params added when packing a command inside CMD_INSERT.
local PARAM_POOL_SIZE = 8 -- #params above this use a memory pool that is much more expensive.
local PARAM_COUNT_MAX = 6 -- Line and Rectangle need 6. Ideally, this would be POOL - INSERT.
local PARAM_POOL_COUNT_MAX = 64 -- Commands can support a ridiculous number of params though.

---@alias ParamCount 0|1|2|3|4|5|6|7|8 The number of parameters passed in a command
---@alias ParamIndex 1|2|3|4|5|6|7|8 The position of a specific parameter in a command's parameters
---@alias ParamCountSet table<ParamCount, true>
---@alias ParamIndexMap table<ParamIndex, ParamIndex>
---@alias ParamIndexSet table<ParamIndex, true>
---@alias ParamGroupName "None"|"Mode"|"Number"|"Object"|"Point"|"Line"|"Rectangle"|"Radius"|"Leash"|"Facing"

---Cannot produce empty sets.
---@param min integer
---@param max integer
---@return ParamCountSet
local function newParamCountSet(min, max, pooled)
	min = math.max(min, 0)
	max = math.min(max, pooled and PARAM_POOL_COUNT_MAX or CMD_INSERT_SIZE + PARAM_POOL_SIZE)

	local tbl = table.new(max - min + 1, 0)

	for i = min, max do
		tbl[i] = true
	end

	return tbl
end

---@param params number|number[]?
---@param p1 number?
---@param p2 number?
---@param p3 number?
---@param p4 number?
---@param p5 number?
---@param p6 number?
local function equalParams(params, p1, p2, p3, p4, p5, p6)
	if params == nil then
		return p1 == nil
	elseif type(params) == "number" then
		return p1 == params
	else
		return
			params[1] == p1 and
			params[2] == p2 and
			params[3] == p3 and
			params[4] == p4 and
			params[5] == p5 and
			params[6] == p6
	end
end

local repackParams
do
	-- NB: PARAM_COUNT_MAX and the sequence length below must match.
	local params = table.new(PARAM_COUNT_MAX, 0)

	-- Pack or repack up to `PARAM_COUNT_MAX` parameters:
	repackParams = function(p1, p2, p3, p4, p5, p6)
		local p = params
		p[1], p[2], p[3], p[4], p[5], p[6] = p1, p2, p3, p4, p5, p6
		return p
	end

	assert(#repackParams(unpack(newParamCountSet(1, PARAM_COUNT_MAX)) == PARAM_COUNT_MAX))
end

---@param code integer
local function getOptions(code)
	return {
		coded    = code,
		internal = 0 ~= bit_and(code, OPT_INTERNAL),
		alt      = 0 ~= bit_and(code, OPT_ALT),
		ctrl     = 0 ~= bit_and(code, OPT_CTRL),
		meta     = 0 ~= bit_and(code, OPT_META),
		right    = 0 ~= bit_and(code, OPT_RIGHT),
		shift    = 0 ~= bit_and(code, OPT_SHIFT),
	}
end

---@param options CommandOptions
---@return integer
local function getOptionCode(options)
	if options == nil then
		return 0 -- or should be nil?
	elseif options.coded then
		return options.coded
	end

	local code = 0

	if options.alt then
		code = code + OPT_ALT
	end

	if options.ctrl then
		code = code + OPT_CTRL
	end

	if options.internal then
		code = code + OPT_INTERNAL
	end

	if options.meta then
		code = code + OPT_META
	end

	if options.right then
		code = code + OPT_RIGHT
	end

	if options.shift then
		code = code + OPT_SHIFT
	end

	return code
end

---Command options are even worse off for our blind type-check issues.
---@param options1 integer|CommandOptions?
---@param options2 integer|CommandOptions?
local function equalOption(options1, options2, ignoreInternal)
	if options1 == options2 then
		return true
	elseif type(options1) == "table" and type(options2) == "table" then
		return
			options1.coded == options2.coded or
			-- Assume the `coded` values might be stale:
			(ignoreInternal or options1.internal == options2.internal) and (
				-- Handle nil == false:
				(not options1.alt) == (not options2.alt) and
				(not options1.ctrl) == (not options2.ctrl) and
				(not options1.meta) == (not options2.meta) and
				(not options1.right) == (not options2.right) and
				(not options1.shift) == (not options2.shift)
			)
	elseif type(options1) == "table" then
		return getOptionCode(options1) == options2
	elseif type(options2) == "table" then
		return getOptionCode(options2) == options1
	else
		return false
	end
end

---@param options table|integer|CommandOptionBit?
local function isInternal(options)
	if type(options) == "table" then
		return options.internal
	elseif options ~= nil then
		return bit_and(options, OPT_INTERNAL) ~= 0
	else
		return false
	end
end

---@param optionsBitSet integer|CommandOptionBit
local function isInternalBit(optionsBitSet)
	return bit_and(optionsBitSet, OPT_INTERNAL) ~= 0
end

local function getObjectPosition(objectID)
	if objectID < FEATURE_BASE_INDEX then
		return spGetUnitPosition(objectID)
	else
		return spGetFeaturePosition(objectID - FEATURE_BASE_INDEX)
	end
end

-- Various widgets will need to issue pseudo-orders during pregame placement:
local pregame = Spring.GetGameFrame and Spring.GetGameFrame() <= 0

local tempTbl = {} -- easier to make a temp iter tbl than to encapsulate this

--------------------------------------------------------------------------------
-- Command introspection -------------------------------------------------------

-- Not reconfigurable. Do not edit any of this except to reflect engine changes.

-- Parameter types and counts --------------------------------------------------

local anyParamCount = newParamCountSet(0, PARAM_POOL_COUNT_MAX, true)
local nullParamsSet = {}

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
---@type table<string, ParamCountSet>
local paramsType = setmetatable({
	-- Basic params types
	Any               = anyParamCount,
	None              = { [0] = true },
	Mode              = { [1] = true },
	Number            = { [1] = true },
	Object            = { [1] = true },
	Point             = { [3] = true },
	Area              = { [4] = true },
	Front             = { [6] = true },
	Rectangle         = { [6] = true },

	-- Flexible params types
	NoneOrMode        = { [0] = true, [1] = true },             -- [0] := option, [1] := mode

	ObjectOrPoint     = { [1] = true, [3] = true },             -- [1] := id, [3] := point
	ObjectOrArea      = { [1] = true, [4] = true },             -- [1] := id, [4] := area
	ObjectOrFront     = { [1] = true, [3] = true, [6] = true }, -- [1] := id, [3] := point, [6] := middle point, right point
	ObjectOrRectangle = { [1] = true, [3] = true, [6] = true }, -- [1] := id, [6] := rectangle

	PointFacing       = { [3] = true, [4] = true },             -- [3] := point, [4] := point, facing
	PointLeash        = { [3] = true, [4] = true },             -- [3] := point, [4] := point, leash radius
	PointOrArea       = { [3] = true, [4] = true },             -- [3] := point, [4] := area
	PointOrFront      = { [3] = true, [6] = true },             -- [3] := point, [6] := middle point, right point

	-- Contextual params types
	ObjectAlly        = { [1] = true },
	ObjectEnemy       = { [1] = true },
	UnloadTask        = { [4] = true, [5] = true },             -- [4] := unload area, [5] := unload area, facing
	WorkerTask        = { [1] = true, [4] = true, [5] = true }, -- [1] := id, [4] := area, [5] := id, point, leash radius

	-- Specific commands
	Insert            = newParamCountSet(CMD_INSERT_SIZE, CMD_INSERT_SIZE + PARAM_COUNT_MAX, true),
	Remove            = newParamCountSet(1, PARAM_POOL_COUNT_MAX, true),
	Wait              = newParamCountSet(1, PARAM_POOL_SIZE),
}, {
	-- Unregistered commands have no restrictions
	-- except that they obey the max param count.
	__index = function(self, key)
		return anyParamCount
	end
})

-- Check for potential configuration errors.

local function validateCommandConfiguration(name, command)
	if type(name) == "string" and
		not commandToParamsTypeConfig[command] and
		not name:find("[^_]STATE_") and not name:find("^OPT_")
	then
		Spring.Log('CMD', LOG.WARNING, "Unconfigured command: " .. name)
	end
end

for commandName, commandID in pairs(CMD) do
	validateCommandConfiguration(commandName, commandID)
end

if GameCMD then
	for commandName, commandID in pairs(GameCMD) do
		validateCommandConfiguration(commandName, commandID)
	end
end

for command, paramsTypeName in pairs(commandToParamsTypeConfig) do
	local params = paramsType[paramsTypeName]

	if not CMD[command] and (not GameCMD or not GameCMD[command]) then
		Spring.Log('CMD', LOG.WARNING, "Unrecognized command: " .. tostring(command))
		-- commandToParamsTypeConfig[command] = nil -- todo: maybe enforce later
	elseif not table.getKeyOf(paramsType, params) then
		Spring.Log('CMD', LOG.ERROR, "Unrecognized paramsType: " .. tostring(params) .. ", in: " .. tostring(command))
	end
end

-- With commands mapped to parameter counts and types (context slightly useless),
-- we can set up automatic tables to use as lookups for the values we might want:
-- - target object id in params (and its index)
-- - target coordinates in params (and their base index)
-- - target coordinate pairs in params (and their base index)
-- - target radius in params (and its index)
-- - target leash radius in params (and its index)

-- Some speedups:
local PRMTYPE_WAIT = paramsType.Wait
local PRMTYPE_POINTFACING = paramsType.PointFacing

-- Object parameter index ------------------------------------------------------

---Contains the parameter index position of the command's target object id.
---@type table<string, ParamIndexMap>
local paramsObjectIndex = setmetatable({
	Object            = { [1] = 1 },
	ObjectAlly        = { [1] = 1 },
	ObjectEnemy       = { [1] = 1 },
	ObjectOrPoint     = { [1] = 1 },
	ObjectOrArea      = { [1] = 1 },
	ObjectOrFront     = { [1] = 1 },
	ObjectOrRectangle = { [1] = 1 },
	WorkerTask        = { [1] = 1, [5] = 1 },
}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

---Maps commands and their param counts to the index position of a target object id.
---@type table<CMD, ParamIndexMap>
local commandParamsObjectIndex = setmetatable({}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

-- Point parameter index -------------------------------------------------------

---Contains the parameter index position of the command's x coordinate.
---@type table<string, ParamIndexMap>
local paramsPointIndex = setmetatable({
	Point         = { [3] = 1 },
	Area          = { [4] = 1 },
	Front         = { [6] = 1 },

	ObjectOrPoint = { [3] = 1 },
	ObjectOrArea  = { [4] = 1 },
	ObjectOrFront = { [3] = 1, [6] = 1 },

	PointLeash    = { [3] = 1, [4] = 1 },
	PointFacing   = { [3] = 1, [4] = 1 },
	PointOrArea   = { [3] = 1, [4] = 1 },
	PointOrFront  = { [3] = 1, [6] = 1 },

	UnloadTask    = { [4] = 1, [5] = 1 },
	WorkerTask    = { [4] = 1, [5] = 2 },
}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

---Maps commands and their param counts to the index position of an x coordinate.
---@type table<CMD, ParamIndexMap>
local commandParamsPointIndex = setmetatable({}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

-- Line parameter index --------------------------------------------------------

---Contains the parameter index positions of the command's two x coordinates.
---@type table<string, table<ParamIndex, ParamIndex>>
local paramsLineIndex = setmetatable({
	Front         = { [6] = 1 },
	ObjectOrFront = { [6] = 1 },
	PointOrFront  = { [6] = 1 },
}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

---Maps commands and their param counts to the index positions of two x coordinates.
---@type table<CMD, table<ParamIndex, ParamIndex>>
local commandParamsLineIndex = setmetatable({}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

-- Rectangle parameter index ---------------------------------------------------

---Contains the parameter index positions of the command's two x coordinates.
---@type table<string, table<ParamIndex, ParamIndex>>
local paramsRectangleIndex = setmetatable({
	Rectangle         = { [6] = 1 },
	ObjectOrRectangle = { [6] = 1 },
}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

---Maps commands and their param counts to the index positions of two x coordinates.
---@type table<CMD, table<ParamIndex, ParamIndex>>
local commandParamsRectangleIndex = setmetatable({}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

-- Radius parameter index ------------------------------------------------------

-- This definition of a "radius" excludes the "leash radius". See next section.

---Contains the parameter index position of the command's target radius.
---@type table<string, ParamIndexMap>
local paramsRadiusIndex = setmetatable({
	Area         = { [4] = 4 },
	ObjectOrArea = { [4] = 4 },
	PointOrArea  = { [4] = 4 },
	UnloadTask   = { [4] = 4, [5] = 4 }, -- [4] := area, [5] := area, facing; atypical radius
	WorkerTask   = { [4] = 4 },
}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

---Maps commands and their param counts to the index position of a target radius.
---@type table<CMD, ParamIndexMap>
local commandParamsRadiusIndex = setmetatable({}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

-- Leash radius parameter index ------------------------------------------------

-- A "leash" is generally the reverse of a "radius" in this module's terminology.
-- Rather than requiring the command to cover the entire area within a volume, as
-- a radius does, a leash allows a command to cover any amount of that volume.

---Contains the index position of the leash radius around the command's target.
---@type table<string, ParamIndexMap>
local paramsLeashIndex = setmetatable({
	PointLeash = { [4] = 4 },
	WorkerTask = { [5] = 5 },
}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

---Maps commands and their param counts to the index position of a target radius.
---@type table<CMD, ParamIndexMap>
local commandParamsLeashIndex = setmetatable({}, {
	__index = function(self, key)
		return nullParamsSet
	end
})

--------------------------------------------------------------------------------
-- Command categories ----------------------------------------------------------

---Map of paramsTypes to commands that imply movement and possible move goals.
--
-- Only command descriptions that are queueing (`queueing == true`) are actually
-- added to the final `moveCommands` reference.
---@type table<string, true>
local moveParamsType = {
	Point         = true,
	Area          = true,
	Front         = true,

	ObjectAlly    = true,
	ObjectEnemy   = true,
	ObjectOrPoint = true,
	ObjectOrArea  = true,
	ObjectOrFront = true,

	PointFacing   = true,
	PointLeash    = true,
	PointOrArea   = true,
	PointOrFront  = true,

	UnloadTask    = true,
	WorkerTask    = true,
}

---@type table<CMD, true>
local moveCommands = setmetatable({}, {
	__index = function(self, command)
		if command < 0 then return true end
	end
})

--------------------------------------------------------------------------------
-- Command auto configuration --------------------------------------------------

-- Allows new commands to be added to the configs via GameCMD and receive their
-- appropriate parameter counts, types, and indexes.

---Maps every command to its accepted parameter counts.
--
-- Adding new commands via this table will populate its entries in the parameter
-- introspection tables, e.g. the param index lookup for target coords or objects.
---@type table<CMD, ParamCountSet>
local commandParamsType = setmetatable({}, {
	__newindex = function(self, command, paramsCounts)
		local paramsTypeName = table.getKeyOf(paramsType, paramsCounts)

		if paramsTypeName == nil then
			Spring.Log('CMD', LOG.ERROR, "Command paramsType is invalid: " .. tostring(command))
			return
		end

		commandParamsObjectIndex[command] = paramsObjectIndex[paramsTypeName]
		commandParamsPointIndex[command] = paramsPointIndex[paramsTypeName]
		commandParamsLineIndex[command] = paramsLineIndex[paramsTypeName]
		commandParamsRectangleIndex[command] = paramsRectangleIndex[paramsTypeName]
		commandParamsRadiusIndex[command] = paramsRadiusIndex[paramsTypeName]
		commandParamsLeashIndex[command] = paramsLeashIndex[paramsTypeName]

		if queueingCommands[command] then
			moveCommands[command] = moveParamsType[paramsTypeName] or nil
		end
	end,

	__index = function(self, command)
		return command < 0 and PRMTYPE_POINTFACING or nullParamsSet
	end
})

-- Populate the params index tables using the initial config.

for command, paramsTypeName in pairs(commandToParamsTypeConfig) do
	commandParamsType[command] = paramsType[paramsTypeName]
end

commandToParamsTypeConfig = nil ---@diagnostic disable-line -- consume table

---Essentially a reverse lookup table to find all paramsTypes that contain a
-- given type or sub-type, e.g. all parameter sets that contain Line params.
---@type table<ParamGroupName, table<ParamIndexMap, true>>
local paramsTypeGroup = {
	None = {
		[paramsType.None]       = true,
		[paramsType.NoneOrMode] = true,
	},
	Mode = {
		[paramsType.Mode]       = true,
		[paramsType.NoneOrMode] = true,
	},
	Number = {
		[paramsType.Number] = true,
	},
	Facing = {
		[paramsType.PointFacing] = true,
		[paramsType.UnloadTask]  = true,
		[paramsType.WorkerTask]  = true,
	},
}

for kind, paramsIndexMap in pairs({
	Object    = paramsObjectIndex,
	Point     = paramsPointIndex,
	Line      = paramsLineIndex,
	Rectangle = paramsRectangleIndex,
	Radius    = paramsRadiusIndex,
	Leash     = paramsLeashIndex,
}) do
	local group = {}

	for name, indexMap in pairs(paramsIndexMap) do
		group[indexMap] = true
	end

	paramsTypeGroup[kind] = group
end

--------------------------------------------------------------------------------
-- Module interfacing ----------------------------------------------------------

---@class CreateGameCMD
---@field code string e.g. the `ATTACK` in `CMD.ATTACK`
---@field cmdType CMDTYPE either the name (string) or id (integer)
---@field params string[]? needed for `CMD_ICON_MODE`
---@field prmTypeName string? name of paramsType set, see commands.lua
---@field name string?
---@field action string?
---@field cursor string?
---@field texture string?
---@field tooltip string?
---@field disabled boolean? set `true` for default-unusable commands
---@field hidden boolean? set `true` for non-player-facing orders
---@field onlyTexture boolean?
---@field queueing boolean? set `false` for non-queued commands
---@field showUnique boolean?

---@param newGameCMD CreateGameCMD
---@return table?
local function parseNewCommand(newGameCMD)
	-- Game commands must be configured already in modules/customcommands.lua.
	local code = newGameCMD.code:gsub("^CMD_", "")
	local cmdType = type(newGameCMD.cmdType) == "string" and CMDTYPE[newGameCMD.cmdType] or newGameCMD.cmdType

	local command = GameCMD[code] ---@type CMD
	local error = false

	if command == nil then
		Spring.Log('CMD', LOG.ERROR, "Game commands must be configured in modules/customcommands.lua: " .. tostring(code))
		error = true
	end

	if CMD[code] then
		Spring.Log('CMD', LOG.ERROR, "Game command code conflicts with an engine CMD code: " .. tostring(code))
		error = true
	end

	if not CMDTYPE[cmdType] then
		Spring.Log('CMD', LOG.ERROR, "Game command's cmdType not recognized: " .. tostring(cmdType))
		error = true
	end

	if error then
		return
	end

	if commandParamsType[command] then
		Spring.Log('CMD', LOG.WARNING, "Game command was already added: " .. tostring(code))
	end

	local prmTypeName = newGameCMD.prmTypeName

	if prmTypeName == nil or paramsType[prmTypeName] == nullParamsSet then
		Spring.Log('CMD', LOG.WARNING, "Game command's prmTypeName not recognized: " .. tostring(prmTypeName))
		newGameCMD.prmTypeName = "Any"
	elseif paramsType[prmTypeName] == anyParamCount and prmTypeName ~= "Any" then
		Spring.Log('CMD', LOG.WARNING, "Game command's prmTypeName default to 'Any': " .. tostring(prmTypeName))
		newGameCMD.prmTypeName = "Any"
	end

	return {
		command     = command,
		cmdType     = cmdType,
		params      = newGameCMD.params,
		prmTypeName = newGameCMD.prmTypeName,

		name        = newGameCMD.name or code,
		action      = newGameCMD.action,
		cursor      = newGameCMD.cursor,
		tooltip     = newGameCMD.tooltip,

		disabled    = newGameCMD.disabled or false,
		hidden      = newGameCMD.hidden or false,
		queueing    = newGameCMD.queueing or false,
		showUnique  = newGameCMD.showUnique or false,

		texture     = newGameCMD.texture,
		onlyTexture = newGameCMD.onlyTexture or false,
	}
end

---Configures a new command description with very basic error detection.
--
-- Call this once at initialization per each game command that you implement.
---@todo: move to customcommands?
---@param newGameCMD CreateGameCMD
---@return CommandDescription?
Commands.NewCommandDescription = function(newGameCMD)
	local command = parseNewCommand(newGameCMD)

	if command == nil or command.cmdID == nil then
		return -- error when parsing
	end

	local paramsCounts = paramsType[command.prmTypeName]

	-- We need to add to the command categories, first.
	if command.queueing then
		queueingCommands[command.cmdID] = true
	end

	-- The introspection tables are populated via metamethod
	-- whenever we add a new command to `commandParamsType`.
	commandParamsType[command.cmdID] = paramsCounts

	return {
		id          = command.cmdID,
		type        = command.cmdType,
		params      = command.cmdParams,

		name        = command.cmdName,
		action      = command.action,
		cursor      = command.cursor,
		tooltip     = command.tooltip,

		disabled    = command.disabled,
		hidden      = command.hidden,
		showUnique  = command.showUnique,
		queueing    = command.queueing,

		texture     = command.texture,
		onlyTexture = command.onlyTexture,
	}
end

---Get the allowed parameter counts of a given type and that contain the given
-- sub-type, e.g. return only the Point count of the type PointOrRectangle.
---@param prmType ParamCountSet
---@param include ParamGroupName[]|ParamGroupName
---@param exclude ParamGroupName[]|ParamGroupName
---@return ParamCountSet? [nil] := no valid parameter counts (even zero)
local function filterParamIndexMap(prmType, include, exclude)
	if prmType == anyParamCount then
		return table.copy(anyParamCount)
	elseif prmType == nullParamsSet then
		return
	end

	local paramsCounts = table.copy(prmType)

	if include ~= nil then
		if type(include) ~= "table" then
			tempTbl[1] = include
			include = tempTbl
		end

		local included = {}

		for _, kind in ipairs(include) do
			for indexMap in pairs(paramsTypeGroup[kind]) do
				for index in pairs(indexMap) do
					included[index] = true
				end
			end
		end

		for index in pairs(paramsCounts) do
			if not included[index] then
				paramsCounts[index] = nil
			end
		end
	end

	if exclude ~= nil then
		if type(exclude) ~= "table" then
			tempTbl[1] = exclude
			exclude = tempTbl
		end

		local excluded = {}

		for _, kind in ipairs(exclude) do
			for indexMap in pairs(paramsTypeGroup[kind]) do
				for index in pairs(indexMap) do
					excluded[index] = true
				end
			end
		end

		for index in pairs(paramsCounts) do
			if excluded[index] then
				paramsCounts[index] = nil
			end
		end
	end

	return next(paramsCounts) and paramsCounts or nil
end

---Get the allowed parameter counts of a given type and that contain the given
-- parameter types (and/or that exclude them).
--
-- For example, get the Object and Point count(s), without the area radius:
--
-- `Commands.GetCommandParamsSet(CMD.REPAIR, { "Object", "Point" }, "Area")`
---@param command CMD
---@param include ParamGroupName[]|ParamGroupName
---@param exclude ParamGroupName[]|ParamGroupName
---@return ParamCountSet?
Commands.FilterCommandParams = function(command, include, exclude)
	local prmType = commandParamsType[command]

	if prmType == nullParamsSet then
		return
	end

	return filterParamIndexMap(prmType, include, exclude)
end

---Get the allowed parameter counts of a list of commands, given two lists
-- of required parameter types, e.g. "Point" or "Area".
--
-- For example, to get Points (xyz) and not Areas (xyzr) from given commands:
--
-- `Commands.FilterCommandParamsList({ CMD.REPAIR, CMD.RECLAIM }, "Point", "Area")`
---@param commands CMD[]|CMD
---@param include ParamGroupName[]|ParamGroupName
---@param exclude ParamGroupName[]|ParamGroupName
---@return table<CMD, ParamCountSet>? commandParams
Commands.FilterCommandParamsList = function(commands, include, exclude)
	if type(commands) == "number" then
		tempTbl[1] = commands
		commands = tempTbl
	end

	local commandParams = {}
	local filter = Commands.FilterCommandParams

	for _, command in ipairs(commands) do
		commandParams[command] = filter(command, include, exclude)
	end

	return commandParams
end

--------------------------------------------------------------------------------
-- Order functions -------------------------------------------------------------

-- Orders are commands as they are issued to units and before they are accepted.
-- Note: This is some niche terminology and applies only to the Commands module.

---Retrieve the command info from the params of a CMD_INSERT.
---@param params number[]|number
---@return CMD command
---@return number[]|number? commandParams
---@return integer commandOptions
---@return integer insertIndex
Commands.GetInsertedCommand = function(params)
	local innerParams

	if #params > 4 then
		innerParams = { params[4], params[5], params[6], params[7], params[8], params[9] }
	else
		innerParams = params[4]
	end

	return
		params[2], ---@diagnostic disable-line: return-type-mismatch -- CMD/integer
		innerParams,
		params[3],
		params[1]
end

local getInsertedCommand = Commands.GetInsertedCommand

---Retrieve the command info from the params of a CMD_INSERT.
---@param params number[]|number
---@return CMD command
---@return number[]|number? commandParams
---@return CommandOptions commandOptions
---@return integer commandTag
Commands.GetFullInsertedCommand = function(params)
	local innerParams

	if params[5] == nil then
		innerParams = params[4]
	else
		innerParams = {}

		for i = 4, #params do
			innerParams[i - 3] = params[i]
		end
	end

	local innerOptions = getOptions(params[3])

	return
		params[2], ---@diagnostic disable-line: return-type-mismatch -- CMD/integer
		innerParams,
		innerOptions,
		params[1]
end

local getFullInsertedCommand = Commands.GetFullInsertedCommand

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
--
-- Removing orders via `CMD_REMOVE` uses a command, which will be gated behind a wait.
---@param unitID integer
Commands.FlushOrders = function(unitID)
	spGiveOrderToUnit(unitID, CMD_WAIT) -- toggle once
	spGiveOrderToUnit(unitID, CMD_WAIT) -- toggle twice
end

local flushOrders = Commands.FlushOrders

--------------------------------------------------------------------------------
-- Command functions -----------------------------------------------------------

-- Commands are orders that have been accepted by the unit, actively or not.
-- Note: This is some niche terminology and applies only to the Commands module.

---Check if the unit is executing an internal or temporary order.
--
-- Some commands, like CMD_FIGHT, don't issue their orders with OPT_INTERNAL, but
-- they will copy the internal flag if passed already, such as from CMD_PATROL.
--
-- This doesn't quite manage to check if a CMD_ATTACK is actually a temp order,
-- truthfully, but it should work for almost all purposes.
---@param command CMD the current command
---@param options integer|CommandOptions?
---@param cmdID CMD? a presumed non-temp command, like guard or fight
---@param cmdOpts integer|CommandOptions?
Commands.IsInTempCommand = function(command, options, cmdID, cmdOpts)
	if isInternal(options) then
		return true -- Disregards additional command info.
	elseif cmdID == CMD_FIGHT then
		return command == CMD_ATTACK and equalOption(options, cmdOpts, false)
	else
		return false
	end
end

local isInTempCommand = Commands.IsInTempCommand

---Check if the unit is executing a given command, including no command.
---@param unitID integer
---@param cmdID CMD?
---@param cmdParams number[]|number?
---@param cmdOpts integer|CommandOptions?
---@return boolean
Commands.IsInCommand = function(unitID, cmdID, cmdParams, cmdOpts)
	local index = 1

	while true do
		-- The engine and other gadgets can reject or modify the orders we issue.
		-- The only way to know is through checking and verifying the new result.
		local command, options, _, p1, p2, p3, p4, p5, p6 = spGetUnitCurrentCommand(unitID, index)

		if command == cmdID and equalParams(cmdParams, p1, p2, p3, p4, p5, p6) then
			return true
		elseif command == nil or not isInTempCommand(command, options, cmdID, cmdOpts) then
			return false
		else
			-- Orders can be inserted internally in front of a valid command;
			-- e.g., reclaiming a feature that is blocking a new build order.
			index = index + 1 -- so keep looking
		end
	end
end

local isInCommand = Commands.IsInCommand

---Whether the unit is in a wait command (generally CMD_WAIT).
---@param unitID integer
Commands.IsInWaitCommand = function(unitID)
	local command = spGetUnitCurrentCommand(unitID)
	return command ~= nil and commandParamsType[command] == PRMTYPE_WAIT
end

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
	if commandIndex == nil then
		commandIndex = 1
	end

	repeat
		local command, options, _, maybeUnitID = spGetUnitCurrentCommand(unitID, commandIndex)

		if command == CMD_GUARD then
			return maybeUnitID
		elseif command == nil or not isInternalBit(options) then
			return
		else
			commandIndex = commandIndex + 1
		end
	until false
end

---Gets the xyz coordinates of a command's target, whether a position or object.
---@param command CMD
---@param params number[]
---@param ignoreObjects boolean? [nil] := false
---@return number? targetX
---@return number? targetY
---@return number? targetZ
Commands.GetCommandPosition = function(command, params, ignoreObjects)
	local pointIndex = commandParamsPointIndex[command][#params]

	if pointIndex ~= nil then
		return params[pointIndex], params[pointIndex + 1], params[pointIndex + 2]
	elseif not ignoreObjects then
		local objectIndex = commandParamsObjectIndex[command][#params]

		if objectIndex ~= nil then
			return getObjectPosition(params[objectIndex])
		end
	end
end

local getCommandPosition = Commands.GetCommandPosition

---Gets the xyz coordinates of the start and end points of the command's line target, if any.
--
-- You may need to use the unit's current position to update the line, e.g. for CMD_FIGHT.
---@param command CMD
---@param params number[]
---@return number? startX
---@return number? startY
---@return number? startZ
---@return number? endX
---@return number? endY
---@return number? endZ
Commands.GetCommandLine = function(command, params)
	local lineIndex = commandParamsLineIndex[command][#params]

	if lineIndex ~= nil then
		return
			params[lineIndex],
			params[lineIndex + 1],
			params[lineIndex + 2],
			params[lineIndex + 3],
			params[lineIndex + 4],
			params[lineIndex + 5]
	end
end

---Gets the xyz coordinates of the start and end points of the command's rectangle target, if any.
---@param command CMD
---@param params number[]
---@return number? startX
---@return number? startY
---@return number? startZ
---@return number? endX
---@return number? endY
---@return number? endZ
Commands.GetCommandRectangle = function(command, params)
	local rectangleIndex = commandParamsRectangleIndex[command][#params]

	if rectangleIndex ~= nil then
		return
			params[rectangleIndex],
			params[rectangleIndex + 1],
			params[rectangleIndex + 2],
			params[rectangleIndex + 3],
			params[rectangleIndex + 4],
			params[rectangleIndex + 5]
	end
end

---Gets the area radius around a command's target, if any.
---@param command CMD
---@param params number[]
---@return number? areaRadius
Commands.GetCommandAreaRadius = function(command, params)
	local radiusIndex = commandParamsRadiusIndex[command][#params]

	if radiusIndex ~= nil then
		return params[radiusIndex]
	end
end

---Gets the leash radius around a command's target, if any.
---@param command CMD
---@param params number[]
---@return number? leashRadius
Commands.GetCommandLeashRadius = function(command, params)
	local leashIndex = commandParamsLeashIndex[command][#params]

	if leashIndex ~= nil then
		return params[leashIndex]
	end
end

---Gets the area or leash radius around a command's target, if any.
---@param command CMD
---@param params number[]
---@return number? radius
---@return boolean? leashed
Commands.GetCommandRadius = function(command, params)
	local leashIndex = commandParamsLeashIndex[command][#params]

	if leashIndex ~= nil then
		return params[leashIndex], true
	end

	local radiusIndex = commandParamsRadiusIndex[command][#params]

	if radiusIndex ~= nil then
		return params[radiusIndex], false
	end
end

local getCommandRadius = Commands.GetCommandRadius

---Gets the xyzw coordinates of a command's target, where w is an area or leash radius.
---@param command CMD
---@param params number[]
---@return number? targetX
---@return number? targetY
---@return number? targetZ
---@return number? radius [nil] := command/params has no radius
---@return boolean? leashed [true] := leash radius, not area radius [nil] := no radius
Commands.GetCommandPositionAndRadius = function(command, params)
	local x, y, z = getCommandPosition(command, params)
	return x, y, z, getCommandRadius(command, params)
end

local getCommandPositionAndRadius = Commands.GetCommandPositionAndRadius

---Get an estimated end position after completing a command.
--
-- Not all commands have move goals, and fewer have explicit goals. To get all
-- move goals, even for commands that are not "move" commands, see `all` arg.
---@param command CMD
---@param params number[]
---@param x number unit position x
---@param y number unit position y
---@param z number unit position z
---@param range number? weapon or build range
---@param all boolean? whether to include non-move commands (default = false)
---@return number? goalX
---@return number? goalY
---@return number? goalZ
Commands.GetCommandMoveGoal = function(command, params, x, y, z, range, all)
	if command ~= nil and (all or moveCommands[command]) then
		-- Move goals with an area radius have to cover the entire area (potentially)
		-- vs a leash radius which only requires reaching the nearest point (usually)
		local x2, y2, z2, radius, leashed = getCommandPositionAndRadius(command, params)

		if x2 ~= nil then
			if radius == nil then
				radius = range
			end

			if radius == nil or radius <= MOVE_GOAL_RESOLUTION then
				x, y, z = x2, y2, z2
			else
				local dx = x2 - x
				local dy = y2 - y
				local dz = z2 - z
				local dw = dx * dx + dy * dy + dz * dz -- squared term

				if leashed then
					-- Get the nearest point on the sphere.
					if dw > radius * radius then
						dw = math_sqrt(dw)
						x = x2 - dx * dw / radius
						y = y2 - dy * dw / radius -- todo: air, ship, etc. y-heights
						z = z2 - dz * dw / radius
					end
				else
					-- Get the furthest point on the sphere.
					if dw <= MOVE_GOAL_RESOLUTION then
						x, y, z = x2, y2, z2
					else
						-- This can over-estimate by very large margins,
						-- e.g. when large areas contain no valid targets.
						dw = math_sqrt(dw)
						x = x + dx + radius * dx / dw
						y = y + dy + radius * dy / dw -- todo: air, ship, etc. y-heights
						z = z + dz + radius * dz / dw
					end
				end
			end
		end
	end

	return x, y, z -- NB: May be unmodified.
end

local getCommandMoveGoal = Commands.GetCommandMoveGoal

---Get an estimated end position after completing a command.
--
-- Not all commands have move goals, and fewer have explicit goals. To get all
-- move goals, even for commands that are not "move" commands, see `all` arg.
---@param command CMD
---@param params number[]
---@param x number unit position x
---@param y number unit position y
---@param z number unit position z
---@param range number? weapon or build range
---@param all boolean? whether to include non-move commands (default = false)
---@return number? goalX
---@return number? goalZ
Commands.GetCommandMoveGoal2D = function(command, params, x, z, range, all)
	if command ~= nil and (all or moveCommands[command]) then
		-- Move goals with an area radius have to cover the entire area (potentially)
		-- vs a leash radius which only requires reaching the nearest point (usually)
		local x2, _, z2, radius, leashed = getCommandPositionAndRadius(command, params)

		if x2 ~= nil then
			if radius == nil then
				radius = range
			end

			if radius == nil or radius <= MOVE_GOAL_RESOLUTION then
				x, z = x2, z2
			else
				local dx = x2 - x
				local dz = z2 - z
				local dw = dx * dx + dz * dz -- squared term

				if leashed then
					-- Get the nearest point on the cylinder.
					if dw > radius * radius then
						dw = math_sqrt(dw)
						x = x2 - dx * dw / radius
						z = z2 - dz * dw / radius
					end
				else
					-- Get the furthest point on the cylinder.
					if dw <= MOVE_GOAL_RESOLUTION then
						x, z = x2, z2
					else
						-- This can over-estimate by very large margins,
						-- e.g. when large areas contain no valid targets.
						dw = math_sqrt(dw)
						x = x + dx + radius * dx / dw
						z = z + dz + radius * dz / dw
					end
				end
			end
		end
	end

	return x, z -- NB: May be unmodified.
end

local getCommandMoveGoal2D = Commands.GetCommandMoveGoal2D

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
		count = count - 1
	end

	local tags = {}

	for i = current and 0 or 1, count do
		tags[#tags + 1] = i -- I... think
	end

	spGiveOrderToUnit(unitID, CMD_REMOVE, tags)
end

-- `SkipCommand` has to handle the pregame build phase, as well.
-- Probably though, this should be an override used in commandq.
if pregame and WG then
	-- Temporary local that lasts until `pregame` ends:
	local function doSkipCommandPregame(current, count)
		pregame = Spring.GetGameFrame() <= 0
		local pregameBuild = WG["pregame-build"]

		if pregame and pregameBuild then
			if current == nil then
				current = true
			end

			if count == nil then
				count = 1
			end

			if count >= 1 and pregameBuild then
				local queue = pregameBuild.getBuildQueue()
				local result = {}

				if not current then
					result[1] = queue[1]
				end

				local start = current and 2 or 1

				for i = start, math.min(start + count - 1, #queue) do
					result[#result + 1] = queue[i]
				end

				pregameBuild.setBuildQueue(result)
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

---Remove commands from the queue that follow a non-terminating command. The resulting
-- command queue is more easily inspected and validated against other tests.
---@param unitID integer
---@return boolean changed Whether any commands were modified or removed
Commands.NormalizeQueue = function(unitID)
	local hasTerminal = false
	local isInPatrol = false

	local index = 1
	local tags = {}
	local count = 0

	repeat
		local command, _, tag = spGetUnitCurrentCommand(unitID, index)

		if command == nil then
			break
		end

		if hasTerminal then
			if not isInPatrol or command ~= CMD_PATROL then
				isInPatrol = false
				count = count + 1
				tags[count] = tag
			end
		elseif
			command == CMD_PATROL or command == CMD_GUARD or
			command == CMD_STOP or command == CMD_WAIT
		then
			hasTerminal = true

			if command == CMD_PATROL then
				isInPatrol = true
			end
		end

		index = index + 1
	until false

	if count > 0 then
		return spGiveOrderToUnit(unitID, CMD_REMOVE, tags)
	else
		return false
	end
end

---Get the position of the unit's queued move commands (or all commands).
---@param unitID integer
---@param all boolean?
---@param count integer?
---@return xyz[] coords
---@return integer count
Commands.GetUnitPositionQueue = function(unitID, all, count)
	local moves = {}
	local num = 0

	if count == nil then
		count = all and 64 or 32
	elseif count == 0 then
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
	local index = -1
	local command, _, _, p1, p2, p3, p4, p5, p6 = spGetUnitCurrentCommand(unitID, index)

	repeat
		if command == nil then
			break
		elseif all or moveCommands[command] then
			local x, y, z = getCommandPosition(command, repackParams(p1, p2, p3, p4, p5, p6))

			if x ~= nil then
				return x, y, z
			end
		end

		index = index - 1
		command, _, _, p1, p2, p3, p4, p5, p6 = spGetUnitCurrentCommand(unitID, index)
	until false

	return spGetUnitPosition(unitID)
end

---Get the position of the unit's queued move commands (or all commands) and the
-- radius within which those commands' move goals would be achieved. This allows
-- you to plot a shorter course through the commands or to combine overlaps etc.
---@param unitID integer
---@param all boolean?
---@param count integer?
---@return table coords <x, y, z, radius> where a negative radius is a leash radius
---@return integer count
Commands.GetUnitMoveGoalQueue = function(unitID, all, count)
	local moves = {}
	local num = 0

	if count == nil then
		count = all and 64 or 32
	elseif count == 0 then
		return moves, num
	end

	local queue = Spring.GetUnitCommands(unitID, count)

	for _, cmdInfo in ipairs(queue) do
		if all or moveCommands[cmdInfo.id] then
			local x, y, z, w, leashed = getCommandPositionAndRadius(cmdInfo.id, cmdInfo.params)

			if x ~= nil then
				num = num + 1
				moves[num] = { x, y, z, leashed and -w or w }
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
	local x, y, z = spGetUnitPosition(unitID)

	for _, command in ipairs(Spring.GetUnitCommands(unitID, -1)) do
		x, y, z = getCommandMoveGoal(command.id, command.params, x, y, z, range, all)
	end

	return x, y, z
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
Commands.GetUnitEndMoveGoal2D = function(unitID, range, all)
	local x, y, z = spGetUnitPosition(unitID)

	for _, command in ipairs(Spring.GetUnitCommands(unitID, -1)) do
		x, y, z = getCommandMoveGoal2D(command.id, command.params, x, z, range, all)
	end

	return x, y, z
end

--------------------------------------------------------------------------------
-- Factory queue functions -----------------------------------------------------

local FACTORY_DEQUEUE = CMD.OPT_RIGHT
local FACTORY_QUEUE_5 = CMD.OPT_SHIFT
local FACTORY_QUEUE_20 = CMD.OPT_CTRL
local FACTORY_QUEUE_100 = FACTORY_QUEUE_5 + FACTORY_QUEUE_20

---@param factoryID integer
---@return Command buildOrder
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

local STATE_DISABLED = "0"

---Get the description for the given command id, if any.
---@param unitID integer
---@param command CMD
---@return CommandDescription?
Commands.GetUnitCommandDescription = function(unitID, command)
	local index = spFindUnitCmdDesc(unitID, command)

	if index ~= nil then
		return spGetUnitCmdDescs(unitID, index, index)[1]
	end
end

local getUnitCommandDescription = Commands.GetUnitCommandDescription

---Determine whether an order given to a unit will occupy its command queue.
---@param unitID integer
---@param command CMD
---@return boolean? [nil] := both non-queueing and no matching command description
Commands.GetUnitCommandIsQueueing = function(unitID, command)
	local description = getUnitCommandDescription(unitID, command)

	if description ~= nil then
		-- Maybe the unit can multitask, so overrides its `queueing` to be `false`:
		return description.queueing == true
	else
		return queueingCommands[command]
	end
end

---Determine whether the unit has a stateful command and its current state, if any.
---@param unitID integer
---@param command CMD
---@return string|false params [false] := unit does not have command description
Commands.GetUnitState = function(unitID, command)
	local description = getUnitCommandDescription(unitID, command)

	if description ~= nil then
		local state = description.params[1]
		return state ~= nil and description.params[state]
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
		return description.params[1] ~= STATE_DISABLED
	end

	return false
end

---Determine whether a unit normally able to execute a command can do so currently.
--
-- Ignores the stunned state but not insufficient resources, etc.
---@param unitID integer
---@param command CMD
---@param unitDefID integer? optional
Commands.GetUnitCanExecute = function(unitID, command, unitDefID)
	local cmdDesc = spFindUnitCmdDesc(unitID, command)

	if cmdDesc ~= nil then
		if cmdDesc.disabled then
			return false
		end

		if command == CMD_LOAD_UNITS then
			local transportees = Spring.GetUnitIsTransporting(unitID)

			if transportees == nil then
				return false
			end

			local unitDef = UnitDefs[unitDefID or Spring.GetUnitDefID(unitID)]
			local capacity = unitDef.transportCapacity or 0
			local mass = unitDef.transportMass or 0

			for _, occupantID in ipairs(transportees) do
				capacity = capacity - 1
				mass = mass - Spring.GetUnitMass(occupantID)
			end

			-- Assuming minimum requirements:
			return capacity >= 1 and mass >= 1
		elseif command == CMD_UNLOAD_UNIT or command == CMD_UNLOAD_UNITS then
			local transportees = Spring.GetUnitIsTransporting(unitID)
			return transportees ~= nil and transportees[1] ~= nil
		elseif command == CMD_MANUALFIRE then
			-- `nil` when non-stockpiling; only `0` fails:
			if (Spring.GetUnitStockpile(unitID)) == 0 then
				return false
			else
				-- todo: check energy needed to fire
				return true
			end
		else
			return true
		end
	end

	-- idk. what else. aren't there commands with no descs?

	return false
end

--------------------------------------------------------------------------------
-- Export module ---------------------------------------------------------------

return Commands
