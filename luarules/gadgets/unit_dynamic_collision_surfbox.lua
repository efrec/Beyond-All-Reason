local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Dynamic Surfboxes",
		desc    = "Allows units to be hit by impact-only weapons in water even when submerged",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 1, -- after unit_dynamic_collision_volume.lua
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

-- Globals

local math_clamp = math.clamp
local math_diag = math.diag

local spGetUnitHeight = Spring.GetUnitHeight
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDirection = Spring.GetUnitDirection
local spGetUnitCollisionVolumeData = Spring.GetUnitCollisionVolumeData
local spSetUnitCollisionVolumeData = Spring.SetUnitCollisionVolumeData
local spSetUnitMidAndAimPos = Spring.SetUnitMidAndAimPos

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
	-- We compensate for inclines with unit tilt math later, so cut in half, but also add a nudge.
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

local function isProbablyFine(unitDef)
	local is = unitDef.modCategories
	if is.ship or is.hover or is.vtol or is.underwater or is.canbeuw then
		return true
	elseif unitDef.isImmobile then
		return true
	elseif (unitDef.moveDef.depth or 0) > math.min(unitDef.height * 0.5, unitDef.radius) then -- badly imperfect test
		return false
	end
end

for unitDefID, unitDef in pairs(UnitDefs) do
	canSurf[unitDefID] = false
	if unitDef.customParams.has_surfing_colvol then
		canSurf[unitDefID] = true
		if isProbablyFine(unitDef) then
			Spring.Log("Surfboxes", LOG.NOTICE, "Floating unit assigned a surfbox: " .. unitDef.name)
		end
	elseif not isProbablyFine(unitDef) then
		canSurf[unitDefID] = true
	end
end

local surferUnitData = {} -- { volume, position }
local surferDefData = {} -- caches the unit data
local surfersInWater = {} -- units that are being watched
local isUsingSurfbox = {} -- units with a modified collider

-- Local functions

-- Project directions into arbitrary vector spaces
local function toBasis(dx, dy, dz, frontX, frontY, frontZ, rightX, rightY, rightZ, upX, upY, upZ)
	return
		dx * rightX + dy * upX + dz * frontX,
		dx * rightY + dy * upY + dz * frontY,
		dx * rightZ + dy * upZ + dz * frontZ
end

-- TODO: We should be more efficient if we're going to start doing this per-piece
-- Project and scale directions onto the world up axis
local function toUpAxis(unitID, pieceID, scale)
	local m11, m12, m13, m21, m22, m23, m31, m32, m33 = Spring.GetUnitPieceMatrix(unitID, pieceID)

	-- From the transform, S = I + k·(U ⊗ U), only one value is not zero or one
	local s22 = 1 + scale -- or is it just scale? idr

	-- Apply, M = S · M_input, impacting one row
	local r21 = s22 * m21
	local r22 = s22 * m22
	local r23 = s22 * m23

	-- Scales are the column lengths of the result
	return
		math_diag(m11, r21, m31),
		math_diag(m12, r22, m32),
		math_diag(m13, r23, m33)
end

local function calculateUnitMidAndAimPos(unitID)
	local bx, by, bz, mx, my, mz, ax, ay, az = spGetUnitPosition(unitID, true, true)
	local fx, fy, fz, rx, ry, rz, ux, uy, uz = spGetUnitDirection(unitID)
	mx, my, mz = toBasis(mx - bx, my - by, mz - bz, fx, fy, fz, rx, ry, rz, ux, uy, uz)
	ax, ay, az = toBasis(ax - bx, ay - by, az - bz, fx, fy, fz, rx, ry, rz, ux, uy, uz)
	return mx, my, mz, ax, ay, az, true
end

local ignorePieceColVol = { 1, 1, 1, 0, 0, 0, 3, 1, false } -- todo: proper visitor pattern instead

local function copyColVolData(tbl, deeper)
	local copy = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			if #v == 9 then
				copy[k] = v[9] == false and ignorePieceColVol or v
			else
				copy[k] = copyColVolData(v, true)
			end
		else
			copy[k] = v
		end
	end
	return copy
end

local function getUnitDefData(unitDefID)
	local data = surferDefData[unitDefID]

	if not data then
		local config, configType, isLoaded = GG.GetUnitDefCollisionVolumeData(unitDefID)

		if isLoaded then
			data = copyColVolData(config)
			data.isUnitVol = configType == 1 or configType == 2
			data.isDynamic = configType == 2 or configType == 4
			surferDefData[unitDefID] = data
		end
	end

	return data
end

local function restoreVolume(unitID)
	isUsingSurfbox[unitID] = nil
	GG.CollisionVolumeCtrl(unitID, false)
	GG.RestoreDefaultColVol(unitID)
end

-- Surfboxes raise collision volumes to just above the water level so units that are
-- able to traverse water deeper than their own height can be attacked and destroyed.
local function surf(unitID)
	local hasSurfbox = isUsingSurfbox[unitID]
	local colvolData = surferUnitData[unitID]
	local isUnitVol = colvolData.isUnitVol
	local isDynamic = colvolData.isDynamic
	local offsets = colvolData.offsets

	-- We'll get there when we get there
	-- if isDynamic then
	-- 	colvolData = colvolData[Spring.GetUnitArmored(unitID) and "off" or "on"]
	-- 	offsets = colvolData.offsets or offsets -- idk maybe
	-- end

	local unitOffset = (isUnitVol and colvolData[5]) or (offsets and offsets[2] or 0) -- colvol y-offset relative to unit base position
	local unitHeight = spGetUnitHeight(unitID) * (isUnitVol and 1 or 0.75)
	local ux, uy, uz = spGetUnitPosition(unitID)

	if uy < -waterDepthMax or uy + unitOffset + unitHeight >= surfHeight + (hasSurfbox and 1 or -1) then
		if hasSurfbox then
			restoreVolume(unitID)
		end
		return
	elseif not hasSurfbox then
		GG.CollisionVolumeCtrl(unitID, true)
		isUsingSurfbox[unitID] = true
	end

	local _, _, _, _, _, _, _, upward = spGetUnitDirection(unitID)
	upward = math_clamp(upward, 1/3, 1)
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

	if isUnitVol then
		-- Use a tight-fitting shape but increase its dimensions.
		local shapeDimensionRatio = inflateRatios[colvolData[7]]

		local ratioX = shapeDimensionRatio
		local ratioY = shapeDimensionRatio * stretch
		local ratioZ = shapeDimensionRatio

		local minXYZ = math.min(colvolData[1], colvolData[2], colvolData[3])
		local maxXZ = math.max(colvolData[1], colvolData[3])

		-- Prevent misses when targeting the collider's near border by exchanging some
		-- of the shape's eccentricity in the XZ axes with its Y axis (in unit space).
		if maxXZ / minXYZ > 1.25 then
			-- Exchange less eccentricity between axes as the unit tilts more.
			ratioX = ratioX / (1 + (colvolData[1] / minXYZ - 0.5) * 0.30 * upward)
			local rateY = 1 / (1 - (colvolData[2] / minXYZ - 0.5) * 0.23 * upward) -- not symmetrical
			ratioZ = ratioZ / (1 + (colvolData[3] / minXYZ - 0.5) * 0.30 * upward)
			ratioY = ratioY * rateY
			yOffset = yOffset + (rateY * rateY - rateY) * (unitHeight * 0.5) -- less lift
		end

		spSetUnitCollisionVolumeData(
			unitID,
			colvolData[1] * ratioX,
			colvolData[2] * ratioY,
			colvolData[3] * ratioZ,
			colvolData[4],
			yOffset * 0.5,
			colvolData[6],
			0, -- Ellipsoids trade good fitness for expensive hit detection.
			colvolData[8],
			colvolData[9]
		)

		if offsets then
			spSetUnitMidAndAimPos(
				unitID,
				offsets[1],
				offsets[2] + yOffset * 0.75,
				offsets[3],
				offsets[4],
				offsets[5] + yOffset * 0.5,
				offsets[6],
				offsets[7]
			)
		else
			spSetUnitMidAndAimPos(unitID, 0, yOffset * 0.75, 0, 0, yOffset * 0.5, 0, true)
		end
	else
		-- Piece colvols are no longer trying to stick to the surface individually.
		-- They can reuse the stretch/offset logic for most but not in entire part.
		local up = { toBasis(0, 1, 0, spGetUnitDirection(unitID)) }

		for piece = 1, colvolData.count do
			local colvol = colvolData[piece]

			if colvol[9] then
				local inflateRatio = inflateRatios[colvol[7]]
				local minXYZ = math.min(colvol[1], colvol[2], colvol[3])
				local rateY = 1 / (1 - (colvol[2] / minXYZ - 0.5) * 0.23)
				local ratioY = inflateRatio * stretch * rateY
				local yOffsetPiece = ((yOffset - colvol[5]) + (rateY * rateY - rateY) * unitHeight * 0.5 * (1 - up[2])) * 0.5

				Spring.SetUnitPieceCollisionVolumeData(
					unitID,
					piece,
					true,
					colvol[1] * (up[1] + 1) * inflateRatio,
					colvol[2] * (up[2] + 1) * ratioY,
					colvol[3] * (up[3] + 1) * inflateRatio,
					colvol[4] + up[1] * ratioY,
					colvol[5] + up[2] * ratioY + yOffsetPiece,
					colvol[6] + up[3] * ratioY,
					0, -- jk ellipsoid
					colvol[8]
				)
			end

			yOffset = yOffset * 0.75 -- piece colliders need to keep their relative positions more

			if offsets then
				spSetUnitMidAndAimPos(
					unitID,
					offsets[1],
					offsets[2] + yOffset * 0.75,
					offsets[3],
					offsets[4],
					offsets[5] + yOffset * 0.5,
					offsets[6],
					offsets[7]
				)
			else
				spSetUnitMidAndAimPos(unitID, 0, yOffset * 0.75, 0, 0, yOffset * 0.5, 0, true)
			end

			-- TODO: Try to do 100% of the work in piece space. Probably unnecessary, though.
			-- TODO: The approach above, which still places offsets per-piece, ought to adapt
			-- TODO: to apply a single major offset to the unit midpoint, before trying this.
			-- if colvol[9] then
			-- 	local upPiece = { toUpAxis(unitID, piece, stretch) }
			-- 	local upward = upUnit[2]
			-- 	local yOffsetPiece = yOffset

			-- 	local shapeDimensionRatio = inflateRatios[colvol[7]]

			-- 	local ratioX = shapeDimensionRatio
			-- 	local ratioY = shapeDimensionRatio * stretch
			-- 	local ratioZ = shapeDimensionRatio

			-- 	local minXYZ = math.min(colvol[1], colvol[2], colvol[3])
			-- 	local maxXZ = math.max(colvol[1], colvol[3])

			-- 	if maxXZ / minXYZ > 1.25 then
			-- 		ratioX = ratioX / (1 + (colvol[1] / minXYZ - 0.5) * 0.30 * upward)
			-- 		local rateY = 1 / (1 - (colvol[2] / minXYZ - 0.5) * 0.23 * upward) -- not symmetrical
			-- 		ratioZ = ratioZ / (1 + (colvol[3] / minXYZ - 0.5) * 0.30 * upward)
			-- 		ratioY = ratioY * rateY
			-- 		yOffsetPiece = yOffsetPiece + (rateY * rateY - rateY) * (unitHeight * 0.5) * (1 - upward) -- less lift
			-- 	end

			-- 	Spring.SetUnitPieceCollisionVolumeData(
			-- 		unitID,
			-- 		piece,
			-- 		true,
			-- 		colvol[1] * ratioX,
			-- 		colvol[2] * ratioY,
			-- 		colvol[3] * ratioZ,
			-- 		colvol[4],
			-- 		yOffsetPiece * 0.5,
			-- 		colvol[6],
			-- 		0, -- Ellipsoids trade good fitness for expensive hit detection.
			-- 		colvol[8]
			-- 	)
			-- end
		end
	end
end

-- Engine events

function gadget:Initialize()
	if not table.any(canSurf, function(value) return value == true end) then
		gadgetHandler:RemoveGadget()
		return
	end

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
		surferUnitData[unitID] = getUnitDefData(unitDefID)
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
