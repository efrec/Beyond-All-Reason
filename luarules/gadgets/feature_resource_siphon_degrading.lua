local gadget = gadget ---@type Gadget

-- Part of a collection of changes to prevent resource sharing:
local enabled = Spring.GetModOptions().resource_siphons == "degrading"

function gadget:GetInfo()
	return {
		name    = 'Anti-Siphoning: Degrading',
		desc    = 'Reclaim harms wrecks. Resurrect heals them. Only full-health wrecks regain resources. Only full-health, full-resource wrecks gain resurrect progress.',
		author  = 'efrec',
		version = '0.1',
		date    = '2025-08-05',
		license = 'GNU GPL, v2 or later',
		layer   = -1, -- Should precede unit_reclaim_fix to prevent refilling metal early.
		enabled = enabled,
	}
end

if not enabled or not gadgetHandler:IsSyncedCode() then
	return
end

-- Global values

local spGetFeatureHealth = Spring.GetFeatureHealth
local spGetFeatureResources = Spring.GetFeatureResources
local spSetFeatureHealth = Spring.SetFeatureHealth
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed
local spDestroyFeature = Spring.DestroyFeature

local CMD_RECLAIM = CMD.RECLAIM

-- Initialize

local buildSpeeds = {}
local unitBuildSpeeds = {}
local inRepairingTask = {}
local inReplenishTask = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.canResurrect then
		buildSpeeds[unitDefID] = { unitDef.buildSpeed, unitDef.repairSpeed, unitDef.resurrectSpeed }
	end
end

-- Local functions

local function setBuildSpeedRepairing(unitID)
	local build = unitBuildSpeeds[unitID][1]
	local repair = unitBuildSpeeds[unitID][2]
	spSetUnitBuildSpeed(unitID, build, nil, nil, repair)
end

local function setBuildSpeedReplenish(unitID)
	local build = unitBuildSpeeds[unitID][1]
	spSetUnitBuildSpeed(unitID, build, nil, nil, build)
end

local function resetBuildSpeed(unitID)
	local build = unitBuildSpeeds[unitID][1]
	local resurrect = unitBuildSpeeds[unitID][3]
	spSetUnitBuildSpeed(unitID, build, nil, nil, resurrect)
end

local function missingReclaim(featureID)
	local metal, metalMax = spGetFeatureResources(featureID)
	return metal < metalMax
end

local function updateResurrect(unitID, featureID, healthRatio)
	if healthRatio == 1 then
		local isInReplenishTask = inReplenishTask[unitID]
		local hasMissingReclaim = missingReclaim(featureID)

		if not isInReplenishTask then
			if hasMissingReclaim then
				setBuildSpeedReplenish(unitID)
				inRepairingTask[unitID] = nil
				inReplenishTask[unitID] = true
			end
		else
			if not hasMissingReclaim then
				resetBuildSpeed(unitID)
				inRepairingTask[unitID] = nil
				inReplenishTask[unitID] = nil
			end
		end

		return true
	else
		if not inRepairingTask[unitID] then
			setBuildSpeedRepairing(unitID)
			inRepairingTask[unitID] = true
			inReplenishTask[unitID] = nil
		end

		return false
	end
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
	if cmdID == CMD_RECLAIM and (inRepairingTask[unitID] or inReplenishTask[unitID]) then
		resetBuildSpeed(unitID)
		inRepairingTask[unitID] = nil
		inReplenishTask[unitID] = nil
	end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	local health, healthMax = spGetFeatureHealth(featureID)
	local healthAfter = health / healthMax + part

	if healthAfter > 0 then
		if healthAfter > 1 then healthAfter = 1 end
		spSetFeatureHealth(featureID, healthMax * healthAfter)
	else
		spDestroyFeature(featureID) -- Is this really needed?
	end

	if part > 0 then
		return updateResurrect(builderID, featureID, healthAfter)
	else
		return true
	end
end
