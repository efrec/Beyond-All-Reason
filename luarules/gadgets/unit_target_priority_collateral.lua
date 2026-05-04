local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name    = "Collateral Target Priority",
		desc    = "Increases the target priority penalty based on nearby allied units.",
		author  = "efrec",
		version = "0.0",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1000, -- expensive so process it last
		enabled = true, -- auto-disables
	}
end

local PRIORITY_CLEAN_SHOT = 0.75
local PRIORITY_COLLATERAL = 10.0
local collateralPenaltyMax = 25.0
local friendPowerRatio = 1.15
local powerFodderMax = 50
local effectTarget = 0.20

local sphereTestRadiusMin = 64.0
local testDamageMin = 100.0

-- Lua env globals -------------------------------------------------------------

local math_clamp = math.clamp

local CallAsTeam = CallAsTeam ---@diagnostic disable-line: undefined-global

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitsInSphere = Spring.GetUnitsInSphere

-- Initialization --------------------------------------------------------------

local unitWeaponSet = {}
local weaponInUnitSet = {}

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

local function ignoreWeaponDef(weaponDef)
	return weaponDef.customParams.bogus == "1"
		or weaponDef.damages[0] <= 1 -- TODO: consider non-default armors also
end

local unitPower = {}
local unitDefRadiusAverage = 0.0 -- TODO: median or something

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitPower[unitDefID] = unitDef.metalCost + unitDef.energyCost / 70
	unitDefRadiusAverage = unitDefRadiusAverage + unitDef.radius
end

unitDefRadiusAverage = unitDefRadiusAverage / (#UnitDefs > 0 and #UnitDefs or 1)
unitDefRadiusAverage = unitDefRadiusAverage + 10 -- just feels about right to do

-- Avoid this radius padding from enabling tests on most/all weapons:
sphereTestRadiusMin = sphereTestRadiusMin + unitDefRadiusAverage * 0.5

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
		radius = aoe + unitDefRadiusAverage
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
		if parent == 0 then
			table.insert(groups[0], i)
		else
			table.insert(table.ensureTable(groups, parent), i)
		end
	end

	for j = 1, #groups[0] do
		local weaponNum = groups[0][j]
		local weaponDefID = weapons[weaponNum].weaponDef
		local weaponDef = WeaponDefs[weaponDefID]
		local subDefs = groups[weaponNum]

		local hitRadius, damageSphere = getExplosionRadiusEffective(weaponDef, subDefs)
		local addSphereTest = damageSphere >= testDamageMin and hitRadius >= sphereTestRadiusMin

		if not ignoreWeaponDef(weaponDef) and (addSphereTest) then
			local tests = {}
			if addSphereTest then
				tests.radius = hitRadius
			end
			table.ensureTable(unitWeaponSet, unitDef.id)[weaponNum] = tests
			weaponInUnitSet[weaponDefID] = true
			Script.SetWatchAllowTarget(weaponDefID, true)
		end
	end
end

local avoidUnit = {}
for _, teamID in pairs(Spring.GetTeamList()) do
	avoidUnit[teamID] = {}
end

local readAs = { read = -1 }

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

	local avoidRadius = avoidUnit[unitTeam][targetID]
	if avoidRadius and avoidRadius <= (weapon.radius or 0) then
		return true, priority * PRIORITY_COLLATERAL
	end

	local readTeam = readAs
	readTeam.read = unitTeam

	local tx, ty, tz = CallAsTeam(readTeam, spGetUnitPosition, targetID)

	local friendPower, enemyPower = 0.0, 0.0

	-- Detect friendly fire within the explosion radius.
	if weapon.radius then
		local friends = CallAsTeam(readTeam, spGetUnitsInSphere, tx, ty, tz, weapon.radius, -3)
		if not friends[1] then
			return true, priority
		end
		for _, friendID in pairs(friends) do
			if friendID ~= unitID then
				friendPower = friendPower + unitPower[spGetUnitDefID(friendID)]
			end
		end

		local enemies = CallAsTeam(readTeam, spGetUnitsInSphere, tx, ty, tz, weapon.radius, -4)
		local foundTarget = false
		for _, enemyID in pairs(enemies) do
			enemyPower = enemyPower + unitPower[spGetUnitDefID(enemyID)]
			if enemyID == targetID then
				foundTarget = true
			end
		end
		if not foundTarget then
			enemyPower = enemyPower + unitPower[spGetUnitDefID(targetID)]
		end
	end

	-- local ratio = (friendPower / math.max(enemyPower, 1e-3)) * friendPowerRatio
	-- local message = tostring(ratio)
	-- Spring.MarkerAddPoint(tx, ty, tz, message) -- ! testing

	if enemyPower <= friendPower * friendPowerRatio then
		if enemyPower <= friendPower and weapon.radius then
			-- TODO: Avoidance really should *match* on radius. That's just a lot of table entries.
			if avoidRadius then
				if avoidRadius > weapon.radius then
					avoidUnit[unitTeam][targetID] = weapon.radius
				end
			else
				avoidUnit[unitTeam][targetID] = weapon.radius
			end
		end

		if enemyPower <= powerFodderMax then
			return true, priority * PRIORITY_COLLATERAL
		else
			-- TODO: The priority penalty is scaling in only this one case, which is potentially inconsistent.
			local avoid = math_clamp((friendPower / enemyPower) * friendPowerRatio, 1, collateralPenaltyMax)
			return true, priority * avoid
		end
	elseif friendPower == 0 then
		return true, priority * PRIORITY_CLEAN_SHOT
	else
		return true, priority
	end
end

local index = 0
function gadget:GameFramePost()
	if avoidUnit[index] then
		avoidUnit[index] = {} -- TODO: avoids should expire on a more sensible poll rate.
	else
		index = -1
	end
	index = index + 1
end

function gadget:Initialize()
	for unitDefID, unitDef in ipairs(UnitDefs) do
		addWeaponFriendlyFireAvoidance(unitDef)
		unitPower[unitDefID] = unitDef.power
	end

	if next(unitWeaponSet) == nil then
		gadgetHandler:RemoveGadget()
		return
	end
end
