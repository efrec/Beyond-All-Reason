local gadget = gadget ---@type Gadget

-- Part of a collection of changes to prevent resource sharing:
local enabled = Spring.GetModOptions().resource_siphons == "slowmoded"

function gadget:GetInfo()
	return {
		name    = "Anti-Siphoning: Slow Mode",
		desc    = 'Rez replaces reclaimed metal at a constant rate per con',
		author  = 'Kyle Anthony Shepherd (Itanthias)',
		version = '0.1',
		date    = '2025-08-04',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = enabled,
	}
end

if not enabled or not gadgetHandler:IsSyncedCode() then
	return
end

local gameSpeed = Game.gameSpeed

local spGetFeatureResources = Spring.GetFeatureResources
local spSetFeatureResources = Spring.SetFeatureResources
local spUseUnitResource = Spring.UseUnitResource

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	local remainingMetal, maxMetal, remainingEnergy, maxEnergy, reclaimLeft, reclaimTime = spGetFeatureResources(featureID)
	if (remainingMetal < maxMetal) and (part > 0) then
		remainingMetal = math.min(maxMetal, remainingMetal + 2/gameSpeed)
		spUseUnitResource(builderID, "m", 2/gameSpeed)
		spSetFeatureResources(featureID, remainingMetal, remainingEnergy, reclaimTime, remainingMetal/maxMetal)
		return false
	else
		return true
	end
end
