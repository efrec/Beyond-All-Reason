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
local conicTestAngleMin = math.deg(10)
local testRangeMin = 200.0
local testDamageMin = 100.0

-- Lua env globals -------------------------------------------------------------

local math_abs = math.abs
local math_clamp = math.clamp
local math_normalize = math.normalize
local math_sqrt = math.sqrt
local math_cos = math.cos
local math_sin = math.sin

local CallAsTeam = CallAsTeam ---@diagnostic disable-line: undefined-global

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitsInPlanes = Spring.GetUnitsInPlanes

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

local weaponTypesConicScan = {
	Flame = true,
	Melee = true,
}

local function ignoreWeaponDef(weaponDef)
	return weaponDef.customParams.bogus == "1"
		or weaponDef.damages[0] <= 1 -- TODO: consider non-default armors also
end

local unitPower = {} -- TODO: respect LOS access level
local unitDefRadiusAverage = 0.0 -- TODO: median or something

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitPower[unitDefID] = unitDef.metalCost + unitDef.energyCost / 70
	unitDefRadiusAverage = unitDefRadiusAverage + unitDef.radius
end

unitDefRadiusAverage = unitDefRadiusAverage / (#UnitDefs > 0 and #UnitDefs or 1)
unitDefRadiusAverage = unitDefRadiusAverage + 10 -- just feels about right to do

local narrowRadius = unitDefRadiusAverage * 0.25

-- Avoid this radius padding from enabling tests on most/all weapons:
sphereTestRadiusMin = sphereTestRadiusMin + unitDefRadiusAverage * 0.5
-- But we do the reverse here, making sure shorter cones are allowed:
testRangeMin = testRangeMin - unitDefRadiusAverage * 0.5

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

local function getScannedConeEffective(weaponDef, subordinates)
	local angle, range, damage = 0.0, 0.0, 0.0

	if not weaponTypesConicScan[weaponDef.type] then
		return angle, range, damage
	end

	if not ignoreWeaponDef(weaponDef) then
		range = weaponDef.range
		local aoe = weaponDef.damageAreaOfEffect
		local effectAtEdge = weaponDef.edgeEffectiveness
		if effectAtEdge < effectTarget then
			aoe = (aoe * (effectTarget - 1) + 0.001 * (1 - effectTarget)) / (effectTarget - effectAtEdge)
		end
		local inaccuracy = weaponDef.accuracy + weaponDef.sprayAngle -- units? radians?
		local scatterAtRange = aoe + range * math_sin(inaccuracy)
		angle = math.atan2(scatterAtRange, range)
		damage = weaponDef.damages[0] -- TODO
	end

	if subordinates then
		for subDefID, subDef in pairs(subordinates) do
			local subAngle, subDamage = getScannedConeEffective(subDef)
			angle = math.max(angle, subAngle)
			damage = damage + subDamage
		end
	end

	if angle > 0 and range > 0 then
		-- We have so much extra room in the cone-bounding planes that we halve this:
		local transverse = range * math_sin(angle) + unitDefRadiusAverage * 0.5
		angle = math.atan2(transverse, range)
	end

	return angle, weaponDef.range, damage
end

local function getScannedLineEffective(weaponDef, subordinates)
	local range, falloff, penalty, damage = 0.0, 1.0, 1.0, 0.0

	if not ignoreWeaponDef(weaponDef) then
		range = weaponDef.range
		damage = weaponDef.damages[0] -- TODO
		if not (weaponDef.noExplode and weaponDef.customParams.overpenetrate) then
			return range, falloff, penalty, damage
		end
		falloff = 1.0
		penalty = tonumber(weaponDef.customParams.overpenetrate_penalty or 0.01) or 0.01
	end

	if subordinates then
		for subDefID, subDef in pairs(subordinates) do
			local ra, fa, pe, da = getScannedLineEffective(subDef)
			if ra + da ~= 0 then
				falloff = math_clamp((falloff * damage + fa * da) / (damage + da), 0, 1)
				penalty = math_clamp((penalty * damage + pe * da) / (damage + da), 0, 1)
				damage = damage + da
			end
		end
	end

	return range, falloff, penalty, damage
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

		-- Avoid friendly targets within some geometry (that may or may not mix and match well):
		local hitRadius, damageSphere = getExplosionRadiusEffective(weaponDef, subDefs)
		local hitAngle, hitHeight, damageCone = getScannedConeEffective(weaponDef, subDefs)
		local hitLength, hitFalloff, hitPenalty, damageLine = getScannedLineEffective(weaponDef, subDefs)

		local addSphereTest = damageSphere >= testDamageMin and
			hitRadius >= sphereTestRadiusMin
		local addConicTest = damageCone >= testDamageMin and hitHeight >= testRangeMin and
			hitAngle >= conicTestAngleMin
		local addLinearTest = damageLine >= testDamageMin and hitLength >= testRangeMin and
			not (hitFalloff == 1 and hitPenalty == 1)

		if not ignoreWeaponDef(weaponDef) and (addSphereTest or addConicTest or addLinearTest) then
			local tests = {
				weaponNum = weaponNum,
			}
			if addSphereTest then
				tests.radius = hitRadius
			end
			if addConicTest then
				tests.angle = hitAngle
				tests.height = hitHeight
			end
			if addLinearTest then
				tests.length = hitLength
				tests.falloff = hitFalloff
				tests.penalty = hitPenalty
				tests.damage = damageLine
			end
			table.ensureTable(unitWeaponSet, unitDef.id)[weaponNum] = tests
			weaponInUnitSet[weaponDefID] = true
			Script.SetWatchAllowTarget(weaponDefID, true)
		end
	end
end

local function dot3(ax, ay, az, bx, by, bz)
	return ax * bx + ay * by + az * bz
end

local function cross3(ax, ay, az, bx, by, bz)
	return
		ay * bz - az * by,
		az * bx - ax * bz,
		ax * by - ay * bx
end

local function orthonormalize(v1x, v1y, v1z)
	if v1x == 0 and v1y == 0 and v1z == 0 then
		return
			0.0, 0.0, 1.0,
			1.0, 0.0, 0.0,
			0.0, 1.0, 0.0
	end

	local v2x, v2y, v2z = v1y, v1z, v1x
	local v3x, v3y, v3z = v1z, v1x, v1y

	local u1x, u1y, u1z = v1x, v1y, v1z

	local u1u1 = dot3(u1x, u1y, u1z, u1x, u1y, u1z)
	local u1v2 = dot3(u1x, u1y, u1z, v2x, v2y, v2z)
	local proj12 = u1v2 / u1u1
	local u2x, u2y, u2z = v2x - u1x * proj12, v2y - u1y * proj12, v2z - u1z * proj12

	local u1v3 = dot3(u1x, u1y, u1z, v3x, v3y, v3z)
	local u2v3 = dot3(u2x, u2y, u2z, v3x, v3y, v3z)
	local u2u2 = dot3(u2x, u2y, u2z, u2x, u2y, u2z)
	local proj13 = u1v3 / u1u1
	local proj23 = u2v3 / u2u2
	local u3x, u3y, u3z = v3x - u1x * proj13 - u2x * proj23, v3y - u1y * proj13 - u2y * proj23, v3z - u1z * proj13 - u2z * proj23

	local e1x, e1y, e1z = math_normalize(u1x, u1y, u1z)
	local e2x, e2y, e2z = math_normalize(u2x, u2y, u2z)
	local e3x, e3y, e3z = math_normalize(u3x, u3y, u3z)

	return
		e1x, e1y, e1z,
		e2x, e2y, e2z,
		e3x, e3y, e3z
end

-- We bound a cone with four sides and an end-cap.
-- A plane is a direction vector and a displacement <xyzd>.
local conePlanes = {
	table.new(4, 0),
	table.new(4, 0),
	table.new(4, 0),
	table.new(4, 0),
	table.new(4, 0),
}

local function planesAroundCone(px, py, pz, dx, dy, dz, halfAngle, height)
	local
	e1x, e1y, e1z,
	e2x, e2y, e2z,
	e3x, e3y, e3z = orthonormalize(dx, dy, dz)

	-- We want to try to return vectors: <d>, <left/right of d>, <up/down from d>
	-- So that we can plan the order in which the planes are tested. For reasons.
	if math_abs(e2y) > math_abs(e3y) then
		local a, b, c = e2x, e2y, e2z
		e2x, e2y, e2z = e3x, e3y, e3z
		e3x, e3y, e3z = a, b, c
	end

	local cosAngle = math_cos(halfAngle)
	local sinAngle = math_sin(halfAngle)

	local planes = conePlanes -- Reduce some GC pressure by not throwing out these tables.
	local p;

	-- Build the sides and end-cap first since they should sieve the most units (most-vertical).
	-- planes[3] is the end-cap (since it might not be vertical) and [1] and [2] are the sides:

	-- Try to sieve units as efficiently as possible by ordering the planes:
	-- Planes 1 and 2: left/right; 3: far cap; 4 and 5: top/bottom.

	p = planes[1]
	p[1], p[2], p[3] = -e2x * sinAngle + e1x * cosAngle, -e2y * sinAngle + e1y * cosAngle, -e2z * sinAngle + e1z * cosAngle
	p[4] = p[1] * px + p[2] * py + p[3] * pz

	p = planes[2]
	p[1], p[2], p[3] = e2x * sinAngle + e1x * cosAngle, e2y * sinAngle + e1y * cosAngle, e2z * sinAngle + e1z * cosAngle
	p[4] = p[1] * px + p[2] * py + p[3] * pz

	p = planes[3]
	p[1], p[2], p[3] = -e1x, -e1y, -e1z
	p[4] = -e1x * px - e1y * py - e1z * pz - height

	p = planes[4]
	p[1], p[2], p[3] = -e3x * sinAngle + e1x * cosAngle, -e3y * sinAngle + e1y * cosAngle, -e3z * sinAngle + e1z * cosAngle
	p[4] = p[1] * px + p[2] * py + p[3] * pz

	p = planes[5]
	p[1], p[2], p[3] = e3x * sinAngle + e1x * cosAngle, e3y * sinAngle + e1y * cosAngle, e3z * sinAngle + e1z * cosAngle
	p[4] = p[1] * px + p[2] * py + p[3] * pz

	return planes
end

-- We bound a cylinder with four sides and two end-caps.
-- A plane is a direction vector and a displacement <xyzd>.
local linePlanes = {
	table.new(4, 0),
	table.new(4, 0),
	table.new(4, 0),
	table.new(4, 0),
	table.new(4, 0),
	table.new(4, 0),
}

local function planesAroundCylinder(px, py, pz, dx, dy, dz, radius, height)
	local
	e1x, e1y, e1z,
	e2x, e2y, e2z,
	e3x, e3y, e3z = orthonormalize(dx, dy, dz)

	-- We want to try to return vectors: <d>, <left/right of d>, <up/down from d>
	-- So that we can plan the order in which the planes are tested. For reasons.
	if math_abs(e2y) > math_abs(e3y) then
		local a, b, c = e2x, e2y, e2z
		e2x, e2y, e2z = e3x, e3y, e3z
		e3x, e3y, e3z = a, b, c
	end

	local planes = linePlanes
	local p;

	-- Try to sieve units as efficiently as possible by ordering the planes:
	-- Planes 1 and 2: left/right; 3 and 4: near/far; 5 and 6: top/bottom.
	p = planes[1]
	p[1], p[2], p[3] = e2x, e2y, e2z
	p[4] = e2x * px + e2y * py + e2z * pz - radius

	p = planes[2]
	p[1], p[2], p[3] = -e2x, -e2y, -e2z
	p[4] = -e2x * px - e2y * py - e2z * pz - radius

	p = planes[3]
	p[1], p[2], p[3] = e1x, e1y, e1z
	p[4] = e1x * px + e1y * py + e1z * pz

	p = planes[4]
	p[1], p[2], p[3] = -e1x, -e1y, -e1z
	p[4] = -e1x * px - e1y * py - e1z * pz - (height - unitDefRadiusAverage)

	p = planes[5]
	p[1], p[2], p[3] = e3x, e3y, e3z
	p[4] = e3x * px + e3y * py + e3z * pz - radius

	p = planes[6]
	p[1], p[2], p[3] = -e3x, -e3y, -e3z
	p[4] = -e3x * px - e3y * py - e3z * pz - radius

	return planes
end

local function movePlanePosition(plane, x, y, z)
	plane[4] = plane[1] * x + plane[2] * y + plane[3] * z
end

local function isUnitInPlanes(unitID, planes)
	local _, _, _, ux, uy, uz = spGetUnitPosition(unitID, true) -- TODO: engine doesn't use midpoint?
	local unitRadius = Spring.GetUnitRadius(unitID)

	for i = 1, #planes do
		local p = planes[i]
		local check = dot3(ux, uy, uz, p[1], p[2], p[3]) + p[4] - unitRadius
		-- ! testing if I wrote the planes inside-out:
		-- if check >= 0 then
		if check < 0 then
			Spring.MarkerAddPoint(ux, uy, uz, i .. "@" .. check)
			return false
		end
	end

	Spring.MarkerAddPoint(ux, uy, uz, ":)")
	return true
end

local function getCornerPoint(plane1, plane2, elevation)
	local plane3 = { 0, 1, 0, elevation }

	local c12x, c12y, c12z = cross3(plane1[1], plane1[2], plane1[3], plane2[1], plane2[2], plane2[3])
	local c23x, c23y, c23z = cross3(plane2[1], plane2[2], plane2[3], plane3[1], plane3[2], plane3[3])
	local c31x, c31y, c31z = cross3(plane3[1], plane3[2], plane3[3], plane1[1], plane1[2], plane1[3])

	local nx = c23x * plane1[4] + c31x * plane2[4] + c12x * plane3[4]
	local ny = c23y * plane1[4] + c31y * plane2[4] + c12y * plane3[4]
	local nz = c23z * plane1[4] + c31z * plane2[4] + c12z * plane3[4]
	local denom = dot3(plane1[1], plane1[2], plane1[3], c23x, c23y, c23z)

	if math_abs(denom) < 1e-6 then
		return 0, 0, 0
	else
		return nx / denom, ny / denom, nz / denom
	end
end

local function pingCorners(planes, elevation)
	for _, func in ipairs { Spring.Echo, Spring.MarkerAddPoint } do
		func(getCornerPoint(planes[1], planes[3], elevation))
		func(getCornerPoint(planes[1], planes[4], elevation))
		func(getCornerPoint(planes[2], planes[3], elevation))
		func(getCornerPoint(planes[2], planes[4], elevation))
	end
end

local avoidUnit = {}
for _, teamID in pairs(Spring.GetTeamList()) do
	avoidUnit[teamID] = {}
end

local readAs = { read = -1 }

-- Rather than using len(weap - mid), use a single generally-good value for the below:
local distanceMin = unitDefRadiusAverage * 2 - 10

local function getWeaponPosition(unitID, weaponNum, px, py, pz)
	-- We need a position that is agnostic to the unit's facing, more or less.
	-- Rotate weapon position around unit midpoint and toward target position:
	-- local wx, wy, wz = spGetUnitWeaponVectors(unitID, weaponNum) -- ! Do we need exact offsets?
	local _, _, _, mx, my, mz = spGetUnitPosition(unitID, true)

	local dx = px - mx
	local dy = py - my
	local dz = pz - mz
	local separation = math_sqrt(dot3(dx, dy, dz, dx, dy, dz))

	if separation <= distanceMin then
		return mx, my, mz
	end

	separation = distanceMin / separation
	local rx = dx * separation
	local ry = dy * separation
	local rz = dz * separation

	return mx + rx, my + ry, mz + rz
end

local function getCollateralInSphere(unitID, weapon, targetID, px, py, pz)
	local friendPower, enemyPower = 0.0, 0.0

	local friends = CallAsTeam(readAs, spGetUnitsInSphere, px, py, pz, weapon.radius, -3)
	if not friends[1] then
		return friendPower, enemyPower
	end

	for _, friendID in pairs(friends) do
		if friendID ~= unitID then
			friendPower = friendPower + unitPower[spGetUnitDefID(friendID)]
		end
	end

	local enemies = CallAsTeam(readAs, spGetUnitsInSphere, px, py, pz, weapon.radius, -4)
	if not enemies[1] then
		enemyPower = enemyPower + unitPower[spGetUnitDefID(targetID)]
		return friendPower, enemyPower
	end

	local seenTarget = false -- Accounts for radar error > search area.

	for _, enemyID in pairs(enemies) do
		enemyPower = enemyPower + unitPower[spGetUnitDefID(enemyID)]
		if enemyID == targetID then
			seenTarget = true
		end
	end

	if not seenTarget then
		enemyPower = enemyPower + unitPower[spGetUnitDefID(targetID)]
	end

	return friendPower, enemyPower
end

local function getCollateralInCone(unitID, weapon, targetID, px, py, pz)
	local friendPower, enemyPower = 0.0, 0.0

	local wx, wy, wz = getWeaponPosition(unitID, weapon.weaponNum, px, py, pz)
	local planes = planesAroundCone(wx, wy, wz, px - wx, py - wy, pz - wz, weapon.angle, weapon.height)

	-- ! GetUnitsInPlanes crashes unconditionally(?) when passing an allegiance
	-- ! Recreate the engine spatial search so we can do our own diagnostics:
	isUnitInPlanes(targetID, planes)
	pingCorners(planes, py) -- TODO: adapt to cone

	if true then
		return
	end

	local friends = CallAsTeam(readAs, spGetUnitsInPlanes, planes, -3)
	if not friends[1] then
		return
	end

	for _, friendID in pairs(friends) do
		if friendID ~= unitID then
			friendPower = friendPower + unitPower[spGetUnitDefID(friendID)]
		end
	end

	local enemies = CallAsTeam(readAs, spGetUnitsInPlanes, planes, -4)
	if not enemies[1] then
		enemyPower = enemyPower + unitPower[spGetUnitDefID(targetID)]
		return friendPower, enemyPower
	end

	local seenTarget = false -- Accounts for radar error > search area.

	for _, enemyID in pairs(enemies) do
		enemyPower = enemyPower + unitPower[spGetUnitDefID(enemyID)]
		if enemyID == targetID then
			seenTarget = true
		end
	end

	if not seenTarget then
		enemyPower = enemyPower + unitPower[spGetUnitDefID(targetID)]
	end

	return friendPower, enemyPower
end

local function getCollateralInCylinder(unitID, weapon, targetID, px, py, pz)
	-- Railgun penetrators are accurate and only overpen on overkill:
	if weapon.damage <= (Spring.GetUnitHealth(targetID)) * 1.1 then
		return
	end

	local friendPower, enemyPower = 0.0, 0.0

	-- TODO: One day, maybe, we can just use Spring.TraceRayUnits(...).
	-- Until then, we have this lousy method and ignore falloff/penalty.
	local wx, wy, wz = getWeaponPosition(unitID, weapon.weaponNum, px, py, pz)

	local planes = planesAroundCylinder(wx, wy, wz, px - wx, py - wy, pz - wz, narrowRadius, weapon.length)

	-- ! GetUnitsInPlanes crashes unconditionally(?) when passing an allegiance.
	-- ! We recreate the engine spatial search so we can do our own diagnostics:
	if not isUnitInPlanes(targetID, planes) then
		pingCorners(planes, py)
	end

	if true then
		return
	end

	-- We only check for allied units in the overpen region after hitting the target.
	movePlanePosition(planes[3], px, py, pz)
	local friends = CallAsTeam(readAs, spGetUnitsInPlanes, planes, -4) -- ! crash
	if not friends[1] then
		return -- Because we are banking on this outcome, which allows an early exit.
	end

	for _, foundID in pairs(friends) do
		if foundID ~= unitID then
			friendPower = friendPower + unitPower[spGetUnitDefID(foundID)]
		end
	end

	if weapon.falloff + weapon.penalty >= 0.1 then
		-- Evaluate penetrator falloff hyper-lazily by overemphasizing the target:
		enemyPower = unitPower[spGetUnitDefID(targetID)]
	end

	-- Enemies can be anywhere along the line of travel, so we reset the near-plane.
	movePlanePosition(planes[3], wx, wy, wz)
	local enemies = CallAsTeam(readAs, spGetUnitsInPlanes, planes, -3) -- ! crash
	if not enemies[1] then
		enemyPower = enemyPower + unitPower[spGetUnitDefID(targetID)]
		return friendPower, enemyPower
	end

	local seenTarget = false -- Accounts for radar error > search area.

	for _, enemyID in pairs(enemies) do
		enemyPower = enemyPower + unitPower[spGetUnitDefID(enemyID)]
		if enemyID == targetID then
			seenTarget = true
		else
			break -- Penetrators are still single-target damagers, mostly.
		end
	end

	if not seenTarget then
		enemyPower = enemyPower + unitPower[spGetUnitDefID(targetID)]
	end

	return friendPower, enemyPower
end

local collateralSearches = {
	radius = getCollateralInSphere,
	angle  = getCollateralInCone,
	length = getCollateralInCylinder,
}

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

	-- Only the sphere test can avoid; the cone is just no good.
	local avoidRadius = avoidUnit[unitTeam][targetID]
	if avoidRadius and avoidRadius <= (weapon.radius or 0) then
		return true, priority * PRIORITY_COLLATERAL
	end

	local readTeam = readAs
	readTeam.read = unitTeam

	local tx, ty, tz = CallAsTeam(readTeam, spGetUnitPosition, targetID)

	local friendPower, enemyPower = 0.0, 0.0

	for property, search in pairs(collateralSearches) do
		if weapon[property] then
			local allied, hostile = search(unitID, weapon, targetID, tx, ty, tz)
			if allied then
				friendPower = allied + friendPower
				enemyPower = hostile + enemyPower
			end
		end
	end

	if friendPower == 0 then
		return true, priority * PRIORITY_CLEAN_SHOT
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
