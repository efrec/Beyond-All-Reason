local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Attached and Paired Units',
		desc    = 'Manages always-attached units with a paired virtual unit.',
		author  = 'efrec',
		version = '0',
		date    = '2025',
		license = 'GNU GPL, v2 or later',
		layer   = -999999,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- Global values ---------------------------------------------------------------

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local resetCommandOptions = Spring.Utilities.Commands.ResetCommandOptions
local resolveCommand = Spring.Utilities.Commands.ResolveCommand

local CMD_STOP = CMD.STOP

local GameCMD = Game.CustomCommands.GameCMD

--------------------------------------------------------------------------------
-- Command introspection -------------------------------------------------------

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

---@type CommandParamsType
local PRM_ANY = setmetatable({}, { __index = function() return true end })
---@type CommandParamsType
local PRM_NUL = {}

-- Allow list ------------------------------------------------------------------

---Parameter counts => allowed
---@type table<string, CommandParamsType>
local countAllowed = {
	changeState  = { [0] = true, [1] = true },
	mapPosition  = { [3] = true, [4] = true },
	mapArea      = { [4] = true },
	targetOrPos  = { [1] = true, [3] = true, [4] = true },
	targetOrArea = { [1] = true, [4] = true },
	buildTarget  = { [1] = true, [5] = true },
}

---Allowed commands, filtered down by param counts
--
-- While attached units can *be* moved they cannot *pursue* separate move goals.
-- Commands with such goals or that require movement should not be allowed.
--
-- For example, CMD_RECLAIM targets a unit or feature given params count 1 or 5,
-- so these counts are allowed. It can target an area given 4 params, as well,
-- so this count is not in the allow list because it implies a future move goal.
---@type table<CMD, CommandParamsType>
local commandParamAllow = setmetatable({
	-- Engine commands:
	[CMD.INSERT]                        = PRM_ANY,
	[CMD.REMOVE]                        = PRM_ANY,
	[CMD.WAIT]                          = PRM_ANY,
	[CMD.DEATHWAIT]                     = PRM_ANY,
	[CMD.TIMEWAIT]                      = PRM_ANY,
	[CMD.GROUPCLEAR]                    = PRM_ANY,

	[CMD.FIRE_STATE]                    = countAllowed.changeState,
	[CMD.MOVE_STATE]                    = countAllowed.changeState,
	[CMD.IDLEMODE]                      = countAllowed.changeState,
	[CMD.ONOFF]                         = countAllowed.changeState,
	[CMD.TRAJECTORY]                    = countAllowed.changeState,
	[CMD.STOCKPILE]                     = countAllowed.changeState,
	[CMD.REPEAT]                        = countAllowed.changeState,

	[CMD.ATTACK]                        = countAllowed.targetOrPos,
	[CMD.MANUALFIRE]                    = countAllowed.targetOrPos,

	-- These commands have their mapArea disallowed (#params == 4):
	[CMD.CAPTURE]                       = countAllowed.buildTarget,
	[CMD.RECLAIM]                       = countAllowed.buildTarget,
	[CMD.REPAIR]                        = countAllowed.buildTarget,
	[CMD.RESURRECT]                     = countAllowed.buildTarget,

	[CMD.RESTORE]                       = countAllowed.mapPosition,

	-- Game commands:
	[GameCMD.CARRIER_SPAWN_ONOFF]       = countAllowed.changeState,
	[GameCMD.MORPH]                     = countAllowed.changeState,
	[GameCMD.PRIORITY]                  = countAllowed.changeState,
	[GameCMD.QUOTA_BUILD_TOGGLE]        = countAllowed.changeState,
	[GameCMD.SMART_TOGGLE]              = countAllowed.changeState,
	[GameCMD.STOP_PRODUCTION]           = countAllowed.changeState,
	[GameCMD.UNIT_CANCEL_TARGET]        = countAllowed.changeState,

	[GameCMD.MANUAL_LAUNCH]             = countAllowed.targetOrPos,

	[GameCMD.UNIT_SET_TARGET]           = countAllowed.targetOrArea,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = countAllowed.targetOrArea,
}, {
	-- Otherwise, pass the null params set.
	__index = function() return PRM_NUL end
})

-- Parameter positions of object IDs -------------------------------------------

---Parameter counts => index of target id
---@type table<string, CommandParamsMap>
local indexMap = {
	anyIndex  = setmetatable({}, { __index = function(_, count) if count >= 1 then return 1 end end }),
	placeUnit = setmetatable({}, { __index = function(_, count) if count >= 4 then return 4 end end }),
	placeList = setmetatable({}, { __index = function(_, count) if count >= 5 then return 5 end end }),
	attacks   = { [1] = 1, [2] = 1 }, -- excludes [3] map position and [4] area attack
	buildCAI  = { [1] = 1, [5] = 1 }, -- excludes [4] area worker task
	iconUnit  = { [1] = 1 },
}

---See `IsObjectCommand` in Command.h, and see BuilderCAI.cpp.
---@type table<CMD, CommandParamsMap>
local commandParamTarget = setmetatable({
	-- Engine commands:
	[CMD.GUARD]                         = indexMap.anyIndex,
	[CMD.LOAD_ONTO]                     = indexMap.anyIndex,

	[CMD.ATTACK]                        = indexMap.attacks,
	[CMD.FIGHT]                         = indexMap.attacks,
	[CMD.MANUALFIRE]                    = indexMap.attacks,

	[CMD.LOAD_UNITS]                    = indexMap.iconUnit,

	[CMD.CAPTURE]                       = indexMap.buildCAI,
	[CMD.RECLAIM]                       = indexMap.buildCAI,
	[CMD.REPAIR]                        = indexMap.buildCAI,
	[CMD.RESURRECT]                     = indexMap.buildCAI,

	-- We need special exceptions for these, in fact:
	[CMD.UNLOAD_UNIT]                   = indexMap.placeUnit,
	[CMD.UNLOAD_UNITS]                  = indexMap.placeList,

	-- Game commands:
	[GameCMD.FACTORY_GUARD]             = indexMap.iconUnit,
	[GameCMD.UNIT_SET_TARGET]           = indexMap.iconUnit,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = indexMap.iconUnit,
}, {
	-- Otherwise, pass the null params set.
	__index = function() return PRM_NUL end
})

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local pairBaseDefID = {} ---@type table<integer, integer>
local pairAttachDefID = {} ---@type table<integer, integer>

local pairUnitID = {} ---@type table<integer, integer>
local pairAttachID = {} ---@type table<integer, true>
local inactiveUnits = {} ---@type table<integer, true>

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

---@return integer? baseID
---@return integer? attachedID
local function getUnitPair(unitID)
	local otherID = pairUnitID[unitID]
	if otherID ~= nil then
		if pairAttachID[unitID] then
			return otherID, unitID
		else
			return unitID, otherID
		end
	end
end

---The resulting unit cannot be interacted with, directly or indirectly, except
-- by the input of the base unit. See the notes on `GG.addPairedUnit`.
local function virtualize(unitID)
	Spring.SetUnitMass(unitID, 0)
	Spring.SetUnitBlocking(unitID, false, false, false, false, false, false, false)

	Spring.SetUnitArmored(unitID, true, 0) -- hacky: prevents all damage

	Spring.SetUnitNoSelect(unitID, true)

	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitSonarStealth(unitID, true)
	Spring.SetUnitSeismicSignature(unitID, 0) -- todo: test, this triggered a crash once

	Spring.SetUnitSensorRadius(unitID, "los", 0)
	Spring.SetUnitSensorRadius(unitID, "airLos", 0)
	Spring.SetUnitSensorRadius(unitID, "radar", 0)
	Spring.SetUnitSensorRadius(unitID, "sonar", 0)
	Spring.SetUnitSensorRadius(unitID, "seismic", 0)
	Spring.SetUnitSensorRadius(unitID, "radarJammer", 0)
	Spring.SetUnitSensorRadius(unitID, "sonarJammer", 0)
end

local function allowPairedUnitCommand(command, params, pairedID)
	local index = commandParamTarget[command][#params]
	return index == nil or params[index] ~= pairedID
end

local function allowAttachedUnitCommand(unitID, command, params, cmdOptions, insertIndex)
	if commandParamAllow[command][#params] == nil then
		return false
	end

	local inserted = insertIndex ~= nil

	if spGetUnitCommandCount(unitID) > 0 then
		if (cmdOptions.alt ~= cmdOptions.shift) or (inserted and insertIndex ~= 0) then
			-- Enqueues and inserts must emplace all commands to the front.
			return false
		elseif cmdOptions.meta or inserted then
			-- Orders inserted at the front of the queue => regular orders.
			if #params ~= 0 then
				-- Some commands with no params have to pass their options.
				-- Otherwise, we must remove any options that will enqueue.
				cmdOptions = resetCommandOptions(cmdOptions, true)
			end

			spGiveOrderToUnit(unitID, command, params, cmdOptions)
			return false
		end
	end

	return true
end

local function setUnitPairInactive(sourceID, inactive)
	---@type integer, integer
	local baseID, attachedID = getUnitPair(sourceID) ---@diagnostic disable-line -- OK

	if sourceID == baseID then
		if inactive then
			-- The base always suspends the attached unit.
			inactiveUnits[baseID] = true
			spGiveOrderToUnit(attachedID, CMD_STOP)
			inactiveUnits[attachedID] = true
		else
			inactiveUnits[baseID] = nil

			-- But might not *un*suspend the attached unit.
			if not Spring.GetUnitIsStunned(attachedID) then
				inactiveUnits[attachedID] = nil
			end
		end
	elseif sourceID == attachedID then
		if inactive then
			spGiveOrderToUnit(attachedID, CMD_STOP)
			inactiveUnits[attachedID] = true
		elseif not inactiveUnits[baseID] then
			inactiveUnits[attachedID] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	local function suspendCallback(unitID, suspended)
		if pairUnitID[unitID] then
			local baseID, attachedID = getUnitPair(unitID)
			setUnitPairInactive(baseID, attachedID, unitID, suspended)
		end
	end
	GG.RegisterSuspendNotify(suspendCallback)

	gadgetHandler:RegisterAllowCommand(CMD.ANY)

	---Required for adding attached unit pairs individually.
	--
	-- Each base and attached def can be associated only once.
	---@see GG.addPairedUnit
	---@param baseDefID integer
	---@param attachDefID integer
	---@return boolean added
	GG.AddPairedUnitDef = function(baseDefID, attachDefID)
		if baseDefID ~= attachDefID and pairAttachDefID[baseDefID] == nil then
			pairBaseDefID[baseDefID] = attachDefID
			pairAttachDefID[attachDefID] = baseDefID
			return true
		else
			return false
		end
	end

	---Create a paired relationship between a unit and a virtual/subordinate attachee.
	--
	-- - Paired units are mutually death-dependent. If one is destroyed, both are.
	-- - When one is stunned or transported (etc), both are.
	-- - Neither can target the other with commands like CMD_REPAIR.
	--
	-- In addition, the attached unit cannot:
	-- - be selected or raytraced
	-- - block other units
	-- - collide with projectiles
	-- - be damaged
	-- - detect other units
	-- - be detected by other units
	-- - receive commands with move goals
	-- - enqueue commands to perform later
	--
	---@param baseID integer
	---@param attachID integer
	---@param pieceNumber integer
	---@return boolean paired
	GG.AddPairedUnit = function(baseID, attachID, pieceNumber)
		if baseID ~= attachID and
			pairBaseDefID[Spring.GetUnitDefID(baseID)] ~= nil and
			pairAttachDefID[Spring.GetUnitDefID(attachID)] ~= nil
		then
			pairAttachID[attachID] = true
			pairUnitID[baseID] = attachID
			pairUnitID[attachID] = baseID
			Spring.UnitAttach(baseID, attachID, pieceNumber)
			virtualize(attachID)

			-- For late-attached units (bad!) and luarulres reloads (okay):

			if Spring.GetUnitIsStunned(baseID) then
				setUnitPairInactive(baseID, true)
			elseif Spring.GetUnitIsStunned(attachID) then
				setUnitPairInactive(attachID, true)
			end

			if Spring.GetUnitIsCloaked(baseID) then
				Spring.SetUnitCloak(attachID, 3, -1)
			elseif Spring.GetUnitIsCloaked(attachID) then
				Spring.SetUnitCloak(attachID, false, false)
			end

			return true
		else
			return false
		end
	end
end

function gadget:Shutdown()
	GG.AddPairedUnitDef = nil
	GG.AddPairedUnit = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if pairUnitID[unitID] then
		inactiveUnits[unitID] = nil
		local pairedID = pairUnitID[unitID]
		pairUnitID[unitID] = nil
		Spring.DestroyUnit(pairedID, false, true)
	end
end

function gadget:UnitTaken(unitID, unitDefID, teamID, newTeamID)
	-- Unlike UnitLoaded, unit transfer is often programmatic.
	-- We need to account for unit transfers from both ends:
	if pairUnitID[unitID] then
		-- ? do trivial transfers get ignored by these callins?
		Spring.TransferUnit(pairUnitID[unitID], newTeamID)
	end
end

function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	if pairUnitID[unitID] and not pairAttachID[unitID] then
		local attachedID = pairUnitID[unitID]
		-- Free cloak, cannot be decloaked, but stunned:
		Spring.SetUnitCloak(attachedID, 3, -1)
	end
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	if pairUnitID[unitID] and not pairAttachID[unitID] then
		local attachedID = pairUnitID[unitID]
		Spring.SetUnitCloak(attachedID, false, false)
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
	local pairedID = pairUnitID[unitID]

	if pairedID == nil then
		return true
	elseif inactiveUnits[unitID] ~= nil then
		return false
	end

	-- FIXME: Not needed after merging PR to unpack CMD_INSERT before gadgets:
	-- https://github.com/beyond-all-reason/Beyond-All-Reason/pull/5560
	local command, params, options, tag = resolveCommand(cmdID, cmdParams, cmdOptions)

	-- We enforce a few requirements in this callin:

	-- 1. Paired units cannot target one another.
	if not allowPairedUnitCommand(command, params, pairedID) then
		return false
	end

	-- 2. Attached units cannot pursue move goals so must reject orders requiring them.
	-- 3. Attached units cannot have disjoint state; e.g. they do not cloak separately.
	if pairAttachID[unitID] then
		if not allowAttachedUnitCommand(unitID, command, params, options, tag) then
			return false
		end
	end

	return true
end

function gadget:AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID,
								   transporteeUnitDefID, transporteeTeam)
	return pairUnitID[transporterID] ~= transporteeID
end
