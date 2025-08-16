local gadget = gadget ---@type Gadget

-- Part of a collection of changes to prevent resource sharing:
local enabled = Spring.GetModOptions().resource_siphons == "hurtyrecl"

-- "reclaim-is-hurty" makes reclaiming mass from an object deal continuous damage
-- so that wrecks cannot be used to transfer resources back and forth infinitely.

function gadget:GetInfo()
	return {
		name    = "Anti-Siphoning: Damaging Reclaim",
		desc    = "Reclaim damages wrecks and resurrect heals them, in a more minimal implementation.",
		author  = "efrec",
		version = "0.1",
		date    = "2025-06-17",
		license = "GNU GPL, v2 or later",
		layer   = -1, -- before reclaim_fix can adjust anything
		enabled = enabled,
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