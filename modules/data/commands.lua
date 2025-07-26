--------------------------------------------------------------------------------
-- Configuration data for engine commands consumed by the `commands.lua` module.

---Maps every command to its accepted parameter counts.
--
-- @see `paramsType` for the names of parameter count sets used here.
---@type table<CMD, string>
local CommandParamType = {
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
local IsQueuingCommand = {
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

---Whether a command is shown to the player, e.g. on the order menu.
--
-- By extension, this includes internal-only and obsoleted commands.
---@type table<CMD, true>
local IsHiddenCommand = {
	[CMD.DEATHWAIT]      = true,
	[CMD.GATHERWAIT]     = true,
	[CMD.GROUPADD]       = true,
	[CMD.GROUPCLEAR]     = true,
	[CMD.GROUPSELECT]    = true,
	[CMD.INSERT]         = true,
	[CMD.INTERNAL]       = true,
	[CMD.LOAD_ONTO]      = true,
	[CMD.LOOPBACKATTACK] = true,
	[CMD.REMOVE]         = true,
	[CMD.SELFD]          = true,
	[CMD.SETBASE]        = true,
	[CMD.SQUADWAIT]      = true,
	[CMD.TIMEWAIT]       = true,
}

return {
	CommandParamType = CommandParamType,
	IsQueuingCommand = IsQueuingCommand,
	IsHiddenCommand  = IsHiddenCommand,
}
