-------------------------------------------------------------- [UnitInfo.lua] --
-- Unit classification and property caching, handled in a centralized module. --

if not UnitDefs or not Game then
	return false
end

---Provides definitions and classifiers for many unit properties and groupings.
---@module UnitInfo
local UnitInfo = {}

--------------------------------------------------------------------------------
-- Module configuration --------------------------------------------------------

-- The cached property tables support two layout strategies:
-- - `sparse` layout produces hash sets that treat `false` and zeroes as `nil`.
-- - `sequential` layout produces dense arrays for faster direct memory access.
local CACHE_TABLE_LAYOUT = "sparse" ---@type "sparse"|"sequential"

--------------------------------------------------------------------------------
-- Module cache ----------------------------------------------------------------

-- Strip trivial, false, and empty values to produce a sparse-er set.
-- Properties with e.g. meaningful zeroes should use `AddCacheValue`.
-- todo: This should be done after all values are determined, not per-value.
-- todo: Eg. if a set contains only nil's and false's, then remap the table.
local function sparsify(value)
	if value ~= nil then
		if type(value) == "table" then
			if not next(value) then
				return
			else
				value = table.copy(value)
			end
		elseif type(value) == "string" then
			-- behold:
			if value == "" or value == "nil" then
				return
			elseif value == "true" then
				return true
			elseif value == "false" then
				return false
			end
			local number = tonumber(value)
			if number ~= nil then
				value = number
			end
		end
		if value ~= false and value ~= "false" and value ~= 0 and value ~= "0" then
			return value
		end
	end
end

-- Create sequential arrays for faster lookups via sequential addressing.
-- Properties that default to `true` on `nil` should use `AddCacheValue`.
-- todo: This also should be done as a whole-table layout, not per-value.
-- todo: Adding this note, since otherwise the WIP approach is confusing.
local function solidify(value)
	return value == nil and false or value
end

local tableCreate = {
	sparse     = function() return table.new(0, 4) end,
	sequential = function() return table.new(#UnitDefs, 0) end,
}

local tableLayout = {
	sparse     = sparsify,
	sequential = solidify,
}

local create = tableCreate[CACHE_TABLE_LAYOUT] or tableCreate.sparse
local layout = tableLayout[CACHE_TABLE_LAYOUT] or tableLayout.sparse

-- The original module was monkey-patchable, but it was a pain to upkeep.
-- I use locals `cache` and `classifiers`, not `Cache` and `Classifiers`.
-- See "How I write Lua modules", from https://blog.separateconcerns.com.

local cache = {}
local classifiers = {}

setmetatable(cache, {
	-- Values that are not in the cache get cached automatically.
	__index = function(self, key)
		if type(key) == "string" then
			local values = create()
			if classifiers[key] then
				local pred = classifiers[key]
				for unitDefID, unitDef in ipairs(UnitDefs) do
					values[unitDefID] = layout(pred(unitDef))
				end
			else
				local lower = key:lower()
				for unitDefID, unitDef in ipairs(UnitDefs) do
					local value = unitDef[key]
					if value == nil then
						value = unitDef.customParams[lower]
					end
					values[unitDefID] = layout(value)
				end
			end
			rawset(self, key, values)
			return values
		end
	end
})

---Add (or get) a shared table of <unitDefID, value> pairs to (and from) cache.
---@param name string
---@param predicate function|table
---@return table? values
---@return boolean? added
local function CacheValue(name, predicate)
	if rawget(cache, name) ~= nil then
		return cache[name], false
	elseif type(predicate) == "function" then
		local values = {}
		for unitDefID, unitDef in ipairs(UnitDefs) do
			values[unitDefID] = predicate(unitDef)
		end
		cache[name] = values
		return values, true
	elseif type(predicate) == "table" then
		cache[name] = predicate
		return predicate, true
	end
end

---Set whether or not the individual cache tables are garbage collected.
---@param collected boolean
local function SetModuleCacheMode(collected)
	if collected then
		for _, name in ipairs { "Cache", "Classifiers", "MoveScripts" } do
			local subtable = UnitInfo[name]; -- load-bearing semicolon
			(getmetatable(subtable) or setmetatable(subtable, {})).__mode = "kv"
		end
	else
		for _, name in ipairs { "Cache", "Classifiers", "MoveScripts" } do
			local subtable = UnitInfo[name]
			local mt = getmetatable(subtable)
			if table.count(mt) == 1 and mt.__mode then
				setmetatable(subtable, nil) -- strip the metatable when we can
			else
				mt.__mode = ""
			end
		end
	end
end

-- Simple rule to follow: If you need it later, stash it into a local variable.
SetModuleCacheMode(true)

--------------------------------------------------------------------------------
-- Module internals ------------------------------------------------------------

local SIDES = VFS.Include("sides_enum.lua") or {}

for key, value in pairs(SIDES) do
	SIDES[value] = key
end

local SPEEDMOD = Game.speedModClasses

-- Dimensions

local FOOTPRINT = Game.squareSize * Game.footprintScale
-- - Vision: Less is "self-vision" to show CEGs when hit in fog.
-- - Range: Equal or less is self-range or detonator range.
local SELF_RANGE = 10

-- From movedefs.lua:
local DEPTH_AMPHIBIOUS = 5000
local SLOPE_MAX = {
	BOT = math.rad(54),
	VEH = math.rad(27),
}

-- Generally accepted:
local METAL_TO_ENERGY = 60
local METAL_TO_WORKER = 200

-- Local functions

local function hasPositiveValue(key, value)
	return type(value) == "number" and value > 0
end

-- Lexical scope fixes:
local hasWeapon                                                     -- isSpecialUpgrade
local isSpamUnit, isUnusualUnit, isVisionBuilding, isJammerBuilding -- isJunoDamageTarget

---Coerce string-ified customParams to boolean
---@return boolean?
local function customBool(value)
	if value == nil or value == false or value == "false" or value == 0 or value == "0" then
		return false
	elseif value == true or value == "true" or value == 1 or value == "1" then
		return true
	end
end

---Coerce string-ified customParams to number
---@return number
local function customNumber(value, default)
	return value ~= nil and tonumber(value) or (default or 0)
end

local function getSideCode(name)
	return SIDES[name:sub(1, 3):lower()]
end

-- todo: helper for cases like this with build trees?
---@type function|nil
local function getStartUnitFn()
	local config = Spring.GetTeamRulesParam(myTeamID, "validStartUnits") or Spring.GetGameRulesParam("validStartUnits")
	if config ~= nil then
		local sideConfig = string.split(config, "|")
		if sideConfig ~= nil and #sideConfig > 0 then
			local unitDefToSideID = {}
			for i, name in ipairs(sideConfig) do
				local unitDef = name and UnitDefNames[name]
				if unitDef ~= nil then
					unitDefToSideID[UnitDefNames[name].id] = getSideCode(unitDef.name) or i
				end
			end
			return function(unitDef) return unitDefToSideID[unitDef.id] end
		end
	end
	-- Fallback attempt. This should be an error condition, most likely.
	return function(unitDef) return customBool(unitDef.customParams.iscommander) end
end

local function metalEquivalence(unitDef)
	return unitDef.metalCost
		+ unitDef.energyCost / METAL_TO_ENERGY
		+ unitDef.buildTime / METAL_TO_WORKER
end

-- source: I made it up
local function spamRating(unitDef)
	return unitDef.speed * 4
		+ unitDef.sightDistance / 4
		- metalEquivalence(unitDef) * 6
end

---Some units have "unused" weapon defs that serve other purposes, which we ignore.
local function equipsDef(unitDef, weaponDefID)
	for _, weapon in ipairs(unitDef.weapons) do
		if weapon.weaponDef == weaponDefID then
			return true
		end
	end
	return false
end

---Some weapons, like the Juno, are exceptional cases. Should this include them?
local function hasDamage(weaponDef)
	local custom = weaponDef.customParams
	if custom.bogus then
		return false
	elseif weaponDef.damages and table.any(weaponDef.damages, hasPositiveValue) then
		return true
	elseif custom.spark_basedamage or custom.spawns_name then
		return true
	elseif custom.cluster_def then
		local cluster = WeaponDefNames[custom.cluster_def]
		return cluster and hasDamage(cluster)
	elseif custom.dronename then
		local drone = UnitDefNames[custom.dronename]
		return drone and drone.weapons[1] and hasDamage(drone.weapons[1])
	else
		return false
	end
end

--------------------------------------------------------------------------------
-- Unit classification ---------------------------------------------------------

-- General classifiers ---------------------------------------------------------

-- Interactivity

---Excludes obvious "abilities", like self-destructing, that we'd rather ignore.
-- todo: Factories can "move" and "attack" but only as a way to give unit orders
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
		or (unitDef.colliding and unitDef.isAirUnit)
		or unitDef.pushResistant
end

local function hasPlayerInteraction(unitDef)
	return unitDef.selectable
end

local function hasSenses(unitDef)
	return unitDef.sightDistance > SELF_RANGE
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

-- Identification

local function isGaiaCritter(unitDef)
	return unitDef.customParams.iscritter or unitDef.name:sub(1, 7) == "critter"
end

local function isRaptorUnit(unitDef)
	return unitDef.customParams.israptor or unitDef.name:sub(1, 6) == "raptor"
end

local function isScavengerUnit(unitDef)
	return unitDef.customParams.isscavenger or unitDef.name:sub(-5, -1) == "_scav"
end

local function side(unitDef)
	if isRaptorUnit(unitDef) then
		return "RAPTORS"
	elseif isScavengerUnit(unitDef) then
		return "SCAVENGERS"
	elseif isGaiaCritter(unitDef) then
		return "GAIA"
	else
		return getSideCode(unitDef.name)
	end
end

-- todo:  Should there be a declarative way to add decoys to a cached set, e.g.:
-- todo:  `local isAnyCommander = UnitInfo.Cache.IncludeDecoys.isCommanderUnit`
-- todo:  or does `CacheValue` cover that use case more appropriately?
local function decoyDef(unitDef)
	if unitDef.customParams.decoyfor then
		return UnitDefNames[unitDef.customParams.decoyfor]
	end
end

local function isCommanderUnit(unitDef)
	return customBool(unitDef.customParams.iscommander)
		or customBool(unitDef.customParams.isscavcommander)
end

local function isDecoyCommanderUnit(unitDef)
	local decoy = decoyDef(unitDef)
	if decoy then
		return isCommanderUnit(decoy)
	else
		return false
	end
end

local function isAnyCommanderUnit(unitDef)
	return isCommanderUnit(unitDef)
		or isDecoyCommanderUnit(unitDef)
end

-- Buildability

local function dimension(unitDef)
	return {
		unitDef.xsize * FOOTPRINT,
		unitDef.height,
		unitDef.zsize * FOOTPRINT,
		unitDef.radius
	}
end

local function footprint(unitDef)
	return { unitDef.xsize, unitDef.zsize }
end

local function footprintSize(unitDef)
	return { unitDef.xsize * FOOTPRINT, unitDef.zsize * FOOTPRINT }
end

local function needsGeothermal(unitDef)
	return unitDef.needGeo or customBool(unitDef.customParams.geothermal)
end

local function needsWater(unitDef)
	return unitDef.minWaterDepth > 0
end

local function isRestrictedUnit(unitDef)
	return unitDef.maxThisUnit == 0 -- todo: other restriction methods?
end

local function isStartUnit(unitDef)
	if getStartUnitFn then
		local fn = getStartUnitFn()
		getStartUnitFn = nil
		classifiers.isStartUnit = fn
		return fn(unitDef)
	end
end

-- Tech and upgrades

local function baseTechLevel(unitDef)
	return math.floor(customNumber(unitDef.customParams.techlevel, 1))
end

local function isTech1(unitDef)
	return baseTechLevel(unitDef) == 1
end

local function isTech2(unitDef)
	return baseTechLevel(unitDef) == 2
end

local function isTech3(unitDef)
	return baseTechLevel(unitDef) == 3
end

local function isTech4(unitDef)
	return baseTechLevel(unitDef) == 4
end

local function isTech5(unitDef)
	return baseTechLevel(unitDef) == 5
end

local function isSpecialTech(unitDef)
	return baseTechLevel(unitDef) ~= customNumber(unitDef.customParams.techlevel, 1)
end

local function isSpecialUpgrade(unitDef)
	-- For now, this includes only the special-tech extractors:
	return (unitDef.extractsMetal > 0 or needsGeothermal(unitDef))
		and (unitDef.stealth or hasWeapon(unitDef)
		-- todo: should be a customparam, but is not
		or (unitDef.customParams.attached_builder_def and UnitDefNames[unitDef.customParams.attached_builder_def]))
		-- todo: should be a customparam, but is not
		or customNumber(unitDef.customParams.techupgrade) ~= nil
end

local function extractionRating(unitDef)
	return (unitDef.extractsMetal or needsGeothermal(unitDef))
		and unitDef.extractsMetal * 100 * 4.3 + -- strong-mex equivalent
		(unitDef.metalMake - unitDef.metalUpkeep) + -- sure
		(unitDef.energyMake - unitDef.energyUpkeep) / METAL_TO_ENERGY
end

-- Unit creation

---Compare against isMobileBuilder
local function isConstructionUnit(unitDef)
	return not unitDef.isImmobile
		and unitDef.isBuilder
		and unitDef.canAssist
		and next(unitDef.buildOptions)
end

local function isConstructionTurret(unitDef)
	return unitDef.isBuilder and unitDef.movementClass == "NANO"
		and unitDef.isImmobile and not unitDef.isFactory
end

local function canCreateUnits(unitDef)
	return next(unitDef.buildOptions) or unitDef.canResurrect
end

local function isReplicatorUnit(unitDef)
	return unitDef.buildOptions[1] == unitDef.id and #unitDef.buildOptions[2] == nil
end

-- todo: go back through and use more focused build lists
local function factoryBuildOptions(unitDef)
	return unitDef.isFactory and unitDef.buildOptions
end

-- todo: go back through and use more focused build lists
local function workerBuildOptions(unitDef)
	return isConstructionUnit(unitDef)
		and unitDef.buildOptions
end

-- Economic

local function unitCosts(unitDef)
	local metal, energy, build = unitDef.metalCost, unitDef.energyCost, unitDef.buildTime
	return { metal, energy, build, metal = metal, energy = energy, build = build }
end

local function metalCostTotal(unitDef)
	return unitDef.metalCost + unitDef.energyCost / METAL_TO_ENERGY
end

local function energyCostTotal(unitDef)
	return unitDef.metalCost * METAL_TO_ENERGY + unitDef.energyCost
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

local function storageAmounts(unitDef)
	if unitDef.metalStorage > 0 or unitDef.energyStorage > 0 then
		local metal, energy = unitDef.metalStorage, unitDef.energyStorage
		return { metal, energy, metal = metal, energy = energy }
	end
end

-- Weapons

hasWeapon = function(unitDef)
	for _, weapon in ipairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if equipsDef(unitDef, weaponDef.id) and hasDamage(weaponDef) then
			return true
		end
	end
	return false
end

local function deathExplosionWeapon(unitDef)
	if unitDef.deathExplosion then
		return WeaponDefNames[unitDef.deathExplosion]
	end
end

local function selfDExplosionWeapon(unitDef)
	if unitDef.selfDExplosion then
		return WeaponDefNames[unitDef.selfDExplosion]
	end
end

local function hasAntiAirWeapon(unitDef)
	for _, weapon in ipairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if equipsDef(unitDef, weaponDef.id) and hasDamage(weaponDef) then
			if weapon.onlyTargets and weapon.onlyTargets.vtol then
				return true
			end
		end
	end
	return false
end

local function hasBomberWeapon(unitDef)
	-- NB: This does not test if the unit is an air unit.
	for _, weapon in ipairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if equipsDef(unitDef, weaponDef.id) and hasDamage(weaponDef) and (
				weaponDef.type == "AircraftBomb" or
				(weaponDef.type == "TorpedoLauncher" and weaponDef.customParams.speceffect == "torpwaterpen") or
				-- Some other thing with this profile:
				weapon.badTargets.mobile and (
					weaponDef.canAttackGround and (weapon.onlyTargets.surface or weapon.onlyTargets.notair) or
					weaponDef.canAttackWater and (weapon.onlyTargets.ship or weapon.onlyTargets.underwater)
				)
			)
		then
			return true
		end
	end
	return false
end

local function hasInterceptableWeapon(unitDef)
	for i = 1, #unitDef.weapons do
		local weaponDef = WeaponDefs[unitDef.weapons[i].weaponDef]
		if weaponDef.targetable > 0 and equipsDef(unitDef, weaponDef.id) then
			return true
		end
	end
	return false
end

local function hasInterceptorWeapon(unitDef)
	for i = 1, #unitDef.weapons do
		local weaponDef = WeaponDefs[unitDef.weapons[i].weaponDef]
		if weaponDef.interceptor and weaponDef.interceptor ~= 0 and equipsDef(unitDef, weaponDef.id) then
			return true
		end
	end
	return false
end

local function hasParalyzerWeapon(unitDef)
	for i = 1, #unitDef.weapons do
		local weaponDef = WeaponDefs[unitDef.weapons[i].weaponDef]
		if weaponDef.paralyzer and hasDamage(weaponDef) and equipsDef(unitDef, weaponDef.id) then
			return true
		end
	end
	return false
end

local function shieldPower(unitDef)
	if unitDef.shieldWeaponDef then
		local weaponDef = WeaponDefs[unitDef.shieldWeaponDef]
		if weaponDef and equipsDef(unitDef, weaponDef.id) then
			return weaponDef.shieldPower
		end
	end
end

local function stockpileLimit(unitDef)
	if unitDef.canStockpile then
		local stockpileSize = 0
		for _, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef.stockpile then
				stockpileSize = math.max(stockpileSize, customNumber(weaponDef.customParams.stockpilelimit))
			end
		end
		return stockpileSize > 0 and stockpileSize or 99 -- 100 is the hard limit
	end
end

local function hasAreaDamageWeapon(unitDef)
	if unitDef.customParams.area_ondeath_ceg then
		if unitDef.selfDExplosion and WeaponDefNames[unitDef.selfDExplosion] then
			return true
		elseif unitDef.deathExplosion and WeaponDefNames[unitDef.deathExplosion] then
			return true
		end
	end
	for i = 1, #unitDef.weapons do
		local weapon = unitDef.weapons[i]
		if weapon.customParams.area_onhit_ceg then
			return true
		end
	end
	return false
end

local function onlyTargetCategory(unitDef)
	local value
	for _, weapon in ipairs(unitDef.weapons) do
		local target = next(weapon.onlyTargets)
		if target and next(weapon.onlyTargets, target) == nil then
			if value == nil then
				value = target
			elseif value ~= target then
				return
			end
		else
			return
		end
	end
	return value
end

-- Damages

local function isParalyzeImmune(unitDef)
	return not unitDef.modCategories.empable
end

local function paralyzeMultiplier(unitDef)
	return customNumber(unitDef.customParams.paralyzemultiplier, 1)
end

local function areaDamageResistance(unitDef)
	local resistance = unitDef.customParams.areadamageresistance
	return resistance and string.lower(resistance)
end

local function isJunoDamageTarget(unitDef)
	return not isUnusualUnit(unitDef) and (
		customBool(unitDef.customParams.juno_damage_target)
		or customBool(unitDef.customParams.mine)
		or isSpamUnit(unitDef)
		or not hasWeapon(unitDef) and (isVisionBuilding(unitDef) or isJammerBuilding(unitDef))
	)
end

-- Unit groups

local function isEnergyConverter(unitDef)
	return customNumber(unitDef.customParams.energyconv_capacity) > 0
		and customNumber(unitDef.customParams.energyconv_efficiency) > 0
end

local function isEconomicUnit(unitDef)
	return unitDef.metalMake > 0
		or unitDef.energyMake > 5
		or unitDef.energyUpkeep < 0
		or unitDef.windGenerator > 0
		or unitDef.tidalGenerator > 0
		or isEnergyConverter(unitDef)
end

local function isRadarBuilding(unitDef)
	return unitDef.isImmobile and unitDef.radarDistance > SELF_RANGE
end

isVisionBuilding = function(unitDef)
	return unitDef.isImmobile
		and (
			unitDef.radarDistance > SELF_RANGE or
			(unitDef.canCloak and unitDef.sightDistance > SELF_RANGE)
		)
end

isJammerBuilding = function(unitDef)
	return unitDef.isImmobile
		and (unitDef.radarDistanceJam > 0 or unitDef.sonarDistanceJam > 0)
end

local function isBaseRaidTargetUnit(unitDef)
	return unitDef.isImmobile
		and isEconomicUnit(unitDef)
		-- For reasons unknown:
		and unitDef.extractsMetal <= 0
		and not needsGeothermal(unitDef)
		and not hasWeapon(unitDef)
end

local function isDefensiveStructureUnit(unitDef)
	if unitDef.isImmobile then
		for _, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef.range > SELF_RANGE and equipsDef(unitDef, weaponDef.id) and hasDamage(weaponDef) then
				return true
			end
		end
	end
	return false
end

local function isLongRangeCannonUnit(unitDef)
	if unitDef.isImmobile then
		local longRange = 2500 -- arbitrary
		for _, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef.type == "Cannon" and weaponDef.range > longRange and
				equipsDef(unitDef, weaponDef.id) and hasDamage(weaponDef)
			then
				return true
			end
		end
	end
	return false
end

isSpamUnit = function(unitDef)
	local score = spamRating(unitDef)
	return score > 0
end

-- Domain

local function needsMapLand(unitDef)
	return not unitDef.canFly and unitDef.minWaterDepth < 0
end

local needsMapWater
do
	-- Units also require map water when they are combat units with:
	-- - only weapons that can fire only while underwater
	-- - only weapons that can target only units that are underwater
	-- - only weapons that can target only categories restricted to water
	-- - only weapons that can damage only water targets (ignoring this)
	local customWaterWeapon = {
		cannonwaterpen = true,
		torpwaterpen   = true,
	}
	local waterTargetCategory = {
		canbeuw    = true,
		ship       = true,
		underwater = true,
	}
	local function inWaterCategory(v) -- dumb
		return waterTargetCategory[v]
	end

	needsMapWater = function(unitDef)
		if unitDef.minWaterDepth > 0 then
			return true
		else
			for _, weapon in ipairs(unitDef.weapons) do
				if equipsDef(unitDef, weapon.weaponDef) then
					local weaponDef = WeaponDefs[weapon.weaponDef]
					local waterWeaponOnly = false

					-- Must fire from water.
					if weaponDef.waterWeapon then
						waterWeaponOnly = true
					else
						local effect = weaponDef.customParams.speceffect
						if effect and customWaterWeapon[effect] then
							waterWeaponOnly = true
						end
					end

					-- May target out of water.
					if weaponDef.submissile then
						waterWeaponOnly = false
					end

					-- Must target water units.
					if table.filterTable(weapon.onlyTargets, inWaterCategory)[1] then
						waterWeaponOnly = true
					end

					if not waterWeaponOnly then
						return false
					end
				end
			end
			return true
		end
	end
end

local function isLandUnit(unitDef)
	-- todo: Should this be so exclusive? Are amphibious units not land units?
	return unitDef.minWaterDepth < 0 and not unitDef.canFly and not unitDef.canSubmerge
end

local function isWaterUnit(unitDef)
	return unitDef.modCategories.ship
end

local function isUnderwaterUnit(unitDef)
	return unitDef.modCategories.underwater
end

local function isHoverUnit(unitDef)
	return unitDef.modCategories.hover
end

-- MoveCtrl and moveType

local function isImmobileUnit(unitDef)
	return unitDef.isImmobile
		and (not unitDef.yardmap or unitDef.yardmap == "")
		and not unitDef.isFactory -- Treat factories as structures regardless?
end

local function isStructureUnit(unitDef)
	return unitDef.isImmobile
		and ((unitDef.yardmap and unitDef.yardmap ~= "") or unitDef.isFactory)
end

local function isInanimateUnit(unitDef)
	return unitDef.isImmobile
		and not hasWeapon(unitDef)
		and not hasUnitAbility(unitDef)
		and not unitDef.windGenerator -- lol
	-- todo: I mean, mexes and radars "animate". So?
end

---@see Spring.MoveCtrl.SetGroundMoveTypeData
local function isGroundMoveCtrlUnit(unitDef)
	local speedMod = unitDef.moveDef and unitDef.moveDef.speedModClass
	return speedMod == SPEEDMOD.KBot
		or speedMod == SPEEDMOD.Tank
		or speedMod == SPEEDMOD.Hover
end

---@see Spring.MoveCtrl.SetAirMoveTypeData
local function isAirMoveCtrlUnit(unitDef)
	return unitDef.canFly and not unitDef.isHoveringAirUnit
end

---@see Spring.MoveCtrl.SetGunshipMoveTypeData
local function isGunshipMoveCtrlUnit(unitDef)
	return unitDef.isHoveringAirUnit
end

-- Why does this exist.
local function moveType(unitDef)
	if unitDef.isHoveringAirUnit then
		return 1 -- gunship
	elseif unitDef.isAirUnit then
		return 0 -- fixedwing
	elseif not unitDef.isImmobile then
		return 2 -- ground/sea
	end
end

local function moveTypeDisplayName(unitDef)
	if unitDef.isImmobile then
		if unitDef.yardmap and unitDef.yardmap ~= "" then
			return "Structure"
		else
			return "Immobile"
		end
	end

	if isRaptorUnit(unitDef) then
		if unitDef.isAirUnit then
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

	if moveDef.smClass == SPEEDMOD.Ship then
		return "Ship"
	elseif moveDef.isSubmarine then
		return "Submarine"
	end

	local slope = moveDef.maxSlope

	if slope > SLOPE_MAX.BOT then
		return "All-Terrain"
	elseif moveDef.smClass == SPEEDMOD.Hover then
		if slope > SLOPE_MAX.VEH then
			return "Hoverbot"
		else
			return "Hovercraft"
		end
	elseif moveDef.depth >= DEPTH_AMPHIBIOUS then
		return "Amphibious"
	elseif moveDef.smClass == SPEEDMOD.KBot then
		if slope > SLOPE_MAX.VEH then
			return "Bot"
		else
			return "Walker"
		end
	else
		return "Vehicle"
	end
end

-- Script type

local function isUnitScriptCOB(unitDef)
	local scriptName = unitDef.scriptName
	return scriptName and scriptName:lower():find(".cob$") and true or false
end

local function isUnitScriptLUS(unitDef)
	local scriptName = unitDef.scriptName
	return scriptName and scriptName:lower():find(".lua$") and true or false
end

-- Animations

local function hasDeathAnimation(unitDef)
	-- Units can do this with `GetScriptEnv`, for example. It's harder for Defs:
	local scriptName = unitDef.scriptName
	if not scriptName then
		return false
	else
		scriptName = scriptName:lower():gsub(".cob$", ".bos")
	end

	if not VFS.FileExists(scriptName) then
		return false
	end

	local files = { scriptName }

	-- We require both the Killed and DeathAnim methods:
	local hasKilled = false
	local hasAnim = false
	local useAnim = false

	-- Must not match lines like "//use call-script DeathAnim(); from Killed()"
	-- though such a comment pretty strongly implies these methods are present.
	local path = [[^#include "([^"]+])"]]
	local kill = "Killed%(%)"
	local has, use
	if isUnitScriptCOB(unitDef) then
		has = "^DeathAnim%("
		use = "^%s*call-script DeathAnim%(%s?%);"
	elseif isUnitScriptLUS(unitDef) then
		has = "f[%a]function DeathAnim%s?%(%s?%)"
		use = "DeathAnim%(%s?%)"
	else
		return false
	end

	for _, file in ipairs(files) do
		local data = VFS.LoadFile(file)
		if data then
			---@diagnostic disable-next-line -- OK
			for _, line in ipairs(string.lines(data)) do
				if not hasKilled and line:find(kill) then
					hasKilled = true
				elseif not hasAnim and line:find(has) then
					hasAnim = true
				elseif not useAnim and line:find(use) then
					useAnim = true
				else
					local _, _, include = line:find(path)
					if include and not table.getKeyOf(files, include:lower()) then
						files[#files + 1] = include:lower()
					end
				end
			end
			if hasKilled and hasAnim and useAnim then
				return true
			end
		end
	end

	return false
end

-- Air units

---Determines bombers more generally (e.g. Phoenix) than `isBomberAirUnit`.
local function isAnyBomberAirUnit(unitDef)
	return unitDef.isAirUnit and hasBomberWeapon(unitDef)
end

---Determines air superiority fighters more strictly than `isFighterAirUnit`.
local function isStrafeFighterAirUnit(unitDef)
	return unitDef.isStrafeFighterUnit and hasAntiAirWeapon(unitDef)
end

local function isStrafeBomberAirUnit(unitDef)
	return unitDef.isStrafeFighterUnit and hasBomberWeapon(unitDef)
end

local function canCrash(unitDef)
	return unitDef.isAirUnit and customBool(unitDef.customParams.crashable)
end

local function airTargetCategory(unitDef)
	if unitDef.isAirUnit then
		if unitDef.isBuilder or unitDef.isTransport then
			return "VTOL"
		elseif hasBomberWeapon(unitDef) then
			return "Bomber"
		elseif hasAntiAirWeapon(unitDef) then
			return "Fighter"
		elseif hasWeapon(unitDef) then
			return "VTOL"
		else
			return "Scout"
		end
	end
end

local function isAirTransport(unitDef)
	return unitDef.isAirUnit and unitDef.isTransport
end

local function isParatrooperUnit(unitDef)
	return customBool(unitDef.customParams.paratrooper)
end

-- Entity types

-- Units that are unlike units have types: critter, decoration, object, virtual.

local function isFakeUnit(unitDef)
	return unitDef.isFeature
end

local function isGaiaCritterUnit(unitDef)
	return isGaiaCritter(unitDef)
		and unitDef.canMove
		and not hasEconomicValue(unitDef)
		and not hasEconomicWreck(unitDef)
		and not canBeSensed(unitDef)
		and unitDef.customParms.nohealthbars
end

local function isGaiaDefenderUnit(unitDef)
	return isGaiaCritter(unitDef)
		and hasWeapon(unitDef)
end

local function isDecorationUnit(unitDef)
	return unitDef.category == "OBJECT"
		and not hasPhysicalInteraction(unitDef)
		and not hasPlayerInteraction(unitDef)
		and not hasEconomicValue(unitDef)
		and not hasEconomicWreck(unitDef)
		and not hasUnitAbility(unitDef)
		and not isAbilityTarget(unitDef)
		and not hasSenses(unitDef)
		and not canBeSensed(unitDef)
		and customBool(unitDef.customParams.nohealthbars)
end

local function isObjectifiedUnit(unitDef)
	return unitDef.category == "OBJECT"
		and hasPhysicalInteraction(unitDef)
		and hasPlayerInteraction(unitDef)
		and not hasUnitAbility(unitDef)
		and isAbilityTarget(unitDef)
		and not hasSenses(unitDef)
		and canBeSensed(unitDef)
		and customBool(unitDef.customParams.nohealthbars)
		and customBool(unitDef.customParams.removestop)
		and customBool(unitDef.customParams.removewait)
end

local function isVirtualizedUnit(unitDef)
	return unitDef.category == "OBJECT"
		and not hasPhysicalInteraction(unitDef)
		and not hasPlayerInteraction(unitDef)
		and hasUnitAbility(unitDef)
		and not isAbilityTarget(unitDef)
		and not hasSenses(unitDef)
		and not canBeSensed(unitDef)
end

local function isAutonomousUnit(unitDef)
	return customBool(unitDef.customParams.drone)
		or (hasPhysicalInteraction(unitDef)
			and not hasPlayerInteraction(unitDef)
			and hasUnitAbility(unitDef)
			and isAbilityTarget(unitDef)
			and hasSenses(unitDef)
			and canBeSensed(unitDef))
end

local function entityType(unitDef)
	if isFakeUnit(unitDef) then
		return "Fake"
	elseif isDecorationUnit(unitDef) then
		return "Decoration"
	elseif isObjectifiedUnit(unitDef) then
		return "Object"
	elseif isVirtualizedUnit(unitDef) then
		return "Virtual"
	elseif isGaiaCritter(unitDef) then
		return "Critter"
	elseif isAutonomousUnit(unitDef) then
		return "Autonomous"
	else
		return "Unit"
	end
end

isUnusualUnit = function(unitDef)
	return entityType(unitDef) ~= "Unit"
end

-- State functions -------------------------------------------------------------

local function isIdleConstructor(unitID)
	return Spring.GetUnitCommandCount(unitID) == 0
end

local function isIdleFactory(unitID)
	return Spring.GetFactoryCommandCount(unitID) == 0
end

local function isIdleBuilderUnit(unitDef)
	if not canCreateUnits(unitDef) or isReplicatorUnit(unitDef) then
		return
	elseif unitDef.canCloak and unitDef.stealth then
		return -- Infiltrator
	elseif isUnusualUnit(unitDef) then
		return
	end

	if unitDef.isFactory then
		return isIdleFactory
	elseif not unitDef.isImmobile then
		return isIdleConstructor -- excludes turrets
	end
end

local function isIdleCombatant(unitID)
	return Spring.GetUnitCommandCount(unitID) == 0
		and Spring.GetUnitWeaponTarget(unitID, 1) == nil
end

local function isIdleCombatantUnit(unitDef)
	if hasWeapon(unitDef) and not unitDef.isImmobile and not isUnusualUnit(unitDef) then
		return isIdleCombatant
	end
end

-- GUI -------------------------------------------------------------------------

-- todo: unit icon bitmaps, textures, normals

-- Scales

-- todo: demagicify the coefficients and constants [?]
-- todo: check that everything is the same as before [?]

---General scaling to cover the radius without exceeding the unit's dimensions.
local function unitScaleSize(unitDef)
	local scale = FOOTPRINT * ((math.diag(unitDef.xsize, unitDef.zsize) + 1) * 0.5) * 0.95
	if unitDef.canFly then
		scale = scale * 0.7
	end
	return scale
end

---General scaling to cover the building footprint with excess on all sides.
---Has to be oriented to match the unit heading (in case of xsize ~= zsize).
local function unitScaleFootprint(unitDef)
	if unitDef.isImmobile then
		return {
			FOOTPRINT * (unitDef.xsize * 1.025 + 1.5) * 0.5,
			FOOTPRINT * (unitDef.zsize * 1.025 + 1.5) * 0.5,
		}
	end
end

---General scaling to add icons or text over a unit without obscuring it.
local function unitScaleIcon(unitDef)
	local scale = math.diag(unitDef.xsize, unitDef.zsize) * 0.15
	return FOOTPRINT * (scale + 0.5) - 1
end

--------------------------------------------------------------------------------
-- Export module ---------------------------------------------------------------

UnitInfo.CacheValue = CacheValue
UnitInfo.SetModuleCacheMode = SetModuleCacheMode

---Cached unit properties, indexed by unitDefID.
--
-- Depending on current module settings, these form either hash sets or arrays.
--
-- You can access any UnitDef property by name. When a property is not found,
-- the name is cast to lowercase, and the customParams are searched instead.
--
-- You also have access to all the named classifiers (see UnitInfo.Classifiers).
---@type table<string, table>
UnitInfo.Cache = cache

---Functions for deriving unit properties from their UnitDef table.
--
-- You can use these for init or testing, but many are over-thorough and slow.
-- The better method is to cache their results by going through UnitInfo.Cache.
--
-- Example usage: `local isCommander = UnitInfo.Cache.isCommanderUnit`.
UnitInfo.Classifiers = {
	-- Interactivity
	hasUnitAbility           = hasUnitAbility,
	isAbilityTarget          = isAbilityTarget,
	hasPhysicalInteraction   = hasPhysicalInteraction,
	hasPlayerInteraction     = hasPlayerInteraction,
	hasSenses                = hasSenses,
	canBeSensed              = canBeSensed,

	-- Identification
	isGaiaCritter            = isGaiaCritter,
	isRaptorUnit             = isRaptorUnit,
	isScavengerUnit          = isScavengerUnit,
	side                     = side,
	decoyDef                 = decoyDef,
	isCommanderUnit          = isCommanderUnit,
	isDecoyCommanderUnit     = isDecoyCommanderUnit,
	isAnyCommanderUnit       = isAnyCommanderUnit,

	-- Buildability
	dimension                = dimension,
	footprint                = footprint,
	footprintSize            = footprintSize,
	needsGeothermal          = needsGeothermal,
	needsWater               = needsWater,
	isRestrictedUnit         = isRestrictedUnit,
	isStartUnit              = isStartUnit,

	-- Tech and upgrades
	baseTechLevel            = baseTechLevel,
	isTech1                  = isTech1,
	isTech2                  = isTech2,
	isTech3                  = isTech3,
	isTech4                  = isTech4,
	isTech5                  = isTech5,
	isSpecialTech            = isSpecialTech,
	isSpecialUpgrade         = isSpecialUpgrade,
	extractionRating         = extractionRating,

	-- Unit creation
	isConstructionUnit       = isConstructionUnit,
	isConstructionTurret     = isConstructionTurret,
	canCreateUnits           = canCreateUnits,
	isReplicatorUnit         = isReplicatorUnit,
	factoryBuildOptions      = factoryBuildOptions,
	workerBuildOptions       = workerBuildOptions,

	-- Economic
	unitCosts                = unitCosts,
	metalCostTotal           = metalCostTotal,
	energyCostTotal          = energyCostTotal,
	hasEconomicValue         = hasEconomicValue,
	hasEconomicWreck         = hasEconomicWreck,
	storageAmounts           = storageAmounts,

	-- Weapons
	hasWeapon                = hasWeapon,
	deathExplosionWeapon     = deathExplosionWeapon,
	selfDExplosionWeapon     = selfDExplosionWeapon,
	hasAntiAirWeapon         = hasAntiAirWeapon,
	hasBomberWeapon          = hasBomberWeapon,
	hasInterceptableWeapon   = hasInterceptableWeapon,
	hasInterceptorWeapon     = hasInterceptorWeapon,
	hasParalyzerWeapon       = hasParalyzerWeapon,
	shieldPower              = shieldPower,
	stockpileLimit           = stockpileLimit,
	hasAreaDamageWeapon      = hasAreaDamageWeapon,
	onlyTargetCategory       = onlyTargetCategory,

	-- Damages
	isParalyzeImmune         = isParalyzeImmune,
	paralyzeMultiplier       = paralyzeMultiplier,
	areaDamageResistance     = areaDamageResistance,
	isJunoDamageTarget       = isJunoDamageTarget,

	-- Unit groups
	isEnergyConverter        = isEnergyConverter,
	isEconomicUnit           = isEconomicUnit,
	isRadarBuilding          = isRadarBuilding,
	isVisionBuilding         = isVisionBuilding,
	isJammerBuilding         = isJammerBuilding,
	isBaseRaidTargetUnit     = isBaseRaidTargetUnit,
	isDefensiveStructureUnit = isDefensiveStructureUnit,
	isLongRangeCannonUnit    = isLongRangeCannonUnit,
	isSpamUnit               = isSpamUnit,

	-- Domain
	needsMapLand             = needsMapLand,
	needsMapWater            = needsMapWater,
	isLandUnit               = isLandUnit,
	isWaterUnit              = isWaterUnit,
	isUnderwaterUnit         = isUnderwaterUnit,
	isHoverUnit              = isHoverUnit,

	-- Move type
	isImmobileUnit           = isImmobileUnit,
	isStructureUnit          = isStructureUnit,
	isInanimateUnit          = isInanimateUnit,
	isGroundMoveCtrlUnit     = isGroundMoveCtrlUnit,
	isAirMoveCtrlUnit        = isAirMoveCtrlUnit,
	isGunshipMoveCtrlUnit    = isGunshipMoveCtrlUnit,
	moveType                 = moveType,
	moveTypeDisplayName      = moveTypeDisplayName,

	-- Script type
	isUnitScriptCOB          = isUnitScriptCOB,
	isUnitScriptLUS          = isUnitScriptLUS,

	-- Animations
	hasDeathAnimation        = hasDeathAnimation,

	-- Air units
	isAnyBomberAirUnit       = isAnyBomberAirUnit,
	isStrafeFighterAirUnit   = isStrafeFighterAirUnit,
	isStrafeBomberAirUnit    = isStrafeBomberAirUnit,
	canCrash                 = canCrash,
	airTargetCategory        = airTargetCategory,
	isAirTransport           = isAirTransport,
	isParatrooperUnit        = isParatrooperUnit,

	-- Entity types
	isFakeUnit               = isFakeUnit,
	isGaiaCritterUnit        = isGaiaCritterUnit,
	isGaiaDefenderUnit       = isGaiaDefenderUnit,
	isDecorationUnit         = isDecorationUnit,
	isObjectifiedUnit        = isObjectifiedUnit,
	isVirtualizedUnit        = isVirtualizedUnit,
	isUnusualUnit            = isUnusualUnit,
	isAutonomousUnit         = isAutonomousUnit,
	entityType               = entityType,

	-- GUI
	unitScaleSize            = unitScaleSize,
	unitScaleFootprint       = unitScaleFootprint,
	unitScaleIcon            = unitScaleIcon,

	-- State functions
	isIdleBuilderUnit        = isIdleBuilderUnit,
	isIdleCombatantUnit      = isIdleCombatantUnit,
}

return UnitInfo
