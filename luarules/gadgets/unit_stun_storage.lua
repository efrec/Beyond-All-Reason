local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Stun Storage",
		desc = "Makes stunned storage drop capactiy",
		author = "Nixtux, Floris",
		date = "June 15, 2014",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetTeamResources = Spring.GetTeamResources
local spSetTeamResource = Spring.SetTeamResource

local paralyzedUnits = {}

local storageDefs = Game.UnitInfo.Cache.storageAmounts
local isImmobile = Game.UnitInfo.Cache.isImmobile

local function restoreStorage(unitID, unitDefID, teamID)
	local storage = storageDefs[unitDefID]
	if storage.metal then
		local _, totalStorage = spGetTeamResources(teamID, "metal")
		spSetTeamResource(teamID, "ms", totalStorage + storage.metal)
	end
	if storage.energy then
		local _, totalStorage = spGetTeamResources(teamID, "energy")
		spSetTeamResource(teamID, "es", totalStorage + storage.energy)
	end
	paralyzedUnits[unitID] = nil
end

local function reduceStorage(unitID, unitDefID, teamID)
	paralyzedUnits[unitID] = unitDefID
	local storage = storageDefs[unitDefID]
	if storage.metal then
		local _, totalStorage = spGetTeamResources(teamID, "metal")
		spSetTeamResource(teamID, "ms", totalStorage - storage.metal)
	end
	if storage.energy then
		local _, totalStorage = spGetTeamResources(teamID, "energy")
		spSetTeamResource(teamID, "es", totalStorage - storage.energy)
	end
end

function gadget:UnitStunned(unitID, unitDefID, teamID, stunned)
	if not storageDefs[unitDefID] or not isImmobile[unitDefID] then
		return
	end

	if stunned then
		if not paralyzedUnits[unitID] then
			if Spring.GetUnitIsBeingBuilt(unitID) == false then
				reduceStorage(unitID, unitDefID, teamID)
			end
		end
	else
		if paralyzedUnits[unitID] then
			restoreStorage(unitID, unitDefID, teamID)
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if paralyzedUnits[unitID] then
		restoreStorage(unitID, unitDefID, oldTeam)
		reduceStorage(unitID, unitDefID, newTeam)
	end
end

--function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
--	gadget:UnitGiven(unitID, unitDefID, newTeam, unitTeam)
--end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if storageDefs[unitDefID] and isImmobile[unitDefID] then
		local _, maxHealth, paralyzeDamage, _, _ = Spring.GetUnitHealth(unitID)
		if paralyzeDamage > maxHealth then
			reduceStorage(unitID, unitDefID, unitTeam)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if paralyzedUnits[unitID] then
		restoreStorage(unitID, unitDefID, unitTeam)
	end
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		if Spring.GetUnitIsBeingBuilt(unitID) == false then
			local unitDefID = Spring.GetUnitDefID(unitID)
			if storageDefs[unitDefID] and isImmobile[unitDefID] and select(2, Spring.GetUnitIsStunned(unitID)) then
				reduceStorage(unitID, unitDefID, Spring.GetUnitTeam(unitID))
			end
		end
	end
end

function gadget:Shutdown()
	local spGetUnitIsStunned = Spring.GetUnitIsStunned
	for unitID, unitDefID in pairs(paralyzedUnits) do
		if spGetUnitIsStunned(unitID) then
			restoreStorage(unitID, unitDefID, Spring.GetUnitTeam(unitID))
		end
	end
end
