local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Surfboxes (Unit Volumes)",
		desc    = "Allows units to be hit by impact-only weapons in water even when submerged",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 1, -- after unit_dynamic_collision_volume.lua
		enabled = true, -- Spring.GetModOptions().experimental_unit_surfboxes,
	}
end

-- Configuration

---@type number Max unit height/water depth for dynamic surfboxes.
local waterDepthMax = 24
---@type number Time between updates, in seconds.
local updateTime = 0.25

-- Debugging surfbox depth for maps

if not gadgetHandler:IsSyncedCode() then
	local DEBUG_MAX_WATER_DEPTH = false

	if not DEBUG_MAX_WATER_DEPTH then
		return
	end

	local GL = GL
	local gl = gl
	local sin, cos = math.sin, math.cos

	local cx = Game.mapSizeX * 0.5
	local cy = waterDepthMax * -1
	local cz = Game.mapSizeZ * 0.5
	local cr = math.hypot(cx, cz) * 1.05
	local segments = 32
	local angleStep = math.tau / segments
	local color = { 1, 0.2, 0.7, 0.8 } -- bright pink

	local function __FilledCircle()
		gl.Color(color[1], color[2], color[3], color[4])
		gl.Vertex(cx, cy, cz)
		for i = 0, segments do
			gl.Color(color[1], color[2], color[3], color[4])
			gl.Vertex(cx + cos(i * angleStep) * cr, cy, cz + sin(i * angleStep) * cr)
		end
	end

	local function DrawFilledCircle()
		gl.DepthTest(true)
		gl.BeginEnd(GL.TRIANGLE_FAN, __FilledCircle)
	end

	gadget.DrawWorldPreUnit = DrawFilledCircle

	return
end

-- Globals

local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp

local spGetUnitHeight = Spring.GetUnitHeight
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDirection = Spring.GetUnitDirection
local spGetUnitCollisionVolumeData = Spring.GetUnitCollisionVolumeData
local spSetUnitCollisionVolumeData = Spring.SetUnitCollisionVolumeData
local spSetUnitMidAndAimPos = Spring.SetUnitMidAndAimPos

-- Local state

local updateFrames = math_clamp(math.round(updateTime * Game.gameSpeed), 1, Game.gameSpeed)

local surfHeight = 0 -- minimum elevation that colliders try to maintain
do
	local waterLevel = Spring.GetWaterPlaneLevel()
	local unitSpeedFast = 100 -- some typical but quick unit speed
	local waterSlowdown = 0.27 -- just eyeballing it here
	local shoreIncline = 22 -- natural coasts are ~4 to ~22 degrees
	local heightChangeMax = unitSpeedFast * (1 - waterSlowdown) * math.sin(math.rad(shoreIncline)) * updateTime
	-- We partly compensate for inclines with unit tilt math later, so cut in half, but also add a nudge.
	surfHeight = waterLevel + heightChangeMax * 0.5 + 0.5
end

-- Inflates a bounded ellipsoid to match its bounding shape's surface and volume.
local inflateRatios = {
	--[[ ellipsoid ]] [0] = 1,
	--[[ cylinder  ]] [1] = 1.25,
	--[[ box       ]] [2] = 1.455,
	--[[ sphere    ]] [3] = 1,
	--[[ footprint ]] [4] = 1, -- as sphere
}

local canSurf = table.new(#UnitDefs, 0)
do
	local function isValidSurfDef(unitDef)
		local is = unitDef.modCategories
		return not (is.ship or is.hover or is.vtol or is.underwater) and not is.canbeuw
	end

	local function needsSurfbox(unitDef)
		return unitDef.moveDef and unitDef.moveDef.depth >= math.max(unitDef.height * 0.6, 1)
	end

	local function isSupported(unitDef)
		return not unitCollisionVolume[unitDef.name]
			and not pieceCollisionVolume[unitDef.name]
			and not dynamicPieceCollisionVolume[unitDef.name]
	end

	local useCustomUnitSet = false

	for unitDefID, unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.has_surfing_colvol then
			useCustomUnitSet = true
			if isValidSurfDef(unitDef) and isSupported(unitDef) then
				Spring.Log("SurfBox", LOG.INFO, "Unit assigned an ordinary surfbox: " .. unitDef.name)
			else
				Spring.Log("SurfBox", LOG.WARNING, "Unit given an abnormal surfbox: " .. unitDef.name)
			end
			canSurf[unitDefID] = true
		else
			canSurf[unitDefID] = false
		end
	end

	if not useCustomUnitSet then
		for unitDefID, unitDef in ipairs(UnitDefs) do
			canSurf[unitDefID] = isValidSurfDef(unitDef) and needsSurfbox(unitDef) and isSupported(unitDef)
		end
	end
end

local surferUnitData = {} -- { volume, position }
local surferDefData = {}  -- caches the unit data
local surfersInWater = {} -- units that are being watched
local isUsingSurfbox = {} -- units with a modified collider

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
	return mx, my, mz, ax, ay, az, true
end

local getCollisionVolumeConfig
do
	local unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume = include("LuaRules/Configs/CollisionVolumes.lua")

	---Unified output data format for our various collision volumes.
	---@alias UnitCollisionVolume ColVolOnOffMap|ColVolPieceList|ColVolDynamicPieceList

	---@class ColVolOnOffMap
	---@field on ColVolConfigData|ColVolPieceList
	---@field off ColVolConfigData|ColVolPieceList

	---@class ColVolPieceList
	---@field [UnitPieceKey] ColVolConfigData Numeric string keys "0"..."65535"

	---@class ColVolDynamicPieceList
	---@field [UnitPieceKey] ColVolConfigData Numeric string keys "0"..."65535"
	---@field offsets float3

	---@alias UnitPieceKey "0"|"1"|"2"|"3"|...|"65536"

	---@class ColVolConfigData
	---@field [1] number? scaleX
	---@field [2] number? scaleY
	---@field [3] number? scaleZ
	---@field [4] number? offsetX
	---@field [5] number? offsetY
	---@field [6] number? offsetZ
	---@field [7] 0|1|2|3? volumeType
	---@field [8] boolean? useContinuousHitTest
	---@field [9] 0|1|2? primaryAxis not used in configs

	---@type (ColVolOnOffMap|ColVolPieceList|ColVolDynamicPieceList)[]
	local configs = { unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume }

	local function isColVolData(a)
		-- NB: This data isn't regularized. This is a reasonable view of them:
		return (a[1] and a[2] and a[3]) or (a[4] and a[5] and a[6]) or a[7] or a[8] or a[9] -- 10 unused
	end

	local function isOnOffMap(t)
		return t.on and t.off and true or false
	end

	local function isPieceList(tbl)
		local noBadKeys = true
		for key in pairs(tbl) do
			local num = tonumber(key)
			if not num then
				noBadKeys = noBadKeys and key == "offsets"
			elseif type(key) ~= "string" then
				noBadKeys = false
			elseif num ~= math.clamp(num, 0, 65535) then
				noBadKeys = false
			elseif num ~= math.round(num) then
				noBadKeys = false
			end
		end
		return noBadKeys
	end

	---@return ColVolConfigData
	local function toVolumeData(tbl)
		local out = table.new(8, 0) -- still not including 9 and 10
		for i = 1, 8 do
			out[i] = tbl[i] or 0 -- regularize
		end
		return out
	end

	---@return ColVolPieceList|ColVolDynamicPieceList
	local function toPieceList(tbl)
		local out = {}
		for k, v in pairs(tbl) do
			if type(k) == "string" and tonumber(k) then
				out[k] = toVolumeData(v)
			end
		end
		if tbl.offsets then
			out.offsets = tbl.offsets
		end
		return out
	end

	---@param unitName string
	---@return UnitCollisionVolume?
	getCollisionVolumeConfig = function(unitName)
		local data

		for _, tbl in ipairs(configs) do
			if not data then
				data = tbl[unitName]
			elseif tbl[unitName] then
				Spring.Log("SurfBox", LOG.ERROR, "Unit with multiple colvol configs found.")
			end
		end

		if not data then
			return
		end

		if isOnOffMap(data) then
			local out = {}
			local onVal = data.on
			local offVal = data.off
			out.on = isPieceList(onVal) and toPieceList(onVal) or toVolumeData(onVal)
			out.off = isPieceList(offVal) and toPieceList(offVal) or toVolumeData(offVal)
			return out
		elseif isPieceList(data) then
			return toPieceList(data)
		elseif isColVolData(data) then
			return -- { unit = toVolumeData(data) } -- there is no point to this
		else
			Spring.Log("SurfBox", LOG.ERROR, "Malformed colvol data found.")
		end
	end
end

local function getUnitData(unitID, unitDefID)
	local data = surferDefData[unitDefID]
	if not data then
		data = {
			position = { calculateUnitMidAndAimPos(unitID) },
			volume   = { spGetUnitCollisionVolumeData(unitID) },
			custom   = getCollisionVolumeConfig(UnitDefs[unitDefID].name),
		}
		surferDefData[unitDefID] = data
	end
	return data
end

local function restoreVolume(unitID, data)
	if not data then
		data = surferUnitData[unitID]
		if not data then
			return
		end
	end
	spSetUnitCollisionVolumeData(unitID, unpack(data.volume))
	spSetUnitMidAndAimPos(unitID, unpack(data.position))
end

-- Surfboxes raise collision volumes to just above the water level so units that are
-- able to traverse water deeper than their own height can be attacked and destroyed.
local function surf(unitID)
	local hasSurfbox = isUsingSurfbox[unitID]
	local data = surferUnitData[unitID]
	local volume = data.volume
	local unitOffset = volume[5]
	local unitHeight = spGetUnitHeight(unitID)
	local ux, uy, uz = spGetUnitPosition(unitID)

	if uy < -waterDepthMax or uy + unitOffset + unitHeight >= surfHeight + (hasSurfbox and 1 or -1) then
		if hasSurfbox then
			isUsingSurfbox[unitID] = nil
			restoreVolume(unitID, data)
		end
		return
	elseif not hasSurfbox then
		isUsingSurfbox[unitID] = true
	end

	local _, _, _, _, _, _, _, upward = spGetUnitDirection(unitID)
	upward = math_clamp(upward, 0.3333, 1)
	local height = unitHeight / upward

	-- New offset needed for the collision volume to reach the surf[ace] height.
	local yOffset = surfHeight - height - uy

	-- Split the difference between stretching the volume and lifting it up, with
	-- the goal of maintaining multiple, but much smaller, deltas in the result..
	local stretch = (1 + (yOffset - unitOffset) / unitHeight) * 0.5

	if stretch > 1 then
		yOffset = (yOffset + unitOffset) * 0.5 -- ...else this value can be large.
	else
		stretch = 1
	end

	-- The ellipsoid is a more tight-fitting shape so we increase its dimensions.
	local shapeDimensionRatio = inflateRatios[volume[7]]

	local ratioX = shapeDimensionRatio
	local ratioY = shapeDimensionRatio * stretch
	local ratioZ = shapeDimensionRatio

	local minXYZ = math_min(volume[1], volume[2], volume[3])
	local maxXZ = math_max(volume[1], volume[3])

	-- Prevent misses when targeting the collider's near border by exchanging some
	-- of the shape's eccentricity in the XZ axes with its Y axis (in unit space).
	if maxXZ / minXYZ > 1.25 then
		-- Exchange less eccentricity between axes as the unit tilts more.
		ratioX = ratioX / (1 + (volume[1] / minXYZ - 0.5) * 0.30 * upward)
		local rateY = 1 / (1 - (volume[2] / minXYZ - 0.5) * 0.23 * upward) -- not symmetrical
		ratioZ = ratioZ / (1 + (volume[3] / minXYZ - 0.5) * 0.30 * upward)
		ratioY = ratioY * rateY
		yOffset = yOffset + (rateY * rateY - rateY) * (unitHeight * 0.5) -- less lift
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
		position[5] + yOffset * 0.5, -- keep aim point close to the model to "look right"
		position[6],
		true
	)
end

-- Engine events

function gadget:Initialize()
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
		for unitID in pairs(surfersInWater) do
			surf(unitID)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if canSurf[unitDefID] then
		surferUnitData[unitID] = getUnitData(unitID, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	surferUnitData[unitID] = nil
	surfersInWater[unitID] = nil
	isUsingSurfbox[unitID] = nil
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if surferUnitData[unitID] then
		surfersInWater[unitID] = true
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if surfersInWater[unitID] then
		surfersInWater[unitID] = nil

		if isUsingSurfbox[unitID] then
			isUsingSurfbox[unitID] = nil
			restoreVolume(unitID)
		end
	end
end
