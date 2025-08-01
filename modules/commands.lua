--------------------------------------------------------------------------------
-------------------------------------------------------------- [commands.lua] --

if not Spring or not CMD then
	return
end

---Functions and utilities for common tasks using RecoilEngine commands.
---@module Commands
local Commands = {}

---Commands typically have up to six parameters,
---but can be inserted, which adds three params.
---@alias CommandParamsCount 0|1|2|3|4|5|6|7|8|9
---The index for a particular command parameter.
---@alias CommandParamIndex 1|2|3|4|5|6|7|8|9
---The accepted parameter counts of a command.
---@alias CommandParamsType table<CommandParamsCount, true>
---The index for a particular command parameter,
---given the command's count of parameters passed.
---@alias CommandParamsMap table<CommandParamsCount, CommandParamIndex>

--------------------------------------------------------------------------------
-- Module internals ------------------------------------------------------------

local bit_and = math.bit_and
local bit_or = math.bit_or

local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMD_INSERT = CMD.INSERT
local CMD_ATTACK = CMD.ATTACK
local CMD_FIGHT = CMD.FIGHT
local CMD_GUARD = CMD.GUARD

local OPT_INTERNAL = CMD.OPT_INTERNAL
local OPT_ALT = CMD.OPT_ALT
local OPT_CTRL = CMD.OPT_CTRL
local OPT_META = CMD.OPT_META
local OPT_SHIFT = CMD.OPT_SHIFT
local OPT_RIGHT = CMD.OPT_RIGHT

local CMD_INSERT_SIZE = 3       -- The extra #params added when packing a command inside CMD_INSERT.
local PARAM_POOL_SIZE = 8       -- #params above this use a memory pool that is much more expensive.
local PARAM_COUNT_MAX = 6       -- Line and Rectangle need 6. Ideally, this would be POOL - INSERT.
local PARAM_POOL_COUNT_MAX = 64 -- Commands can support a ridiculous number of params though.

---Cannot produce empty sets.
---@param min integer
---@param max integer
---@return CommandParamsType
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

local getTempTbl
do
	local tempTbl = {} -- sometimes easier to use a temp iter tbl

	getTempTbl = function(value)
		tempTbl[1] = value
		return tempTbl
	end
end

-- Command options have extremely flexible equivalence, without type equality.
-- So, there are a bunch of ways that we might need to convert between them:

-- Command option nils: `nil` -> all options false
-- Command option strings: "alt"|"internal"|...
-- Command option bits: 128|64|32|...
-- Command option codes: integer
-- Command option maps: { ["alt"] = boolean, ["internal"] = boolean, ... }
-- Command option sequences: { "alt", "internal", ... }
-- Command option mixed tables: { "alt", ["internal"] = boolean, ... }

---@param code integer
---@return CommandOptions
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

---@type table<CommandOptionName, CommandOptionBit>
local optionNameCodes = {
	alt      = OPT_ALT,
	shift    = OPT_SHIFT,
	meta     = OPT_META,
	ctrl     = OPT_CTRL,
	right    = OPT_RIGHT,

	-- Ignored option names:
	coded    = 0,
	internal = OPT_INTERNAL,
}

---The module should try to resolve type mismatches, however annoying to do:
---@param options CommandOptions|CreateCommandOptions|integer?
---@return integer?
local function resolveOptionCode(options)
	if options == nil then
		return 0
	elseif type(options) == "number" then
		return options
	end

	local code = 0

	-- `options := table<CommandOptionName, boolean>|CommandOptionName[]|CommandOptionName`:
	for key, value in pairs(type(options) == "table" and options or getTempTbl(options)) do
		code = code + (optionNameCodes[key] or optionNameCodes[value] or 0)
	end

	return code
end

---Command options have an expensive equality check due to blind type-check issues.
---@param options1 CommandOptions|CreateCommandOptions|integer? original (if temp)
---@param options2 CommandOptions|CreateCommandOptions|integer? copied (if temp)
---@param isTemp boolean?
---@param ignoreMeta boolean?
local function equalOption(options1, options2, isTemp, ignoreMeta)
	if options1 == options2 then
		return true
	end

	local code1 = resolveOptionCode(options1)
	local code2 = resolveOptionCode(options2)

	if code1 == code2 then
		return true
	end

	-- Most temp commands add OPT_INTERNAL:
	if isTemp then
		code1 = bit_or(code1, OPT_INTERNAL)
	end

	-- Most Recoil games hook OPT_META:
	if ignoreMeta then
		code1 = bit_or(code1, OPT_META)
		code2 = bit_or(code2, OPT_META)
	end

	return code1 == code2
end

---@param optionsBitSet integer|CommandOptionBit
local function isInternalBit(optionsBitSet)
	return bit_and(optionsBitSet, OPT_INTERNAL) ~= 0
end

---@param options CommandOptions|CreateCommandOptions|integer?
local function isInternal(options)
	if options == nil then
		return false
	elseif type(options) == "table" then
		return options.internal or (table.getKeyOf(options, "internal") ~= nil)
	elseif type(options) == "number" then
		return isInternalBit(options)
	elseif type(options) == "string" then
		return options == "internal"
	else
		return false
	end
end

--------------------------------------------------------------------------------
-- Module diagnostics ----------------------------------------------------------

-- There is a lot of annoying friction between CMD and integer for commands,
-- number and number[] and nil for parameters, and command options are a mess.
-- It's better to do without diagnostics than to have 100 erroneous warnings:

---@diagnostic disable: cast-local-type
---@diagnostic disable: redundant-return-value
---@diagnostic disable: redundant-parameter
---@diagnostic disable: return-type-mismatch

--------------------------------------------------------------------------------
-- Order functions -------------------------------------------------------------

-- Orders are commands as they are issued to units and before they are accepted.
-- Note: This is some niche terminology and applies only to the Commands module.

---Retrieve the command info from the params of a CMD_INSERT.
---@param params number[]|number
---@return CMD command
---@return number[]|number? commandParams
---@return integer commandOptionsBits
---@return integer insertIndex
Commands.GetInsertedCommand = function(params)
	local innerParams

	if params[5] == nil then
		innerParams = params[4]
	else
		innerParams = { params[4], params[5], params[6], params[7], params[8], params[9] }
	end

	return
		params[2],
		innerParams,
		params[3],
		params[1]
end

local getInsertedCommand = Commands.GetInsertedCommand

---Retrieve the command info from the params of a CMD_INSERT.
---@param params number[]
---@return CMD command
---@return number[]|number? commandParams
---@return CommandOptions commandOptions
---@return integer commandTag
Commands.GetInsertedFullCommand = function(params)
	local innerParams

	if params[5] == nil then
		innerParams = params[4]
	else
		innerParams = {}
		for i = 4, #params do
			innerParams[i - 3] = params[i]
		end
	end

	return
		params[2],
		innerParams,
		getOptions(params[3]),
		params[1]
end

local getInsertedFullCommand = Commands.GetInsertedFullCommand

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

local resolveCommand = Commands.ResolveCommand

---Retrieve the actual command from an order, resolving any meta-commands passed.
---@param command CMD
---@param params number[]
---@param options CommandOptions
---@param tag integer
---@return CMD? command
---@return number[]|number? commandParams
---@return CommandOptions? commandOptions
---@return integer? insertIndex
Commands.ResolveFullCommand = function(command, params, options, tag)
	if command == CMD_INSERT then
		---@diagnostic disable-next-line: param-type-mismatch -- Should throw on nil.
		return getInsertedFullCommand(params)
	else
		return command, params, options, tag
	end
end

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
		return command == CMD_ATTACK and (cmdOpts == nil or equalOption(options, cmdOpts, true))
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

---Issue an order and test if the command was accepted.
--
-- __Note:__ This checks only the front of the command queue.
---@param unitID integer
---@param command CMD
---@param params number[]|number?
---@param options CommandOptions|integer?
Commands.TryGiveOrder = function(unitID, command, params, options)
	return
		spGiveOrderToUnit(unitID, command, params, options)
		and isInCommand(unitID, command, params, options)
end

---Insert an order and test if the command was accepted.
--
-- __Note:__ This checks only the front of the command queue.
---@param unitID integer
---@param command CMD
---@param params number[]|number?
---@param options CommandOptions|integer?
Commands.TryInsertOrder = function(unitID, command, params, options)
	return spGiveOrderToUnit(unitID, command, params, options)
		and isInCommand(unitID, resolveCommand(command, params))
end

---Get the unitID of the target of CMD_GUARD, if any.
---@param unitID integer
---@param index integer? default = 1
---@return integer? guardedID
Commands.GetGuardedID = function(unitID, index)
	if index == nil then
		index = 1
	end

	repeat
		local command, options, _, maybeUnitID = spGetUnitCurrentCommand(unitID, index)

		if command == CMD_GUARD then
			return maybeUnitID
		elseif command == nil or not isInternal(options) then
			return
		else
			index = index + 1
		end
	until false
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
-- Export module ---------------------------------------------------------------

return Commands
