function gadget:GetInfo()
	return {
		name    = 'Attached Con Turret on Metal Extractor',
		desc    = 'Allows the mex to function as a con turret by replacing it with a fake mex with a con turret attached',
		author  = 'EnderRobo',
		version = 'v1',
		date    = 'September 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 12, -- TODO: explain layer
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local ALLY_UNITS_FLAG = -3 -- See LuaUtils.UnitAllegiance, fake teamID (<0) for passing unit queries.
local mexDefIDs = {}       -- The constructed mex unit. Maps to its hidden replacement and attached con unit IDs.
local conDefIDs = {}       -- The replacement constructor which is selectable, takes damage, etc.
local mexSwapID = {}       -- Handles pending replacements of constructed mexes with attached hidden/turret units.

function gadget:Initialize()
	for unitDefID, unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.attached_con_turret and unitDef.customParams.attached_mex_replace then
			local conDefID = UnitDefNames[unitDef.customParams.attached_con_turret].id
			local repDefID = UnitDefNames[unitDef.customParams.attached_mex_replace].id
			mexDefIDs[unitDefID] = { conDefID = conDefID, mexDefID = repDefID }
			conDefIDs[conDefID] = true
		end
	end
	if not next(mexDefIDs) then
		gadgetHandler:RemoveGadget(self)
	end
end

do
	local function getUpgradedMex(newMexID)
		local ux, _, uz = Spring.GetUnitPosition(newMexID)
		local units = Spring.GetUnitsInCylinder(ux, uz, 4, ALLY_UNITS_FLAG)
		for _, unitID in ipairs(units) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			if UnitDefs[unitDefID].extractsMetal then
				return unitID, unitDefID
			end
		end
	end

	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		if mexDefIDs[unitDefID] then
			local oldUnitID, oldUnitDefID = getUpgradedMex(unitID)
			mexSwapID[unitID] = {
				unitDefID    = unitDefID,
				builderTeam  = unitTeam,
				oldUnitID    = oldUnitID,
				oldUnitDefID = oldUnitDefID,
			}
		end
	end
end

do
	local function swapMexAndAttachCon(mexUnitID, swapData)
		mexSwapID[mexUnitID] = nil
		local newUnitTeam = Spring.GetUnitTeam(mexUnitID)
		local mx, my, mz = Spring.GetUnitPosition(mexUnitID)
		local facing = Spring.GetUnitBuildFacing(mexUnitID)
		local _, metalSpent, energySpent = Spring.GetUnitCosts(mexUnitID)
		local health = Spring.GetUnitHealth(mexUnitID)
		local extractMetal = Spring.GetUnitMetalExtraction(mexUnitID)
		Spring.DestroyUnit(mexUnitID, false, true, nil, true)
		local metalReclaim
		if swapData.oldUnitID then
			_, metalReclaim = Spring.GetUnitCosts(swapData.oldUnitID)
			Spring.DestroyUnit(swapData.oldUnitID, false, true, nil, true)
		end
		local newMexID = Spring.CreateUnit(mexDefIDs[swapData.unitDefID].mexDefID, mx, my, mz, facing, newUnitTeam)
		local newConID = Spring.CreateUnit(mexDefIDs[swapData.unitDefID].conDefID, mx, my, mz, facing, newUnitTeam)
		if newMexID and newConID then
			Spring.AddTeamResource(swapData.builderTeam, "metal", metalReclaim or 0)
			Spring.SetUnitBlocking(newMexID, true, true, false)
			Spring.SetUnitNoSelect(newMexID, true)
			Spring.SetUnitHealth(newMexID, health)
			Spring.SetUnitResourcing(newMexID, "umm", -extractMetal)
			Spring.SetUnitResourcing(newConID, "umm", extractMetal)
			Spring.UnitAttach(newMexID, newConID, 6)
			return
		elseif newMexID or newConID then
			Spring.DestroyUnit(newMexID or newConID, false, true, nil, true)
		end
		if swapData.oldUnitDefID then
			Spring.CreateUnit(swapData.oldUnitDefID, mx, my, mz, facing, newUnitTeam)
		end
		Spring.AddTeamResource(swapData.builderTeam, "metal", metalSpent)
		Spring.AddTeamResource(swapData.builderTeam, "energy", energySpent)
	end

	function gadget:GameFrame(frame)
		for unitID, swapData in pairs(mexSwapID) do
			swapMexAndAttachCon(unitID, swapData)
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if conDefIDs[unitDefID] then
		Spring.TransferUnit(Spring.GetUnitTransporter(unitID), newTeam)
	end
end

do
	local spGetUnitHealth = Spring.GetUnitHealth
	local function attachedUnitPreDamaged(unitID, unitDefID, unitTeam, damage)
		local health, maxHealth = spGetUnitHealth(unitID)
		if health - damage <= 0 then
			local xx, yy, zz = Spring.GetUnitPosition(unitID)
			local facing = Spring.GetUnitBuildFacing(unitID)
			local name = UnitDefs[unitDefID].name
			if damage < maxHealth * 0.25 then
				local featureID = Spring.CreateFeature(name .. "_dead", xx, yy, zz, facing, unitTeam)
				Spring.SetFeatureResurrect(featureID, name, facing, 0)
			elseif damage < maxHealth * 0.5 then
				Spring.CreateFeature(name .. "_heap", xx, yy, zz, facing, unitTeam)
			end
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID,
		                           attackerID, attackerDefID, attackerTeam)
		if not paralyzer and conDefIDs[unitDefID] then
			attachedUnitPreDamaged(unitID, unitDefID, unitTeam, damage)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if conDefIDs[unitDefID] then
		if Spring.GetUnitTransporter(unitID) then
			Spring.DestroyUnit(Spring.GetUnitTransporter(unitID), false, true)
		end
		for maybeDeadID, swapData in pairs(mexSwapID) do
			if unitID == maybeDeadID then
				mexSwapID[maybeDeadID] = nil
				if swapData.oldUnitID then
					local _, metalReclaim = Spring.GetUnitCosts(swapData.oldUnitID)
					Spring.AddTeamResource(swapData.unitTeamID, "metal", metalReclaim)
					break
				end
			end
		end
	end
end
