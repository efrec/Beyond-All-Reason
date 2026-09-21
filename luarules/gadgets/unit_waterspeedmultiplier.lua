local gadget = gadget ---@type Gadget

local enabled = true
do
	local success, mapinfo = pcall(VFS.Include, "mapinfo.lua")
	if success and mapinfo and mapinfo.voidwater then
		enabled = false
	end
end

function gadget:GetInfo()
	return {
		name = "Water Speed Multiplier",
		desc = "Speeds up or slows down units on water compared to their default land speed.",
		author = "ZephyrSkies",
		date = "2025-09-14",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = enabled,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Configuration ---------------------------------------------------------------

local depthUpdateRate = 0.2500 ---@type number # in seconds | for units with speeds variable by water depth
local watchUpdateRate = 0.5000 ---@type number # in seconds | slow watch interval for variable-speed units

local searchCellSize = 64 ---@type number # in elmos | side of a coarse planning cell
local routePassabilityStep = 32 ---@type number # in elmos | sampling interval when a path is checked vs the direct line
local burstClusterSize = 4 ---@type integer # in cells | orders whose goals share a square this wide form one burst
local searchBudgetSlice = 360 ---@type integer # in expansions per frame | provisional, fixed by the synthetic tests
local burstBudgetTotal = 1600 ---@type integer # in expansions per burst | provisional, fixed by the synthetic tests
local routeUnitBudget = 20 ---@type integer # in units per frame | provisional, fixed by the synthetic tests
local burstAgeMax = 5.0 ---@type number # in seconds | a burst older than this is dropped unplanned
local routeQueueMax = 10 ---@type integer # in bursts | new bursts are dropped while this many wait
local routeCooldown = 20.0 ---@type number # in seconds | the same order is not planned again sooner than this
local routeBiasWeight = 1.5 ---@type number # above 1 closes a burst's field sooner at some loss of route quality

-- Globals ---------------------------------------------------------------------

local table_remove = table.remove

local math_abs = math.abs
local math_floor = math.floor
local math_ceil = math.ceil
local math_sqrt = math.sqrt
local math_pi = math.pi
local math_max = math.max
local math_min = math.min
local math_clamp = math.clamp
local math_huge = math.huge

local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundNormal = Spring.GetGroundNormal
local spGetMoveTypeData = Spring.GetUnitMoveTypeData
local spSetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spTestMoveOrder = Spring.TestMoveOrder
local spGetGameFrame = Spring.GetGameFrame
local CallAsTeam = CallAsTeam

local CMD_INSERT = CMD.INSERT
local CMD_MOVE = CMD.MOVE
local CMD_FIGHT = CMD.FIGHT
local CMD_PATROL = CMD.PATROL
local CMD_ATTACK = CMD.ATTACK
local CMD_GUARD = CMD.GUARD
local CMD_REMOVE = CMD.REMOVE

local routedOrders = {
	[CMD_MOVE] = CMD_MOVE,
	[CMD_FIGHT] = CMD_FIGHT,
	[CMD_PATROL] = CMD_FIGHT,
	[CMD_ATTACK] = CMD_MOVE,
	[CMD_GUARD] = CMD_MOVE,
	-- TODO: various other orders, probably
}

local SMCLASS_HOVER = 2
local SMCLASS_SHIP = 3

-- Setup -----------------------------------------------------------------------

local unitDefData = {}

---An order shorter than `2 * sqrt((4r - d)d)` for turn radius `r` cannot be an improvement.
---Find the single-cell deviation from the straight-line path per unitdef to compare against.
local function getMinRouteLength(unitDef, speedFactorMax)
	local turnRate = math_max(1.0, (unitDef.turnRate or 0.0) * (speedFactorMax * 0.50 + 0.50))
	local speedPerFrame = (unitDef.speed or 0.0) * speedFactorMax / Game.gameSpeed
	local CIRCLE_DIVS = 65536
	local radius = speedPerFrame * (CIRCLE_DIVS / turnRate) / (2 * math_pi)
	local across = math_min(searchCellSize, 4 * radius)
	local minRouteLength = 2 * math_sqrt(across * (4 * radius - across))
	return math_max(minRouteLength, searchCellSize * (1 + routeBiasWeight))
end

for defID, ud in pairs(UnitDefs) do
	local params = ud.customParams

	local speedFactorInWater = tonumber(params.speedfactorinwater or 1.0) or 1.0
	local speedFactorAtDepth = math_abs(params.speedfactoratdepth and tonumber(params.speedfactoratdepth) or 0.0) * -1

	if ud.moveDef and ud.moveDef.smClass and speedFactorInWater ~= 1.0 then
		if speedFactorAtDepth > -1 then
			speedFactorAtDepth = 0
		end

		local moveDef = ud.moveDef
		local maxSlope = moveDef.maxSlope or 0
		local slopeMod = moveDef.slopeMod or 0
		local speedFactorMax = math_max(1, speedFactorInWater)

		unitDefData[defID] = {
			defID = defID,
			speedFactorInWater = speedFactorInWater,
			speedFactorAtDepth = speedFactorAtDepth,

			speed = ud.speed,
			turn = ud.turnRate,
			acc = ud.maxAcc,
			dec = ud.maxDec,

			moveClass = moveDef and moveDef.smClass,
			moveDepth = moveDef and moveDef.depth or 0.0,
			maxSlope = maxSlope,
			slopeMod = slopeMod,
			speedFactorMax = speedFactorMax,
			worst = speedFactorMax * (1 + maxSlope * slopeMod),
			range = ud.maxWeaponRange or 0.0,
			routeStride = math_max(1, math_floor(moveDef and moveDef.xsize * 4 / routePassabilityStep or 1)), -- Retests every move-footprint-width.
			halfWidth = moveDef and moveDef.xsize * 4 or 0.0,
			minRouteLength = getMinRouteLength(ud, speedFactorMax),
		}
	end
end

local unitDepthSlowUpdate = {}
local unitDepthFastUpdate = {}
local slowUpdateFrames = math.round(watchUpdateRate * Game.gameSpeed, 0)
local fastUpdateFrames = math.round(depthUpdateRate * Game.gameSpeed, 0)

---@type GroundMoveType
local moveTypeData = {
	maxSpeed = 0,
	maxWantedSpeed = 0,
	turnRate = 0,
	accRate = 0,
	decRate = 0,
}

local cellSize = searchCellSize
local gridCols = math_ceil(Game.mapSizeX / cellSize)
local gridRows = math_ceil(Game.mapSizeZ / cellSize)
local cellCount = gridCols * gridRows
local clusterCols = math_ceil(gridCols / burstClusterSize)
local sampleOffset = cellSize * 3 / 8 -- could be in config

local GROUND_BIAS = 1024
local GROUND_SPAN = 4096
local SLOPE_SCALE = 254
local SLOPE_UNKNOWN = 255

local terrainCode = {}
local waterDistance = {}
local fieldCost = {}
local fieldParent = {}
local fieldStamp = {}
local startStamp = {}
local heapPos = {}
local heapIndex = {}
local heapScore = {}
local heapSize = 0

local burstAgeFrames = math_floor(burstAgeMax * Game.gameSpeed)
local cooldownFrames = math_floor(routeCooldown * Game.gameSpeed)

local generation = 0
local refreshTick = 0
local unsettled = 0
local boxMinCol, boxMaxCol, boxMinRow, boxMaxRow = 0, 0, 0, 0 ---@type number, number, number, number

---@class RouteJob
---@field unitID integer
---@field gx number
---@field gz number
---@field goalIndex integer
---@field dropped boolean
---@field path integer[]|false

---@class RouteBurst
---@field key number
---@field unitData table
---@field frame integer
---@field jobs RouteJob[]
---@field started boolean
---@field source integer
---@field bound number
---@field expansions integer
---@field next integer

local openBursts = {} ---@type table<integer, RouteBurst>
local openList = {} ---@type RouteBurst[]
local searchQueue = {} ---@type RouteBurst[]
local rerouteQueue = {} ---@type RouteBurst[]
local unitJob = {} ---@type table<UnitID, RouteJob>
local plannedTag = {}
local plannedFrame = {}
local plannedX = {}
local plannedZ = {}
local plannedWaypoints = {}
local waypointTag = {}
local waypointIndex = {}
local waypointRadius = {}
local rerouting = false

local stats = {
	rejected = 0,
	recorded = 0,
	bursts = 0,
	expansions = 0,
	verified = 0,
	inserted = 0,
	dropped = 0,
	abandoned = 0,
}

-- Local functions -------------------------------------------------------------

-- applies a multiplicative factor to a unit's base movement stats: speed, wanted speed, turn rate, accel, decel
-- The base stats come from UnitDefs and are scaled proportionally
--
-- TODO: unify with GG.ForceUpdateWantedMaxSpeed / unit_wanted_speed.lua
-- This gadget should eventually integrate with a system that can compose
-- multiple wanted speeds, constraints, and coefficients, as per efrec/BONELESS/qscrew
-- Current implementation is local only.
local function setMoveTypeData(unitID, unitData, factor)
	local data = moveTypeData

	--these factor effectiveness values for the given unit stats were chosen arbitrarily for the best mechanical feel and balance,
	--as well as to avoid strange jerky visuals
	local speed = unitData.speed * factor

	data.maxSpeed = speed
	data.maxWantedSpeed = speed
	data.turnRate = unitData.turn * (factor * 0.50 + 0.50)
	data.accRate = unitData.acc * (factor * 0.75 + 0.25)
	data.decRate = unitData.dec * (factor * 0.75 + 0.25)

	spSetGroundMoveTypeData(unitID, data)
end

local fake = {} -- just in case tbh

local function canSetSpeed(unitID)
	return spGetUnitIsDead(unitID) == false and (spGetMoveTypeData(unitID) or fake).name == "ground"
end

local function getUnitDepth(unitID)
	local x, y, z = spGetUnitPosition(unitID)
	return x and spGetGroundHeight(x, z) or 0
end

---@return number factor
local function speedFactorAtGroundHeight(unitData, ground)
	if ground >= 0 then
		return 1
	end
	local depthMax = unitData.speedFactorAtDepth
	if depthMax == 0 then
		return unitData.speedFactorInWater
	end
	return 1 + (unitData.speedFactorInWater - 1) * math_clamp(ground / depthMax, 0, 1)
end

local function applySpeed(unitID, unitData, factor)
	setMoveTypeData(unitID, unitData, factor or speedFactorAtGroundHeight(unitData, getUnitDepth(unitID)))
end

local function slowUpdate()
	local getDepth = getUnitDepth -- micro speedup

	for unitID, unitData in pairs(unitDepthSlowUpdate) do
		if getDepth(unitID) > unitData.speedFactorAtDepth - 15 then
			unitDepthFastUpdate[unitID] = unitData
			unitDepthSlowUpdate[unitID] = nil
		end
	end
end

local function fastUpdate()
	local canSetSpeed, getDepth, setMoveData = canSetSpeed, getUnitDepth, setMoveTypeData -- micro speedup

	for unitID, unitData in pairs(unitDepthFastUpdate) do
		if canSetSpeed(unitID) then
			local depth, depthMax = getDepth(unitID), unitData.speedFactorAtDepth
			if depth >= depthMax - 15 then
				setMoveData(
					unitID,
					unitData,
					1 + (unitData.speedFactorInWater - 1) * math_clamp(depth / depthMax, 0, 1)
				)
			else
				unitDepthSlowUpdate[unitID] = unitData
				unitDepthFastUpdate[unitID] = nil
			end
		else
			unitDepthSlowUpdate[unitID] = unitData
			unitDepthFastUpdate[unitID] = nil
		end
	end
end

-- Water routing ---------------------------------------------------------------
-- We do some A* pathing in here so obligatory: -- TODO: move into a new module.

---Grid cells are coarse and rolled into a compact sequence for fast accesses.
local function posToCell(x, z)
	return (
		math_clamp(math_floor(z / cellSize), 0, gridRows - 1) * gridCols
		+ math_clamp(math_floor(x / cellSize), 0, gridCols - 1)
		+ 1
	) ---@as integer
end

---Position returned is the exact center so may not match the seeded position.
local function cellToPos(index)
	return ((index - 1) % gridCols) * cellSize + cellSize / 2,
		math_floor((index - 1) / gridCols) * cellSize + cellSize / 2
end

---@return number ground
---@return number slope
local function cellTerrain(index)
	-- This is data packing. Five heights and five slopes, take highest and steepest, packed to coded integer.
	-- Maps can be massive and very many orders can be given. Try to produce a near-constant memory footprint.
	local code = terrainCode[index] or 0

	local groundInt = code % GROUND_SPAN
	local slopeBucket = (code - groundInt) / GROUND_SPAN

	if code == 0 then
		local x, z = cellToPos(index)
		local o = sampleOffset
		local ground = math_max(
			spGetGroundHeight(x, z),
			spGetGroundHeight(x - o, z - o),
			spGetGroundHeight(x + o, z - o),
			spGetGroundHeight(x - o, z + o),
			spGetGroundHeight(x + o, z + o)
		)
		groundInt = math_clamp(math_floor(ground + GROUND_BIAS), 1, GROUND_SPAN - 1) ---@as integer
		slopeBucket = SLOPE_UNKNOWN
		terrainCode[index] = slopeBucket * GROUND_SPAN + groundInt
	end

	local ground = groundInt - GROUND_BIAS
	if slopeBucket == SLOPE_UNKNOWN then
		if ground < 0 then
			return ground, 0
		end
		local x, z = cellToPos(index)
		local o = sampleOffset
		local _, _, _, s1 = spGetGroundNormal(x, z)
		local _, _, _, s2 = spGetGroundNormal(x - o, z - o)
		local _, _, _, s3 = spGetGroundNormal(x + o, z - o)
		local _, _, _, s4 = spGetGroundNormal(x - o, z + o)
		local _, _, _, s5 = spGetGroundNormal(x + o, z + o)
		local slope = math_max(s1 or 0, s2 or 0, s3 or 0, s4 or 0, s5 or 0)
		slopeBucket = math_clamp(math_floor(slope * SLOPE_SCALE + 0.5), 0, SLOPE_SCALE)
		terrainCode[index] = slopeBucket * GROUND_SPAN + groundInt
	end

	return ground, slopeBucket / SLOPE_SCALE
end

---Time-cost per elmo traveled relative to the unit's fastest terrain, so the cheapest cell costs 1.0.
---
---Needs some work to cover a couple more cases. Fine for the use case of water speed > ground speeds.
---@return number|false cost `false` when impassible
local function terrainCost(unitData, ground, slope)
	local speedFactorMax = unitData.speedFactorMax
	local class = unitData.moveClass

	if ground < 0 then
		if class == SMCLASS_SHIP then
			return -ground >= unitData.moveDepth and speedFactorMax / speedFactorAtGroundHeight(unitData, ground)
				or false
		elseif class == SMCLASS_HOVER or -ground <= unitData.moveDepth then
			return speedFactorMax / speedFactorAtGroundHeight(unitData, ground)
		else
			return false
		end
	else
		if class == SMCLASS_SHIP or slope > unitData.maxSlope then
			return false
		else
			return speedFactorMax * (1 + slope * unitData.slopeMod)
		end
	end
end

local function cellCost(unitData, index)
	local ground, slope = cellTerrain(index)
	return terrainCost(unitData, ground, slope)
end

---@return number cost
---@return integer samples
local function coarseLineCost(unitData, ax, az, bx, bz)
	local worst = unitData.worst -- For impassable cells, same way the engine handles them.
	local dx, dz = bx - ax, bz - az
	local distance = math_sqrt(dx * dx + dz * dz)
	local steps = math_max(1, math_ceil(distance / (cellSize / 2)))
	local total = 0.0
	for i = 0, steps do
		local t = i / steps
		local cost = cellCost(unitData, posToCell(ax + dx * t, az + dz * t)) or worst
		total = total + cost * ((i == 0 or i == steps) and 0.5 or 1.0)
	end
	return total * (distance / steps), steps
end

---A pessimistic cost over the worst ground in a band as wide as the unit footprint.
---The footprint may not be able to traverse some costed cells, tested on "strides".
---@return number cost
local function fineLineCost(unitData, ax, az, bx, bz)
	local defID = unitData.defID
	local worst = unitData.worst -- For impassable cells, same way the engine handles them.
	local routeStride = unitData.routeStride
	local halfWidth = unitData.halfWidth
	local dx, dz = bx - ax, bz - az

	local distance = math_sqrt(dx * dx + dz * dz)
	local steps = math_max(1, math_ceil(distance / routePassabilityStep))
	local px, pz = -dz / distance * halfWidth, dx / distance * halfWidth

	local passable = true
	local total = 0.0

	for i = 0, steps do
		local t = i / steps
		local x, z = ax + dx * t, az + dz * t
		local ground =
			math_max(spGetGroundHeight(x, z), spGetGroundHeight(x + px, z + pz), spGetGroundHeight(x - px, z - pz))
		if i % routeStride == 0 then
			passable = spTestMoveOrder(defID, x, ground, z, 0, 0, 0, true, false, false)
		end
		local cost = worst
		if passable then
			local slope = 0.0 ---@type number
			if ground >= 0.0 then
				local _, _, _, s1 = spGetGroundNormal(x, z)
				local _, _, _, s2 = spGetGroundNormal(x + px, z + pz)
				local _, _, _, s3 = spGetGroundNormal(x - px, z - pz)
				slope = math_max(s1 or 0.0, s2 or 0.0, s3 or 0.0)
			end
			cost = terrainCost(unitData, ground, slope) or worst
		end
		total = total + cost * ((i == 0 or i == steps) and 0.5 or 1.0)
	end

	return total * (distance / steps)
end

local function heapUp(n, index, score)
	while n > 1 do
		local parent = math_floor(n / 2)
		local parentScore = heapScore[parent]
		if parentScore <= score then
			break
		end
		local parentIndex = heapIndex[parent]
		heapIndex[n], heapScore[n] = parentIndex, parentScore
		heapPos[parentIndex] = n
		n = parent
	end
	heapIndex[n], heapScore[n] = index, score
	heapPos[index] = n
end

local function heapPop()
	local index = heapIndex[1]
	heapPos[index] = 0
	local n = heapSize
	heapSize = n - 1
	if n > 1 then
		local lastIndex, lastScore = heapIndex[n], heapScore[n]
		n = n - 1
		local i = 1
		while true do
			local child = i * 2
			if child > n then
				break
			end
			local childScore = heapScore[child]
			if child < n and heapScore[child + 1] < childScore then
				child = child + 1
				childScore = heapScore[child]
			end
			if childScore >= lastScore then
				break
			end
			local childIndex = heapIndex[child]
			heapIndex[i], heapScore[i] = childIndex, childScore
			heapPos[childIndex] = i
			i = child
		end
		heapIndex[i], heapScore[i] = lastIndex, lastScore
		heapPos[lastIndex] = i
	end
	return index
end

---Maximum relative length of the eight-connected path to the straight line path.
local octileSlack = math_sqrt(4 - 2 * math_sqrt(2))
local neighbourCol = { 1, -1, 0, 0, 1, 1, -1, -1 }
local neighbourRow = { 0, 0, 1, -1, 1, -1, 1, -1 }
local neighbourHalfLength = {
	cellSize / 2,
	cellSize / 2,
	cellSize / 2,
	cellSize / 2,
	math_sqrt(2) * cellSize / 2,
	math_sqrt(2) * cellSize / 2,
	math_sqrt(2) * cellSize / 2,
	math_sqrt(2) * cellSize / 2,
}

---Cell count to the nearest water in steps, over eight neighbours, from every cell with any water in it.
---This populates a heap storage with neighbors to give a fast, light cache for finding water approaches.
local function populateWaterDistances()
	local o = sampleOffset
	local queued = 0
	for index = 1, cellCount do
		local x, z = cellToPos(index)
		local h1 = spGetGroundHeight(x, z)
		local h2 = spGetGroundHeight(x - o, z - o)
		local h3 = spGetGroundHeight(x + o, z - o)
		local h4 = spGetGroundHeight(x - o, z + o)
		local h5 = spGetGroundHeight(x + o, z + o)
		local ground = math_max(h1, h2, h3, h4, h5)
		terrainCode[index] = SLOPE_UNKNOWN * GROUND_SPAN
			+ math_clamp(math_floor(ground + GROUND_BIAS), 1, GROUND_SPAN - 1)
		if math_min(h1, h2, h3, h4, h5) < 0 then
			waterDistance[index] = 0
			queued = queued + 1
			heapIndex[queued] = index
		else
			waterDistance[index] = cellCount
		end
	end

	local head = 1
	while head <= queued do
		local index = heapIndex[head]
		head = head + 1
		local distance = waterDistance[index] + 1
		local col, row = (index - 1) % gridCols, math_floor((index - 1) / gridCols)
		for n = 1, 8 do
			---@diagnostic disable-next-line: need-check-nil -- OK: range is 1..8
			local ncol, nrow = col + neighbourCol[n], row + neighbourRow[n]
			if ncol >= 0 and ncol < gridCols and nrow >= 0 and nrow < gridRows then
				local nindex = nrow * gridCols + ncol + 1
				if waterDistance[nindex] > distance then
					waterDistance[nindex] = distance
					queued = queued + 1
					heapIndex[queued] = nindex
				end
			end
		end
	end
end

---A water reroute pays land costs at both ends to reach water, so when those two
---distances alone cover the direct distance, nothing can be gained via planning.
---
---This is, importantly, a constant-time operation to bound the reroute job cost.
local function mayGainFromWater(unitData, sx, sz, gx, gz)
	local dx, dz = gx - sx, gz - sz
	local direct = math_sqrt(dx * dx + dz * dz)
	if direct < unitData.minRouteLength then
		return false
	end
	local goalIndex = posToCell(gx, gz)
	local goalGround = spGetGroundHeight(gx, gz)
	local goalSlope = 0.0
	if goalGround >= 0 then
		local _, _, _, slope = spGetGroundNormal(gx, gz)
		goalSlope = slope or 0.0
	end
	if not terrainCost(unitData, goalGround, goalSlope) then
		return false
	end
	local land = waterDistance[posToCell(sx, sz)] + waterDistance[goalIndex] - 2
	return land * cellSize < direct
end

local function gridDistance(col, row)
	local dx = math_max(boxMinCol - col, col - boxMaxCol, 0)
	local dz = math_max(boxMinRow - row, row - boxMaxRow, 0)
	return math_sqrt(dx * dx + dz * dz) * cellSize
end

local function isClosed(index)
	return fieldStamp[index] == generation and heapPos[index] == 0
end

---Since reroutes are deferred/planned, the unit can move immediately along the engine's pathing.
---We refresh the job when reaching the unit to update its route, beginning with its start cells.
local function refreshStarts(burst)
	refreshTick = refreshTick + 1
	unsettled = 0
	boxMinCol, boxMaxCol, boxMinRow, boxMaxRow = gridCols, -1, gridRows, -1
	local jobs = burst.jobs
	for i = 1, #jobs do
		local job = jobs[i]
		if job.dropped then
			-- TODO: remove dropped jobs before here? or just let them clean up with the burst?
			-- TODO: how hard is reusing the pool, more or less, mid-burst?
			-- continue
		else
			local x, _, z = spGetUnitPosition(job.unitID)
			if not x then
				job.dropped = true
			else
				local index = posToCell(x, z)
				if not isClosed(index) and startStamp[index] ~= refreshTick then
					startStamp[index] = refreshTick
					unsettled = unsettled + 1
					local col, row = (index - 1) % gridCols, math_floor((index - 1) / gridCols)
					boxMinCol, boxMaxCol = math_min(boxMinCol, col), math_max(boxMaxCol, col)
					boxMinRow, boxMaxRow = math_min(boxMinRow, row), math_max(boxMaxRow, row)
				end
			end
		end
	end
end

---@return integer? samples Count of coarse samples spent, or nil for no job.
local function startSearch(burst)
	local jobs = burst.jobs
	local unitData = burst.unitData
	local count, meanX, meanZ = 0, 0.0, 0.0
	for i = 1, #jobs do
		local job = jobs[i]
		if not job.dropped then
			count = count + 1
			meanX, meanZ = meanX + job.gx, meanZ + job.gz
		end
	end
	if count == 0 then
		return nil
	end
	meanX, meanZ = meanX / count, meanZ / count -- bursts search once via centroid

	local source, nearest = 0, math_huge
	local bound, samples = 0.0, 0
	for i = 1, #jobs do
		local job = jobs[i]
		if not job.dropped then
			local x, _, z = spGetUnitPosition(job.unitID)
			if not x then
				job.dropped = true
			else
				local away = (job.gx - meanX) ^ 2 + (job.gz - meanZ) ^ 2
				if away < nearest then
					source, nearest = job.goalIndex, away
				end
				local direct, steps = coarseLineCost(unitData, x, z, job.gx, job.gz)
				samples = samples + steps
				bound = math_max(bound, direct)
			end
		end
	end
	if source == 0 then
		return nil
	end

	generation = generation + 1
	heapSize = 1
	fieldCost[source] = 0
	fieldParent[source] = 0
	fieldStamp[source] = generation
	heapUp(1, source, 0)

	burst.source = source
	burst.bound = bound * octileSlack + cellSize
	burst.expansions = 0
	burst.started = true
	return samples
end

---Increases the search region and sums the burst's costs until the search exhausts,
---the field outgrows the immediate per-frame budget, or the total budget runs out.
---@return boolean done
local function searchSlice(burst, budget)
	if not burst.started then
		local samples = startSearch(burst)
		if not samples then
			return true
		end
		budget = budget - samples
	end

	refreshStarts(burst)
	if unsettled == 0 then
		return true
	end

	local unitData = burst.unitData
	local bound = burst.bound
	local expansions = burst.expansions
	local before = expansions
	local limit = math_min(expansions + budget, burstBudgetTotal) ---@as integer
	local weight = routeBiasWeight -- extra added costs

	while heapSize > 0 and expansions < limit do
		expansions = expansions + 1
		local index = heapPop()
		if startStamp[index] == refreshTick then
			unsettled = unsettled - 1
			if unsettled == 0 then
				break
			end
		end

		---@diagnostic disable-next-line: need-check-nil -- OK: really is never nil
		local sliceCost = fieldCost[index]
		local cost = cellCost(unitData, index) or unitData.worst
		local col, row = (index - 1) % gridCols, math_floor((index - 1) / gridCols)
		for n = 1, 8 do
			---@diagnostic disable-next-line: need-check-nil -- OK: range is 1..8
			local ncol, nrow = col + neighbourCol[n], row + neighbourRow[n]
			if ncol >= 0 and ncol < gridCols and nrow >= 0 and nrow < gridRows then
				local nindex = nrow * gridCols + ncol + 1
				local updated = fieldStamp[nindex] == generation
				if not updated or heapPos[nindex] > 0 then
					local neighborCost = cellCost(unitData, nindex)
					if neighborCost then
						---@diagnostic disable-next-line: need-check-nil -- OK: range is 1..8
						local tentative = sliceCost + neighbourHalfLength[n] * (cost + neighborCost)
						if not updated or tentative < fieldCost[nindex] then
							local h = gridDistance(ncol, nrow)
							if tentative + h <= bound then
								fieldCost[nindex] = tentative
								fieldParent[nindex] = index
								if updated then
									heapUp(heapPos[nindex], nindex, tentative + weight * h)
								else
									fieldStamp[nindex] = generation
									heapSize = heapSize + 1
									heapUp(heapSize, nindex, tentative + weight * h)
								end
							end
						end
					end
				end
			end
		end
	end

	burst.expansions = expansions
	stats.expansions = stats.expansions + (expansions - before) ---@as integer
	return unsettled == 0 or heapSize == 0 or expansions >= burstBudgetTotal
end

---Copies each completed job's chain out of the shared field so the next burst can reuse it.
local function finishSearch(burst)
	local jobs = burst.jobs
	local any = false
	for i = 1, #jobs do
		local job = jobs[i]
		if not job.dropped then
			local x, _, z = spGetUnitPosition(job.unitID)
			local index = x and posToCell(x, z)
			if index and isClosed(index) then
				local path = {}
				while index ~= 0 do
					path[#path + 1] = index
					index = fieldParent[index]
				end
				job.path = path
				any = true
			else
				job.dropped = true
				stats.dropped = stats.dropped + 1
			end
		end
	end
	if any then
		burst.next = 1
		rerouteQueue[#rerouteQueue + 1] = burst
	end
end

---@return number[][] waypoints
local function getWaypoints(unitData, path, sx, sz, gx, gz)
	-- Build a path in a straight line and take its segment costs.
	local costTo = { [1] = 0.0 }
	for i = 2, #path do
		local ax, az = cellToPos(path[i - 1])
		local bx, bz = cellToPos(path[i])
		costTo[i] = costTo[i - 1] + coarseLineCost(unitData, ax, az, bx, bz)
	end

	-- Corners are the furthest point a straight segment reaches for a given cost.
	local corners = {}
	for i = 2, #path - 1 do
		if path[i] - path[i - 1] ~= path[i + 1] - path[i] then
			corners[#corners + 1] = i
		end
	end
	corners[#corners + 1] = #path

	local waypoints = {} ---@type number[][]
	local anchorX, anchorZ = sx, sz
	local anchorIndex = 1
	local firstIndex = 1
	while anchorIndex < #path do
		local best
		for j = #corners, firstIndex, -1 do
			local index = corners[j]
			if index > anchorIndex then
				local px, pz = cellToPos(path[index])
				if index == #path then
					px, pz = gx, gz
				end
				local costStraight = coarseLineCost(unitData, anchorX, anchorZ, px, pz)
				if costStraight <= costTo[index] - costTo[anchorIndex] + cellSize then
					best = j
					break
				end
			end
		end
		if not best then
			best = firstIndex
			while corners[best] <= anchorIndex do
				best = best + 1
			end
		end
		anchorIndex = corners[best]
		firstIndex = best + 1
		if anchorIndex < #path then
			anchorX, anchorZ = cellToPos(path[anchorIndex])
			waypoints[#waypoints + 1] = { anchorX, anchorZ }
		end
	end
	return waypoints
end

local readAs = { read = -1 }
local function readAsTeam(teamID, ...)
	readAs.read = teamID or -1
	return CallAsTeam(readAs, ...)
end

---@return number? x
---@return number? z
local function getOrderTargetPosition(cmdID, teamID, p1, p2, p3)
	if not routedOrders[cmdID] then
		return
	end
	if p3 then
		return p1, p3 -- TODO: not always right, there are other command shapes
	end
	if p1 and not p2 then
		local x, _, z = readAsTeam(teamID, spGetUnitPosition, p1)
		return x, z
	end
end

---Planning is done when the front command is the one recorded for the job (or an indistinguishable one).
---Deferred planning means the unit can have updates, new commands, a new queue, etc, so check all of it.
---@return boolean planned
local function planUnitRoute(burst, job, frame)
	local unitData = burst.unitData
	if frame - burst.frame > burstAgeFrames then
		stats.dropped = stats.dropped + 1
		return false
	end

	local path, goalID, unitID = job.path, job.goalIndex, job.unitID
	if not path or spGetUnitIsDead(unitID) ~= false then
		return false
	end

	local cmdID, cmdOpts, cmdTag, p1, p2, p3 = spGetUnitCurrentCommand(unitID)
	if not cmdID or not p1 then
		return false
	end
	local gx, gz = getOrderTargetPosition(cmdID, spGetUnitTeam(unitID), p1, p2, p3)
	if not gx or not gz then
		return false
	end

	local goalIndex = posToCell(gx, gz)
	local goalCol, goalRow = (goalIndex - 1) % gridCols, math_floor((goalIndex - 1) / gridCols)
	local jobCol, jobRow = (goalID - 1) % gridCols, math_floor((goalID - 1) / gridCols)
	if math_abs(goalCol - jobCol) > 1 or math_abs(goalRow - jobRow) > 1 then
		return false
	end

	local sx, _, sz = spGetUnitPosition(unitID)
	local waypoints = getWaypoints(unitData, path, sx, sz, gx, gz)

	-- ATTACK is Recoil's most special boy and causes no end of headache everywhere he goes.
	-- Remove waypoints from the end so a target that approaches the unit won't slip you by.
	if cmdID == CMD_ATTACK then
		local reach = unitData.range + 200 -- 200 from leash states and generally seems fine
		while #waypoints > 0 do
			local last = waypoints[#waypoints]
			if math_sqrt((last[1] - gx) ^ 2 + (last[2] - gz) ^ 2) > reach then
				break
			end
			waypoints[#waypoints] = nil
		end
	end
	if #waypoints == 0 then
		return false
	end

	local routeCost = 0.0
	local ax, az = sx, sz
	for i = 1, #waypoints do
		local wx, wz = waypoints[i][1], waypoints[i][2]
		routeCost = routeCost + fineLineCost(unitData, ax, az, wx, wz)
		ax, az = wx, wz
	end
	routeCost = routeCost + fineLineCost(unitData, ax, az, gx, gz)
	stats.verified = stats.verified + 1
	if routeCost + cellSize > fineLineCost(unitData, sx, sz, gx, gz) then
		return false
	end

	local waypointOrder = routedOrders[cmdID]
	local planned = {}
	rerouting = true
	for i = 1, #waypoints do
		local x, z = waypoints[i][1], waypoints[i][2]
		spGiveOrderToUnit(unitID, CMD_INSERT, { cmdTag, waypointOrder, cmdOpts, x, spGetGroundHeight(x, z), z }, 0)
		planned[#planned + 1] = x
		planned[#planned + 1] = z
	end
	rerouting = false
	plannedTag[unitID] = cmdTag
	plannedFrame[unitID] = frame
	plannedX[unitID] = gx
	plannedZ[unitID] = gz
	plannedWaypoints[unitID] = planned
	local tags = {}
	for i = 1, #waypoints do
		local _, _, tag = spGetUnitCurrentCommand(unitID, i)
		tags[i] = tag
	end
	waypointTag[unitID] = tags
	waypointIndex[unitID] = 1
	waypointRadius[unitID] = 2 * unitData.halfWidth * math_sqrt(#burst.jobs / math_pi) -- constant for now
	stats.inserted = stats.inserted + 1
	return true
end

---Check if a completed command was (very likely) a planned one. Perfection isn't needed here.
local function isPlannedWaypoint(unitID, p1, p3)
	local planned = plannedWaypoints[unitID]
	if not planned or not p3 then
		return false
	end
	for i = 1, #planned, 2 do
		if math_abs(planned[i] - p1) < 0.5 and math_abs(planned[i + 1] - p3) < 0.5 then
			return true
		end
	end
	return false
end

local function addRerouteJob(unitID, unitData, gx, gz, frame)
	local previous = unitJob[unitID]
	if previous then
		previous.dropped = true
	end

	local goalIndex = posToCell(gx, gz)
	local cluster = math_floor(math_floor((goalIndex - 1) / gridCols) / burstClusterSize) * clusterCols
		+ math_floor(((goalIndex - 1) % gridCols) / burstClusterSize)
	local hash = cluster * 65536 + unitData.defID -- unique per unitDefID, clusterID
	local burst = openBursts[hash]
	if not burst then
		if #openList + #searchQueue + #rerouteQueue >= routeQueueMax then
			stats.dropped = stats.dropped + 1
			return
		end
		burst = {
			key = hash,
			unitData = unitData,
			frame = frame,
			jobs = {},
			started = false,
			source = 0,
			bound = 0,
			expansions = 0,
			next = 0,
		}
		openBursts[hash] = burst
		openList[#openList + 1] = burst
		stats.bursts = stats.bursts + 1
	end

	local job = { unitID = unitID, gx = gx, gz = gz, goalIndex = goalIndex, dropped = false, path = false } ---@type RouteJob
	burst.jobs[#burst.jobs + 1] = job
	unitJob[unitID] = job
	stats.recorded = stats.recorded + 1
end

---All constant-time evaluation up to this point, with bounded time to accept or reject plans.
local function tryAddRouting(unitID, unitData, unitTeam, cmdID, p1, p2, p3)
	local gx, gz = getOrderTargetPosition(cmdID, unitTeam, p1, p2, p3)
	if not gx or not gz then
		return
	end
	local sx, _, sz = spGetUnitPosition(unitID)
	if not sx then
		return
	end
	if mayGainFromWater(unitData, sx, sz, gx, gz) then
		addRerouteJob(unitID, unitData, gx, gz, spGetGameFrame())
	else
		stats.rejected = stats.rejected + 1
	end
end

local function removeUnit(unitID)
	local job = unitJob[unitID]
	if job then
		job.dropped = true
		unitJob[unitID] = nil
	end
	plannedTag[unitID] = nil
	plannedFrame[unitID] = nil
	plannedX[unitID] = nil
	plannedZ[unitID] = nil
	plannedWaypoints[unitID] = nil
	waypointTag[unitID] = nil
	waypointIndex[unitID] = nil
	waypointRadius[unitID] = nil
end

local function closeBursts()
	for _, burst in ipairs(openList) do
		openBursts[burst.key] = nil
		searchQueue[#searchQueue + 1] = burst
	end
	for i = #openList, 1, -1 do
		openList[i] = nil
	end
end

local function trySkipWaypoint(unitID, index)
	local tags = waypointTag[unitID]
	local tag = tags and tags[index]
	if not tag then
		waypointIndex[unitID] = nil
		return
	end

	local planned = plannedWaypoints[unitID]
	local wx, wz = planned and planned[index * 2 - 1], planned and planned[index * 2]
	local x, _, z = spGetUnitPosition(unitID)
	if not x or not wx then
		return
	end

	local dx, dz = x - wx, z - wz
	local radius = waypointRadius[unitID] or 0.0 -- constant radius size for now, no impatience
	if dx * dx + dz * dz >= radius * radius then
		return
	end

	local tx, tz = planned[index * 2 + 1], planned[index * 2 + 2]
	if not tx then
		tx, tz = plannedX[unitID], plannedZ[unitID]
	end
	local unitData = tx and unitDefData[spGetUnitDefID(unitID)]
	if not unitData then
		return
	end

	if
		fineLineCost(unitData, x, z, tx, tz)
		> fineLineCost(unitData, x, z, wx, wz) + fineLineCost(unitData, wx, wz, tx, tz)
	then
		return -- Cutting a corner can reroute onto high-cost terrain. Avoid trying it.
	end

	local _, _, frontTag = spGetUnitCurrentCommand(unitID)
	if frontTag == tag then
		rerouting = true
		spGiveOrderToUnit(unitID, CMD_REMOVE, { tag }, 0)
		rerouting = false
		stats.abandoned = stats.abandoned + 1
	end
	waypointIndex[unitID] = index + 1
end
local function runWaypointImpatience()
	for unitID, index in pairs(waypointIndex) do
		trySkipWaypoint(unitID, index)
	end
end

local function runSearch(frame)
	local burst = searchQueue[1]
	if not burst then
		return
	end
	if frame - burst.frame > burstAgeFrames then
		table_remove(searchQueue, 1)
		stats.dropped = stats.dropped + 1
		return
	end
	if searchSlice(burst, searchBudgetSlice) then
		table_remove(searchQueue, 1)
		finishSearch(burst)
	end
end

local function runReroute(frame)
	local burst = rerouteQueue[1]
	local planned = 0
	while burst and planned < routeUnitBudget do
		local job = burst.jobs[burst.next]
		if not job then
			table_remove(rerouteQueue, 1)
			burst = rerouteQueue[1]
		else
			burst.next = burst.next + 1
			if not job.dropped then
				planUnitRoute(burst, job, frame)
				planned = planned + 1
			end
			if unitJob[job.unitID] == job then
				unitJob[job.unitID] = nil
			end
		end
	end
end

-- Engine callins --------------------------------------------------------------

function gadget:GameFrame(frame)
	if frame % slowUpdateFrames == 0 then
		slowUpdate()
	end
	if frame % fastUpdateFrames == 0 then
		fastUpdate()
	end

	closeBursts()
	runSearch(frame)
	runReroute(frame)
	if frame % Game.gameSpeed == 0 then
		runWaypointImpatience()
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local unitData = unitDefData[unitDefID]
	if unitData and getUnitDepth(unitID) <= 0 then
		if canSetSpeed(unitID) then
			applySpeed(unitID, unitData)
		end
		if unitData.speedFactorAtDepth ~= 0 then
			unitDepthFastUpdate[unitID] = unitData
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	unitDepthSlowUpdate[unitID] = nil
	unitDepthFastUpdate[unitID] = nil
	removeUnit(unitID)
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	removeUnit(unitID)
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	local unitData = unitDefData[unitDefID]
	if unitData then
		if canSetSpeed(unitID) then
			applySpeed(unitID, unitData)
		end
		if unitData.speedFactorAtDepth ~= 0 then
			unitDepthFastUpdate[unitID] = unitData
		end
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	local unitData = unitDefData[unitDefID]
	if unitData then
		if canSetSpeed(unitID) then
			applySpeed(unitID, unitData, 1)
		end
		unitDepthSlowUpdate[unitID] = nil
		unitDepthFastUpdate[unitID] = nil
	end
end

function gadget:AllowCommand(
	unitID,
	unitDefID,
	unitTeam,
	cmdID,
	cmdParams,
	cmdOpts,
	cmdTag,
	playerID,
	fromSynced,
	fromLua,
	fromInsert
)
	if rerouting then
		return true
	end
	local unitData = unitDefData[unitDefID]
	if not unitData or not routedOrders[cmdID] then
		return true
	end

	local isFirstCommand
	if fromInsert then
		if spGetUnitCommandCount(unitID) == 0 then
			isFirstCommand = true
		elseif fromInsert.alt then
			isFirstCommand = cmdTag == 0
		else
			local _, _, inTag = spGetUnitCurrentCommand(unitID)
			isFirstCommand = inTag == cmdTag and not fromInsert.right
		end
	else
		isFirstCommand = not cmdOpts.shift or spGetUnitCommandCount(unitID) == 0
	end
	if isFirstCommand then
		tryAddRouting(unitID, unitData, unitTeam, cmdID, cmdParams[1], cmdParams[2], cmdParams[3])
	end
	return true
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if rerouting then
		return
	end
	local unitData = unitDefData[unitDefID]
	if not unitData then
		return
	end
	local inCommand, _, inTag, p1, p2, p3 = spGetUnitCurrentCommand(unitID)
	-- An insert to the front passes the displaced command as the done command while it is still first.
	if not inCommand or inTag == cmdTag or not routedOrders[inCommand] then
		return
	end
	if inTag == plannedTag[unitID] then
		local gx, gz = getOrderTargetPosition(inCommand, unitTeam, p1, p2, p3)
		if not gx or not gz then
			return
		end
		local moved = math_abs(gx - plannedX[unitID]) > cellSize or math_abs(gz - plannedZ[unitID]) > cellSize
		if not moved or spGetGameFrame() - plannedFrame[unitID] < cooldownFrames then
			return
		end
	end
	if isPlannedWaypoint(unitID, p1, p3) then
		return
	end
	tryAddRouting(unitID, unitData, unitTeam, inCommand, p1, p2, p3)
end

function gadget:TerraformComplete(unitID, unitDefID, unitTeam, buildUnitID, buildUnitDefID, buildUnitTeam)
	local x, _, z = spGetUnitPosition(buildUnitID)
	local buildDef = UnitDefs[buildUnitDefID]
	if not x or not buildDef then
		return false
	end
	local halfX, halfZ = buildDef.xsize * 4 + cellSize, buildDef.zsize * 4 + cellSize
	local colMin = math_clamp(math_floor((x - halfX) / cellSize), 0, gridCols - 1)
	local colMax = math_clamp(math_floor((x + halfX) / cellSize), 0, gridCols - 1)
	local rowMin = math_clamp(math_floor((z - halfZ) / cellSize), 0, gridRows - 1)
	local rowMax = math_clamp(math_floor((z + halfZ) / cellSize), 0, gridRows - 1)
	for row = rowMin, rowMax do
		for col = colMin, colMax do
			terrainCode[row * gridCols + col + 1] = 0
		end
	end
	return false
end

function gadget:Initialize()
	if not next(unitDefData) then
		gadgetHandler:RemoveGadget()
		return
	end

	for i = 1, cellCount do
		terrainCode[i] = 0
		waterDistance[i] = 0
		fieldCost[i] = 0
		fieldParent[i] = 0
		fieldStamp[i] = 0
		startStamp[i] = 0
		heapPos[i] = 0
		heapIndex[i] = 0
		heapScore[i] = 0
	end
	populateWaterDistances()
	GG.WaterRoutingStats = stats

	-- The engine sets two orders on Patrol routes that we can only track through UnitCmdDone.
	for cmdID in pairs(routedOrders) do
		if cmdID ~= CMD_PATROL then
			gadgetHandler:RegisterAllowCommand(cmdID)
		end
	end

	local unitFinished = gadget.UnitFinished
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		unitFinished(gadget, unitID, Spring.GetUnitDefID(unitID), 0)
	end
end
