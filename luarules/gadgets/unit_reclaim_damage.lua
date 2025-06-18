local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Reclaim Degrades Features',
		desc    = 'Reclaim damages wrecks; resurrect heals them. Only full-health wrecks gain resurrect progress.',
		author  = 'efrec',
		version = '0.1',
		date    = '2025-06-17',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spDestroyFeature = Spring.DestroyFeature
local spGetFeatureHealth = Spring.GetFeatureHealth
local spSetFeatureHealth = Spring.SetFeatureHealth

-- NB: Features have very different health when compared to units.
-- They can have strange health:build costs or even fractional HP.
local healthMaxFractionalLimit = 10

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	local health, healthMax = spGetFeatureHealth(featureID)

	local healthAfter = health / healthMax + part

	if healthAfter > 0 and (healthMax < healthMaxFractionalLimit or healthMax * healthAfter >= 1) then
		if healthAfter > 1 then
			healthAfter = 1
		end
		spSetFeatureHealth(featureID, healthMax * healthAfter)
	else
		spDestroyFeature(featureID)
	end

	-- Reclaim is always allowed.
	-- Resurrect is allowed at full health.
	return part < 0 or health == healthMax
end
