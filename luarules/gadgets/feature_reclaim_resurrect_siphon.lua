local gadget = gadget ---@type Gadget

local enabled = Spring.GetModOptions().resource_siphons

function gadget:GetInfo()
	return {
		name    = 'Reclaim Degrades Features',
		desc    = 'Reclaim harms wrecks. Resurrect heals them. Only full-health wrecks regain resources. Only full-health, full-resource wrecks gain resurrect progress.',
		author  = 'efrec',
		version = '0.0',
		date    = '2025-08-05',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = enabled,
	}
end

if not enabled or not gadgetHandler:IsSyncedCode() then
	return
end

-- Configuration

-- Destroy features with at least this much max hp when their health remaining is fractional.
local HEALTH_FRACTION_LIMIT = 10

-- Global values

local spGetFeatureHealth = Spring.GetFeatureHealth
local spGetFeatureResources = Spring.GetFeatureResources

local spSetFeatureHealth = Spring.SetFeatureHealth
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed

local spDestroyFeature = Spring.DestroyFeature

-- Initialize

local buildSpeeds = {}
local unitBuildSpeeds = {}
local inReplenishTask = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.canResurrect then
		buildSpeeds[unitDefID] = { unitDef.buildSpeed, unitDef.resurrectSpeed }
	end
end

-- Local functions

local function missingReclaim(featureID)
	local metal, metalMax = spGetFeatureResources(featureID)
	return metal < metalMax
end

local function setBuildSpeedReplenish(unitID)
	local build = unitBuildSpeeds[unitID][1]
	spSetUnitBuildSpeed(unitID, build, nil, nil, build)
end

local function resetBuildSpeed(unitID)
	local speeds = unitBuildSpeeds[unitID]
	spSetUnitBuildSpeed(unitID, speeds[1], nil, nil, speeds[2])
end

-- Engine callins

function gadget:Initialize()
	if not next(buildSpeeds) then
		gadgetHandler:RemoveGadget()
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if buildSpeeds[unitDefID] then
		unitBuildSpeeds[unitID] = buildSpeeds[unitDefID]
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	unitBuildSpeeds[unitID] = nil
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID)
	if cmdID == CMD.RECLAIM and inReplenishTask[unitID] then
		resetBuildSpeed(unitID)
		inReplenishTask[unitID] = nil
	end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	local health, healthMax = spGetFeatureHealth(featureID)
	local healthAfter = health / healthMax + part

	if healthAfter > 0 then
		if healthMax * healthAfter >= 1 or healthMax < HEALTH_FRACTION_LIMIT then
			if healthAfter > 1 then
				healthAfter = 1
			end
			spSetFeatureHealth(featureID, healthMax * healthAfter)
		end
	else
		spDestroyFeature(featureID)
	end

	if part <= 0 then
		return true
	end

	-- Otherwise, we are resurrecting a unit from a feature.

	if health >= healthMax then
		local isInReplenishTask = inReplenishTask[builderID]
		local hasMissingReclaim = missingReclaim(featureID)

		if not isInReplenishTask then
			if hasMissingReclaim then
				setBuildSpeedReplenish(builderID) -- Trade down to slower build speed.
				inReplenishTask[builderID] = true
			end
		else
			if not hasMissingReclaim then
				resetBuildSpeed(builderID) -- Restore both build and ressurect speeds.
				inReplenishTask[builderID] = nil
			end
		end

		return true
	else
		return false
	end
end
