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
local spGetUnitCommands = Spring.GetUnitCommands
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

local function updateTurretHeading(unitID, dx, dz)
	local heading1 = spGetHeadingFromVector(dx, dz)
	local heading2 = spGetUnitHeading(unitID)
	spCallCOBScript(unitID, "UpdateHeading", 0, heading1 - heading2 + 32768)
end

local function updateTurretCommands()
	for turretID, unitID in pairs(attachedUnits) do
		local ux, _, uz = spGetUnitPosition(turretID)
		local radius = attachedUnitBuildRadius[turretID]
		do
			local commands = spGetUnitCommands(unitID, 1)
			local command = commands and commands[1]
			if command and (command.id < 0 or (
					(command.id == CMD_REPAIR or command.id == CMD_RECLAIM) and
					#command.params ~= 4
				))
			then
				spGiveOrderToUnit(turretID, command.id, command.params, EMPTY)
			else
				commands = spGetUnitCommands(turretID, 1)
				command = commands and commands[1]
			end
			local distance
			if command then
				if command.id < 0 and command.id ~= turretID then
					local tx, tz = command.params[1], command.params[3]
					if tx then
						local objectRadius = spGetUnitRadius(-command.id)
						distance = math.sqrt((ux - tx) ^ 2 + (uz - tz) ^ 2) - objectRadius
					end
				elseif command.id == CMD_REPAIR or command.id == CMD_RECLAIM then
					if command.params[1] < FEATURE_BASE_INDEX then
						distance = Spring.GetUnitSeparation(turretID, command.params[1], true, true)
					else
						distance = Spring.GetUnitFeatureSeparation(turretID, command.params[1] - FEATURE_BASE_INDEX, true, true)
					end
				end
			end
			if distance and distance <= radius then
				updateTurretHeading(turretID, ux - tx, uz - tz)
				return
			end
		end

		-- Attached unit has no valid, explicit command. Search for automatic/smart behaviors in priority order:
		-- (1) repair ally (2) reclaim enemy (3) reclaim non-ressurectable feature (4) build existing nanoframe.

		local nearUnits = spGetUnitsInCylinder(ux, uz, radius + unitDefRadiusMax)
		local teamID = Spring.GetUnitTeam(unitID)
		local testUnitBuildAssist = {}

		for i = #nearUnits, 1, -1 do
			local nearID = nearUnits[i]
			if
				nearID ~= unitID and nearID ~= turretID and
				radius > spGetUnitSeparation(nearID, turretID, true) - spGetUnitRadius(nearID)
			then
				if Spring.AreTeamsAllied(teamID, Spring.GetUnitTeam(nearID)) then
					if UnitDefs[spGetUnitDefID(nearID)].repairable then
						local health, maxHealth, _, _, buildProgress = spGetUnitHealth(nearID)
						if buildProgress == 1 and health < maxHealth then
							spGiveOrderToUnit(turretID, CMD_REPAIR, { nearID }, EMPTY)
							local tx, _, tz = spGetUnitPosition(nearID)
							updateTurretHeading(turretID, ux - tx, uz - tz)
							return
						end
					end
					testUnitBuildAssist[#testUnitBuildAssist+1] = nearID
					nearUnits[i] = nil
				end
			else
				nearUnits[i] = nil
			end
		end

		for _, nearID in pairs(nearUnits) do
			if UnitDefs[spGetUnitDefID(nearID)].reclaimable then
				spGiveOrderToUnit(turretID, CMD_RECLAIM, { nearID }, EMPTY)
				local tx, _, tz = spGetUnitPosition(nearID)
				updateTurretHeading(turretID, ux - tx, uz - tz)
				return
			end
		end

		local nearFeatures = spGetFeaturesInCylinder(ux, uz, radius + unitDefRadiusMax)
		for _, nearID in ipairs(nearFeatures) do
			local nearDefID = spGetFeatureDefID(nearID)
			if
				FeatureDefs[nearDefID].reclaimable and spGetFeatureResurrect(nearID) == FEATURE_NO_UNITDEF and
				radius > spGetUnitFeatureSeparation(turretID, nearID, true, true)
			then
				spGiveOrderToUnit(turretID, CMD_RECLAIM, { nearID + FEATURE_BASE_INDEX }, EMPTY)
				local tx, _, tz = spGetFeaturePosition(nearID)
				updateTurretHeading(turretID, ux - tx, uz - tz)
				return
			end
		end

		for _, nearID in ipairs(testUnitBuildAssist) do
			if spGetUnitIsBeingBuilt(nearID) and not unitCannotBeAssisted[spGetUnitDefID(nearID)] then
				spGiveOrderToUnit(turretID, CMD_REPAIR, { nearID }, EMPTY)
				local tx, _, tz = spGetUnitPosition(nearID)
				updateTurretHeading(turretID, ux - tx, uz - tz)
				return
			end
		end

		-- Exhaust attempt and issue stop order.
		spGiveOrderToUnit(turretID, CMD.STOP, EMPTY, EMPTY)
	end
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
		Spring.AddTeamResource(unitTeam, "metal", metalRefund)
		Spring.AddTeamResource(unitTeam, "energy", energyRefund)
	end
end

function gadget:GameFrame(gameFrame)
	if gameFrame % 15 == 0 then
		retryUnitAttachments()
		updateTurretCommands()
	end
end
