local gadget = gadget ---@type Gadget

-- Part of a collection of changes to prevent resource sharing:
local enabled = Spring.GetModOptions().resource_siphons == "ownership"

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

local spGetFeatureResources = Spring.GetFeatureResources
local spAreTeamsAllied = Spring.AreTeamsAllied

-- Initialize

local ownedDefs = {}
local taxRate = Spring.GetModOptions().whatever_tax_variable -- todo

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.corpse then
		local corpseDef = FeatureDefNames[unitDef.corpse]
		if corpseDef.metal and corpseDef.metal > 0 then
			ownedDefs[corpseDef.id] = true
		end
		-- todo: Also get debris and transfer it to the owner
		-- todo: Given that its %metal > 1 - %tax
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

-- Engine callins

function gadget:FeatureCreated(featureID, featureAllyTeam)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if featureDefID and ownedDefs[featureDefID] then
		local featureTeam = Spring.GetFeatureTeam(featureID)
		if featureTeam and featureTeam >= 0 then
			local metal, _, energy = spGetFeatureResources(featureID)
			featureTracking[featureID] = {
				team   = featureTeam,
				metal  = metal,
				energy = energy,
			}
		end
	end
end

function gadget:FeatureDestroyed(featureID, featureAllyTeam)
	featureTracking[featureID] = nil
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if part < 0 and featureTracking[featureID] then
		local feature = featureTracking[featureID]
		local metal, _, energy = spGetFeatureResources(featureID)
		sendToAlliedOwner(builderTeam, feature, metal, energy)
	end
	return true
end
