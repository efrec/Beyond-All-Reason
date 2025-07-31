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

local CMD_GUARD = CMD.GUARD
local CMD_RECLAIM = CMD.RECLAIM
local CMD_REMOVE = CMD.REMOVE
local CMD_REPAIR = CMD.REPAIR
local CMD_STOP = CMD.STOP
local OPT_ALT = CMD.OPT_ALT
local OPT_INTERNAL = CMD.OPT_INTERNAL
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
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGiveOrderToUnit = Spring.GiveOrderToUnit

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

-- FIXME: Added in next commit:
local tryOrderDirection
local applyTurretOrder
local tryExecuteFight

---Synchronize the turret unit to the base unit's current activity,
---then attempt to continue an ongoing command already in progress,
---then attempt to find an action to perform independently,
---then forward any command to the base, if it is not busy.
---@param baseID integer
---@param turretID integer
local function updateTurretOrders(baseID, turretID)
	local abilities = turretAbilities[turretID]
	local buildRadius = turretBuildRadius[turretID]

	local command, params, paramsType, options = getCommandInfo(baseID)
	if paramsType == PRM_WAIT then
		return
	elseif command ~= nil then
		if command ~= CMD_GUARD and
			math.bit_and(options, OPT_INTERNAL) == OPT_INTERNAL and
			spGetUnitCurrentCommand(baseID, 2) == CMD_GUARD
		then
			return
		elseif paramsType ~= nil and paramsType[#params] ~= nil then
			spGiveOrderToUnit(turretID, command, params)
		end
	end

	command, params, paramsType, options = getCommandInfo(turretID)
	local dx, dz
	if paramsType == PRM_WAIT then
		return
	elseif command ~= nil then
		dx, dz = tryOrderDirection(paramsType, params, turretID, buildRadius)
		if dx ~= nil then
			applyTurretOrder(turretID, dx, dz)
			return
		end
	end
	local turretCommand = command

	dx, dz, command, params = tryExecuteFight(baseID, turretID, abilities, buildRadius)
	if dx ~= nil then
		applyTurretOrder(turretID, dx, dz, baseID)
	elseif turretCommand ~= nil then
		spGiveOrderToUnit(turretID, CMD_REMOVE, turretCommand, OPT_ALT)
	end
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
