local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Attached Construction Turret',
		desc    = 'Attaches a builder to another mobile unit, so builder can repair while moving',
		author  = 'Itanthias',
		version = 'v1.1',
		date    = 'July 2023',
		license = 'GNU GPL, v2 or later',
		layer   = 12,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- Localize --------------------------------------------------------------------

local spCallCOBScript = Spring.CallCOBScript
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureRadius = Spring.GetFeatureRadius
local spGetFeatureResurrect = Spring.GetFeatureResurrect
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetHeadingFromVector = Spring.GetHeadingFromVector
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitFeatureSeparation = Spring.GetUnitFeatureSeparation
local spGetUnitHeading = Spring.GetUnitHeading
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitSeparation = Spring.GetUnitSeparation
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMD_REPAIR = CMD.REPAIR
local CMD_RECLAIM = CMD.RECLAIM
local EMPTY = {}
local FEATURE_BASE_INDEX = Game.maxUnits
local FEATURE_NO_UNITDEF = ""
local FILTER_ALLY_UNITS = -3
local FILTER_ENEMY_UNITS = -4

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local attachedBuilderDefID = {}
local unitCannotBeAssisted = {}
local unitDefRadiusMax = 0

local attachedUnits = {}
local attachedUnitBuildRadius = {}
local detachedUnits = {}

do
	local function checkSameBuildOptions(unitDef1, unitDef2)
		if #unitDef1.buildoptions == #unitDef2.buildoptions then
			for _, unitName in ipairs(unitDef1.buildoptions) do
				if not table.contains(unitDef2.buildoptions, unitName) then
					return false
				end
			end
			return true
		end
		return false
	end

	function gadget:Initialize()
		for unitDefID, unitDef in pairs(UnitDefs) do
			unitDefRadiusMax = math.max(unitDef.radius, unitDefRadiusMax)
			if unitDef.customParams.attached_con_turret and not unitDef.customParams.attached_mex_replace then
				local nanoDef = UnitDefNames[unitDef.customParams.attached_con_turret]
				if checkSameBuildOptions(unitDef, nanoDef) then
					attachedBuilderDefID[unitDefID] = nanoDef and nanoDef.id or nil
				else
					local message = "Unit and its attached con turret have different build lists: "
					Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
				end
			elseif unitDef.customParams.mine or unitDef.modCategories.object or unitDef.customParams.objectify then
				unitCannotBeAssisted[unitDefID] = true
			end
		end
		if table.count(attachedBuilderDefID) == 0 then
			gadgetHandler:RemoveGadget(self)
		end
		for _, unitID in Spring.GetAllUnits() do
			local unitDefID = Spring.GetUnitDefID(unitID)
			if attachedBuilderDefID[unitDefID] then
				local attachedIDs = Spring.GetUnitIsTransporting(unitID)
				local hasAttachedCon = false
				for _, attachedID in ipairs(attachedIDs) do
					local attachedDefID = Spring.GetUnitDefID(attachedID)
					if attachedDefID == attachedBuilderDefID[unitDefID] then
						attachedUnits[attachedID] = unitID
						attachedUnitBuildRadius[attachedID] = UnitDefs[attachedDefID].buildDistance
						hasAttachedCon = true
						break
					end
				end
				if not hasAttachedCon then
					detachedUnits[unitID] = {
						attempts  = 30, -- Some information loss; dunno age of unit.
						frame     = Spring.GetGameFrame(),
						unitDefID = unitDefID,
					}
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Process ---------------------------------------------------------------------

local function attachToUnit(unitID, unitDefID, unitTeam, attempts)
	if attempts > 0 then
		local attachedDefID = attachedBuilderDefID[unitDefID]
		local xx, yy, zz = spGetUnitPosition(unitID)
		local facing = math.random(0, 3)
		local attachedID = Spring.CreateUnit(attachedDefID, xx, yy, zz, facing, unitTeam)
		if attachedID then
			Spring.UnitAttach(unitID, attachedID, 3)
			Spring.SetUnitBlocking(attachedID, false, false, false)
			Spring.SetUnitNoSelect(attachedID, true)
			attachedUnits[attachedID] = unitID
			attachedUnitBuildRadius[attachedID] = UnitDefs[attachedDefID].buildDistance
			detachedUnits[unitID] = nil
		else
			local detachedUnitData = detachedUnits[unitID]
			if not detachedUnitData then
				detachedUnitData = { unitDefID = unitDefID }
				detachedUnits[unitID] = detachedUnitData
			end
			detachedUnitData.attempts = attempts - 1
			detachedUnitData.frame = Spring.GetGameFrame()
		end
	else
		Spring.DestroyUnit(unitID)
	end
end

local function retryUnitAttachments(gameFrame)
	for unitID, detachedUnitData in pairs(detachedUnits) do
		if detachedUnitData.frame + Game.gameSpeed <= gameFrame then
			attachToUnit(unitID, detachedUnitData.unitDefID, Spring.GetUnitTeam(unitID), detachedUnitData.attempts)
		end
	end
end

local function giveTurretSameCommand(turretID, unitID, unitX, unitZ, radius)
	local command, _, _, param1, param2, param3, param4 = spGetUnitCurrentCommand(unitID)
	if	not command or (command >= 0 and command ~= CMD_REPAIR and command ~= CMD_RECLAIM)
		or param4
		or not spGiveOrderToUnit(turretID, command, { param1, param2, param3, param4 }, EMPTY)
	then
		command, _, _, param1, param2, param3, param4 = spGetUnitCurrentCommand(turretID)
	end
	if command and not param4 then
		if command < 0 and -command ~= unitID and -command ~= turretID then
			if radius > math.sqrt((unitX - param1) ^ 2 + (unitZ - param3) ^ 2) - spGetUnitRadius(-command) then
				return unitX - param1, unitZ - param3
			end
		elseif command == CMD_REPAIR or command == CMD_RECLAIM then
			if param1 < FEATURE_BASE_INDEX then
				if radius > spGetUnitSeparation(turretID, param1, false, true) then
					local cx, cy, cz = spGetUnitPosition(param1)
					return unitX - cx, unitZ - cz
				end
			elseif radius > spGetUnitFeatureSeparation(turretID, param1 - FEATURE_BASE_INDEX, false, true) then
				local cx, cy, cz = spGetFeaturePosition(param1 - FEATURE_BASE_INDEX)
				return unitX - cx, unitZ - cz
			end
		end
	end
end

---This gadget has a polling rate, so should not issue orders that will be disallowed.
---See unit_prevent_cloaked_unit_reclaim for the order logic.
local function preventEnemyUnitReclaim(enemyID, teamID)
	local enemyUnitDef = UnitDefs[spGetUnitDefID(enemyID)]
	return	(not enemyUnitDef.reclaimable) or
			(enemyUnitDef.canCloak and Spring.GetUnitIsCloaked(enemyID) and not Spring.IsUnitInRadar(enemyID, Spring.GetTeamAllyTeamID(teamID)))
end

---Performs a search for the first executable automatic/smart behavior, in priority order:
---(1) repair ally (2) reclaim enemy (3) reclaim non-ressurectable feature (4) build-assist allied unit.
local function giveTurretAutoCommand(turretID, unitID, unitX, unitZ, radius)
	local unitTeamID = Spring.GetUnitTeam(unitID)
	local assistUnits = {}
	local alliedUnits = CallAsTeam(unitTeamID, spGetUnitsInCylinder, unitX, unitZ, radius + unitDefRadiusMax, FILTER_ALLY_UNITS)
	for _, allyID in ipairs(alliedUnits) do
		if allyID ~= unitID and allyID ~= turretID and radius > spGetUnitSeparation(allyID, unitID, false, true) then
			if UnitDefs[spGetUnitDefID(allyID)].repairable then
				local health, maxHealth, _, _, buildProgress = spGetUnitHealth(allyID)
				if buildProgress == 1 and health < maxHealth then
					spGiveOrderToUnit(turretID, CMD_REPAIR, { allyID }, EMPTY)
					local cx, _, cz = spGetUnitPosition(allyID)
					return unitX - cx, unitZ - cz
				end
			end
			assistUnits[#assistUnits+1] = allyID
		end
	end
	local enemyUnits = CallAsTeam(unitTeamID, spGetUnitsInCylinder, unitX, unitZ, radius + unitDefRadiusMax, FILTER_ENEMY_UNITS)
	for _, enemyID in ipairs(enemyUnits) do
		if radius > spGetUnitSeparation(enemyID, unitID, false, true) and not preventEnemyUnitReclaim(enemyID, unitTeamID) then
			spGiveOrderToUnit(turretID, CMD_RECLAIM, { enemyID }, EMPTY)
			local cx, _, cz = spGetUnitPosition(enemyID)
			return unitX - cx, unitZ - cz
		end
	end
	local features = spGetFeaturesInCylinder(unitX, unitZ, radius + unitDefRadiusMax)
	for _, featureID in ipairs(features) do
		if	FeatureDefs[spGetFeatureDefID(featureID)].reclaimable and
			spGetFeatureResurrect(featureID) == FEATURE_NO_UNITDEF and
			radius > spGetUnitFeatureSeparation(unitID, featureID, false, true)
		then
			spGiveOrderToUnit(turretID, CMD_RECLAIM, { featureID + FEATURE_BASE_INDEX }, EMPTY)
			local cx, _, cz = Spring.GetFeaturePosition(featureID)
			return unitX - cx, unitZ - cz
		end
	end
	for _, maybeBuildID in ipairs(assistUnits) do
		if spGetUnitIsBeingBuilt(maybeBuildID) and not unitCannotBeAssisted[spGetUnitDefID(maybeBuildID)] then
			spGiveOrderToUnit(turretID, CMD_REPAIR, { maybeBuildID }, EMPTY)
			local cx, _, cz = spGetUnitPosition(maybeBuildID)
			return unitX - cx, unitZ - cz
		end
	end
	spGiveOrderToUnit(turretID, CMD.STOP, EMPTY, EMPTY)
end

local function updateTurretCommand(turretID, unitID)
	local ux, uy, uz = spGetUnitPosition(turretID)
	local radius = attachedUnitBuildRadius[turretID]
	local dx, dz = giveTurretSameCommand(turretID, unitID, ux, uz, radius)
	if dx == nil then
		dx, dz = giveTurretAutoCommand(turretID, unitID, ux, uz, radius)
	end
	return dx, dz
end

local function updateTurretHeading(turretID, dx, dz)
	local headingCurrent = spGetUnitHeading(turretID)
	local headingNew = dx and spGetHeadingFromVector(dx, dz) - 32768 or spGetUnitHeading(attachedUnits[turretID])
	spCallCOBScript(turretID, "UpdateHeading", 0, headingNew - headingCurrent)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if attachedBuilderDefID[unitDefID] then
		attachToUnit(unitID, unitDefID, unitTeam, 30)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	attachedUnits[unitID] = nil
	attachedUnitBuildRadius[unitID] = nil
	if detachedUnits[unitID] then
		detachedUnits[unitID] = nil
		local _, metalRefund, energyRefund = Spring.GetUnitCosts(unitID)
		Spring.AddTeamResource(unitTeam,  "metal",  metalRefund)
		Spring.AddTeamResource(unitTeam, "energy", energyRefund)
	end
end

function gadget:GameFrame(gameFrame)
	if gameFrame % 11 == 0 then
		retryUnitAttachments()
		for turretID, unitID in pairs(attachedUnits) do
			local dx, dz = updateTurretCommand(turretID, unitID)
			updateTurretHeading(turretID, dx, dz)
		end
	end
end
