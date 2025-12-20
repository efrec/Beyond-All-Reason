local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Dynamic Surfboxes",
		desc    = "Allows units to be hit by impact-only weapons in water even when submerged",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 10, -- after unit_dynamic_collision_volume.lua
		enabled = true, -- Spring.GetModOptions().experimental_unit_surfboxes,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- Configuration

---@type number Max unit height/water depth for dynamic surfboxes.
local waterDepthMax = Spring.GetModOptions().proposed_unit_reworks and 20 or 22 -- default maximum for land units
---@type number Time between updates, in seconds.
local updateTime = 0.3333

local debug = false

-- Globals

local math_abs = math.abs
local math_min = math.min
local math_clamp = math.clamp

local spGetUnitArmored = Spring.GetUnitArmored
local spGetUnitHeight = Spring.GetUnitHeight
local spGetUnitPosition = Spring.GetUnitPosition

local spSetUnitCollisionVolumeData = Spring.SetUnitCollisionVolumeData
local spSetUnitMidAndAimPos = Spring.SetUnitMidAndAimPos

local worldToUnitBasis, unitToWorldBasis = GG.WorldToUnitBasis, GG.UnitToWorldBasis
local worldToPieceBasis, pieceToWorldBasis = GG.WorldToPieceBasis, GG.PieceToWorldBasis

-- Local state

-- Since map square traversability uses strange rules and some rounding.
-- This is only used to do a bit less work so the number doesn't matter.
waterDepthMax = waterDepthMax + 4

local updateFrames = math_clamp(math.round(updateTime * Game.gameSpeed), 1, Game.gameSpeed)

local surfHeight = 0 -- minimum elevation that colliders try to maintain
do
	local waterLevel = Spring.GetWaterPlaneLevel()
	local unitSpeedFast = 100 -- some typical but quick unit speed
	local waterSlowdown = 0.27 -- just eyeballing it here
	local shoreIncline = math.rad(22) -- natural coasts are ~4 to ~22 degrees
	local heightChangeMax = unitSpeedFast * math.sin(shoreIncline) * (1 - waterSlowdown) * updateTime
	surfHeight = waterLevel + heightChangeMax * 0.5 + 0.5
end

-- Inflates a bounded ellipsoid to match its bounding shape's surface and volume.
local inflateRatios = {
	--[[ cylinder  ]] 1.25,
	--[[ box       ]] 1.455,
	--[[ sphere    ]] 1,
	--[[ footprint ]] 1, -- as sphere
	--[[ ellipsoid ]] [0] = 1,
}

local canSurf = {} -- units that will have their colvols dynamically replaced
do
	local function needsSurfbox(unitDef)
		if unitDef.isImmobile or unitDef.name:match("critter") then
			return false
		end

		local cat = unitDef.modCategories

		if cat.ship or cat.hover or cat.vtol or cat.underwater or cat.canbeuw then
			return false
		end

		local height = unitDef.upright and math.max(unitDef.height, unitDef.radius) or (unitDef.height + unitDef.radius) * 0.5
		local depth = unitDef.moveDef.depth or 0

		return depth > height
	end

	for unitDefID, unitDef in pairs(UnitDefs) do
		canSurf[unitDefID] = needsSurfbox(unitDef)

		if debug and canSurf[unitDefID] then
			Spring.Echo("surfbox",
				unitDef.name,
				unitDef.height,
				unitDef.radius,
				unitDef.moveDef.depth or 0,
				unitDef.waterLine or unitDef.waterline
			)
		end
	end
end

local colvolDefData = {} -- data from collisionvolumes.lua
local colvolDefType = {} -- unit/piece and static/dynamic

local surferUnitData = {} -- units with adjustable volumes
local surfersInWater = {} -- units that are being watched
local isUsingSurfbox = {} -- units with a modified collider

-- Local functions

local function getUnitDefData(unitDefID)
	local data = colvolDefData[unitDefID]

	if not data then
		local configType
		data, configType = GG.GetUnitDefCollisionVolumeData(unitDefID)
		colvolDefData[unitDefID] = data
		colvolDefType[unitDefID] = configType
	end

	return data
end

local function restoreVolume(unitID)
	isUsingSurfbox[unitID] = nil
	GG.CollisionVolumeCtrl(unitID, false)
	GG.RestoreDefaultColVol(unitID)
end

local function setUnitCollisionVolume(unitID, colvol, stretchY, offsetY, upX, upY, upZ)
	local shapeDimensionRatio = inflateRatios[colvol[7]]

	local ratioX = shapeDimensionRatio
	local ratioY = shapeDimensionRatio * stretchY
	local ratioZ = shapeDimensionRatio

	-- Move some eccentricity from XZ to Y to handle the inflated dimensions.
	if shapeDimensionRatio > 1 then
		local minXYZ = math_min(colvol[1], colvol[2], colvol[3]) * shapeDimensionRatio
		ratioX = ratioX / (1 + (colvol[1] / minXYZ - 1) * (1 - math_abs(upX))) -- todo: missing a coeff
		ratioY = ratioY / (1 + (colvol[2] / minXYZ - 1) * (1 - math_abs(upY)))
		ratioZ = ratioZ / (1 + (colvol[3] / minXYZ - 1) * (1 - math_abs(upZ)))
	end

	-- Offset the collision volume vertically in world-space, not in unit-space.
	local shiftX, shiftY, shiftZ = unitToWorldBasis(colvol[4], colvol[5], colvol[6], unitID)
	local yOffsetColVol = offsetY - colvol[5] * upY

	spSetUnitCollisionVolumeData(
		unitID,
		colvol[1] * ratioX,
		colvol[2] * ratioY,
		colvol[3] * ratioZ,
		shiftX + yOffsetColVol * upX,
		shiftY + yOffsetColVol * upY,
		shiftZ + yOffsetColVol * upZ,
		0, -- ellipsoid
		colvol[8],
		colvol[9]
	)
end

local function setPieceCollisionVolume(unitID, data, stretchY, offsetY)
	for piece = 1, data.count do
		local colvol = data[piece]

		if colvol[9] then
			local upX, upY, upZ = worldToPieceBasis(0, 1, 0, unitID, piece) -- todo: can do w/ way fewer ops because of 0s and 1s

			local shapeDimensionRatio = inflateRatios[colvol[7]]
			local ratioX = shapeDimensionRatio
			local ratioY = shapeDimensionRatio * stretchY
			local ratioZ = shapeDimensionRatio

			local minXYZ = math.min(colvol[1], colvol[2], colvol[3])
			ratioX = ratioX / (1 + (colvol[1] / minXYZ - 0.5) * 0.1667 * math_abs(upY))
			ratioY = ratioY / (1 - (colvol[2] / minXYZ - 0.5) * 0.6667 * math_abs(upY)) -- pieces tend to be layer-caked and need more height
			ratioZ = ratioZ / (1 + (colvol[3] / minXYZ - 0.5) * 0.1667 * math_abs(upY))

			local shiftX, shiftY, shiftZ = pieceToWorldBasis(colvol[4], colvol[5], colvol[6], unitID, piece) -- todo: whereas this cannot but could reuse the piece matrix
			local yOffsetColVol = offsetY - colvol[5] * upY

			Spring.SetUnitPieceCollisionVolumeData(
				unitID,
				piece,
				true,
				colvol[1] * ratioX,
				colvol[2] * ratioY,
				colvol[3] * ratioZ,
				shiftX + yOffsetColVol * upX,
				shiftY + yOffsetColVol * upY,
				shiftZ + yOffsetColVol * upZ,
				0,
				colvol[8]
			)
		end
	end
end

-- Surfboxes raise collision volumes to just above the water level so units that are
-- able to traverse water deeper than their own height can be attacked and destroyed.
local function surf(unitID)
	local ux, uy, uz = spGetUnitPosition(unitID)

	if uy < -waterDepthMax then
		if isUsingSurfbox[unitID] then
			restoreVolume(unitID)
		end
		return
	end

	local colvolData = surferUnitData[unitID]
	local colvolType = colvolDefType[unitDefID]
	local isUnitType = colvolType == 1 or colvolType == 2

	if colvolType == 2 or colvolType == 4 then
		colvolData = colvolData[spGetUnitArmored(unitID) and "off" or "on"]
	end

	local offsets = colvolData.offsets
	local unitOffset = isUnitType and colvolData[5] or offsets[2]
	local unitHeight = spGetUnitHeight(unitID) * (isUnitType and 1 or 0.75)
	local upX, upY, upZ = worldToUnitBasis(0, 1, 0, unitID)

	local height = uy + unitOffset * upY + unitHeight * 0.5 * upY
	local target = surfHeight + (isUsingSurfbox[unitID] and 1 or -1)

	if height >= target then
		if isUsingSurfbox[unitID] then
			restoreVolume(unitID)
		end
		return
	end

	if not isUsingSurfbox[unitID] then
		isUsingSurfbox[unitID] = true
		GG.CollisionVolumeCtrl(unitID, true)
	end

	-- New offset needed for the collision volume to reach the surf[ace] height.
	local offsetY = target - height

	-- Split the difference between stretching the volume and lifting it upward.
	-- Maintaining multiple, smaller deltas in the result reduces any disjoints.
	local stretchY = 1 + 0.5 * (offsetY - unitOffset) / unitHeight
	offsetY = offsetY * math_clamp(1 / stretchY, 0.5, 1)

	spSetUnitMidAndAimPos(
		unitID,
		offsets[1],
		offsets[2] + offsetY * 0.5,
		offsets[3],
		offsets[4],
		offsets[5] + offsetY * 0.5,
		offsets[6],
		offsets[7]
	)

	if isUnitType then
		setUnitCollisionVolume(unitID, colvolData, stretchY, offsetY, upX, upY, upZ)
	else
		setPieceCollisionVolume(unitID, colvolData, stretchY, offsetY)
	end
end

-- Engine events

function gadget:Initialize()
	if not table.any(canSurf, function(value) return value == true end) then
		gadgetHandler:RemoveGadget()
		return
	end

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
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
		surferUnitData[unitID] = getUnitDefData(unitDefID)
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		if uy <= 0 then
			gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
		end
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
			restoreVolume(unitID)
		end
	end
end
