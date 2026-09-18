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

-- Configuration

local depthUpdateRate = 0.2500 ---@type number in seconds | for units with speeds variable by water depth
local watchUpdateRate = 0.5000 ---@type number in seconds | slow watch interval for variable-speed units

-- Globals

local math_clamp = math.clamp
local math_floor = math.floor
local math_sqrt = math.sqrt
local math_max = math.max
local math_min = math.min

local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitCommands = Spring.GetUnitCommands
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundNormal = Spring.GetGroundNormal
local spGetMoveTypeData = Spring.GetUnitMoveTypeData
local spSetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit

local CMD_MOVE = CMD.MOVE
local CMD_OPT_SHIFT = CMD.OPT_SHIFT

local SM_CLASS_HOVER = 2
local SM_CLASS_SHIP = 3

-- Setup

local unitDefData = {}

local function canHaveGroundMoveType(unitDef)
	-- I think you are not supposed to be able to set a moveDef on air or immobile units,
	-- but I think you can MoveCtrl.Enable, then MoveCtrl.SetMoveDef, to get around this.
	return true -- so, lol
end

for defID, ud in pairs(UnitDefs) do
	local params = ud.customParams

	local speedFactorInWater = tonumber(params.speedfactorinwater or 1) or 1
	local speedFactorAtDepth = math.abs(params.speedfactoratdepth and tonumber(params.speedfactoratdepth) or 0) * -1

	if speedFactorInWater ~= 1 and canHaveGroundMoveType(ud) then
		if speedFactorAtDepth > -1 then
			speedFactorAtDepth = 0
		end

		local moveDef = ud.moveDef

		unitDefData[defID] = {
			speedFactorInWater = speedFactorInWater,
			speedFactorAtDepth = speedFactorAtDepth,

			speed = ud.speed,
			turn = ud.turnRate,
			acc = ud.maxAcc,
			dec = ud.maxDec,

			moveClass = moveDef and moveDef.smClass,
			moveDepth = moveDef and moveDef.depth or 0,
			maxSlope = moveDef and moveDef.maxSlope or 0,
			slopeMod = moveDef and moveDef.slopeMod or 0,
			width = moveDef and moveDef.xsize * 8 or 0,
			routeCosts = {},
		}
	end
end

local unitDepthSlowUpdate = {}
local unitDepthFastUpdate = {}
local slowUpdateFrames = math.round(watchUpdateRate * Game.gameSpeed)
local fastUpdateFrames = math.round(depthUpdateRate * Game.gameSpeed)

---@type GroundMoveType
local moveTypeData = {
	maxSpeed = 0,
	maxWantedSpeed = 0,
	turnRate = 0,
	accRate = 0,
	decRate = 0,
}

local squareSize = Game.squareSize or 8.0
do
	local narrowest = math.huge
	for _, unitData in pairs(unitDefData) do
		if unitData.moveClass and unitData.width > 0 then
			narrowest = math_min(narrowest, unitData.width)
		end
	end
	if narrowest < math.huge then
		squareSize = 2 ^ math_floor(math.log(narrowest) / math.log(2))
	end
end
local gridCols = math.ceil(Game.mapSizeX / squareSize)
local gridRows = math.ceil(Game.mapSizeZ / squareSize)
local cellGround = {}
local cellSlope = {}

local routeMemo = {}
local rerouting = false

-- Local functions

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

---@return number factor The unit class's speed at this ground height relative to its land speed.
local function factorAtElevation(unitData, ground)
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
	setMoveTypeData(unitID, unitData, factor or factorAtElevation(unitData, getUnitDepth(unitID)))
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

local function cellGroundAt(index)
	local ground = cellGround[index]
	if ground then
		return ground, cellSlope[index]
	end
	local half, quarter = squareSize / 2, squareSize / 4
	local x = (index % gridCols) * squareSize + half
	local z = math_floor(index / gridCols) * squareSize + half
	ground = math_max(
		spGetGroundHeight(x, z),
		spGetGroundHeight(x - quarter, z - quarter),
		spGetGroundHeight(x + quarter, z - quarter),
		spGetGroundHeight(x - quarter, z + quarter),
		spGetGroundHeight(x + quarter, z + quarter)
	)
	local _, _, _, slope = spGetGroundNormal(x, z)
	cellGround[index] = ground
	cellSlope[index] = slope or 0
	return ground, cellSlope[index]
end

---Time per elmo relative to the class's fastest medium. The cheapest cell costs 1.
local function cellCost(unitData, index)
	local costs = unitData.routeCosts
	local cost = costs[index]
	if cost ~= nil then
		return cost
	end
	local ground, slope = cellGroundAt(index)
	local top = math_max(1, unitData.speedFactorInWater)
	local class = unitData.moveClass
	if ground < 0 then
		if class == SM_CLASS_SHIP then
			cost = -ground >= unitData.moveDepth and top / factorAtElevation(unitData, ground) or false
		elseif class == SM_CLASS_HOVER or -ground <= unitData.moveDepth then
			cost = top / factorAtElevation(unitData, ground)
		else
			cost = false
		end
	else
		if class == SM_CLASS_SHIP or slope > unitData.maxSlope then
			cost = false
		else
			cost = top * (1 + slope * unitData.slopeMod)
		end
	end
	costs[index] = cost
	return cost
end

---Impassable cells get the worst-possible cost, same as how the engine reroutes.
---@return number
local function segmentCost(unitData, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local length = math_sqrt(dx * dx + dz * dz)
	local steps = math_max(1, math.ceil(length / (squareSize / 2)))
	local worst = math_max(1, unitData.speedFactorInWater) * (1 + unitData.maxSlope * unitData.slopeMod)
	local total = 0
	for i = 0, steps do
		local t = i / steps
		local col = math_clamp(math_floor((ax + dx * t) / squareSize), 0, gridCols - 1)
		local row = math_clamp(math_floor((az + dz * t) / squareSize), 0, gridRows - 1)
		local cost = cellCost(unitData, row * gridCols + col) or worst
		total = total + cost * ((i == 0 or i == steps) and 0.5 or 1)
	end
	return total * (length / steps)
end

local openIndex = {}
local openScore = {}

local function heapPush(index, score)
	local n = #openIndex + 1
	openIndex[n], openScore[n] = index, score
	while n > 1 do
		local parent = math_floor(n / 2)
		if openScore[parent] <= score then
			break
		end
		openIndex[n], openScore[n] = openIndex[parent], openScore[parent]
		openIndex[parent], openScore[parent] = index, score
		n = parent
	end
end

local function heapPop()
	local n = #openIndex
	local index, score = openIndex[1], openScore[1]
	openIndex[1], openScore[1] = openIndex[n], openScore[n]
	openIndex[n], openScore[n] = nil, nil
	n = n - 1
	local i = 1
	while true do
		local left, right = i * 2, i * 2 + 1
		local smallest = i
		if left <= n and openScore[left] < openScore[smallest] then
			smallest = left
		end
		if right <= n and openScore[right] < openScore[smallest] then
			smallest = right
		end
		if smallest == i then
			break
		end
		openIndex[i], openScore[i], openIndex[smallest], openScore[smallest] =
			openIndex[smallest], openScore[smallest], openIndex[i], openScore[i]
		i = smallest
	end
	return index, score
end

local neighbourCol = { 1, -1, 0, 0, 1, 1, -1, -1 }
local neighbourRow = { 0, 0, 1, -1, 1, -1, 1, -1 }
local neighbourLength = { 1, 1, 1, 1, math_sqrt(2), math_sqrt(2), math_sqrt(2), math_sqrt(2) }

---A* over the cells, bounded by the cost of the direct order, so the search
---is confined to the ellipse where an improvement _can_ exist to begin with.
---@return integer[]? path Cell indices from start to goal (or nil)
---@return number cost
local function searchRoute(unitData, startIndex, goalIndex, bound)
	local goalCol, goalRow = goalIndex % gridCols, math_floor(goalIndex / gridCols)

	local gScore = { [startIndex] = 0 }
	local cameFrom = {}
	local closed = {}
	for i = #openIndex, 1, -1 do
		openIndex[i], openScore[i] = nil, nil
	end
	heapPush(startIndex, 0)

	while #openIndex > 0 do
		local index = heapPop()
		if index == goalIndex then
			local path = {}
			while index do
				path[#path + 1] = index
				index = cameFrom[index]
			end
			for i = 1, math_floor(#path / 2) do
				path[i], path[#path + 1 - i] = path[#path + 1 - i], path[i]
			end
			return path, gScore[goalIndex]
		end
		if not closed[index] then
			closed[index] = true
			local col, row = index % gridCols, math_floor(index / gridCols)
			local here = cellCost(unitData, index) or 0
			for n = 1, 8 do
				---@diagnostic disable-next-line: need-check-nil -- OK: range is 1..8
				local ncol, nrow = col + neighbourCol[n], row + neighbourRow[n]
				if ncol >= 0 and ncol < gridCols and nrow >= 0 and nrow < gridRows then
					local nindex = nrow * gridCols + ncol
					local there = cellCost(unitData, nindex)
					if there and not closed[nindex] then
						local tentative = gScore[index] + neighbourLength[n] * squareSize * (here + there) / 2
						if tentative < (gScore[nindex] or math.huge) then
							local hx, hz = (goalCol - ncol) * squareSize, (goalRow - nrow) * squareSize
							local estimate = tentative + math_sqrt(hx * hx + hz * hz)
							if estimate < bound then
								gScore[nindex] = tentative
								cameFrom[nindex] = index
								heapPush(nindex, estimate)
							end
						end
					end
				end
			end
		end
	end
	return nil, math.huge
end

local function center(index)
	return (index % gridCols) * squareSize + squareSize / 2, math_floor(index / gridCols) * squareSize + squareSize / 2
end

---Corners are the furthest point a straight segment reaches for a given cost.
local function pullWaypoints(unitData, path, sx, sz, gx, gz)
	local costTo = { [1] = 0.0 }
	for i = 2, #path do
		local ax, az = center(path[i - 1])
		local bx, bz = center(path[i])
		costTo[i] = costTo[i - 1] + segmentCost(unitData, ax, az, bx, bz)
	end
	local corners = {}
	for i = 2, #path - 1 do
		if path[i] - path[i - 1] ~= path[i + 1] - path[i] then
			corners[#corners + 1] = i
		end
	end
	corners[#corners + 1] = #path

	local waypoints = {}
	local anchorX, anchorZ = sx, sz
	local anchorAt = 1
	local first = 1
	while anchorAt < #path do
		local chosen
		for j = #corners, first, -1 do
			local at = corners[j]
			if at > anchorAt then
				local px, pz = center(path[at])
				if at == #path then
					px, pz = gx, gz
				end
				local straight = segmentCost(unitData, anchorX, anchorZ, px, pz)
				if straight <= costTo[at] - costTo[anchorAt] + squareSize then
					chosen = j
					break
				end
			end
		end
		if not chosen then
			chosen = first
			while corners[chosen] <= anchorAt do
				chosen = chosen + 1
			end
		end
		anchorAt = corners[chosen]
		first = chosen + 1
		if anchorAt < #path then
			anchorX, anchorZ = center(path[anchorAt])
			waypoints[#waypoints + 1] = { anchorX, anchorZ }
		end
	end
	return waypoints
end

---@return table[]|false waypoints Positions to visit before the goal (or `false` when not rerouting)
local function routeWaypoints(unitData, sx, sz, gx, gz)
	local startIndex = math_clamp(math_floor(sz / squareSize), 0, gridRows - 1) * gridCols
		+ math_clamp(math_floor(sx / squareSize), 0, gridCols - 1)
	local goalIndex = math_clamp(math_floor(gz / squareSize), 0, gridRows - 1) * gridCols
		+ math_clamp(math_floor(gx / squareSize), 0, gridCols - 1)
	if startIndex == goalIndex then
		return false
	end

	local key = unitData.routeCosts
	local memo = routeMemo[key]
	if not memo then
		memo = {}
		routeMemo[key] = memo
	end
	local memoKey = startIndex * gridCols * gridRows + goalIndex
	local known = memo[memoKey]
	if known ~= nil then
		return known
	end

	local direct = segmentCost(unitData, sx, sz, gx, gz)
	local path = searchRoute(unitData, startIndex, goalIndex, direct - squareSize)
	local waypoints = false ---@as false|table
	if path then
		waypoints = pullWaypoints(unitData, path, sx, sz, gx, gz)
		if #waypoints == 0 then
			waypoints = false
		end
	end
	memo[memoKey] = waypoints
	return waypoints
end

---A queued order starts where the order before it ends, if that one has a position.
local function positionAfterLastCommand(unitID, queued)
	if queued then
		local commands = spGetUnitCommands(unitID, -1)
		for i = #commands, 1, -1 do
			local params = commands[i].params
			if #params >= 3 then
				return params[1], params[3]
			end
		end
	end
	local x, _, z = spGetUnitPosition(unitID)
	return x, z
end

-- Engine callins

function gadget:GameFrame(frame)
	if frame % slowUpdateFrames == 0 then
		slowUpdate()
	end
	if frame % fastUpdateFrames == 0 then
		fastUpdate()
	end
	if next(routeMemo) then
		routeMemo = {}
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
	fromLua
)
	-- Accepts only CMD.MOVE.
	if rerouting or #cmdParams < 3 or cmdOpts.meta then
		return true
	end
	local unitData = unitDefData[unitDefID]
	if not unitData or not unitData.moveClass then
		return true
	end

	-- Not handling any fancy inserts yet:
	local sx, sz = positionAfterLastCommand(unitID, cmdOpts.shift)
	if not sx then
		return true
	end
	local waypoints = routeWaypoints(unitData, sx, sz, cmdParams[1], cmdParams[3])
	if not waypoints then
		return true
	end

	local firstOptions = cmdOpts.coded
	local laterOptions = firstOptions + (cmdOpts.shift and 0 or CMD_OPT_SHIFT)
	local orders = {}
	for i = 1, #waypoints do
		local x, z = waypoints[i][1], waypoints[i][2]
		orders[i] = { CMD_MOVE, { x, spGetGroundHeight(x, z), z }, i == 1 and firstOptions or laterOptions }
	end
	orders[#orders + 1] = { CMD_MOVE, cmdParams, laterOptions }

	rerouting = true
	spGiveOrderArrayToUnit(unitID, orders)
	rerouting = false

	return false
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

function gadget:Initialize()
	if not next(unitDefData) then
		gadgetHandler:RemoveGadget()
		return
	end

	gadgetHandler:RegisterAllowCommand(CMD_MOVE)

	local unitFinished = gadget.UnitFinished
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		unitFinished(gadget, unitID, Spring.GetUnitDefID(unitID), 0)
	end
end
