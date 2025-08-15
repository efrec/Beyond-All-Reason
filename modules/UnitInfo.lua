-------------------------------------------------------------- [UnitInfo.lua] --
-- Unit classification and property caching, handled in a centralized module. --

if not UnitDefs or not Game then
	return false
end

---@module UnitInfo
local UnitInfo = {}

UnitInfo.Classifiers = {} ---@type table<string, function> Unit def properties and their value functions.
UnitInfo.MoveScripts = {} ---@type table<string, table> Unit def moveTypes and unit script type handling.
UnitInfo.Cache = {} ---@type table<string, any> Cached unit def properties. Booleans form sparse sets.

--------------------------------------------------------------------------------
-- Module caching --------------------------------------------------------------

-- Rather than keep multiple copies of the same information all over the place,
-- the idea is we can cache this once, allow gadgets/widgets/wupgets/waddups to
-- acquire local copies at init and set the cache collection to have weak keys.

local classifier = UnitInfo.Classifiers

-- To add "non-sparse" values to a set, use `DefInfo.AddCacheValue`.
local sparseKeys = {
	[false]   = true,
	["false"] = true,
	[0]       = true,
	["0"]     = true,
}

-- Strip trivial, false, and empty values to produce a sparse-er set.
-- Properties with e.g. meaningful zeroes should use `AddCacheValue`.
local function sparsify(value)
	if value ~= nil then
		if type(value) == "table" then
			if not next(value) then
				return
			else
				value = table.copy(value)
			end
		elseif type(value) == "string" then
			if tonumber(value) ~= nil then
				value = tonumber(value)
			end
		end
		if not sparseKeys[value] then
			return value
		end
	end
end

UnitInfo.Cache = setmetatable({}, {
	-- Values that are not in the cache get cached automatically.
	__index = function(self, key)
		if type(key) == "string" then
			local values = {}
			if classifier[key] then
				local pred = classifier[key]
				for unitDefID, unitDef in ipairs(UnitDefs) do
					values[unitDefID] = sparsify(pred(unitDef))
				end
			else
				for unitDefID, unitDef in ipairs(UnitDefs) do
					local value = unitDef[key]
					if value == nil then
						value = unitDef.customParams[key]
					end
					values[unitDefID] = sparsify(value)
				end
			end
			rawset(self, key, values)
			return values
		end
	end,

	-- Cached values that do not maintain a reference get collected.
	__mode = "kv",
})

-- We can cut down the module size further by encouraging aggressive collection.
-- This might have confusing results, though; key/value pairs become ephemeral.
-- Simple rule to follow: If you need it later, stash it into a local variable.
setmetatable(UnitInfo.Classifiers, { __mode = "kv" })
setmetatable(UnitInfo.MoveScripts, { __mode = "kv" })

---Add (or get) a shared table of <unitDefID, value> pairs to (and from) cache.
---@param name string
---@param predicate function|table
---@return table values
---@return boolean added
UnitInfo.AddCacheValue = function(name, predicate)
	if rawget(UnitInfo.Cache, name) ~= nil then
		return UnitInfo.Cache[name], false
	end

	if type(predicate) == "function" then
		local values = {}
		for unitDefID, unitDef in ipairs(UnitDefs) do
			values[unitDefID] = predicate(unitDef)
		end
		UnitInfo.Cache[name] = values
		return values, true
	elseif type(predicate) == "table" then
		UnitInfo.Cache[name] = predicate
		return predicate, true
	end
end

--------------------------------------------------------------------------------
-- Module internals ------------------------------------------------------------

local SIDES = VFS.Include("sides_enum.lua")

local diag = math.diag

local SQUARE_SIZE = Game.squareSize
local ARMORTYPE_BASE = Game.armorTypes.default
local ARMORTYPE_VTOL = Game.armorTypes.vtol

local MoveDefs = Game.MoveDefs
local MoveDefNames = {}
for index, moveDef in ipairs(MoveDefs) do
	MoveDefNames[moveDef.name] = moveDef
	moveDef.index = index
end

local DEPTH_AMPHIBIOUS = 5000 -- see movedefs.lua

local function hasPositiveValue(key, value)
	return type(value) == "number" and value > 0
end

---Excludes obvious "abilities", like self-destructing, that we'd rather ignore.
local function hasUnitAbility(unitDef)
	return unitDef.canAttack
		or unitDef.canManualFire
		or unitDef.kamikaze
		or unitDef.canCloak
		or unitDef.canFight
		or unitDef.canGuard
		or unitDef.canMove
		or unitDef.canPatrol
		or unitDef.canAssist
		or unitDef.canCapture
		or unitDef.canReclaim
		or unitDef.canRepair
		or unitDef.canRestore
		or unitDef.canResurrect
		or (unitDef.firePlatform and unitDef.isTransport)
end

local function isAbilityTarget(unitDef)
	return unitDef.reclaimable
		or unitDef.repairable
		or unitDef.capturable
end

local function hasPhysicalInteraction(unitDef)
	return unitDef.blocking
		or unitDef.colliding -- air only
		or unitDef.pushResistant
end

local function hasPlayerInteraction(unitDef)
	return unitDef.selectable
end

local function hasEconomicValue(unitDef)
	return unitDef.reclaimable and (unitDef.metalCost > 0 or unitDef.energyCost > 0)
end

local function hasEconomicWreck(unitDef)
	if unitDef.corpse then
		local featureDef = FeatureDefNames[unitDef.corpse]
		if featureDef.metal > 0 or featureDef.energy > 0 then
			return true
		end
	end
	return false
end

local function hasSenses(unitDef)
	return unitDef.sightDistance > 1 -- "blind" units have sight == 1 to show explosions when hit in fog.
		or unitDef.airSightDistance > 0
		or unitDef.radarDistance > 0
		or unitDef.sonarDistance > 0
		or unitDef.seismicDistance > 0
end

local function canBeSensed(unitDef)
	return unitDef.stealth
		or unitDef.sonarStealth
		or unitDef.seismicSignature > 0
end

---Some units have "unused" weapon defs that serve other purposes, which we ignore.
local function equipsDef(unitDef, weaponDef)
	for _, weapon in ipairs(unitDef.weapons) do
		if weapon.weaponDef == weaponDef.id then
			return true
		end
	end
	return false
end

local function hasDamage(weaponDef)
	local custom = weaponDef.customParams
	if custom.bogus or custom.dronename then
		return false
	elseif weaponDef.damages and table.any(weaponDef.damages, hasPositiveValue) then
		return true
	elseif custom.cluster_def or custom.spark_basedamage then
		return true
	else
		return false
	end
end

local function hasWeapon(unitDef)
	for _, weapon in ipairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if equipsDef(unitDef, weaponDef) and hasDamage(weaponDef) then
			return true
		end
	end
	return false
end

local function hasAntiAirWeapon(unitDef)
	for _, weapon in ipairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if equipsDef(unitDef, weaponDef) and hasDamage(weaponDef) then
			if weaponDef.damages[ARMORTYPE_VTOL] >= 4 * weaponDef.damages[ARMORTYPE_BASE] then
				return true
			elseif weapon.onlyTargets and weapon.onlyTargets.vtol then
				return true
			end
		end
	end
	return false
end

local function hasBomberWeapon(unitDef)
	if unitDef.isAirUnit then
		for _, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if equipsDef(unitDef, weaponDef) and hasDamage(weaponDef) and (
					weaponDef.type == "AircraftBomb" or
					weaponDef.type == "TorpedoLauncher" or (
						-- or some other thing:
						weapon.onlyTargets and
						weapon.onlyTargets.surface
					))
			then
				return true
			end
		end
	end
	return false
end

local function isGaiaCritter(unitDef)
	return unitDef.name:sub(1, 7) == "critter" -- todo: customparam or something
end

local function isRaptorUnit(unitDef)
	return unitDef.customParams.is_raptor or unitDef.name:sub(1, 6) == "raptor"
end

local function isScavengerUnit(unitDef)
	return unitDef.customParams.is_scavenger or unitDef.name:find("_scav$")
end

local function getSide(unitDef)
	return table.getKeyOf(SIDES, unitDef.name:sub(1, 3))
end

--------------------------------------------------------------------------------
-- Unit classification ---------------------------------------------------------

-- General classifiers ---------------------------------------------------------

classifier.hasUnitAbility         = hasUnitAbility
classifier.isAbilityTarget        = isAbilityTarget
classifier.hasPhysicalInteraction = hasPhysicalInteraction
classifier.hasPlayerInteraction   = hasPlayerInteraction
classifier.hasEconomicValue       = hasEconomicValue
classifier.hasEconomicWreck       = hasEconomicWreck
classifier.hasSenses              = hasSenses
classifier.canBeSensed            = canBeSensed
classifier.hasWeapon              = hasWeapon

-- Weapons

classifier.hasAntiAirWeapon = hasAntiAirWeapon
classifier.hasBomberWeapon = hasBomberWeapon

classifier.hasInterceptableWeapon = function(unitDef)
	for i = 1, #unitDef.weapons do
		local weaponDef = WeaponDefs[unitDef.weapons[i].weaponDef]
		if weaponDef.targetable == 1 and equipsDef(unitDef, weaponDef) then
			return true
		end
	end
	return false
end

classifier.hasInterceptorWeapon = function(unitDef)
	for i = 1, #unitDef.weapons do
		local weaponDef = WeaponDefs[unitDef.weapons[i].weaponDef]
		if weaponDef.interceptor and weaponDef.interceptor ~= 0 and equipsDef(unitDef, weaponDef) then
			return true
		end
	end
	return false
end

classifier.hasParalyzerWeapon = function(unitDef)
	for i = 1, #unitDef.weapons do
		local weaponDef = WeaponDefs[unitDef.weapons[i].weaponDef]
		if weaponDef.paralyzer and hasDamage(weaponDef) and equipsDef(unitDef, weaponDef) then
			return true
		end
	end
	return false
end

classifier.shieldPower = function(unitDef)
	if unitDef.shieldWeaponDef then
		local weaponDef = WeaponDefs[unitDef.shieldWeaponDef]
		if weaponDef and equipsDef(unitDef, weaponDef) then
			return weaponDef.shieldPower
		end
	end
	return false
end

-- Damages

classifier.isParalyzeImmune = function(unitDef)
	return not unitDef.modCategories.empable
end

classifier.paralyzeMultiplier = function(unitDef)
	return tonumber(unitDef.customParams.paralyzemultiplier or 1)
end

-- Intel

classifier.decoyDef = function(unitDef)
	if unitDef.customParams.decoyfor then
		return UnitDefNames[unitDef.customParams.decoyfor]
	end
end

-- Categories

---Determines bombers more generally (e.g. minelayer) than `isBomberAirUnit`.
classifier.isAnyBomberAirUnit = function(unitDef)
	return unitDef.isAirUnit and hasBomberWeapon(unitDef)
end

---Determines air superiority fighters more strictly than `isFighterAirUnit`.
classifier.isStrafeFighterAirUnit = function(unitDef)
	return unitDef.isStrafeFighterUnit and hasAntiAirWeapon(unitDef)
end

classifier.isStrafeBomberAirUnit = function(unitDef)
	return unitDef.isStrafeFighterUnit and hasBomberWeapon(unitDef)
end

classifier.isConstructionUnit = function(unitDef)
	return unitDef.isBuilder
		and not unitDef.isFactory
		and unitDef.canMove
		and unitDef.canAssist
		and next(unitDef.buildOptions)
end

classifier.isConstructionTurret = function(unitDef)
	return unitDef.isBuilder and unitDef.movementClass == "NANO"
		and unitDef.isImmobile and not unitDef.isFactory
end

classifier.isParatrooperUnit = function(unitDef)
	return unitDef.customParams.paratrooper
end

classifier.isAirTransport = function(unitDef)
	return unitDef.isAirUnit and unitDef.isTransport
end

-- Move types and script types -------------------------------------------------

-- MoveDef, category, footprint, speed mods, and other movement state.
local moveType = {}

-- Most units fall into a few broad groups with varying mobility.

moveType.isImmobileUnit = function(unitDef)
	return unitDef.isImmobile and (not unitDef.yardmap or unitDef.yardmap == "")
end

moveType.isStructureUnit = function(unitDef)
	return unitDef.isImmobile and (unitDef.yardmap and unitDef.yardmap ~= "")
end

moveType.isInanimateUnit = function(unitDef)
	return unitDef.isImmobile
		and not hasWeapon(unitDef)
		and not hasUnitAbility(unitDef)
		and not unitDef.windGenerator
end

local slopeMax = {
	BOT = math.rad(54),
	VEH = math.rad(27),
}

moveType.moveTypeDisplayName = function(unitDef)
	if unitDef.isImmobile then
		if unitDef.yardmap and unitDef.yardmap ~= "" then
			return "Structure"
		else
			return "Immobile"
		end
	end

	if isRaptorUnit(unitDef) then
		if unitDef.isHoveringAirUnit or unitDef.isStrafingAirUnit then
			return "Winged"
		else
			return "Raptor" -- amphibious, hovering, and etc.
		end
	elseif unitDef.isStrafingAirUnit then
		return "Plane"
	elseif unitDef.isHoveringAirUnit then
		return "Gunship"
	end

	local moveDef = unitDef.moveDef
	local speedMods = Game.speedModClasses

	if moveDef.smClass == speedMods.Ship then
		return "Ship"
	elseif moveDef.isSubmarine then
		return "Submarine"
	end

	local slope = moveDef.maxSlope

	if slope > slopeMax.BOT then
		return "All-Terrain"
	elseif moveDef.smClass == speedMods.Hover then
		if slope > slopeMax.VEH then
			return "Hoverbot"
		else
			return "Hovercraft"
		end
	elseif moveDef.depth >= DEPTH_AMPHIBIOUS then
		return "Amphibious"
	elseif moveDef.smClass == speedMods.KBot then
		if slope > slopeMax.VEH then
			return "Bot"
		else
			return "Walker"
		end
	else
		return "Vehicle"
	end
end

-- Units may not match their footprints (for odd reasons)
-- but must at least fit within their maximum  dimensions
moveType.hasSufficientFootprint = function(unitDef)
	local moveDef = MoveDefNames[unitDef.moveDef.name]

	if not moveDef or unitDef.canFly then
		return true
	elseif unitDef.xsize > moveDef.footprintx or unitDef.zsize > moveDef.footprintz then
		return false
	end

	local mdSizeMin = math.min(moveDef.footprintx, moveDef.footprintz)
	local udSizeMax = math.max(unitDef.xsize, unitDef.zsize, unitDef.radius / SQUARE_SIZE)

	if mdSizeMin < udSizeMax then
		return false
	end
end

-- MoveCtrl has its own mini-classification of move types.
local controlType = {}

---@see Spring.MoveCtrl.SetGroundMoveTypeData
controlType.isGroundMoveCtrlUnit = function(unitDef)
	local speedMod = unitDef.moveDef and unitDef.moveDef.speedModClass
	return speedMod == Game.speedModClasses.KBot
		or speedMod == Game.speedModClasses.Tank
		or speedMod == Game.speedModClasses.Hover
end

---@see Spring.MoveCtrl.SetAirMoveTypeData
controlType.isAirMoveCtrlUnit = function(unitDef)
	return unitDef.canFly and not unitDef.isHoveringAirUnit
end

---@see Spring.MoveCtrl.SetGunshipMoveTypeData
controlType.isGunshipMoveCtrlUnit = function(unitDef)
	return unitDef.isHoveringAirUnit
end

-- Unit scripts of different types may not share an interface.
local scriptType = {}

scriptType.isUnitScriptCOB = function(unitDef)
	local scriptName = unitDef.scriptName
	return scriptName and scriptName:lower():find(".cob$") or false
end

scriptType.isUnitScriptLUS = function(unitDef)
	local scriptName = unitDef.scriptName
	return scriptName and scriptName:lower():find(".lua$") or false
end

do
	UnitInfo.MoveScripts.moveType    = moveType
	UnitInfo.MoveScripts.controlType = controlType
	UnitInfo.MoveScripts.scriptType  = scriptType

	for _, tbl in ipairs { moveType, controlType, scriptType } do
		for key, value in pairs(tbl) do
			classifier[key] = value
		end
	end
end

-- Entity types ----------------------------------------------------------------

-- Units that are unlike units have types: critter, decoration, object, virtual.

classifier.isFakeUnit = function(unitDef)
	return unitDef.isFeature
end

classifier.isGaiaCritterUnit = function(unitDef)
	return isGaiaCritter(unitDef)
		and unitDef.canMove
		and not hasEconomicValue(unitDef)
		and not hasEconomicWreck(unitDef)
		and not canBeSensed(unitDef)
		and unitDef.customParms.nohealthbars
end

classifier.isGaiaDefenderUnit = function(unitDef)
	return isGaiaCritter(unitDef)
		and hasWeapon(unitDef)
end

classifier.isDecorationUnit = function(unitDef)
	return unitDef.category == "OBJECT"
		and not hasPhysicalInteraction(unitDef)
		and not hasPlayerInteraction(unitDef)
		and not hasEconomicValue(unitDef)
		and not hasEconomicWreck(unitDef)
		and not hasUnitAbility(unitDef)
		and not isAbilityTarget(unitDef)
		and not hasSenses(unitDef)
		and not canBeSensed(unitDef)
		and unitDef.customParams.nohealthbars
end

classifier.isObjectifiedUnit = function(unitDef)
	return unitDef.category == "OBJECT"
		and hasPhysicalInteraction(unitDef)
		and hasPlayerInteraction(unitDef)
		and not hasUnitAbility(unitDef)
		and isAbilityTarget(unitDef)
		and not hasSenses(unitDef)
		and canBeSensed(unitDef)
		and unitDef.customParams.nohealthbars
		and unitDef.customParams.removestop
		and unitDef.customParams.removewait
end

classifier.isVirtualizedUnit = function(unitDef)
	return unitDef.category == "OBJECT"
		and not hasPhysicalInteraction(unitDef)
		and not hasPlayerInteraction(unitDef)
		and hasUnitAbility(unitDef)
		and not isAbilityTarget(unitDef)
		and not hasSenses(unitDef)
		and not canBeSensed(unitDef)
end

classifier.entityType = function(unitDef)
	if classifier.isFakeUnit(unitDef) then
		return "Fake"
	elseif classifier.isDecorationUnit(unitDef) then
		return "Decoration"
	elseif classifier.isObjectifiedUnit(unitDef) then
		return "Object"
	elseif classifier.isVirtualizedUnit(unitDef) then
		return "Virtual"
	elseif classifier.isGaiaCritterUnit(unitDef) or classifier.isGaiaDefenderUnit(unitDef) then
		return "Critter"
	else
		return "Unit"
	end
end

-- Factions and sides ----------------------------------------------------------

classifier.side = function(unitDef)
	if isRaptorUnit(unitDef) then
		return "RAPTORS"
	elseif isScavengerUnit(unitDef) then
		return "SCAVENGERS"
	elseif isGaiaCritter(unitDef) then
		return "GAIA"
	else
		return getSide(unitDef)
	end
end

classifier.isAnyCommanderUnit = function(unitDef)
	return unitDef.customParams.iscommander
		or unitDef.customParams.isscavcommander
end

classifier.isDecoyCommanderUnit = function(unitDef)
	local decoy = classifier.decoyDef(unitDef)
	if decoy then
		return classifier.isAnyCommanderUnit(decoy)
	else
		return false
	end
end

classifier.isRestrictedUnit = function(unitDef)
	return unitDef.maxThisUnit == 0
end

-- GUI -------------------------------------------------------------------------

-- Scales

---General scaling to cover the radius without exceeding the unit's dimensions.
classifier.unitScaleSize = function(unitDef)
	local scale = (diag(unitDef.xsize, unitDef.zsize) + 1) * SQUARE_SIZE * 0.95
	if unitDef.canFly then
		scale = scale * 0.7
	end
	return scale
end

---General scaling to cover the building footprint with excess on all sides.
---Has to be oriented to match the unit heading (in case of xsize ~= zsize).
classifier.unitScaleFootprint = function(unitDef)
	if unitDef.isImmobile then
		return {
			(unitDef.xsize * 1.025 + 1.5) * SQUARE_SIZE,
			(unitDef.zsize * 1.025 + 1.5) * SQUARE_SIZE,
		}
	end
end

---General scaling to add icons or text over a unit without obscuring it.
classifier.unitScaleIcon = function(unitDef)
	local scale = diag(unitDef.xsize, unitDef.zsize) * SQUARE_SIZE * 0.3
	return scale + SQUARE_SIZE - 1
end

--------------------------------------------------------------------------------
-- Export module ---------------------------------------------------------------

return UnitInfo
