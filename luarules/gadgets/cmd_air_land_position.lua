local gadget = gadget ---@type Gadget

local CMD_LAND_AT_POSITION = GameCMD.LAND_AT_POSITION

function gadget:GetInfo()
	return {
		name    = "Land At Position",
		desc    = "Give predictable landing orders and prevent bomber Stop command micro-tech",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = (CMD_LAND_AT_POSITION ~= nil),
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- todo: create a command for landing accurately near a location
-- todo: look at how the engine drops bombs, use it to determine the bombing path
-- todo: disarm/rearm bombers depending on their moveType data
-- todo: orchestrate a lot of moderate-complexity unit behaviors until they work

-- Configuration ---------------------------------------------------------------

---When to convert implicit land orders to explicit ones.
---@type table<CMD, true>
local landWhenInCommand = {
	[CMD.STOP] = true,
	[CMD.WAIT] = true,
	[CMD_LAND_AT_POSITION] = true,
}

---When to consider an enemy unit inside the path of a bombing run.
local BOMBING_ANGLE = math.rad(30) ---@type number in radians | declining from 90 degrees
local BOMBING_FRAMES = 0.7 * Game.gameSpeed ---@type number in frames | non-integer is OK

-- Globals ---------------------------------------------------------------------

local math_diag = math.diag

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder

local spIsPosInMap = Spring.IsPosInMap

local TARGET_UNIT = 1
local TARGET_GROUND = 2

local SQUARE_SIZE = Game.squareSize

local CMD_STOP = CMD.STOP
local CMD_IDLEMODE = CMD.IDLEMODE
local IDLEMODE_LAND = 0

-- Initialize ------------------------------------------------------------------

---@type CommandDescription
local cmdDescLandAtPosition = {
	name     = "Land at Position",
	id       = CMD_LAND_AT_POSITION,
	type     = CMDTYPE.ICON_MAP,
	action   = "landatposition",
	cursor   = "Move",
	tooltip  = "Order the unit to land close to this position.",
	hidden   = true, -- Maybe?
	queueing = true,
}

local gaiaTeamID = Spring.GetGaiaTeamID()

local strafeAirSpeed = {}
local isStrafeBomber = {}
local isStrafeAirUnit = {}

do
	local bombTypeSet = {
		AircraftBomb    = true,
		TorpedoLauncher = true,
	}

	for unitDefID, unitDef in pairs(UnitDefs) do
		if not unitDef.isStrafingAirUnit then
			strafeAirSpeed[unitDefID] = 0
		else
			strafeAirSpeed[unitDefID] = unitDef.speed

			local weapons = {}
			-- Including decoy and non-damaging weapons:
			for index, weapon in ipairs(unitDef.weapons) do
				if weapon.onlyTargets.surface or bombTypeSet[WeaponDefs[weapon.weaponDef].type] then
					weapons[#weapons + 1] = index
					isStrafeBomber[unitDefID] = weapons
				end
			end
		end
	end
end

-- Local functions -------------------------------------------------------------

local function shouldLandOnGround(unitID, unitDefID)
	local idleModeIndex = Spring.FindUnitCmdDesc(unitID, CMD_LAND_AT_POSITION) ---@diagnostic disable-line -- OK
	local idleModeDesc = Spring.GetUnitCmdDescs(unitID, idleModeIndex, idleModeIndex) ---@diagnostic disable-line -- OK

	if idleModeDesc ~= nil and idleModeDesc.params[1] == IDLEMODE_LAND then
		-- todo: What else to check? Current commands?
	end

	return false
end

local function checkStrafeLandingMoveGoals()
	for index, unitID in ipairs(isStrafeAirUnit) do
		if spGetUnitTeam(unitID) ~= gaiaTeamID then
			local inCommand = Spring.GetUnitCurrentCommand(unitID) or CMD_STOP
			if landWhenInCommand[inCommand] then
				-- todo
				local x, y, z = spGetUnitPosition(unitID)
				y = math.max(Spring.GetGroundHeight(x, z), Spring.GetWaterLevel(x, z))
				Spring.SetUnitMoveGoal(unitID, x, y, z, 2 * SQUARE_SIZE)
			end
		end
	end
end

local function isInsideMap(unitID)
	local x, _, z = spGetUnitPosition(unitID)
	return spIsPosInMap(x, z)
end

local function getTargetPosition(unitID, weaponNumber)
	local targetType, target = spGetUnitWeaponTarget(unitID, weaponNumber)
	if targetType == TARGET_UNIT then
		return spGetUnitPosition(target)
	elseif targetType == TARGET_GROUND then
		return target[1], target[2], target[3]
	end
end

local function inBombingRange(ux, uy, uz, tx, ty, tz, vx, vy, vz, speed)
	-- Added tolerance for weapons firing backwards:
	local dx = tx - (ux - vx * BOMBING_FRAMES * 0.3)
	local dy = ty - (uy - vy * BOMBING_FRAMES * 0.3)
	local dz = tz - (uz - vz * BOMBING_FRAMES * 0.3)

	local dotProduct = dx * vx + dy * vy + dz * vz

	return dotProduct > 0 -- for fast exit
		and BOMBING_FRAMES * speed >= math_diag(ux, uy, uz, tx, ty, tz)
		and BOMBING_ANGLE * math_diag(dx, dy, dz) * math_diag(vx, vy, vz) <= dotProduct
end

local function inBombingRun(unitID, unitDefID)
	local ux, uy, uz = spGetUnitPosition(unitID)
	local vx, vy, vz, speed = spGetUnitVelocity(unitID)

	if speed < 1 then
		-- Use a minimum speed to set tolerances.
		vx, vy, vz = Spring.GetUnitDirection(unitID)
		speed = 1
	end

	for _, weapon in ipairs(isStrafeBomber[unitDefID]) do
		local tx, ty, tz = getTargetPosition(unitID, weapon)
		if tx ~= nil and inBombingRange(ux, uy, uz, tx, ty, tz, vx, vy, vz, speed) then
			return true
		end
	end
	return false
end

local CallAsTeam = CallAsTeam
local readHandle = { read = 0 }

local function getTargets(teamID, x, z, radius)
	local rh = readHandle
	rh.read = teamID
	local FILTER_ENEMIES = -3
	return CallAsTeam(rh, spGetUnitsInCylinder, x, z, radius, FILTER_ENEMIES)
end

local function mayDropBombs(unitID)
	local ux, uy, uz = spGetUnitPosition(unitID)
	local vx, vy, vz, speed = spGetUnitVelocity(unitID)
	local unitTeam = spGetUnitTeam(unitID)

	local ox = ux + vx * BOMBING_FRAMES * 0.5
	local oz = uz + vz * BOMBING_FRAMES * 0.5
	local radius = BOMBING_FRAMES * speed * (1 + math.cos(BOMBING_ANGLE) * 0.5)

	local enemies = getTargets(unitTeam, ox, oz, radius)

	local getUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
	for _, targetID in ipairs(enemies) do
		if getUnitWeaponTestTarget(unitID, targetID) then
			return true
		end
	end
end

local function landAtPosition(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	return true -- not implemented
end

-- Engine callins --------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if strafeAirSpeed[unitDefID] ~= 0 then
		isStrafeAirUnit[unitID] = ":)" -- todo
		Spring.InsertUnitCmdDesc(unitID, cmdDescLandAtPosition)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	isStrafeAirUnit[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % 420 == 69 then
		checkStrafeLandingMoveGoals()
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, fromSynced, fromLua)
	return not isStrafeBomber[unitDefID] or not inBombingRun(unitID, unitDefID)
end

function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	if cmdID == CMD_LAND_AT_POSITION then
		return landAtPosition(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_STOP)
	gadgetHandler:RegisterAllowCommand(CMD_LAND_AT_POSITION)

	for _, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), spGetUnitTeam(unitID))
	end
end
