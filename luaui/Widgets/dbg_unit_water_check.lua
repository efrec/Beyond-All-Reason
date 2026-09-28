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

local AMPHIBIOUS_DEPTH = 5000 -- Same threshold as the drowning gadget.
local UPDATE_FRAMES = 15

local SPEEDMOD_HOVER = 2
local SPEEDMOD_SHIP = 3

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
local spGetViewGeometry = Spring.GetViewGeometry
local spIsGUIHidden = Spring.IsGUIHidden

local SQUARE_SIZE = Game.squareSize

local vsx, vsy = spGetViewGeometry()
local font, fontSize

local selectedUnitID
local lines = {}

---@class LaserWeapon
---@field type string
---@field radius number Damage radius below the waterline. Zero for impact-only weapons.
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

local function addLine(text, color)
	lines[#lines + 1] = (color or COLOR_TEXT) .. text
end

local function checkUnit(unitID)
	lines = {}

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
	elseif moveDef.smClass == SPEEDMOD_HOVER then
		addLine("Hovers. Not checked.")
		return
	elseif moveDef.smClass == SPEEDMOD_SHIP then
		addLine("Sails. Not checked.")
		return
	end

	local bx, by, bz, mx, my, mz = spGetUnitPosition(unitID, true)
	local _, up = spGetUnitVectors(unitID)
	local radius = spGetUnitRadius(unitID)
	local sx, sy, sz, ox, oy, oz = spGetUnitCollisionVolumeData(unitID)
	if not bx or not up or not radius or not sx then
		return
	end

	-- Measure along the unit's own up axis so a unit standing on a slope reads as on flat ground.
	local midHeight = (mx - bx) * up[1] + (my - by) * up[2] + (mz - bz) * up[3]
	local hiddenDepth = midHeight + radius
	local hitboxTop = midHeight + oy + sy * 0.5
	local sideX = math_max(math_abs(ox) - sx * 0.5, 0)
	local sideZ = math_max(math_abs(oz) - sz * 0.5, 0)
	local sideOffset = math_sqrt(sideX * sideX + sideZ * sideZ)

	local walkDepth = moveDef.depth
	local isAmphibious = walkDepth >= AMPHIBIOUS_DEPTH
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

	if isAmphibious then
		return
	elseif #problems == 0 then
		addLine("No problems found.", COLOR_GOOD)
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

function widget:GameFrame(frame)
	-- Pop-up units swap hitboxes when they open and close.
	if selectedUnitID and frame % UPDATE_FRAMES == 0 then
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
