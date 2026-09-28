local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Water Check",
		desc = "Select a unit to see how deep it can go in water before it hides or lasers stop hurting it",
		author = "efrec",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
	}
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local AMPHIBIOUS_MOVEDEF_NAME = "^[SMH]?A[BHT]" -- Code `A` in the naming scheme
local UPDATE_FRAMES = 15
local PIECE_UPDATE_FRAMES = 1 -- Catch pieces that swing out during an animation
local CIRCLE_SAMPLES = 16

-- Pending the collision volumes refactor stack we just have to hardcode these
local VOLUME_ELLIPSOID = 0
local VOLUME_CYLINDER = 1
local VOLUME_BOX = 2
local VOLUME_SPHERE = 3
local AXIS_X = 0
local AXIS_Y = 1

local LASER_TYPES = { "BeamLaser", "LaserCannon", "LightningCannon" }
local LASER_NAMES = {
	BeamLaser = "Beam lasers",
	LaserCannon = "Laser cannons",
	LightningCannon = "Lightning weapons",
}

local COLOR_TITLE = "\255\255\255\255"
local COLOR_TEXT = "\255\210\210\210"
local COLOR_GOOD = "\255\120\230\120"
local COLOR_PROBLEM = "\255\255\110\90"

--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local format = string.format

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVectors = Spring.GetUnitVectors
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitCollisionVolumeData = Spring.GetUnitCollisionVolumeData
local spGetUnitPieceCollisionVolumeData = Spring.GetUnitPieceCollisionVolumeData
local spGetUnitPieceList = Spring.GetUnitPieceList
local spGetUnitPieceMatrix = Spring.GetUnitPieceMatrix
local spGetViewGeometry = Spring.GetViewGeometry
local spIsGUIHidden = Spring.IsGUIHidden

local SQUARE_SIZE = Game.squareSize
local SPEED_CLASS = Game.speedModClasses

local vsx, vsy = spGetViewGeometry()
local font, fontSize

local selectedUnitID
local selectedUsesPieces = false
local lines = {}

---@class LaserWeapon
---@field type string
---@field radius number Damage radius below the waterline. Zero for impact-only.
---@field onlyTargets table<string, true>

local laserWeapons = {} ---@type LaserWeapon[]
do
	local seen = {}
	for _, unitDef in pairs(UnitDefs) do
		for _, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef] ---@as table
			if LASER_NAMES[weaponDef.type] and not weaponDef.waterWeapon then
				local radius = weaponDef.impactOnly and 0 or math_max(1, weaponDef.damageAreaOfEffect)
				local categories = {}
				for category in pairs(weapon.onlyTargets) do
					categories[#categories + 1] = category
				end
				table.sort(categories)
				local key = format("%s:%s:%s", weaponDef.type, radius, table.concat(categories, ","))
				if not seen[key] then
					seen[key] = true
					laserWeapons[#laserWeapons + 1] = {
						type = weaponDef.type,
						radius = radius,
						onlyTargets = weapon.onlyTargets,
					}
				end
			end
		end
	end
end

local amphibiousDepth = math.huge
for _, moveDef in ipairs(VFS.Include("gamedata/movedefs.lua")) do
	if moveDef.name:find(AMPHIBIOUS_MOVEDEF_NAME) and moveDef.maxwaterdepth then
		amphibiousDepth = math_min(amphibiousDepth, moveDef.maxwaterdepth)
	end
end

local piecesOutside = {} ---@type table<integer, table<string, table<string, true>>> unitID -> finding -> piece names
local pieceNames = {} ---@type table<integer, string[]>

local circleCos, circleSin = {}, {}
for i = 1, CIRCLE_SAMPLES do
	local angle = 2 * math.pi * i / CIRCLE_SAMPLES
	circleCos[i], circleSin[i] = math.cos(angle), math.sin(angle)
end

--------------------------------------------------------------------------------
-- Checks ----------------------------------------------------------------------

local function formatDepth(depth)
	return (format("%.1f", depth):gsub("%.0$", ""))
end

local function canTarget(onlyTargets, categories)
	for category in pairs(onlyTargets) do
		if categories[category] then
			return true
		end
	end
	return false
end

local function getSmallestLaserRadius(unitDef)
	local smallest = {}
	for _, laser in ipairs(laserWeapons) do
		if canTarget(laser.onlyTargets, unitDef.modCategories) then
			local radius = smallest[laser.type]
			if not radius or laser.radius < radius then
				smallest[laser.type] = laser.radius
			end
		end
	end
	return smallest
end

local function getLaserReachDepth(hitboxTop, sideOffset, radius)
	if radius > sideOffset then
		return hitboxTop + math_sqrt(radius * radius - sideOffset * sideOffset)
	end
	return hitboxTop
end

local function getBoundingRadius(hx, hy, hz, volumeType, axis)
	if volumeType == VOLUME_BOX then
		return math_sqrt(hx * hx + hy * hy + hz * hz)
	elseif volumeType == VOLUME_SPHERE then
		return hx
	elseif volumeType == VOLUME_ELLIPSOID then
		return math_max(hx, hy, hz)
	elseif axis == AXIS_X then
		return math_sqrt(hx * hx + math_max(hy, hz) ^ 2)
	elseif axis == AXIS_Y then
		return math_sqrt(hy * hy + math_max(hx, hz) ^ 2)
	else
		return math_sqrt(hz * hz + math_max(hx, hy) ^ 2)
	end
end

-- Piece volumes are measured in model space, where the unit's position is the origin.
local matrix = {}
local centerX, centerY, centerZ = 0, 0, 0
local farthest, farthestFlat = 0, 0

local function measurePoint(x, y, z)
	local m = matrix
	local px = m[1] * x + m[5] * y + m[9] * z + m[13]
	local py = m[2] * x + m[6] * y + m[10] * z + m[14]
	local pz = m[3] * x + m[7] * y + m[11] * z + m[15]
	local dx, dy, dz = px - centerX, py - centerY, pz - centerZ
	farthest = math_max(farthest, math_sqrt(dx * dx + dy * dy + dz * dz))
	farthestFlat = math_max(farthestFlat, math_sqrt(px * px + pz * pz))
end

local function measurePieceVolume(hx, hy, hz, ox, oy, oz, volumeType, axis)
	if volumeType == VOLUME_BOX then
		for i = -1, 1, 2 do
			for j = -1, 1, 2 do
				for k = -1, 1, 2 do
					measurePoint(ox + i * hx, oy + j * hy, oz + k * hz)
				end
			end
		end
	elseif volumeType == VOLUME_CYLINDER then
		for i = 1, CIRCLE_SAMPLES do
			local c, s = circleCos[i], circleSin[i]
			for side = -1, 1, 2 do
				if axis == AXIS_X then
					measurePoint(ox + side * hx, oy + c * hy, oz + s * hz)
				elseif axis == AXIS_Y then
					measurePoint(ox + c * hx, oy + side * hy, oz + s * hz)
				else
					measurePoint(ox + c * hx, oy + s * hy, oz + side * hz)
				end
			end
		end
	else
		for i = 1, CIRCLE_SAMPLES do
			for j = 1, CIRCLE_SAMPLES do
				local c = circleCos[j]
				measurePoint(ox + hx * c * circleCos[i], oy + hy * circleSin[j], oz + hz * c * circleSin[i])
			end
		end
	end
end

local function remember(findings, key, name)
	local names = findings[key]
	if not names then
		names = {}
		findings[key] = names
	end
	names[name] = true
end

local function listNames(names)
	local list = {}
	for name in pairs(names) do
		list[#list + 1] = name
	end
	table.sort(list)
	return table.concat(list, ", ")
end

local function checkPieces(unitID, unitDefID, unitRadius, mainX, mainY, mainZ, mainRadius, smallestRadius)
	local names = pieceNames[unitDefID]
	if not names then
		names = spGetUnitPieceList(unitID)
		pieceNames[unitDefID] = names
	end

	local findings = piecesOutside[unitID]
	if not findings then
		findings = {}
		piecesOutside[unitID] = findings
	end

	centerX, centerY, centerZ = mainX, mainY, mainZ

	for piece = 1, #names do
		local sx, sy, sz, ox, oy, oz, volumeType, _, axis, disabled = spGetUnitPieceCollisionVolumeData(unitID, piece)
		if sx and not disabled then
			local m = matrix
			m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12], m[13], m[14], m[15], m[16] =
				spGetUnitPieceMatrix(unitID, piece)
			if m[1] then
				farthest, farthestFlat = 0, 0
				measurePieceVolume(sx * 0.5, sy * 0.5, sz * 0.5, ox, oy, oz, volumeType, axis)
				-- The engine files units into map cells by their radius around their position.
				if farthestFlat > unitRadius then
					remember(findings, "radius", names[piece])
				end
				-- Explosions only consider units whose main volume's bounding sphere they touch.
				for _, laserType in ipairs(LASER_TYPES) do
					local laserRadius = smallestRadius[laserType]
					if laserRadius and laserRadius > 0 and farthest >= mainRadius + laserRadius then
						remember(findings, laserType, names[piece])
					end
				end
			end
		end
	end

	return findings
end

local function addLine(text, color)
	lines[#lines + 1] = (color or COLOR_TEXT) .. text
end

local function checkUnit(unitID)
	lines = {}
	selectedUsesPieces = false

	local unitDef = UnitDefs[spGetUnitDefID(unitID)]
	if not unitDef then
		return
	end

	addLine(unitDef.translatedHumanName or unitDef.humanName, COLOR_TITLE)

	local moveDef = unitDef.moveDef
	if unitDef.canFly then
		addLine("Flies. Not checked.")
		return
	elseif not moveDef or not moveDef.depth then
		addLine("Does not move. Not checked.")
		return
	elseif moveDef.smClass == SPEED_CLASS.Hover then
		addLine("Hovers. Not checked.")
		return
	elseif moveDef.smClass == SPEED_CLASS.Ship then
		addLine("Sails. Not checked.")
		return
	end

	local bx, by, bz, mx, my, mz = spGetUnitPosition(unitID, true)
	local front, up, right = spGetUnitVectors(unitID)
	local radius = spGetUnitRadius(unitID)
	local sx, sy, sz, ox, oy, oz, volumeType, _, axis, ignoreHits = spGetUnitCollisionVolumeData(unitID)
	if not bx or not up or not radius or not sx then
		return
	end

	-- Measure along the unit's own axes so a unit standing on a slope reads as on flat ground.
	local dx, dy, dz = mx - bx, my - by, mz - bz
	local midHeight = dx * up[1] + dy * up[2] + dz * up[3]
	local hiddenDepth = midHeight + radius
	local hitboxTop = midHeight + oy + sy * 0.5
	local sideX = math_max(math_abs(ox) - sx * 0.5, 0)
	local sideZ = math_max(math_abs(oz) - sz * 0.5, 0)
	local sideOffset = math_sqrt(sideX * sideX + sideZ * sideZ)

	local walkDepth = moveDef.depth
	local isAmphibious = walkDepth >= amphibiousDepth
	local smallestRadius = getSmallestLaserRadius(unitDef)

	local problems = {}

	if isAmphibious then
		addLine("Amphibious. No verdict.")
	else
		addLine(format("Walks into water up to %s deep.", formatDepth(walkDepth)))
	end

	if not isAmphibious and hiddenDepth >= walkDepth then
		addLine("Can be seen and targeted at every depth it can walk to.")
	else
		addLine(format("Can be seen and targeted down to %s deep.", formatDepth(hiddenDepth)))
		if not isAmphibious then
			problems[#problems + 1] = format(
				"Hidden and cannot be targeted from %s to %s deep.",
				formatDepth(hiddenDepth),
				formatDepth(walkDepth)
			)
		end
	end

	local exposedDepth = isAmphibious and hiddenDepth or math_min(hiddenDepth, walkDepth)

	for _, laserType in ipairs(LASER_TYPES) do
		local laserRadius = smallestRadius[laserType] ---@as number?
		if laserRadius then
			local name = LASER_NAMES[laserType]
			local reachDepth = getLaserReachDepth(hitboxTop, sideOffset, laserRadius)
			if not isAmphibious and reachDepth >= exposedDepth then
				addLine(format("%s hurt it at every depth it can be targeted.", name))
			else
				addLine(format("%s hurt it down to %s deep.", name, formatDepth(reachDepth)))
				if not isAmphibious then
					problems[#problems + 1] = format(
						"%s shoot it but do no damage from %s to %s deep.",
						name,
						formatDepth(math_max(reachDepth, 0)),
						formatDepth(exposedDepth)
					)
				end
			end
		end
	end

	-- Ground units are pushed apart by their movement footprint, not by their hitbox.
	local footprintRadius = math_max(moveDef.xsize, moveDef.zsize) * 0.5 * SQUARE_SIZE
	local hitboxHalfWidth = math_max(math_abs(ox) + sx * 0.5, math_abs(oz) + sz * 0.5)
	local packedGap = 2 * (footprintRadius - hitboxHalfWidth)

	for _, laserType in ipairs(LASER_TYPES) do
		local laserRadius = smallestRadius[laserType]
		if laserRadius and laserRadius > 0 and packedGap < laserRadius then
			problems[#problems + 1] =
				format("%s hit two of these at once when they stand side by side.", LASER_NAMES[laserType])
		end
	end

	local pieceProblems = {}

	selectedUsesPieces = ignoreHits == true
	if selectedUsesPieces then
		-- Model space mirrors the unit's right axis.
		local midX = -(dx * right[1] + dy * right[2] + dz * right[3])
		local midZ = dx * front[1] + dy * front[2] + dz * front[3]
		local findings = checkPieces(
			unitID,
			unitDef.id,
			radius,
			midX - ox,
			midHeight + oy,
			midZ + oz,
			getBoundingRadius(sx * 0.5, sy * 0.5, sz * 0.5, volumeType, axis),
			smallestRadius
		)
		if findings.radius then
			pieceProblems[#pieceProblems + 1] =
				format("Shots can pass through these parts: %s.", listNames(findings.radius))
		end
		for _, laserType in ipairs(LASER_TYPES) do
			if findings[laserType] then
				pieceProblems[#pieceProblems + 1] = format(
					"%s can hit these parts and do no damage: %s.",
					LASER_NAMES[laserType],
					listNames(findings[laserType])
				)
			end
		end
	end

	if isAmphibious then
		problems = pieceProblems
	else
		for _, problem in ipairs(pieceProblems) do
			problems[#problems + 1] = problem
		end
	end

	if #problems == 0 then
		if not isAmphibious then
			addLine("No problems found.", COLOR_GOOD)
		end
	else
		for _, problem in ipairs(problems) do
			addLine("Problem: " .. problem, COLOR_PROBLEM)
		end
	end
end

local function refresh()
	local selectedUnits = spGetSelectedUnits()
	selectedUnitID = selectedUnits[1]
	if selectedUnitID then
		checkUnit(selectedUnitID)
	else
		lines = {}
	end
end

local function refreshFont()
	if WG.fonts then
		font, fontSize = WG.fonts.getFont(2, 0.6, 0.22, 1.6)
	else
		fontSize = math.floor(17 * (vsy / 1080) + 0.5)
		font = gl.LoadFont("fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"), fontSize, 4, 1.6)
	end
end

--------------------------------------------------------------------------------
-- Engine callins --------------------------------------------------------------

function widget:UnitDestroyed(unitID)
	piecesOutside[unitID] = nil
end

function widget:GameFrame(frame)
	-- Pop-up units swap hitboxes when they open and close.
	local updateFrames = selectedUsesPieces and PIECE_UPDATE_FRAMES or UPDATE_FRAMES
	if selectedUnitID and frame % updateFrames == 0 then
		refresh()
	end
end

function widget:SelectionChanged()
	refresh()
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	refreshFont()
end

function widget:DrawScreen()
	if #lines == 0 or spIsGUIHidden() then
		return
	end
	local lineHeight = fontSize * 1.3
	local x, y = vsx * 0.5, vsy * 0.8
	font:Begin()
	for i = 1, #lines do
		font:Print(lines[i], x, y - (i - 1) * lineHeight, fontSize, "co")
	end
	font:End()
end

function widget:Initialize()
	refreshFont()
	refresh()
end
