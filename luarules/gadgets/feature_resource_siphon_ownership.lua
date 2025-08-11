local gadget = gadget ---@type Gadget

-- Part of a collection of changes to prevent resource sharing:
local enabled = Spring.GetModOptions().resource_siphons == "ownership"

-- The "ownership" method sends reclaim back to the original unit's owner.
-- It does not, as of yet, reestablish as a new owner a player who refills
-- the metal missing from a wreckage; so at present it is a very efficient
-- means of sending metal directly to another player via their unit wreck.

function gadget:GetInfo()
	return {
		name    = "Anti-Siphoning: Ownership",
		desc    = "Reclaim returns to the previous owner of a unit wreck",
		author  = "efrec",
		version = "0.1",
		date    = "2025-08-10",
		license = "GNU GPL, v2 or later",
		layer   = 100, -- After all other reclaim build steps.
		enabled = enabled,
	}
end

if not enabled or not gadgetHandler:IsSyncedCode() then
	return
end

-- Global values

local math_max = math.max
local spGetFeatureResources = Spring.GetFeatureResources
local spGetTeamList = Spring.GetTeamList
local spAreTeamsAllied = Spring.AreTeamsAllied

-- Initialize

local ownedDefs = {}
local shareTaxRate = Spring.GetModOptions().tax_resource_sharing_amount or 0

local function addOwnedDef(metalCost, featureDef)
	if metalCost > 0 and featureDef and featureDef.metal / metalCost > 1 - shareTaxRate then
		ownedDefs[featureDef.id] = true
		return true
	end
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	local metalCost = unitDef.metalCost
	if addOwnedDef(metalCost, FeatureDefNames[unitDef.corpse or unitDef.name .. "_dead"]) then
		addOwnedDef(metalCost, FeatureDefNames[unitDef.name .. "_heap"])
	end
end

local featureTracking = {}

-- Local functions

local function sendToAlliedOwner(builderTeam, feature, metal, energy)
	if feature.team ~= builderTeam and spAreTeamsAllied(feature.team, builderTeam) then
		local metalDiff = feature.metal - metal
		local energyDiff = feature.energy - energy

		if metalDiff > 0 then
			Spring.UseTeamResource(builderTeam, "metal", metalDiff)
			Spring.UseTeamResource(feature.team, "metal", -metalDiff)
		end

		if energyDiff > 0 then
			Spring.UseTeamResource(builderTeam, "energy", energyDiff)
			Spring.UseTeamResource(feature.team, "energy", -energyDiff)
		end
	end

	feature.metal = metal
	feature.energy = energy
end

local function getPower(metal, energy)
	return metal + energy / 60 -- In effect, power == metal.
end

---Filling a wreck with metal gradually increases ownership of the wreck.
---Reclaiming from the same wreck is, eventually, not considered sharing.
---Players who own a wreckage are given higher priority toward ownership.
local function updateOwnership(builderTeam, feature, metal, energy, featureID)
	local metalDiff  = feature.metal - metal
	local energyDiff = feature.energy - energy
	local progress   = getPower(metalDiff, energyDiff) / feature.power

	if feature.team == builderTeam then
		for _, team in ipairs(spGetTeamList()) do
			if team ~= builderTeam and feature[team] then
				-- Ownership perk: Your progress resets other teams'.
				feature[team] = math_max(0, feature[team] - progress)
			end
		end
	else
		local ownership = (feature[builderTeam] or 0) + progress

		if ownership < 1 then
			feature[builderTeam] = ownership
		else
			feature.team = builderTeam
			Spring.TransferFeature(featureID, builderTeam)
			progress = ownership - 1

			for _, team in ipairs(spGetTeamList()) do
				if feature[team] then
					feature[team] = math_max(0, feature[team] - progress)
				end
			end
		end
	end
end

-- Engine callins

function gadget:FeatureCreated(featureID, featureAllyTeam)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if featureDefID and ownedDefs[featureDefID] then
		local featureTeam = Spring.GetFeatureTeam(featureID)
		if featureTeam and featureTeam >= 0 then
			local metal, _, energy = spGetFeatureResources(featureID)
			featureTracking[featureID] = {
				metal  = metal,
				energy = energy,
				power  = getPower(metal, energy),
				team   = featureTeam,
			}
		end
	end
end

function gadget:FeatureDestroyed(featureID, featureAllyTeam)
	featureTracking[featureID] = nil
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if featureTracking[featureID] then
		local feature = featureTracking[featureID]
		local metal, _, energy = spGetFeatureResources(featureID)

		if part < 0 then
			sendToAlliedOwner(builderTeam, feature, metal, energy)
		elseif part > 0 then
			updateOwnership(builderTeam, feature, metal, energy, featureID)
		end
	end
	return true
end
