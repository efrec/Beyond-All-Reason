local gadget = gadget ---@type Gadget

-- Part of a collection of changes to prevent resource sharing:
local enabled = Spring.GetModOptions().resource_siphons == "taxshared"
local shareTaxRate = Spring.GetModOptions().tax_resource_sharing_amount or 0

if shareTaxRate <= 0 then
	enabled = false
end

-- The "taxshared" method sends reclaim back to the original unit's owner.
-- The amount sent is taxed, resembling transaction overhead/inefficiency.

function gadget:GetInfo()
	return {
		name    = "Anti-Siphoning: Tax Shared",
		desc    = "Reclaim returns to the previous owner of a unit wreck, and is taxed",
		author  = "efrec",
		version = "0.1",
		date    = "2025-08-16",
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

local transferRate = 1 - shareTaxRate
local ownedDefs = {}

local function addOwnedDef(metalCost, featureDef)
	if metalCost > 0 and featureDef and featureDef.metal / metalCost > transferRate then
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
	if builderTeam ~= feature.team and spAreTeamsAllied(builderTeam, feature.team) then
		local metalDiff = feature.metal - metal
		local energyDiff = feature.energy - energy

		if metalDiff > 0 then
			Spring.UseTeamResource(builderTeam, "metal", -metalDiff)
			Spring.UseTeamResource(feature.team, "metal", metalDiff * transferRate)
		end

		if energyDiff > 0 then
			Spring.UseTeamResource(builderTeam, "energy", -energyDiff)
			Spring.UseTeamResource(feature.team, "energy", energyDiff * transferRate)
		end
	end
end

local function getPower(metal, energy)
	return metal + energy / 60 -- In effect, power == metal.
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
		end

		feature.metal = metal
		feature.energy = energy
	end
	return true
end
