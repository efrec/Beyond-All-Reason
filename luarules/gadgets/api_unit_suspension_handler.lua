local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Suspended Unit Handler",
		desc    = "Prevent actions by units that are stunned, trapped, or disabled.",
		author  = "efrec",
		date    = "2025",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer   = -999999,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

--------------------------------------------------------------------------------

---Immediately remove commands from the unit's queue when it is suspended.
---@type table<CMD, true>
local commandSuspendRemoves = {
	[CMD.MOVE]         = true,
	[CMD.GUARD]        = true,
	[CMD.FIGHT]        = true,
	[CMD.PATROL]       = true,

	[CMD.LOAD_ONTO]    = true,
	[CMD.LOAD_UNITS]   = true,
	[CMD.UNLOAD_UNIT]  = true,
	[CMD.UNLOAD_UNITS] = true,

	[CMD.GATHERWAIT]   = true,
	[CMD.SQUADWAIT]    = true,

	[CMD.CAPTURE]      = true,
	[CMD.RECLAIM]      = true,
	[CMD.REPAIR]       = true,
	[CMD.RESURRECT]    = true,
	[CMD.RESTORE]      = true,
}

---Prevent the unit from accepting commands when it is suspended.
---@type table<CMD, true>
local commandSuspendDisallows = {
	[CMD.LOAD_ONTO]    = true,
	[CMD.LOAD_UNITS]   = true,
	[CMD.UNLOAD_UNIT]  = true,
	[CMD.UNLOAD_UNITS] = true,

	[CMD.GATHERWAIT]   = true,
	[CMD.SQUADWAIT]    = true,

	[CMD.CAPTURE]      = true,
	[CMD.RECLAIM]      = true,
	[CMD.REPAIR]       = true,
	[CMD.RESURRECT]    = true,
	[CMD.RESTORE]      = true,
}

--------------------------------------------------------------------------------

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spSetUnitRulesParam = Spring.SetUnitRulesParam

local removeIDs = {}

for command, check in pairs(commandSuspendRemoves) do
	if command >= 0 and check then
		removeIDs[#removeIDs + 1] = command
	end
end

local suspendReasons = {
	-- Engine (stunned units):
	UnitStunned      = "UnitStunned",
	UnitBeingBuilt   = "UnitFinished",
	UnitCloaked      = "UnitDecloaked", -- see `Spring.SetUnitCloak`
	UnitLoaded       = "UnitUnloaded",

	-- Game:
	UnitEnteredAir   = "UnitLeftAir",
	UnitEnteredWater = "UnitLeftWater",
	UnitLeftAir      = "UnitEnteredAir",
	UnitLeftWater    = "UnitEnteredWater",
}

local suspendedUnits = {}

--------------------------------------------------------------------------------

function gadget:Initialize()
	---Map your gadget's special-purpose disable to its re-enable reason.
	--
	-- General disable/enable functionality is part of the unit suspend handler.
	---@param suspend string
	---@param resume string
	GG.AddUnitSuspendAndResumeReason = function(suspend, resume)
		if suspend ~= nil and resume ~= nil and suspendReasons[suspend] == nil then
			suspendReasons[suspend] = resume
			return true
		else
			return false
		end
	end

	---Disable the unit and set the reason why it cannot take actions.
	---@param unitID integer
	---@param reason string?
	---@param remove boolean? whether to clear disallowed commands from the command queue
	---@return string? enableReason
	GG.AddSuspendReason = function(unitID, reason, remove)
		local suspendedUnit = suspendedUnits[unitID]

		if suspendedUnit == nil then
			spSetUnitRulesParam(unitID, "suspended", 1)
			suspendedUnit = {}

			if remove ~= false then
				spGiveOrderToUnit(unitID, CMD.REMOVE, removeIDs, CMD.OPT_ALT)
			end
		end

		if reason ~= nil then
			local enableReason = suspendReasons[reason] or reason
			suspendedUnit[enableReason] = true
			return enableReason
		end
	end

	---Clear a disable reason on the unit and attempt to re-enable it.
	---@param unitID integer
	---@param reason string?
	---@return boolean enabled
	GG.ClearSuspendReason = function(unitID, reason)
		local suspendedUnit = suspendedUnits[unitID]

		if suspendedUnit == nil then
			return true
		end

		local enableReason = reason ~= nil and suspendReasons[reason]

		if enableReason then
			suspendedUnit[enableReason] = nil
		end

		if not enableReason or next(suspendedUnit) == nil then
			spSetUnitRulesParam(unitID, "suspended", 0)
			suspendedUnits[unitID] = nil
			return true
		end

		return false
	end

	---@param unitID integer
	GG.GetUnitIsSuspended = function(unitID)
		return suspendedUnits[unitID] ~= nil
	end

	---@param unitID integer
	---@return string[]? enableReasons
	GG.GetUnitSuspendReasons = function(unitID)
		local suspendedUnit = suspendedUnits[unitID]

		if suspendedUnit ~= nil then
			local reasons = {}

			for reason in pairs(reasons) do
				reasons[#reasons + 1] = reason
			end

			return reasons
		end
	end
end

function gadget:Shutdown()
	GG.AddSuspendReason = nil
	GG.ClearSuspendReason = nil
	GG.GetUnitIsSuspended = nil
	GG.GetUnitSuspendReasons = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	suspendedUnits[unitID] = nil
end

--------------------------------------------------------------------------------

local function addSuspendReason(unitID, reason, remove)
	local suspendedUnit = suspendedUnits[unitID]

	if suspendedUnit == nil then
		spSetUnitRulesParam(unitID, "suspended", 1)
		suspendedUnit = {}

		if remove ~= false then
			spGiveOrderToUnit(unitID, CMD.REMOVE, removeIDs, CMD.OPT_ALT)
		end
	end

	if reason ~= nil then
		local enableReason = suspendReasons[reason] or reason
		suspendedUnit[enableReason] = true
	end
end

local function clearSuspendReason(unitID, reason)
	local suspendedUnit = suspendedUnits[unitID]
	suspendedUnit[suspendReasons[reason]] = nil

	if next(suspendedUnit) == nil then
		spSetUnitRulesParam(unitID, "suspended", 0)
		suspendedUnits[unitID] = nil
	end
end

-- Removing stuns

function gadget:UnitStunned(unitID, unitDefID, unitTeam, stunned)
	if stunned then
		addSuspendReason(unitID, "UnitStunned", false)
	elseif suspendedUnits[unitID] then
		clearSuspendReason(unitID, "UnitStunned")
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if suspendedUnits[unitID] then
		clearSuspendReason(unitID, "UnitFinished")
	end
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	if suspendedUnits[unitID] then
		clearSuspendReason(unitID, "UnitDecloaked")
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if suspendedUnits[unitID] ~= nil then
		clearSuspendReason(unitID, "UnitUnloaded")
	end
end

-- Removing non-stuns

function gadget:UnitEnteredAir(unitID, unitDefID, unitTeam)
	if suspendedUnits[unitID] then
		clearSuspendReason(unitID, "UnitEnteredAir")
	end
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if suspendedUnits[unitID] then
		clearSuspendReason(unitID, "UnitEnteredWater")
	end
end

function gadget:UnitLeftAir(unitID, unitDefID, unitTeam)
	if suspendedUnits[unitID] then
		clearSuspendReason(unitID, "UnitLeftAir")
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if suspendedUnits[unitID] then
		clearSuspendReason(unitID, "UnitLeftWater")
	end
end

--------------------------------------------------------------------------------

local function checkShouldAllow(_, unitID)
	return suspendedUnits[unitID] == nil
end

gadget.AllowUnitBuildStep = checkShouldAllow
gadget.AllowUnitCaptureStep = checkShouldAllow
gadget.AllowUnitTransport = checkShouldAllow

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced, fromLua)
	if suspendedUnits[unitID] then
		return cmdID >= 0 and commandSuspendDisallows[cmdID] == nil
	else
		return true
	end
end
