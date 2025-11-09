local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Surfboxes (Unit Volumes)",
		desc    = "Allows units to be hit by impact-only weapons in water even when submerged",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 1, -- after unit_dynamic_collision_volume.lua
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- Configuration

---@type number Max unit height/water depth for dynamic surfboxes.
local waterDepthMax = 22
---@type number Time between updates, in seconds.
local updateTime = 0.1

-- Globals

local math_clamp = math.clamp

local spGetUnitHeight = Spring.GetUnitHeight
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDirection = Spring.GetUnitDirection
local spGetUnitCollisionVolumeData = Spring.GetUnitCollisionVolumeData
local spSetUnitCollisionVolumeData = Spring.SetUnitCollisionVolumeData
local spSetUnitMidAndAimPos = Spring.SetUnitMidAndAimPos

-- Local state

local updateFrames = math_clamp(math.round(updateTime * Game.gameSpeed), 1, Game.gameSpeed)

-- The surf height = water height + tiny nudge + update interval * some unit speed * some incline
local surfHeight = Spring.GetWaterPlaneLevel() + 1 + updateTime * 64 * math.cos(math.rad(45)) -- approx +5.5

-- Inflates a bounded ellipsoid to match its bounding shape's surface and volume.
local inflateRatios = {
	--[[ ellipsoid ]] [0] = 1,
	--[[ cylinder  ]] [1] = 1.25,
	--[[ box       ]] [2] = 1.455,
	--[[ sphere    ]] [3] = 1,
	--[[ footprint ]] [4] = 1, -- as sphere
}

local canSurf = {} -- units that will have their colvols dynamically replaced
local canFloat = {} -- units that need to be able to float above surfer units

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.has_surfing_colvol then
		canSurf[unitDefID] = true
	else
		local is = unitDef.modCategories
		if (is.ship or is.hover or is.vtol) and not (is.underwater or is.canbeuw) then
			canFloat[unitDefID] = true
		end
	end
end

local surferUnitData = {} -- { volume, position }
local surferDefData = {} -- caches the unit data
local surfersInWater = {} -- units that are actually updated
local surfersDiving = {} -- forced to use its normal collider
local isFloatingUnit = {}
local gameFrame = 0

-- Local functions

local function toUnitSpace(dx, dy, dz, frontX, frontY, frontZ, rightX, rightY, rightZ, upX, upY, upZ)
	return
		dx * rightX + dy * upX + dz * frontX,
    	dx * rightY + dy * upY + dz * frontY,
    	dx * rightZ + dy * upZ + dz * frontZ
end

local function calculateUnitMidAndAimPos(unitID)
	-- Reverse-engineer our unit mid and aim point offsets.
	-- todo: just publish it from unit_dyn_col_vol, sheesh.
	local bx, by, bz, mx, my, mz, ax, ay, az = spGetUnitPosition(unitID, true, true)
	local fx, fy, fz, rx, ry, rz, ux, uy, uz = spGetUnitDirection(unitID)
	mx, my, mz = toUnitSpace(mx - bx, my - by, mz - bz, fx, fy, fz, rx, ry, rz, ux, uy, uz)
	ax, ay, az = toUnitSpace(ax - bx, ay - by, az - bz, fx, fy, fz, rx, ry, rz, ux, uy, uz)
	return { mx, my, mz, ax, ay, az, true } -- todo: invert ay?
end

local function getUnitData(unitID, unitDefID)
	local data = surferDefData[unitDefID]
	if not data then
		data = {
			position = calculateUnitMidAndAimPos(unitID),
			radius   = Spring.GetUnitRadius(unitID),
			volume   = { spGetUnitCollisionVolumeData(unitID) },
		}
		surferDefData[unitDefID] = data
	end
	return data
end

local function restoreVolume(unitID)
	local data = surferUnitData[unitID]
	if data then
		spSetUnitCollisionVolumeData(unitID, unpack(data.volume))
		spSetUnitMidAndAimPos(unitID, unpack(data.position))
	end
end

-- Surfboxes raise collision volumes to just above the water level so units that are
-- able to traverse water deeper than their own height can be attacked and destroyed.
local function surf(unitID)
	local unitHeight = spGetUnitHeight(unitID)
	local ux, uy, uz = spGetUnitPosition(unitID)

	local data = surferUnitData[unitID]
	local volume = data.volume

	if
		unitHeight + uy + volume[5] >= surfHeight + 2 or -- add +2 laziness
		unitHeight + uy <= waterDepthMax -- unit sank too far beneath water
	then
		restoreVolume(unitID) -- todo: don't restore if already restored
		return
	end

	local _, _, _, _, _, _, _, upward = spGetUnitDirection(unitID)
	upward = math_clamp(upward, 0.3333, 1)
	local height = unitHeight / upward

	-- New offset needed for the collision volume to reach the surf[ace] height.
	local yOffset = surfHeight - height - uy

	-- Split the difference between stretching the volume and lifting it up, with
	-- the goal of maintaining multiple, but much smaller, deltas in the result..
	local stretch = (1 + (yOffset - volume[5]) / unitHeight) * 0.5

	if stretch > 1 then
		yOffset = (volume[5] + yOffset) * 0.5 -- ...else this value can be large.
	else
		stretch = 1
	end

	-- The ellipsoid is a more tight-fitting shape so we increase its dimensions.
	local shapeDimensionRatio = inflateRatios[volume[7]]

	local ratioX = shapeDimensionRatio
	local ratioY = shapeDimensionRatio * stretch
	local ratioZ = shapeDimensionRatio

	local minXYZ = math.min(volume[1], volume[2], volume[3])
	local maxXZ = math.max(volume[1], volume[3])

	-- todo: This was an OK kludge to test if this would work. We need it to also:
	-- todo: (1) gradually reduce the yOffset in response to large changes in eccentricity
	-- todo: (2) have a maximum change in eccentricity; e.g. a long unit => a spherical colvol
	-- todo: (3) more accurately fit what we are trying to do; this just slightly overdoes it
	if maxXZ / minXYZ > 1.125 then
		-- Prevent targetBorder = 1 setting from causing misses by exchanging the
		-- volume's eccentricity in the unit's X and Z axes over to its Y axis.
		ratioX = ratioX / (1 + (volume[1] / minXYZ - 0.5) * 0.25 * upward)
		local rateY = 1 / (1 - (volume[2] / minXYZ - 0.5) * 0.17 * upward)
		ratioZ = ratioZ / (1 + (volume[3] / minXYZ - 0.5) * 0.25 * upward)

		-- Increasing shape dimension in Y means we don't need as much offset.
		ratioY = ratioY * rateY
		yOffset = yOffset - (rateY - 1) * rateY * unitHeight
	end

	spSetUnitCollisionVolumeData(
		unitID,
		volume[1] * ratioX,
		volume[2] * ratioY,
		volume[3] * ratioZ,
		volume[4],
		yOffset * 0.5,
		volume[6],
		0, -- Ellipsoids trade great fitness for expensive detection.
		volume[8],
		volume[9]
	)

	local position = data.position

	spSetUnitMidAndAimPos(
		unitID,
		position[1],
		position[2] + yOffset * 0.75,
		position[3],
		position[4],
		position[5] + yOffset * 0.5,
		position[6],
		true
	)
end

-- Sneak one unit beneath another by simply setting its collision volume back to normal.
local function duck(unitID, collideeID)
	-- todo: only restore the ordinary volume when the colliddee is above us, not just on any collision
	-- todo: check impacted unit's wanted speed & smooth out the collision (doesn't have to be removed completely)
	surfersDiving[unitID] = gameFrame
	restoreVolume(unitID)
end

-- Engine events

function gadget:Initialize()
	gameFrame = Spring.GetGameFrame()

	-- For luarules reload:
	local waterLevel = Spring.GetWaterPlaneLevel()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		if uy <= waterLevel then
			gadget:UnitEnteredWater(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end
	end
end

function gadget:GameFrame(n)
	if n % updateFrames == 0 then
		local update = n - updateFrames
		for unitID in pairs(surfersInWater) do
			if not surfersDiving[unitID] or surfersDiving[unitID] >= update then
				surf(unitID)
			end
		end
	end
	gameFrame = n
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if canSurf[unitDefID] then
		surferUnitData[unitID] = getUnitData(unitID, unitDefID)
	elseif canFloat[unitDefID] then
		isFloatingUnit[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	surferUnitData[unitID] = nil
	surfersInWater[unitID] = nil
	surfersDiving[unitID] = nil
	isFloatingUnit[unitID] = nil
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if surferUnitData[unitID] then
		surfersInWater[unitID] = true
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if surfersInWater[unitID] then
		restoreVolume(unitID)
		surfersInWater[unitID] = nil
		surfersDiving[unitID] = nil
	end
end

function gadget:UnitUnitCollision(colliderID, collideeID)
	-- Currently ignoring that a submarine could move above surfer:
	if surferUnitData[colliderID] and isFloatingUnit[collideeID] then
		duck(colliderID, collideeID)
	end
	if surferUnitData[collideeID] and isFloatingUnit[colliderID] then
		duck(collideeID, colliderID)
	end
end
