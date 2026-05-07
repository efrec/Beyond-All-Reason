local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name    = "Collateral Target Priority",
		desc    = "Modifies the target priority based on nearby units.",
		author  = "efrec",
		version = "0.0",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1000, -- expensive so process it last
		enabled = true, -- auto-disables
	}
end

local PRIORITY_CLEAN_SHOT = 0.875
local PRIORITY_COLLATERAL = 4

local collateralPenaltyMax = 25.0
local friendPowerRatio = 1.15
local powerFodderMax = 50
local effectTarget = 0.20

local sphereTestRadiusMin = 64.0
local testDamageMin = 100.0

-- Lua env globals -------------------------------------------------------------

local math_clamp = math.clamp

local CallAsTeam = CallAsTeam ---@diagnostic disable-line: undefined-global

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitsInSphere = Spring.GetUnitsInSphere

-- Initialization --------------------------------------------------------------

local unitWeaponSet = {}
local weaponInUnitSet = {}

local allyTeams = {}
local avoidUnit, preferUnit = {}, {}
do
	local allyTeamList = Spring.GetAllyTeamList()
	for _, allyTeam in pairs(allyTeamList) do
		allyTeams[allyTeam] = true
		avoidUnit[allyTeam] = {}
		preferUnit[allyTeam] = {}
	end
end

local readAs = { read = -1 }

local unitPower = {} -- TODO: respect LOS access level
local unitDefRadiusAverage = 0.0 -- TODO: median or something

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitPower[unitDefID] = unitDef.metalCost + unitDef.energyCost / 70
	unitDefRadiusAverage = unitDefRadiusAverage + unitDef.radius
end

unitDefRadiusAverage = unitDefRadiusAverage / (#UnitDefs > 0 and #UnitDefs or 1)
unitDefRadiusAverage = unitDefRadiusAverage + 10 -- just feels about right to do

sphereTestRadiusMin = sphereTestRadiusMin + unitDefRadiusAverage * 0.5

local function ignoreWeaponDef(weaponDef)
	return weaponDef.customParams.bogus == "1"
		or weaponDef.damages[0] <= 1 -- TODO: consider non-default armors also
end

local weaponTypesExplosion = {
	Cannon            = true,
	BeamLaser         = true,
	LaserCannon       = true,
	LightningCannon   = true,
	MissileLauncher   = true,
	TorpedoLauncher   = true,
	StarburstLauncher = true,
	AircraftBomb      = true,
}

local function getExplosionRadiusEffective(weaponDef, subordinates)
	local radius, damage = 0.0, 0.0

	if not weaponTypesExplosion[weaponDef.type] then
		return radius, damage
	end

	if not ignoreWeaponDef(weaponDef) then
		local aoe = weaponDef.damageAreaOfEffect
		local effectAtEdge = weaponDef.edgeEffectiveness
		if effectAtEdge < effectTarget then
			aoe = (aoe * (effectTarget - 1) + 0.001 * (1 - effectTarget)) / (effectTarget - effectAtEdge)
		end
		local scatter = weaponDef.range * (math.max(weaponDef.accuracy, weaponDef.movingAccuracy * 0.5) + weaponDef.sprayAngle + 0.25 * weaponDef.targetMoveError)
		local miss = (1 - weaponDef.predictBoost) * 54
		if weaponDef.leadLimit > 0 then
			miss = math.min(weaponDef.leadLimit, miss)
		end
		radius = aoe + scatter + miss + unitDefRadiusAverage
		damage = weaponDef.damages[0] -- TODO
	end

	if subordinates then
		for subDefID, subDef in pairs(subordinates) do
			local subRadius, subDamage = getExplosionRadiusEffective(subDef)
			radius = math.max(radius, subRadius)
			damage = damage + subDamage
		end
	end

	return radius, damage
end

local function addWeaponFriendlyFireAvoidance(unitDef)
	local weapons = unitDef.weapons

	local groups = { [0] = {} }

	-- TODO: Drone targeting weapons use the weapon on a different unit entirely.
	for i, weapon in ipairs(weapons) do
		local parent = weapon.slavedTo
		local cycles = #weapons
		while weapons[parent] and cycles > 0 do
			parent = weapons[parent].slavedTo
			cycles = cycles - 1
		end
		local group = table.ensureTable(groups, parent)
		group[#group + 1] = i
	end

	for j = 1, #groups[0] do
		local weaponNum = groups[0][j]
		local weaponDefID = weapons[weaponNum].weaponDef
		local weaponDef = WeaponDefs[weaponDefID]
		local subDefs = groups[weaponNum]

		-- Avoid friendly targets within some geometry (that may or may not mix and match well):
		local radius, damage = getExplosionRadiusEffective(weaponDef, subDefs)

		if not ignoreWeaponDef(weaponDef) and damage >= testDamageMin and radius >= sphereTestRadiusMin then
			Script.SetWatchAllowTarget(weaponDefID, true)
			weaponInUnitSet[weaponDefID] = true
			table.ensureTable(unitWeaponSet, unitDef.id)[weaponNum] = {
				weaponNum = weaponNum,
				radius = radius,
			}
		end
	end
end

-- Local functions -------------------------------------------------------------

local function getCollateralInSphere(unitID, unitTeam, radius, targetID)
	local friendPower, enemyPower = 0.0, 0.0

	local readTeam = readAs
	readTeam.read = unitTeam
	local tx, ty, tz = CallAsTeam(readTeam, spGetUnitPosition, targetID)

	local friends = CallAsTeam(readTeam, spGetUnitsInSphere, tx, ty, tz, radius, -3)
	if not friends[1] then
		return 0.0, unitPower[spGetUnitDefID(targetID)]
	end

	for _, friendID in pairs(friends) do
		if friendID ~= unitID then
			friendPower = friendPower + unitPower[spGetUnitDefID(friendID)]
		end
	end

	-- TODO: Two spatial searches has worse perf than checking allegiance in a loop.
	local enemies = CallAsTeam(readTeam, spGetUnitsInSphere, tx, ty, tz, radius, -4)
	if not enemies[1] then
		return friendPower, unitPower[spGetUnitDefID(targetID)]
	end

	for _, enemyID in pairs(enemies) do
		enemyPower = enemyPower + unitPower[spGetUnitDefID(enemyID)]
	end

	return friendPower, enemyPower
end

-- Engine callins --------------------------------------------------------------

function gadget:AllowWeaponTarget(unitID, targetID, weaponNum, weaponDefID, priority)
	if not priority or not weaponInUnitSet[weaponDefID] then
		return true, priority
	end

	local weaponSet = unitWeaponSet[spGetUnitDefID(unitID)]
	local weapon = weaponSet and weaponSet[weaponNum]
	if not weapon then
		return true, priority
	end

	local unitTeam = spGetUnitTeam(unitID)
	local allyTeam = spGetUnitAllyTeam(unitID)
	local searchRadius = weapon.radius

	-- Check preferred targets first. If it's getting bombarded anyway...
	local preferRadius = preferUnit[allyTeam][targetID]
	if preferRadius and preferRadius + 10 >= searchRadius then
		return true, priority
	end

	-- Avoids are not as important
	local avoidRadius = avoidUnit[allyTeam][targetID]
	if avoidRadius and avoidRadius - 10 <= searchRadius then
		return true, priority * PRIORITY_COLLATERAL
	end

	local friendPower, enemyPower = getCollateralInSphere(unitID, unitTeam, searchRadius, targetID)

	if enemyPower >= friendPower * friendPowerRatio then
		if enemyPower >= friendPower and (not preferRadius or preferRadius < searchRadius) then
			preferUnit[allyTeam][targetID] = searchRadius
		end

		if friendPower <= powerFodderMax then
			return true, priority * PRIORITY_CLEAN_SHOT
		else
			return true, priority
		end
	else
		if enemyPower <= friendPower and (not avoidRadius or avoidRadius > searchRadius) then
			avoidUnit[allyTeam][targetID] = searchRadius
		end

		if enemyPower <= powerFodderMax then
			return true, priority * collateralPenaltyMax
		else
			local avoid = math_clamp((friendPower / enemyPower) * friendPowerRatio, 1, collateralPenaltyMax)
			return true, priority * avoid
		end
	end
end

local index = 0 -- TODO: use an actual polling rate instead of whatever this is
local reset = table.reduce(allyTeams, function(a, v, k) return k < a and k or a end, 1) - 1

function gadget:GameFramePost(frame)
	if avoidUnit[index] then
		avoidUnit[index] = {}
		preferUnit[index] = {}
	else
		index = reset
	end
	index = index + 1
end

function gadget:Initialize()
	for unitDefID, unitDef in ipairs(UnitDefs) do
		addWeaponFriendlyFireAvoidance(unitDef)
	end

	if next(unitWeaponSet) == nil then
		gadgetHandler:RemoveGadget()
		return
	end
end
