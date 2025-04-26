if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Unit Statistics Popover",
		desc    = "Detailed unit stats popover via a hotkey or other widgets.",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local armorTypesHidden         = { "standard", "shields", "indestructable" } -- [sic]
local showSelectedUnits        = true
local displayNumberMax         = 999999

local damageStatsPath          = "LuaUI/Config/BAR_damageStats.lua"
local widgetRmlPath            = "luaui/rmlwidgets/unit_statistics/unit_statistics.rml"

--------------------------------------------------------------------------------
-- Cached globals --------------------------------------------------------------

local damageStats              = damageStatsPath and VFS.Include(damageStatsPath)

local max                      = math.max
local min                      = math.min
local ceil                     = math.ceil
local round                    = math.round

local spGetModKeyState         = Spring.GetModKeyState
local spGetMouseState          = Spring.GetMouseState
local spGetMyTeamID            = Spring.GetMyTeamID
local spGetPlayerInfo          = Spring.GetPlayerInfo
local spGetTeamColor           = Spring.GetTeamColor
local spGetTeamInfo            = Spring.GetTeamInfo
local spGetTeamResources       = Spring.GetTeamResources
local spIsUserWriting          = Spring.IsUserWriting
local spTraceScreenRay         = Spring.TraceScreenRay

local spGetUnitDefID           = Spring.GetUnitDefID
local spGetUnitExperience      = Spring.GetUnitExperience
local spGetUnitSensorRadius    = Spring.GetUnitSensorRadius
local spGetUnitTeam            = Spring.GetUnitTeam
local spGetUnitWeaponState     = Spring.GetUnitWeaponState

local i18n                     = Spring.I18N("ui.unitstats")

local defaultArmorTypeIndex    = Game.armorTypes.default
local convertPerFrameSquared   = Game.gameSpeed * Game.gameSpeed
local headingToRadianPerSecond = (2 / 32767) * convertPerFrameSquared
local gameName                 = Game.gameName
local windGeneration           = Game.windMax
local tideGeneration           = Game.tidal

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local replayDamageStats
if damageStats then
	replayDamageStats = damageStats[gameName] and damageStats[gameName].team
end

local armorTypesDisplayIndex = {} -- for plain iteration on 0-based index
local armorTypesDisplayNames = {} -- for reverse lookup, maybe not needed

if Spring.GetModOptions().map_tidal then
	tideGeneration = ({
		low       = 13,
		medium    = 18,
		high      = 23,
		unchanged = Game.tidal,
	})[Spring.GetModOptions().map_tidal]
end

local anonymousTeamMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamName = "?????"
local anonymousTeamColor

local spectating = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()

-- Local state setup

local unitDefStatistics -- Cache the display values of the last few unitDefs.

local selectedUnits = {}

local showStatistics = false
local showUnitDefID = false
local showUnitID = false

local inBuildOrder = false
local inBuildMenu = false

-- Data model objects

local document
local dataModelHandle
local dataModelName = "unit-statistics"
local dataModelInitial = {
	visible   = false,
	expanded  = false,
	baseStats = {},
	unitStats = {},
}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function getTeamColorCode(teamID)
	return "rcss_color_code"
end

local function getTeamName(teamID)
	return "team_name"
end

local function descending(a, b)
	return a > b
end
local function positive(value, default)
	value = tonumber(value)
	return value and value > 0 and value or default
end
local function nonidentity(value, default)
	value = tonumber(value)
	return value ~= 1 and value or default
end
local function nontrivial(value, default)
	value = tonumber(value)
	return value ~= 0 and value ~= 1 and value or default
end

---Aggregates and humanizes a summary of the unit def's general statistics.
---@param unitDefID integer
---@return table unitDefSummary
local function getBaseStats(unitDefID)
	-- Accessing UnitDefs is slower than other tables. We want to get around it.
	local unitDef = UnitDefs[unitDefID]
	local isExplodingUnit = unitDef.customParams.unitgroup == "explo"

	-- We have to extensively transform weapon def properties to humanize them.
	local weaponSummary = {}
	local damageBurstTotal, damageRateTotal = 0, 0
	local effectBurstTotal, effectRateTotal = 0, 0
	local empBurstTotal, empRateTotal = 0, 0
	do
		local weaponDefs = {}
		local weaponCounts = {}
		local weaponIndexes = {}
		for i = 1, #unitDef.weapons do
			local weaponDefID = unitDef.weapons[i].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			-- BAR has better and worse conventions for identifying non-weapon weapons:
			if not weaponDef.customParams.bogus and not weaponDef.customParams.nofire and weaponDef.range ~= 0 then
				local weaponCount = weaponCounts[weaponDefID]
				if weaponCount then
					weaponCounts[weaponDefID] = weaponCount + 1
				else
					weaponDefs[#weaponDefs + 1] = weaponDef
					weaponCounts[weaponDefID] = 1
					weaponIndexes[weaponDefID] = i
				end
			end
		end

		local selfDWeaponDefID = WeaponDefNames[unitDef.selfDExplosion].id
		if WeaponDefs[selfDWeaponDefID].damageAreaOfEffect < 8 then
			weaponDefs[#weaponDefs + 1] = selfDWeaponDefID
			weaponCounts[selfDWeaponDefID] = 1
		end

		local deathWeaponDefID = WeaponDefNames[unitDef.deathExplosion].id
		if WeaponDefs[deathWeaponDefID].damageAreaOfEffect < 8 then
			weaponDefs[#weaponDefs + 1] = deathWeaponDefID
			weaponCounts[deathWeaponDefID] = 1
		end

		for i = 1, #weaponDefs do
			local weaponDef = weaponDefs[i]
			local weaponDefID = weaponDef.id
			local addToTotals = true

			-- Aiming and pre-firing properties
			local name, range, reload, stockpileTime, stockpileLimit, burst, burstRate, energyPerShot, metalPerShot
			if weaponDefID == deathWeaponDefID then
				name = i18n.deathexplosion
				range = weaponDef.damageAreaOfEffect * 0.5
				reload = 1
				addToTotals = isExplodingUnit
			elseif weaponDefID == selfDWeaponDefID then
				name = i18n.selfdestruct
				range = weaponDef.damageAreaOfEffect * 0.5
				reload = max(1, unitDef.selfDestructCountdown)
				addToTotals = isExplodingUnit
			else
				name          = weaponDef.description
				range         = weaponDef.range
				stockpileTime = positive(weaponDef.stockpileTime)
				reload        = max(weaponDef.reload, stockpileTime or 0)
				burst         = weaponDef.burst
				burstRate     = weaponDef.burstRate
				energyPerShot = positive(weaponDef.energyPerShot)
				metalPerShot  = positive(weaponDef.metalPerShot)
				if stockpileTime then
					stockpileLimit = positive(weaponDef.customParams.stockpilelimit, 1)
				end
			end

			-- Firing properties
			local accuracyError      = weaponDef.accuracy
			local accuracyMoveError  = weaponDef.targetMoveError
			local sprayAngleMax      = weaponDef.sprayAngle
			local projectiles        = weaponDef.projectiles
			-- TODO: burst fire on BeamLaser and other considerations per weapon type
			-- TODO: missile dance (Catapult), sector fire (Tremor)

			-- Projectile properties
			local baseArmorTypeIndex
			if weaponDef.customParams.armorTypeFocus then
				baseArmorTypeIndex = weaponDef.customParams.armorTypeFocus
			elseif unitDef.weapons[i].badtargetcategory == "NOTAIR" then
				baseArmorTypeIndex = Game.armorTypes.vtol
			elseif unitDef.weapons[i].badtargetcategory == "NOTSUB" then
				baseArmorTypeIndex = Game.armorTypes.subs
			elseif unitDef.weapons[i].onlytargetcategory == "MINE" then
				baseArmorTypeIndex = Game.armorTypes.mine
				addToTotals = false
			else
				baseArmorTypeIndex = defaultArmorTypeIndex
			end

			local baseDamage = weaponDef.damages[baseArmorTypeIndex]
			local defaultDamage = weaponDef.damages[defaultArmorTypeIndex]
			local areaOfEffect = not weaponDef.impactOnly and weaponDef.damageAreaOfEffect
			areaOfEffect = areaOfEffect and areaOfEffect > 8 and areaOfEffect or nil

			if weaponDef.customParams.speceffect == "split" then
				projectiles = projectiles * weaponDef.customParams.number
				weaponDef = WeaponDefNames[weaponDef.customParams.speceffect_def]
				weaponDefID = weaponDef.id
				-- TODO: Technically there's a small sprayAngle from the split scatter.
				areaOfEffect = not weaponDef.impactOnly and weaponDef.damageAreaOfEffect
				areaOfEffect = areaOfEffect and areaOfEffect > 8 and areaOfEffect or nil
				baseArmorTypeIndex = weaponDef.customParams.armorTypeFocus or defaultArmorTypeIndex
				defaultDamage = weaponDef.damages[defaultArmorTypeIndex]
				baseDamage = weaponDef.damages[baseArmorTypeIndex]
			end

			local edgeEffectiveness, impulseFactorNet, craterFactorNet
			if areaOfEffect then
				edgeEffectiveness = weaponDef.edgeEffectiveness
				impulseFactorNet = weaponDef.damages.impulseFactor
				impulseFactorNet = impulseFactorNet + weaponDef.damages.impulseBoost / max(baseDamage, 1)
				impulseFactorNet = impulseFactorNet > 0.123 and impulseFactorNet or nil
				craterFactorNet = positive(positive(weaponDef.craterMult, 0) +
					positive(weaponDef.damages.craterBoost, 0) / max(defaultDamage, 1))
			end

			-- Effect damage consists of scripted effects (which deal burst) and temporal effects (which change DPS).
			-- This becomes a nebulous categorization when both effect types occur on the same weapon. Please do not.
			-- The data presentation of effect damage is as extra/bonus damage, e.g. 120 + 40 with the "40" stylized.

			local effectExplain
			local effectBurst, effectRate = 0, 0
			if weaponDef.customParams.spark_basedamage then
				effectExplain = i18n.explain_spark -- TODO: effect explanation text in i18n for tooltips
				local damage = weaponDef.customParams.spark_basedamage * weaponDef.customParams.spark_forkdamage
				effectBurst = damage * weaponDef.customParams.spark_maxunits
			elseif weaponDef.customParams.cluster then
				effectExplain = i18n.explain_cluster
				local munition = WeaponDefNames[weaponDef.customParams.cluster_def]
				local damage = munition.damages[baseArmorTypeIndex]
				local scatter = munition.range + munition.areaofeffect * 0.5
				effectBurst = damage * weaponDef.customParams.cluster_number
				-- TODO: Some cluster weapons work more like a sprayAngle than an extended damage area of effect.
				if areaOfEffect then
					areaOfEffect = (areaOfEffect * baseDamage + scatter * effectBurst) / (baseDamage + effectBurst)
				else
					areaOfEffect = scatter
				end
			elseif weaponDef.customParams.area_onhit_damage then
				effectExplain = i18n.explain_area_timed_damage
				areaOfEffect = max(areaOfEffect or 0, weaponDef.customParams.area_onhit_range)
				effectBurst = weaponDef.customParams.area_onhit_damage * weaponDef.customParams.area_onhit_time
			elseif unitDef.customParams.area_ondeath and (weaponDefID == deathWeaponDefID or weaponDefID == selfDWeaponDefID) then
				effectExplain = i18n.explain_area_timed_damage
				areaOfEffect = max(areaOfEffect or 0, unitDef.customParams.area_ondeath_range)
				effectBurst = unitDef.customParams.area_ondeath_damage * unitDef.customParams.area_ondeath_time
			elseif baseDamage ~= 0 then
				local temporalExplain, temporalRate
				if burst and (burst - 1) * burstRate >= 0.5 and (burst - 1) * burstRate / reload >= 0.5 then
					temporalExplain = i18n.explain_extended_burst
					temporalRate = baseDamage / ((burst - 1) * burstRate) - baseDamage / reload
				elseif stockpileTime and stockpileTime > reload and stockpileLimit > 1 then
					temporalExplain = i18n.explain_extended_stockpile
					temporalRate = baseDamage * (1 - reload / stockpileTime)
				end
				if temporalRate and temporalRate > 5 and temporalRate / baseDamage * reload >= 0.5 then
					effectExplain = temporalExplain
					effectRate = temporalRate
				end
			end

			local damageBurst, damageRate = 0, 0
			local xpToDPS = true
			if isExplodingUnit then
				damageBurst = baseDamage
				xpToDPS = false
			else
				if weaponDef.commandfire then
					effectExplain = effectExplain or i18n.explain_commandfire
					effectBurst, effectRate = effectBurst + baseDamage, effectRate + baseDamage / reload
				else
					damageBurst, damageRate = baseDamage, baseDamage / reload
				end
				if reload == stockpileTime then
					xpToDPS = false
				end
			end

			local damageModifiers = {}
			if baseDamage ~= 0 then
				local defaultDamageRate = round(100 * defaultDamage / baseDamage)
				local groupByDamageRate = { [defaultDamageRate] = { "default" } }
				for _, armorTypeIndex in ipairs(armorTypesDisplayIndex) do
					local percent = round(100 * weaponDef.damages[armorTypeIndex] / baseDamage)
					if percent ~= defaultDamageRate then
						local group = groupByDamageRate[percent] or {}
						groupByDamageRate[percent] = table.insert(group, armorTypesDisplayNames[armorTypeIndex])
					end
				end
				local sortedByDamageRate = {}
				for p in pairs(groupByDamageRate) do sortedByDamageRate[#sortedByDamageRate + 1] = p end
				table.sort(sortedByDamageRate, descending)
				for _, p in ipairs(sortedByDamageRate) do
					damageModifiers[#damageModifiers + 1] = ("%d%% %s"):format(
						p, table.concat(groupByDamageRate[p], ", "))
				end
			elseif effectBurst ~= 0 then
				-- This damage type is scripted so is arbitrary. We assume it is uniform:
				damageModifiers[1] = "100%% default"
				-- Non-default armor types can be hidden from display:
				if armorTypesDisplayNames.indestructable then -- [sic]
					damageModifiers[2] = "0%% indestructible"
				end
			else
				addToTotals = false
				xpToDPS = false
			end

			if damageBurst + effectBurst >= displayNumberMax then
				damageBurst, damageRate = displayNumberMax, displayNumberMax
				effectBurst, effectRate = 0, 0
				xpToDPS = false
			end

			-- NB: Damage must be be entirely paralyzing or non-paralyzing per weapon.
			-- Widgets are not the correct way to enforce anything/find errors though.
			local paralyzeDamageTime = positive(weaponDef.damages.paralyzeDamageTime)
			local empBurst, empRate = 0, 0
			if paralyzeDamageTime then
				empBurst, empRate = damageBurst, damageRate
				damageBurst, damageRate = 0, 0
			end

			local xpToRange = positive(unitDef.customParams.rangexpscale) and true or false

			local weapon = {
				weaponDefID        = weaponDefID,
				count              = weaponCounts[weaponDefID],
				index              = weaponIndexes[weaponDefID],
				name               = name,
				hidden             = not addToTotals,

				range              = range,
				accuracyError      = accuracyError,
				accuracyMoveError  = accuracyMoveError,

				reload             = reload,
				stockpileTime      = stockpileTime,
				stockpileLimit     = stockpileLimit,
				energyPerShot      = energyPerShot,
				metalPerShot       = metalPerShot,
				salvoSize          = burst,

				projectiles        = projectiles, -- NB: Damage values are per-projectile.
				damageBurst        = damageBurst,
				damageRate         = damageRate,
				empBurst           = empBurst,
				empRate            = empRate,
				damageModifiers    = damageModifiers,
				paralyzeDamageTime = paralyzeDamageTime,
				effectBurst        = effectBurst,
				effectRate         = effectRate,
				effectExplain      = effectExplain,

				experienceBonuses  = xpToDPS or xpToRange,

				areaOfEffect       = areaOfEffect,
				edgeEffectiveness  = edgeEffectiveness,
				impulseFactorNet   = impulseFactorNet,
				craterFactorNet    = craterFactorNet,

				damageDecay        = nonidentity(weaponDef.minIntensity),
			}

			-- Not sure if there are performance-oriented flags to add. This is a rough idea of one.
			-- There might be a tutorial-mode UI where you see a short pros/cons list or something,
			-- but tbh you don't need a "dynamic" UI to do that. So doing it like this is pointless?
			if range * (accuracyError + accuracyMoveError * 0.25 + sprayAngleMax / projectiles) > (
					areaOfEffect and (32767 * 0.25 + areaOfEffect * edgeEffectiveness) * 0.5
					or 32767 * 0.25 * 0.5)
			then
				weapon.isWeakAccuracy = true
			end

			if baseArmorTypeIndex == Game.armorTypes.vtol then
				weapon.isAntiAir = true
			elseif baseArmorTypeIndex == Game.armorTypes.mines then
				weapon.isAntiMine = true
			elseif baseArmorTypeIndex == Game.armorTypes.subs then
				weapon.isAntiSubmarine = true
			end

			if addToTotals then
				local countTotal = weapon.count * projectiles
				damageBurstTotal = damageBurstTotal + damageBurst * countTotal
				damageRateTotal = damageRateTotal + damageRate * countTotal
				effectBurstTotal = effectBurstTotal + effectBurst * countTotal
				effectRateTotal = effectRateTotal + effectRate * countTotal
				empBurstTotal = empBurstTotal + empBurst * countTotal
				empRateTotal = empRateTotal + empRate * countTotal
			end

			weaponSummary[#weaponSummary + 1] = weapon
		end
	end

	if damageBurstTotal == 0 and empBurstTotal == 0 then
		if effectBurstTotal == 0 then
			damageBurstTotal, damageRateTotal = nil, nil
			effectBurstTotal, effectRateTotal = nil, nil
			empBurstTotal, empRateTotal = nil, nil
			weaponSummary = nil
		else
			for _, weapon in ipairs(weaponSummary) do
				defaultDamage = effectBurst
				baseDamage = effectBurst
				weapon.damageBurst, weapon.damageRate = effectBurst, effectRate
				weapon.effectBurst, weapon.effectRate = 0, 0
			end
			damageBurstTotal, damageRateTotal = effectBurstTotal, effectRateTotal
			effectBurstTotal, effectRateTotal = 0, 0
		end
	end

	local summary = {
		unitDefID           = unitDefID,
		name                = unitDef.name,
		description         = unitDef.description, -- TODO add unit extended descriptions
		quotation           = unitDef.quotation, -- TODO add quotations/admonitions
		buildPicture        = unitDef.buildPic,

		metalCost           = unitDef.metalCost,
		energyCost          = unitDef.energyCost,
		buildTime           = unitDef.buildTime,
		techLevel           = unitDef.customParams.techlevel,

		metalProduction     = positive(unitDef.metalMake),
		metalUpkeep         = positive(unitDef.metalUse),
		metalStorage        = positive(unitDef.metalStorage),
		energyProduction    = positive(unitDef.energyMake),
		energyUpkeep        = positive(unitDef.energyUpkeep),
		energyStorage       = positive(unitDef.energyStorage),
		buildPower          = positive(unitDef.workertime),

		healthMax           = unitDef.health,
		armorMultiplier     = nontrivial(unitDef.armoredMultiple),
		paralysisMultiplier = nonidentity(unitDef.customParams.paralyzemultiplier),
		armorTypeName       = armorTypesDisplayNames[unitDef.armorType],

		canBuild            = unitDef.canBuild,
		canAssist           = unitDef.canAssist,
		canRepair           = unitDef.canRepair,
		canReclaim          = unitDef.canReclaim,
		canResurrect        = unitDef.canResurrect,
		canCapture          = unitDef.canCapture,

		reclaimImmune       = not unitDef.reclaimable,
		captureImmune       = not unitDef.capturable,

		stealth             = unitDef.stealth,
		canCloak            = unitDef.canCloak,
		cloakCost           = positive(unitDef.cloakcost),
		cloakCostMoving     = positive(unitDef.cloakcostmoving),

		radiusSight         = positive(unitDef.sightDistance),
		radiusSightAir      = positive(unitDef.airSightDistance),
		radiusRadar         = positive(unitDef.radarDistance),
		radiusSonar         = positive(unitDef.sonarDistance),
		radiusJammingRadar  = positive(unitDef.radarDistanceJam),
		radiusJammingSonar  = positive(unitDef.sonarDistanceJam),
		radiusSeismicSense  = positive(unitDef.seismicDistance),

		canAttackWater      = unitDef.canAttackWater,
		canManualFire       = unitDef.canManualFire,
		canStockpile        = unitDef.canStockpile,
		canParalyze         = unitDef.canParalyze,
		canKamikaze         = unitDef.canKamikaze,

		weaponSummary       = weaponSummary,
		damageBurstTotal    = damageBurstTotal,
		damageRateTotal     = damageRateTotal,
		effectBurstTotal    = effectBurstTotal,
		effectRateTotal     = effectRateTotal,
		empBurstTotal       = empBurstTotal,
		empRateTotal        = empRateTotal,
	}

	-- Welcome to hell, where metalMake <> makesMetal and both are numbers:

	-- TODO: This part is non-cache-able, technically, though the issue is rare.
	-- TODO: So there should be a third table binding, maybe to a "buildHelper".
	-- TODO: So there should be a separate function to get it, "getBuildHelper".
	if inBuildOrder then
		if not inBuildMenu then
			-- Requires {Land|WaterSubmerged|WaterSurface}:
			local categories = unitDef.modCategories
			if categories.hover then
				summary.requiresLand = true
				summary.requiresWaterSurface = true
			elseif categories.ship then
				summary.requiresWaterSurface = true
			elseif categories.underwater then
				summary.requiresWaterSubmerged = true
			elseif categories.canbeuw then
				summary.requiresLand = true
				summary.requiresWaterSubmerged = true
			else
				summary.requiresLand = true
			end
			-- Requires {Geothermal|MetalSpot}:
			if unitDef.needGeo then
				summary.requiresGeothermal = true
			elseif positive(unitDef.customParams.metal_extractor or unitDef.extractsMetal) then
				summary.requiresMetalSpot = true
			end
		end
	end

	if summary.energyProduction then
		if unitDef.customParams.solar then
			summary.isSolarGenerator = true -- Unused?
		elseif unitDef.tidalGenerator then
			summary.isTidalGenerator = true
			if unitDef.tidalGenerator < tideGeneration or tideGeneration < 10 then
				summary.isWeakGenerator = true
			end
		elseif unitDef.windGenerator then
			summary.isWindGenerator = true
			if unitDef.windGenerator < windGeneration or windGeneration < 10 then
				summary.isWeakGenerator = true
			end
		elseif unitDef.needGeo then
			summary.isGeothermalExtractor = true
			-- TODO: unstable/volatile/explosive check?
		end
	end

	-- TODO: Why are there two? This is a running theme.
	if positive(unitDef.customParams.metal_extractor or unitDef.extractsMetal) then
		summary.metalExtraction = unitDef.customParams.metal_extractor or unitDef.extractsMetal
	elseif positive(unitDef.metalMake) then
		summary.metalProduction = unitDef.metalMake
	end

	if positive(unitDef.customParams.energyconv_efficiency) then
		local energyToConvert = unitDef.customParams.energyconv_capacity
		summary.energyToConvert = energyToConvert
		summary.metalConverted = round(energyToConvert * unitDef.customParams.energyconv_efficiency)
	end

	-- The self-repair rate of mines and (eg) walls isn't a notable feature of these units.
	-- It just makes them behave more predictably when encountered. Should usually suppress.
	if not isExplodingUnit and unitDef.repairable then
		local autoHealRate = positive(unitDef.autoheal)
		if autoHealRate and autoHealRate / unitDef.health < 1 / (2 * 60) then
			summary.autoHealRate = autoHealRate
		end
		local idleHealRate = positive(unitDef.idleautoheal)
		local idleHealTime = positive(unitDef.idletime)
		if idleHealRate and idleHealTime then
			if idleHealRate > 5 and idleHealRate / unitDef.health < 1 / (1 * 60) then
				summary.idleHealRate = idleHealRate
			end
			if idleHealTime < 60 * Game.gameSpeed then
				summary.idleHealTime = idleHealTime
			end
		end
	end

	if not unitDef.isBuilding and not unitDef.isFactory and positive(unitDef.speed) then
		summary.speed = unitDef.speed
		summary.acceleration = unitDef.maxAcc * convertPerFrameSquared
		summary.turnRate = unitDef.turnRate * headingToRadianPerSecond
	else
		summary.footprint = ("%.0f x %.0f"):format(unitDef.xsize or 1, unitDef.zsize or 1)
	end

	if not unitDef.cantBeTransported then
		local mass = unitDef.mass
		local size = (unitDef.xsize or 0) * 0.5
		if mass > 0 and size > 0 then
			if mass <= 750 and size <= 3 then
				summary.transportableLight = true
			elseif mass <= 100000 and size <= 4 then
				summary.transportableHeavy = true
			end
		end
	end

	if replayDamageStats and replayDamageStats[unitDef.name] then
		summary.effectiveness = replayDamageStats[unitDef.name].killed_cost / replayDamageStats[unitDef.name].cost
	end

	return summary
end

---Composes only the unit's stat difference (or compliment) from its base statistics.
---@param unitID integer
---@param summary unitDefSummary
---@param expanded boolean Whether to include information typically hidden from view.
---@return table compliment
local function getUnitStats(unitID, summary, expanded)
	local unitTeam = Spring.GetUnitTeam(unitID)
	local isAlliedUnit = Spring.AreTeamsAllied(myTeamID, unitTeam)
	local isBeingBuilt, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
	if isBeingBuilt then
		local mCost = summary.metalCost
		local eCost = summary.energyCost
		local compliment = {
			unitID        = unitID,
			unitTeam      = unitTeam,
			isBeingBuilt  = isBeingBuilt,
			buildProgress = buildProgress,
			metalSpent    = mCost * buildProgress,
			metalUnspent  = mCost * (1 - buildProgress),
			energySpent   = eCost * buildProgress,
			energyUnspent = eCost * (1 - buildProgress),
		}
		if isAlliedUnit then
			local mStored, _, _, mIncome, _, _, _, mReceived = Spring.GetTeamResources(unitTeam, "metal")
			local eStored, _, _, eIncome, _, _, _, eReceived = Spring.GetTeamResources(unitTeam, "energy")
			local metalTimer = max(0, mCost * (1 - buildProgress) - mStored) / (mIncome + mReceived)
			local energyTimer = max(0, eCost * (1 - buildProgress) - eStored) / (eIncome + eReceived)
			-- local buildTimer = summary.buildTime / < this would be a lot of work to get tbh >
			if metalTimer >= energyTimer then
				compliment.metalTimer = metalTimer
			else
				compliment.energyTimer = energyTimer
			end
		end
		return compliment
	elseif isAlliedUnit then
		-- todo: check if in death anims or something? idk prolly tho
		local unitExperience = Spring.GetUnitExperience(unitID)
		local compliment = {
			unitID     = unitID,
			unitTeam   = unitTeam,
			experience = unitExperience,
		}
		if unitExperience > 0 then
			local _, healthMax = Spring.GetUnitHealth(unitID)
			if summary.armorMultiplier then
				local isArmored, armoredMultiple = Spring.GetUnitArmored(unitID)
				if isArmored and armoredMultiple > 0 then
					compliment.closed = isArmored
					compliment.healthMax = healthMax / armoredMultiple
				end
			end
			local weaponChanges = {}
			for i = 1, #summary.weaponSummary do
				local weapon = summary.weaponSummary[i]
				if weapon.experienceBonuses and (expanded or not weapon.hidden) then
					local changes  = {}
					local reload   = Spring.GetUnitWeaponState(unitID, weapon.index, "reloadTime")
					local accuracy = Spring.GetUnitWeaponState(unitID, weapon.index, "accuracy")
					local range    = Spring.GetUnitWeaponState(unitID, weapon.index, "range")
					if reload and reload < weapon.reload then changes.reload = reload end
					if accuracy and accuracy < weapon.accuracy then changes.accuracy = accuracy end
					if range and range > weapon.range then changes.range = range end
					if next(changes) then weaponChanges[i] = changes end
				end
			end
			if next(weaponChanges) then
				compliment.weapons = weaponChanges
			end
		end
		if summary.speed then
			local moveTypeData = Spring.GetUnitMoveTypeData(unitID)
			if moveTypeData.maxSpeed ~= summary.speed then
				-- TODO: Add explain_ and an icon showing slowdown is from terrain, transported mass, etc.
				compliment.speed = moveTypeData.maxSpeed
			end
		end
		return compliment
	else
		-- TODO: Check if unit is visible. Some traits can be verified without sight but not many.
		-- TODO: Check if unit is decoy. We might need to make extensive corrections in that case.
		-- TODO: ...List potential decoy units on enemies? "Maybe that wall is a lying bastard?"
	end
end

local newCachedDefsTable
do
	local function getNonCachedBaseStats(self, key)
		if type(key) == "number" and key > 0 then
			local summary = getBaseStats(key)
			self[key] = summary
			return summary
		end
	end

	local function addNonCachedBaseStats(self, key, value)
		if type(key) == "number" and key > 0 then
			if self.size < self.max then
				local size = self.size + 1
				rawset(self, -size, key)
				rawset(self, "size", size)
			else
				local i = self.i
				rawset(self, self[-i], nil)
				rawset(self, -i, key)
				rawset(self, "i", (i % self.max) + 1)
			end
		end
		rawset(self, key, value)
	end

	---Reset the unitDef summaries cache table and set its maximum capacity.
	---@param maxCount integer? default = 5
	---@return table
	newCachedDefsTable = function(maxCount)
		local tbl = setmetatable(
			{ i = 1, size = 0, max = maxCount or 5 },
			{
				__index    = getNonCachedBaseStats,
				__newindex = addNonCachedBaseStats,
			}
		)
		return tbl
	end
end

--------------------------------------------------------------------------------
-- Engine callins --------------------------------------------------------------

do
	local function initializeUnitStatistics()
		i18n = Spring.I18N("ui.unitstats")
		for index = 0, #Game.armorTypes do
			local name = Game.armorTypes[index]
			armorTypesDisplayIndex[index + 1] = index
			armorTypesDisplayNames[name] = index
		end
		for _, name in ipairs(armorTypesHidden) do
			if Game.armorTypes[name] then
				local index = Game.armorTypes[name]
				armorTypesHidden[name] = index
				armorTypesDisplayNames[name] = nil
				table.removeFirst(armorTypesDisplayIndex, index)
			end
		end
		unitDefStatistics = newCachedDefsTable(5)
		widget:PlayerChanged()
		return true
	end

	local function showAction()
		local _, buildDefID = Spring.GetActiveCommand()
		inBuildOrder, inBuildMenu = false, false
		if buildDefID and buildDefID < 0 then
			showUnitDefID = -buildDefID
			inBuildOrder = true
		elseif WG.buildmenu and WG.buildmenu.hoverID then
			showUnitDefID = WG.buildmenu.hoverID
			inBuildOrder = true
			inBuildMenu = true
		else
			if selectedUnits[1] then
				showUnitID = selectedUnits[1]
			else
				local mx, my = Spring.GetMouseState()
				local hitType, hitID = Spring.TraceScreenRay(mx, my)
				showUnitID = hitType == "unit" and hitID
			end
			showUnitDefID = showUnitID and Spring.GetUnitDefID(showUnitID)
		end

		if not showUnitDefID then
			showStatistics = false
		else
			showStatistics = true
		end
	end

	local function hideAction()
		showStatistics = false
		showUnitDefID = false
		showUnitID = false
	end

	local function showUnitStatistics(unitDefID, unitID)
		showUnitDefID = unitDefID or (unitID and Spring.GetUnitDefID(unitID))
		showUnitID = unitID
		showStatistics = showUnitDefID and true or false
		return showStatistics
	end

	local function hideArmorTypeStatistics(armorTypeName)
		if type(armorTypeName) == "string" and armorTypeName ~= "default"
			and Game.armorTypes[armorTypeName]
		then
			local armorTypeIndex = Game.armorTypes[armorTypeName]
			table.removeFirst(armorTypesDisplayIndex, armorTypeIndex)
			armorTypesDisplayNames[armorTypeName] = nil
		end
	end

	local function showArmorTypeStatistics(armorTypeName)
		if type(armorTypeName) == "string" and not armorTypesDisplayNames[armorTypeName]
			and Game.armorTypes[armorTypeName]
		then
			local armorTypeIndex = Game.armorTypes[armorTypeName]
			armorTypesDisplayNames[armorTypeName] = armorTypeIndex
			for k, v in ipairs(armorTypesDisplayIndex) do
				if v > armorTypeIndex then
					armorTypesDisplayIndex:insert(k, armorTypeName)
					break
				end
			end
		end
	end

	local function initializeRmlUi()
		widget.rmlContext = RmlUi.GetContext("shared")
		dataModelHandle = widget.rmlContext:OpenDataModel(dataModelName, dataModelInitial)
		if not dataModelHandle then
			Spring.Echo("RmlUi: Failed to open data model ", dataModelName)
			return
		end
		document = widget.rmlContext:LoadDocument(widgetRmlPath, widget)
		if not document then
			Spring.Echo("Failed to load document")
			return
		end
		document:ReloadStyleSheet()
		return true
	end

	function widget:Initialize()
		widgetHandler:AddAction("unit_stats", showAction, nil, "p")
		widgetHandler:AddAction("unit_stats", hideAction, nil, "r")
		widgetHandler:RegisterGlobal("HideArmorTypeStatistics", hideArmorTypeStatistics)
		widgetHandler:RegisterGlobal("ShowArmorTypeStatistics", showArmorTypeStatistics)
		WG.ShowUnitStatistics = showUnitStatistics
		if not initializeUnitStatistics() or not initializeRmlUi() then
			widgetHandler:RemoveWidget(self)
		end
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction(self, "unit_stats", "p")
	widgetHandler:RemoveAction(self, "unit_stats", "r")
	widgetHandler:DeregisterGlobal("HideArmorTypeStatistics")
	widgetHandler:DeregisterGlobal("ShowArmorTypeStatistics")
	WG.ShowUnitStatistics = nil
	if document then document:Close() end
	widget.rmlContext:RemoveDataModel(dataModelName)
end

function widget:Reload(event)
	widget:Shutdown()
	widget:Initialize()
end

function widget:PlayerChanged()
	spectating = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
end

if showSelectedUnits then
	function widget:SelectionChanged(selection, isSubset)
		selectedUnits = selection
	end
end

do
	local function update()
		if showUnitDefID
			and (not WG.topbar or not WG.topbar.showingQuit())
			and (not WG.chat or not WG.chat.isInputActive())
			and (not Spring.IsUserWriting())
		then
			local _, _, _, shift = Spring.GetModKeyState()
			local baseStats = unitDefStatistics[showUnitDefID]
			local unitStats = showUnitID and getUnitStats(showUnitID, baseStats, shift)
			dataModelHandle.visible = true
			dataModelHandle.baseStats = baseStats
			dataModelHandle.unitStats = unitStats
			dataModelHandle.expanded = shift
		else
			dataModelHandle.visible = false
			showStatistics = false
			showUnitDefID = false
			showUnitID = false
		end
	end

	function widget:Update()
		if showStatistics then update() end
	end
end
