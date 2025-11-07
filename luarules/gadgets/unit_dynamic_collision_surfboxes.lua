local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Surfboxes (Unit Volumes)",
		desc    = "Allows units to be hit by impact-only weapons in water even when submerged",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

---@type number Max unit height/water depth for dynamic surfboxes.
local waterDepthMax = 22
---@type number Time between updates, in seconds.
local updateTime = 0.1

local math_abs = math.abs
local math_cos = math.cos
local math_clamp = math.clamp

local spGetUnitHeight = Spring.GetUnitHeight
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRotation = Spring.GetUnitRotation
local spGetUnitCollisionVolumeData = Spring.GetUnitCollisionVolumeData
local spSetUnitCollisionVolumeData = Spring.SetUnitCollisionVolumeData
-- local spGetPieceList = Spring.GetUnitPieceList -- todo
-- local spSetPieceCollisionData = Spring.SetUnitPieceCollisionVolumeData -- todo

-- Local state

local updateFrames = math_clamp(math.round(updateTime * Game.gameSpeed), 1, Game.gameSpeed)

-- The surf height = water height + tiny nudge + update interval * some unit speed * some incline
local surfHeight = Spring.GetWaterPlaneLevel() + 1 + updateTime * 64 * math_cos(math.rad(45)) -- approx +5.5

local surfboxDefs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	local categories = unitDef.modCategories
	if categories.notsub and categories.notair and categories.nothover and unitDef.height < waterDepthMax then
		-- todo: and moveDef.maxwaterdepth > unitDef.height, or something
		surfboxDefs[unitDefID] = true
	end
end

local surferVolumes = {}
local surfersInWater = {}
local surfersDiving = {}
local gameFrame = 0

-- Local functions

local function restoreVolume(unitID)
	spSetUnitCollisionVolumeData(unitID, unpack(surferVolumes[unitID]))
end

-- Inflates a bounded ellipsoid to match its bounding rectangle's surface and volume.
local halfInflateRatio = 1 + sqrt(2) / math.pi

-- Surfboxes raise collision volumes to just above the water level so units that are
-- able to traverse water deeper than their own height can be attacked and destroyed.
local function surf(unitID)
	local unitHeight = spGetUnitHeight(unitID)
	local ux, uy = spGetUnitPosition(unitID)
	local pitch, yaw, roll = spGetUnitRotation(unitID)

	-- Give some weight to the actual height to avoid comical stretches and offsets.
	local mix = math_clamp(0.25 + 0.75 * math_abs(math_cos(pitch) * math_cos(roll)), 0.5, 1)
	local height = unitHeight / mix

	local volume = surferVolumes[unitID]

	if uy + volume[5] + unitHeight >= surfHeight then
		restoreVolume(unitID) -- todo: only restore when needed
		return
	end

	-- Offset needed for the collision volume to reach the surf[ace] height.
	local yOffset = surfHeight - height - uy

	-- Split the difference between stretching the volume and lifting it up, with
	-- the goal of maintaining multiple, but much smaller, deltas in the result..
	local stretch = 0.5 * (yOffset - (uy + volume[5])) / unitHeight
	yOffset = 0.5 * yOffset -- ..else this value can be huge with roll/tilt.

	spSetUnitCollisionVolumeData(
		unitID,
		volume[1] * halfInflateRatio,
		volume[2] * halfInflateRatio * stretch,
		volume[3] * halfInflateRatio,
		volume[4],
		yOffset,
		volume[6],
		0, -- Ellipsoids trade great fitness for expensive detection.
		volume[8],
		volume[9]
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
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
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
	if surfboxDefs[unitDefID] then
		surferVolumes[unitID] = { spGetUnitCollisionVolumeData(unitID) }
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	surferVolumes[unitID] = nil
	surfersInWater[unitID] = nil
	surfersDiving[unitID] = nil
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if surferVolumes[unitID] then
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
	if surferVolumes[colliderID] then
		if not surferVolumes[collideeID] then
			duck(colliderID, collideeID)
		end
	elseif surferVolumes[collideeID] then
		duck(collideeID, colliderID)
	end
end
