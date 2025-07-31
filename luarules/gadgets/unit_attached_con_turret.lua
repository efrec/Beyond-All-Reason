local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Attached Construction Turret',
        desc      = 'Attaches a builder to another mobile unit, so builder can repair while moving',
        author    = 'Itanthias',
        version   = 'v1.1',
        date      = 'July 2023',
        license   = 'GNU GPL, v2 or later',
        layer     = 12,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local updateInterval = 0.33 -- in seconds

--------------------------------------------------------------------------------
-- Command introspection -------------------------------------------------------

local PRM_NUL = {} ---@type CommandParamsType Null params set

---Parameter counts => allowed
---@type table<string, CommandParamsType>
local countAllowed = {
	changeState = { [0] = true, [1] = true }, -- [0] option [1] mode
	buildOrder  = { [3] = true, [4] = true }, -- [3] xyz [4] xyz, facing
	buildTarget = { [1] = true, [5] = true }, -- [1] object [4] xyz, area radius [5] object, xyz, leash radius
	mapPosition = { [3] = true, [4] = true }, -- [3] xyz [4] xyz, area radius
	waitCommand = { [0] = true, [1] = true, [2] = true, [6] = true }, -- see WaitCommandsAI.cpp
}

-- Speedups and reverse lookups:

local PRM_BUILD = countAllowed.buildOrder
local PRM_WAIT = countAllowed.waitCommand
local PRMTYPE_COORDS = { [countAllowed.buildOrder] = true, [countAllowed.mapPosition] = true, }
local PRMTYPE_OBJECT = { [countAllowed.buildTarget] = true, }

---The attached turret has the statistics of its base unit
-- but can process only a subset of the base unit's orders:
---@type table<CMD, table<CommandParamsCount, true>>
local commandParamForward = setmetatable({
	-- Engine commands:
	[CMD.WAIT]         = countAllowed.waitCommand,
	[CMD.DEATHWAIT]    = countAllowed.waitCommand,
	[CMD.GATHERWAIT]   = countAllowed.waitCommand,
	[CMD.TIMEWAIT]     = countAllowed.waitCommand,

	[CMD.CAPTURE]      = countAllowed.buildTarget,
	[CMD.RECLAIM]      = countAllowed.buildTarget,
	[CMD.REPAIR]       = countAllowed.buildTarget,
	[CMD.RESURRECT]    = countAllowed.buildTarget,

	[CMD.RESTORE]      = countAllowed.mapPosition,

	-- Game commands:
	[GameCMD.PRIORITY] = countAllowed.noneOrMode,
}, {
	__index = function(self, key)
		return key < 0 and PRM_BUILD or PRM_NUL
	end
})

--------------------------------------------------------------------------------
-- Global values ---------------------------------------------------------------

local CMD_REPAIR = CMD.REPAIR
local CMD_RECLAIM = CMD.RECLAIM
local CMD_STOP = CMD.STOP
local SpGetUnitCommands = Spring.GetUnitCommands
local SpGiveOrderToUnit = Spring.GiveOrderToUnit
local SpGetUnitPosition = Spring.GetUnitPosition
local SpGetFeaturePosition = Spring.GetFeaturePosition
local SpGetUnitDefID = Spring.GetUnitDefID
local SpGetUnitsInCylinder = Spring.GetUnitsInCylinder
local SpGetUnitAllyTeam = Spring.GetUnitAllyTeam
local SpGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local SpGetFeatureDefID = Spring.GetFeatureDefID
local SpGetFeatureResurrect = Spring.GetFeatureResurrect
local SpGetUnitHealth = Spring.GetUnitHealth
local SpGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local SpGetUnitDefDimensions = Spring.GetUnitDefDimensions
local SpGetFeatureRadius = Spring.GetFeatureRadius
local spGetUnitPosition = Spring.GetUnitPosition
local SpGetUnitRadius = Spring.GetUnitRadius
local SpGetUnitFeatureSeparation = Spring.GetUnitFeatureSeparation
local SpGetUnitSeparation = Spring.GetUnitSeparation
local SpGetUnitTransporter = Spring.GetUnitTransporter

local SpGetHeadingFromVector = Spring.GetHeadingFromVector
local SpGetUnitHeading = Spring.GetUnitHeading
local SpCallCOBScript = Spring.CallCOBScript

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

updateInterval = math.floor(updateInterval * Game.gameSpeed + 0.5)
updateInterval = math.clamp(updateInterval, 1, Game.gameSpeed)
local updateOffset = math.round(updateInterval * 0.5)

local baseToTurretDefID = {}
local baseDefAttachIndex = {}
local turretDefAbilities = {}
local repairableDefID = {}
local reclaimableDefID = {}
local capturableDefID = {}
local unitDefRadiusMax = 0

local combatReclaimDefID = {}
local resurrectableDefID = {}

local baseToTurretID = {}
local turretAbilities = {}
local turretBuildRadius = {}

local function parseBaseUnitDef(unitDef)
	local turretDef = UnitDefNames[unitDef.customParams.attached_con_turret]
	local abilities
	local pieceIndex = tonumber(unitDef.customParams.attached_piece_index)
	local success = true

	if turretDef then
		abilities = {
			[CMD.CAPTURE]   = turretDef.canCapture and turretDef.captureSpeed > 0 or nil,
			[CMD.RECLAIM]   = turretDef.canReclaim and turretDef.reclaimSpeed > 0 or nil,
			[CMD.REPAIR]    = turretDef.canRepair and turretDef.repairSpeed > 0 or nil,
			[CMD.RESTORE]   = turretDef.canRestore and turretDef.terraformSpeed > 0 or nil,
			[CMD.RESURRECT] = turretDef.canResurrect and turretDef.resurrectSpeed > 0 or nil,
			-- We have two other types that complicate the issue.
			-- These depend on move state (assist) and build option (build).
			assist          = turretDef.canAssist and turretDef.buildSpeed > 0 or nil,
			build           = turretDef.buildOptions and next(turretDef.buildOptions) and true or nil,
		}

		if next(abilities) == nil then
			local message = "Con turret def has no builder abilities: "
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
			success = false
		end
	else
		local message = "Incorrect or missing attached con def: "
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
		success = false
	end

	if not pieceIndex then
		local message = "Incorrect or missing attach piece index: "
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
		success = false
	end

	if success then
		return turretDef.id, abilities, pieceIndex
	end
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams.attached_con_turret and not (unitDef.extractsMetal > 0) then
		local turretDefID, abilities, pieceNumber = parseBaseUnitDef(unitDef)
		if turretDefID then
			baseToTurretDefID[unitDefID] = turretDefID
			turretDefAbilities[turretDefID] = abilities
			baseDefAttachIndex[unitDefID] = pieceNumber
			GG.addPairedUnitDef(unitDefID, turretDefID)
		end
	end
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitDefRadiusMax = math.max(unitDef.radius, unitDefRadiusMax)
	if unitDef.capturable then
		capturableDefID[unitDefID] = true
	end
	if unitDef.reclaimable then
		reclaimableDefID[unitDefID] = true
	end
	if unitDef.repairable then
		repairableDefID[unitDefID] = true
	end
end

for featureDefID, featureDef in ipairs(FeatureDefs) do
	if featureDef.reclaimable and (featureDef.resurrectable == 0 or not featureDef.customParams.fromunit) then
		combatReclaimDefID[featureDefID] = true
	end
	if featureDef.resurrectable and (featureDef.resurrectable ~= 0 and not featureDef.customParams.fromunit) then
		resurrectableDefID[featureDefID] = true
	end
end

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function attachToUnit(baseID, baseDefID, baseTeam)
	local turretDefID = baseToTurretDefID[baseDefID]
	local ux, uy, uz = spGetUnitPosition(baseID)
	local facing = Spring.GetUnitBuildFacing(baseID)
	local turretID = Spring.CreateUnit(turretDefID, ux, uy, uz, facing, baseTeam)
	if turretID and GG.addPairedUnit(baseID, turretID, baseDefAttachIndex[baseDefID]) then
		baseToTurretID[baseID] = turretID
		turretBuildRadius[turretID] = UnitDefs[turretDefID].buildDistance
		turretAbilities[turretID] = turretDefAbilities[turretDefID]
		return true
	else
		Spring.DestroyUnit(baseID)
	end
end

-- Command helpers -------------------------------------------------------------

local commandParams = table.new(6, 0) -- helper table

---@param unitID integer
---@param index integer?
---@return CMD? command
---@return number[] params
---@return table<CommandParamsCount, true> PRMTYPE
---@return CommandOptionBit? options
local function getCommandInfo(unitID, index)
	local command, options, _, p1, p2, p3, p4, p5, p6 = spGetUnitCurrentCommand(unitID, index)
	local paramsType = command ~= nil and commandParamForward[command] or PRM_NUL
	local p = commandParams
	p[1], p[2], p[3], p[4], p[5], p[6] = p1, p2, p3, p4, p5, p6
	return command, p, paramsType, options
end

local getReadHandle
do
	local callAsTeamOptions = { read = 0 }
	---@param teamID number|integer
	---@return CallAsTeamOptions
	getReadHandle = function(teamID)
		callAsTeamOptions.read = teamID
		return callAsTeamOptions
	end
end

local function isUnitInBuildRadius(turretID, unitID)
	local separation = spGetUnitSeparation(turretID, unitID, true, true)
	if separation ~= nil then
		local radius = spGetUnitEffectiveBuildRange(turretID, spGetUnitDefID(unitID))
		return radius >= separation
	else
		return false
	end
end

local function isFeatureInBuildRadius(turretID, featureID, radius)
	local separation = spGetUnitFeatureSeparation(turretID, featureID, true)
	if separation ~= nil then
		return radius >= separation - spGetFeatureRadius(featureID)
	else
		return false
	end
end

-- Process commands ------------------------------------------------------------

local function auto_repair_routine(baseUnitID, nanoID)
	local transporterID = SpGetUnitTransporter(baseUnitID)
	if transporterID then
		Spring.GiveOrderToUnit(nanoID, CMD_STOP, {}, 0)
	return
	end
	-- first, check command the body is performing
	local commandQueue = SpGetUnitCommands(baseToTurretID[nanoID], 1)
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] < 0) then
        -- build command
		-- The attached turret must have the same buildlist as the body for this to work correctly
		--for XX, YY, baseUnitID in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX, YY)
		--end
        SpGiveOrderToUnit(nanoID, commandQueue[1]["id"], commandQueue[1]["params"])
    end
    if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR) then
        -- repair command
		--for XX, YY, baseUnitID in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX, YY)
		--end
		if #commandQueue[1]["params"] ~= 4 then
			SpGiveOrderToUnit(nanoID, CMD_REPAIR, commandQueue[1]["params"])
		end
    end
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM) then
        -- reclaim command
		if #commandQueue[1]["params"] ~= 4 then
			SpGiveOrderToUnit(nanoID, CMD_RECLAIM, commandQueue[1]["params"])
		end
    end

	-- next, check to see if current command (including command from chassis) is in range
	commandQueue = SpGetUnitCommands(nanoID, 1)
	local ux, uy, uz = SpGetUnitPosition(nanoID)
	local tx, ty, tz
	local radius = turretBuildRadius[nanoID]
	local distance = radius^2 + 1
	local object_radius = 0
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] < 0) then
        -- out of range build command
		object_radius = SpGetUnitDefDimensions(-commandQueue[1]["id"]).radius
		distance = math.sqrt((ux-commandQueue[1]["params"][1])^2 + (uz-commandQueue[1]["params"][3])^2) - object_radius
    end
    if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR) then
        -- out of range repair command
		if (commandQueue[1]["params"][1] >= Game.maxUnits) then
			tx, ty, tz = SpGetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			object_radius = SpGetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx, ty, tz = SpGetUnitPosition(commandQueue[1]["params"][1])
			object_radius = SpGetUnitRadius(commandQueue[1]["params"][1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux-tx)^2 + (uz-tz)^2) - object_radius
		end
    end
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM) then
		-- out of range reclaim command
		if (commandQueue[1]["params"][1] >= Game.maxUnits) then
			tx, ty, tz = SpGetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			object_radius = SpGetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx, ty, tz = SpGetUnitPosition(commandQueue[1]["params"][1])
			object_radius = SpGetUnitRadius(commandQueue[1]["params"][1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux-tx)^2 + (uz-tz)^2) - object_radius
		end
    end
	if tx and distance <= radius then
		--let auto con turret continue its thing
		--update heading, by calling into unit script
		heading1 = SpGetHeadingFromVector(ux-tx, uz-tz)
		heading2 = SpGetUnitHeading(nanoID)
		SpCallCOBScript(nanoID, 'UpdateHeading', 0, heading1-heading2+32768)
		return
	end

	-- next, check to see if valid repair/reclaim targets in range
	local near_units = SpGetUnitsInCylinder(ux, uz, radius + unitDefRadiusMax, -3)

	for XX, near_unit in pairs(near_units) do
		-- check for free repairs
		local near_defid = SpGetUnitDefID(near_unit)
		if ( (SpGetUnitSeparation(near_unit, nanoID, true) - SpGetUnitRadius(near_unit)) < radius) then
			local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = SpGetUnitHealth(near_unit)
			if buildProgress == 1 and health < maxHealth and UnitDefs[near_defid].repairable and near_unit ~= baseToTurretID[nanoID] then
				SpGiveOrderToUnit(nanoID, CMD_REPAIR, {near_unit})
				return
			end
		end
	end

	local near_enemies = SpGetUnitsInCylinder(ux, uz, radius + unitDefRadiusMax, -4)

	for XX, near_unit in pairs(near_enemies) do
		-- check for enemy to reclaim
		local near_defid = SpGetUnitDefID(near_unit)
		if ( (SpGetUnitSeparation(near_unit, nanoID, true) - SpGetUnitRadius(near_unit)) < radius) then
			if UnitDefs[near_defid].reclaimable then
				SpGiveOrderToUnit(nanoID, CMD_RECLAIM, {near_unit})
				return
			end
		end
	end

	local near_features = SpGetFeaturesInCylinder(ux, uz, radius + unitDefRadiusMax)
	for XX, near_feature in pairs(near_features) do
		-- check for non resurrectable feature to reclaim
		local near_defid = SpGetFeatureDefID(near_feature)
		if ( (SpGetUnitFeatureSeparation(nanoID, near_feature, true) - SpGetFeatureRadius(near_feature)) < radius) then
			if FeatureDefs[near_defid].reclaimable and SpGetFeatureResurrect(near_feature) == "" then
				SpGiveOrderToUnit(nanoID, CMD_RECLAIM, {near_feature+Game.maxUnits})
				return
			end
		end
	end

	for XX, near_unit in pairs(near_units) do
		-- check for nanoframe to build
		if SpGetUnitAllyTeam(near_unit) == SpGetUnitAllyTeam(nanoID) then
			if ( (SpGetUnitSeparation(near_unit, nanoID, true) - SpGetUnitRadius(near_unit)) < radius) then
				if SpGetUnitIsBeingBuilt(near_unit) then
					SpGiveOrderToUnit(nanoID, CMD_REPAIR, {near_unit})
					return
				end
			end
		end
	end

	-- give stop command to attached con turret if nothing to do
	SpGiveOrderToUnit(nanoID, CMD.STOP)

end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:GameFrame(gameFrame)

	if gameFrame % updateInterval == updateOffset then
	    -- go on a slowupdate cycle
		for baseUnitID, nanoID in pairs(baseToTurretID) do	
			CallAsTeam(Spring.GetUnitTeam(baseUnitID), auto_repair_routine, baseUnitID, nanoID)
		end
	end

end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if baseToTurretDefID[unitDefID] then
		attachToUnit(unitID, unitDefID, unitTeam)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	baseToTurretID[unitID] = nil
	turretAbilities[unitID] = nil
	turretBuildRadius[unitID] = nil
end
