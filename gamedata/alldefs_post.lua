
--------------------------
-- DOCUMENTATION
-------------------------

-- BAR contains weapondefs in its unitdef files
-- Standalone weapondefs are only loaded by Spring after unitdefs are loaded
-- So, if we want to do post processing and include all the unit+weapon defs, and have the ability to bake these changes into files, we must do it after both have been loaded
-- That means, ALL UNIT AND WEAPON DEF POST PROCESSING IS DONE HERE

-- What happens:
-- unitdefs_post.lua calls the _Post functions for unitDefs and any weaponDefs that are contained in the unitdef files
-- unitdefs_post.lua writes the corresponding unitDefs to customparams (if wanted)
-- weapondefs_post.lua fetches any weapondefs from the unitdefs,
-- weapondefs_post.lua fetches the standlaone weapondefs, calls the _post functions for them, writes them to customparams (if wanted)
-- strictly speaking, alldefs.lua is a misnomer since this file does not handle armordefs, featuredefs or movedefs

-- Switch for when we want to save defs into customparams as strings (so as a widget can then write them to file)
-- The widget to do so is included in the game and detects these customparams auto-enables itself
-- and writes them to Spring/baked_defs
SaveDefsToCustomParams = false

-------------------------
-- DEFS PRE-BAKING
--
-- This section is for testing changes to defs and baking them into the def files
-- Only the changes in this section will get baked, all other changes made in post will not
--
-- 1. Add desired def changes to this section
-- 2. Test changes in-game
-- 3. Bake changes into def files
-- 4. Delete changes from this section
-------------------------

function PrebakeUnitDefs()
	for name, unitDef in pairs(UnitDefs) do
		-- UnitDef changes go here
	end
end

-------------------------
-- DEFS POST PROCESSING
-------------------------

-- Unit properties

local categories = {} ---@type table<string, fun(unitDef:table):boolean>
do
	local hoverList = {
		HOVER2 = true,
		HOVER3 = true,
		HHOVER4 = true,
		AHOVER2 = true
	}
	local shipList = {
		BOAT3 = true,
		BOAT4 = true,
		BOAT5 = true,
		BOAT9 = true,
		EPICSHIP = true
	}
	local subList = {
		UBOAT4 = true,
		EPICSUBMARINE = true
	}
	local amphibList = {
		VBOT6 = true,
		COMMANDERBOT = true,
		SCAVCOMMANDERBOT = true,
		ATANK3 = true,
		ABOT3 = true,
		HABOT5 = true,
		ABOTBOMB2 = true,
		EPICBOT = true,
		EPICALLTERRAIN = true
	}
	local commanderList = {
		COMMANDERBOT = true,
		SCAVCOMMANDERBOT = true
	}

	local function isNotShieldWeapon(weaponDef)
		return weaponDef.weapontype ~= "Shield" and not weaponDef.shield
	end

	--- - Manual categories: `OBJECT T4AIR LIGHTAIRSCOUT GROUNDSCOUT RAPTOR`
	--- - Deprecated categories: `BOT TANK PHIB NOTLAND SPACE`
	categories = {
		ALL        = function(uDef) return true end,
		MOBILE     = function(uDef) return uDef.speed and uDef.speed > 0 end,
		NOTMOBILE  = function(uDef) return not categories.MOBILE(uDef) end,
		WEAPON     = function(uDef) return uDef.weapondefs and table.any(uDef.weapondefs, isNotShieldWeapon) end,
		NOWEAPON   = function(uDef) return not uDef.weapondefs end,
		VTOL       = function(uDef) return uDef.canfly == true end,
		NOTAIR     = function(uDef) return not categories.VTOL(uDef) end,
		-- Units that convert between land and ship-type (rather than hover) movement must have a maxwaterdepth >= 1:
		HOVER      = function(uDef) return hoverList[uDef.movementclass] and (uDef.maxwaterdepth == nil or uDef.maxwaterdepth < 1) end,
		NOTHOVER   = function(uDef) return not categories.HOVER(uDef) end,
		SHIP       = function(uDef) return shipList[uDef.movementclass] or (hoverList[uDef.movementclass] and uDef.maxwaterdepth and uDef.maxwaterdepth >= 1) end,
		NOTSHIP    = function(uDef) return not categories.SHIP(uDef) end,
		NOTSUB     = function(uDef) return not subList[uDef.movementclass] end,
		CANBEUW    = function(uDef) return amphibList[uDef.movementclass] or uDef.cansubmerge == true end,
		UNDERWATER = function(uDef) return (uDef.minwaterdepth and uDef.waterline == nil) or (uDef.minwaterdepth and uDef.waterline > uDef.minwaterdepth and uDef.speed and uDef.speed > 0) end,
		SURFACE    = function(uDef) return not (categories.UNDERWATER(uDef) and categories.MOBILE(uDef)) and not categories.VTOL(uDef) end,
		MINE       = function(uDef) return uDef.weapondefs and uDef.weapondefs.minerange end,
		COMMANDER  = function(uDef) return commanderList[uDef.movementclass] end,
		EMPABLE    = function(uDef) return categories.SURFACE(uDef) and uDef.customparams and uDef.customparams.paralyzemultiplier ~= 0 end,
	}
end

-- Weapon properties

--[[ Sanitize to whole frames (plus leeways because float arithmetic is bonkers).
     The engine uses full frames for actual reload times, but forwards the raw
     value to LuaUI (so for example calculated DPS is incorrect without sanitisation). ]]
local function round_to_frames(wd, key)
	local original_value = wd[key]
	if not original_value then
		-- even reloadtime can be nil (shields, death explosions)
		return
	end

	local frames = math.max(1, math.floor((original_value + 1E-3) * Game.gameSpeed))
	local sanitized_value = frames / Game.gameSpeed

	return sanitized_value
end

local function processWeapons(unitDefName, unitDef)
	local weaponDefs = unitDef.weapondefs
	if not weaponDefs then
		return
	end

	for weaponDefName, weaponDef in pairs(weaponDefs) do
		weaponDef.reloadtime = round_to_frames(weaponDef, "reloadtime")
		weaponDef.burstrate = round_to_frames(weaponDef, "burstrate")

		if weaponDef.customparams and weaponDef.customparams.cluster_def then
			weaponDef.customparams.cluster_def = unitDefName .. "_" .. weaponDef.customparams.cluster_def
			weaponDef.customparams.cluster_number = weaponDef.customparams.cluster_number or 5
		end
	end
end

local baseDefsPostData = "unitbasedefs/post/"
local isPostDataLoaded = false

local holidays = holidays
local modOptions = modOptions

local holidayObjectNames
local isTechLevel15, isAirFactory, isFusion, isUnrestrictedDefense, isTacticalNuke, isLongRangePlasmaCannon, isEndGameLRPC
local extraBuildLists, scavengerBuildLists, candidateBuildLists
local airReworkUnit, airReworkWeapon, empReworkUnit, empReworkWeapon, junoReworkUnit, skyshiftReworkUnit, proposedReworkUnit, techSplitReworkUnit
local communityBalanceUnit, factoryBalanceUnit, lategameBalanceUnit, navalBalanceUnit, techSplitBalanceUnit

local function load(fileName)
	local result = VFS.Include(baseDefsPostData .. fileName)
	return type(result) == "table" and result or {}
end

local function loadAllDefsPostData()
	isPostDataLoaded = true

	holidays = Spring.Utilities.Gametype.GetCurrentHolidays()
	holidayObjectNames = {}
	local remodels = VFS.Include(baseDefsPostData .. "holiday_objectnames.lua")
	for holiday in pairsByKeys(holidays) do
		if holidays[holiday] and remodels[holiday] then
			table.mergeInPlace(holidayObjectNames, remodels[holiday])
		end
	end

	modOptions = Spring.GetModOptions()

	if modOptions.unit_restrictions_notech15 then
		isTechLevel15 = load("tech_level_15.lua").unitDefMap
	end
	if modOptions.unit_restrictions_nodefence then
		isUnrestrictedDefense = load("non_restricted_defenses.lua").unitDefMap
	end
	if modOptions.unit_restrictions_noair then
		isAirFactory = load("air_factories.lua").unitDefMap
	end
	if modOptions.unit_restrictions_nofusion then
		isFusion = load("fusions.lua").unitDefMap
	end
	if modOptions.unit_restrictions_notacnukes then
		isTacticalNuke = load("tactical_nukes.lua").unitDefMap
	end
	if modOptions.unit_restrictions_nolrpc then
		isLongRangePlasmaCannon = load("long_range_plasma_cannons.lua").unitDefMap
	end
	if modOptions.unit_restrictions_noendgamelrpc then
		isEndGameLRPC = load("lolcannons.lua").unitDefMap
	end

	if modOptions.experimentalextraunits then
		extraBuildLists = load("extra_units.lua").buildOptionsList
	end
	if modOptions.scavunitsforplayers then
		scavengerBuildLists = load("scav_units_for_players.lua").buildOptionsList
	end
	if modOptions.releasecandidates or modOptions.experimentalextraunits then
		candidateBuildLists = load("release_candidates.lua").buildOptionsList
	end

	if modOptions.emprework then
		local empReworkData = load("emp_rework_defs.lua")
		empReworkUnit = empReworkData.unitDefReworks
		empReworkWeapon = empReworkData.weaponDefReworks
	end
	if modOptions.junorework then
		junoReworkUnit = load("juno_rework_defs.lua").unitDefReworks
	end
	if modOptions.air_rework then
		local airReworkData = load("air_rework_defs.lua")
		airReworkUnit = airReworkData.airReworkUnitTweaks
		airReworkWeapon = airReworkData.airReworkWeaponTweaks
	end
	if modOptions.skyshift then
		skyshiftReworkUnit = load("skyshiftunits_post.lua").skyshiftUnitTweaks
	end
	if modOptions.proposed_unit_reworks then
		proposedReworkUnit = load("proposed_unit_reworks_defs.lua").proposed_unit_reworksTweaks
	end
	if modOptions.community_balance_patch ~= "disabled" then
		communityBalanceUnit = load("community_balance_patch_defs.lua").communityBalanceTweaks
	end
	if modOptions.naval_balance_tweaks then
		navalBalanceUnit = load("proposed_naval_balance.lua").navalBalanceTweaks
	end
	if modOptions.lategame_rebalance then
		lategameBalanceUnit = load("proposed_lategame_balance.lua").unitDefReworks
	end
	if modOptions.factory_costs then
		factoryBalanceUnit = load("proposed_factory_balance.lua").factoryCostTweaks
	end
	if modOptions.techsplit then
		techSplitReworkUnit = load("techsplit_defs.lua").techsplitTweaks
	end
	if modOptions.techsplit_balance then
		techSplitBalanceUnit = load("techsplit_balance_defs.lua").techsplit_balanceTweaks
	end
end

function UnitDef_Post(name, uDef)
	if not isPostDataLoaded then
		loadAllDefsPostData()
	end

	local isScav = string.sub(name, -5, -1) == "_scav"
	local basename = isScav and string.sub(name, 1, -6) or name
	local decoyName = uDef.customparams and uDef.customparams.decoyfor or name

	local function lookup(tbl)
		return tbl[name] or tbl[basename] or tbl[decoyName]
	end

	if not uDef.icontype then
		uDef.icontype = name
	end

	--global physics behavior changes
	if uDef.health then
		uDef.minCollisionSpeed = 75 / Game.gameSpeed -- define the minimum velocity(speed) required for all units to suffer fall/collision damage.
	end

	if holidayObjectNames[name] then
		uDef.objectname = holidayObjectNames[name]
	end

	----------------------------------------------------------------------------------------------------------

	if uDef.sounds then
		if uDef.sounds.ok then
			uDef.sounds.ok = nil
		end

		if uDef.sounds.select then
			uDef.sounds.select = nil
		end

		if uDef.sounds.activate then
			uDef.sounds.activate = nil
		end
		if uDef.sounds.deactivate then
			uDef.sounds.deactivate = nil
		end
		if uDef.sounds.build then
			uDef.sounds.build = nil
		end

		if uDef.sounds.underattack then
			uDef.sounds.underattack = nil
		end
	end

	if uDef.customparams then
		if not uDef.customparams.techlevel then
			uDef.customparams.techlevel = 1
		end
		if not uDef.customparams.subfolder then
			uDef.customparams.subfolder = "none"
		end

		-- Unit Restrictions

		if modOptions.unit_restrictions_notech2 then
			if tonumber(uDef.customparams.techlevel) == 2 or tonumber(uDef.customparams.techlevel) == 3 then
				uDef.customparams.modoption_blocked = true
			end
		elseif modOptions.unit_restrictions_notech3 then
			if tonumber(uDef.customparams.techlevel) == 3 then
				uDef.customparams.modoption_blocked = true
			end
		end

		if modOptions.unit_restrictions_notech15 and lookup(isTechLevel15) then
			uDef.customparams.modoption_blocked = true
		end

		if modOptions.unit_restrictions_noair and not uDef.customparams.ignore_noair then
			if string.find(uDef.customparams.subfolder, "Aircraft", 1, true) then
				uDef.customparams.modoption_blocked = true
			elseif uDef.customparams.unitgroup and uDef.customparams.unitgroup == "aa" then
				uDef.customparams.modoption_blocked = true
			elseif uDef.canfly then
				uDef.customparams.modoption_blocked = true
			elseif uDef.customparams.disable_when_no_air then --used to remove drone carriers with no other purpose (ex. leghive but not rampart)
				uDef.customparams.modoption_blocked = true
			end
			if lookup(isAirFactory) then
				uDef.customparams.modoption_blocked = true
			end
		end

		if modOptions.unit_restrictions_noextractors then
			if (uDef.extractsmetal and uDef.extractsmetal > 0) and (uDef.customparams.metal_extractor and uDef.customparams.metal_extractor > 0) then
				uDef.customparams.modoption_blocked = true
			end
		end

		if modOptions.unit_restrictions_noconverters then
			if uDef.customparams.energyconv_capacity and uDef.customparams.energyconv_efficiency then
				uDef.customparams.modoption_blocked = true
			end
		end

		if modOptions.unit_restrictions_nofusion and lookup(isFusion) then
			uDef.customparams.modoption_blocked = true
		end

		if modOptions.unit_restrictions_nonukes then
			if uDef.weapondefs then
				for _, weapon in pairs(uDef.weapondefs) do
					if (weapon.interceptor and weapon.interceptor == 1) or (weapon.targetable and weapon.targetable == 1) then
						uDef.customparams.modoption_blocked = true
						break
					end
				end
			end
		end

		if modOptions.unit_restrictions_nodefence and not lookup(isUnrestrictedDefense) then
			local subfolder_lower = string.lower(uDef.customparams.subfolder)
			if string.find(subfolder_lower, "defen", 1, true) then
				uDef.customparams.modoption_blocked = true
			end
		end

		if modOptions.unit_restrictions_noantinuke then
			if uDef.weapondefs then
				local numWeapons = 0
				local newWdefs = {}
				local hasAnti = false
				for i, weapon in pairs(uDef.weapondefs) do
					if weapon.interceptor and weapon.interceptor == 1 then
						uDef.weapondefs[i] = nil
						hasAnti = true
					else
						numWeapons = numWeapons + 1
						newWdefs[numWeapons] = weapon
					end
				end
				if hasAnti then
					uDef.weapondefs = newWdefs
					if numWeapons == 0 and (not uDef.radardistance or uDef.radardistance < 1500) then
						uDef.customparams.modoption_blocked = true
					else
						if uDef.metalcost then
							uDef.metalcost = math.floor(uDef.metalcost * 0.6)	-- give a discount for removing anti-nuke
							uDef.energycost = math.floor(uDef.energycost * 0.6)
						end
					end
				end
			end
		end

		if	(modOptions.unit_restrictions_notacnukes and lookup(isTacticalNuke)) or
			(modOptions.unit_restrictions_nolrpc and lookup(isLongRangePlasmaCannon)) or
			(modOptions.unit_restrictions_noendgamelrpc and lookup(isEndGameLRPC))
		then
			uDef.customparams.modoption_blocked = true
		end

		-- Commander modoptions

		if modOptions.comrespawn == "all" or (modOptions.comrespawn == "evocom" and modOptions.evocom)then
			if name == "armcom" or name == "corcom" or name == "legcom" then
				uDef.customparams.effigy = "comeffigylvl1"
				uDef.customparams.effigy_offset = 1
				uDef.customparams.respawn_condition = "health"
				uDef.customparams.minimum_respawn_stun = 5
				uDef.customparams.distance_stun_multiplier = 1
				local numBuildoptions = #uDef.buildoptions
				uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl1"
			end
		end

		if modOptions.evocom then
			if uDef.customparams.evocomlvl or name == "armcom" or name == "corcom" or name == "legcom" then
				local comLevel = uDef.customparams.evocomlvl
				if modOptions.comrespawn == "all" or modOptions.comrespawn == "evocom" then--add effigy respawning, if enabled
					uDef.customparams.respawn_condition = "health"

					local numBuildoptions = #uDef.buildoptions
					if comLevel == 2 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl1"
					elseif comLevel == 3 or comLevel == 4 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl2"
					elseif comLevel == 5 or comLevel == 6 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl3"
					elseif comLevel == 7 or comLevel == 8 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl4"
					elseif comLevel == 9 or comLevel == 10 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl5"
					end
				end
				uDef.customparams.combatradius = 0
				uDef.customparams.evolution_health_transfer = "percentage"

				if uDef.power then
					uDef.power = uDef.power/modOptions.evocomxpmultiplier
				else
					uDef.power = ((uDef.metalcost+(uDef.energycost/60))/modOptions.evocomxpmultiplier)
				end

				if  name == "armcom" then
					uDef.customparams.evolution_target = "armcomlvl2"
					uDef.customparams.inheritxpratemultiplier = 0.5
					uDef.customparams.childreninheritxp = "TURRET MOBILEBUILT"
					uDef.customparams.parentsinheritxp = "TURRET MOBILEBUILT"
					uDef.customparams.evocomlvl = 1
					elseif name == "corcom" then
					uDef.customparams.evolution_target = "corcomlvl2"
					uDef.customparams.evocomlvl = 1
					elseif name == "legcom" then
					uDef.customparams.evolution_target = "legcomlvl2"
					uDef.customparams.evocomlvl = 1
					end

				if modOptions.evocomlevelupmethod == "dynamic" then
					uDef.customparams.evolution_condition = "power"
					uDef.customparams.evolution_power_multiplier = 1			-- Scales the power calculated based on your own combined power.
					local evolutionPowerThreshold = uDef.customparams.evolution_power_threshold or 10000 --sets threshold for level 1 commanders
					uDef.customparams.evolution_power_threshold = evolutionPowerThreshold*modOptions.evocomlevelupmultiplier
				elseif modOptions.evocomlevelupmethod == "timed" then
					uDef.customparams.evolution_timer = modOptions.evocomleveluptime*60*uDef.customparams.evocomlvl
					uDef.customparams.evolution_condition = "timer_global"
				end

				if comLevel and modOptions.evocomlevelcap <= comLevel then
					uDef.customparams.evolution_health_transfer = nil
					uDef.customparams.evolution_target = nil
					uDef.customparams.evolution_condition = nil
					uDef.customparams.evolution_timer = nil
					uDef.customparams.evolution_power_threshold = nil
					uDef.customparams.evolution_power_multiplier = nil
				end
			end
		end

		if uDef.customparams.evolution_target then
			local udcp                            = uDef.customparams
			udcp.combatradius                     = udcp.combatradius or 1000
			udcp.evolution_announcement_size      = tonumber(udcp.evolution_announcement_size)
			udcp.evolution_condition              = udcp.evolution_condition or "timer"
			udcp.evolution_health_threshold       = tonumber(udcp.evolution_health_threshold) or 0
			udcp.evolution_health_transfer        = udcp.evolution_health_transfer or "flat"
			udcp.evolution_power_enemy_multiplier = tonumber(udcp.evolution_power_enemy_multiplier) or 1
			udcp.evolution_power_multiplier       = tonumber(udcp.evolution_power_multiplier) or 1
			udcp.evolution_power_threshold        = tonumber(udcp.evolution_power_threshold) or 600
			udcp.evolution_timer                  = tonumber(udcp.evolution_timer) or 20
		end
	end

	-- Tech Blocking System -------------------------------------------------------------------------------------------------------------------------
	if modOptions.tech_blocking and uDef.customparams then
		local techLevel = uDef.customparams.techlevel or 1
		if uDef.buildoptions and #uDef.buildoptions > 0 and (not uDef.speed or uDef.speed == 0) then
			if techLevel == 1 then
				uDef.customparams.tech_points_gain = uDef.customparams.tech_points_gain or 1
			elseif techLevel == 2 then
				uDef.customparams.tech_points_gain = uDef.customparams.tech_points_gain or 6
				uDef.customparams.tech_build_blocked_until_level = uDef.customparams.tech_build_blocked_until_level or 2
			elseif techLevel == 3 then
				uDef.customparams.tech_points_gain = uDef.customparams.tech_points_gain or 9
				uDef.customparams.tech_build_blocked_until_level = uDef.customparams.tech_build_blocked_until_level or 3
			end
		end
	end

	-- Extra Units ----------------------------------------------------------------------------------------------------------------------------------
	if modOptions.experimentalextraunits and lookup(extraBuildLists) then
		uDef.buildoptions = table.appendArray(uDef.buildoptions or {}, lookup(extraBuildLists))
	end

	-- Scavengers Units ------------------------------------------------------------------------------------------------------------------------
	if modOptions.scavunitsforplayers and lookup(scavengerBuildLists) then
		uDef.buildoptions = table.appendArray(uDef.buildoptions or {}, lookup(scavengerBuildLists))
	end

	-- Release candidate units --------------------------------------------------------------------------------------------------------------------------------------------------------
	if modOptions.releasecandidates or modOptions.experimentalextraunits and lookup(candidateBuildLists) then
		uDef.buildoptions = table.appendArray(uDef.buildoptions or {}, lookup(candidateBuildLists))
	end

	if string.find(name, "raptor", 1, true) and uDef.health then
		local raptorHealth = uDef.health
		uDef.activatewhenbuilt = true
		uDef.metalcost = raptorHealth * 0.5
		uDef.energycost = math.min(raptorHealth * 5, 16000000)
		uDef.buildtime = math.min(raptorHealth * 10, 16000000)
		uDef.hidedamage = true
		uDef.mass = raptorHealth
		uDef.canhover = true
		uDef.autoheal = math.ceil(math.sqrt(raptorHealth * 0.8))
		uDef.customparams.paralyzemultiplier = uDef.customparams.paralyzemultiplier or .2
		uDef.customparams.areadamageresistance = "_RAPTORACID_"
		uDef.upright = false
		uDef.floater = true
		uDef.turninplace = true
		uDef.turninplaceanglelimit = 360
		uDef.capturable = false
		uDef.leavetracks = false
		uDef.maxwaterdepth = 0

		if uDef.cancloak then
			uDef.cloakcost = 0
			uDef.cloakcostmoving = 0
			uDef.mincloakdistance = 100
			uDef.seismicsignature = 3
			uDef.initcloaked = 1
		else
			uDef.seismicsignature = 0
		end

		if uDef.sightdistance then
			uDef.sonardistance = uDef.sightdistance * 2
			uDef.radardistance = uDef.sightdistance * 2
			uDef.airsightdistance = uDef.sightdistance * 2
		end

		if (not uDef.canfly) and uDef.speed then
			uDef.rspeed = uDef.speed * 0.65
			uDef.turnrate = uDef.speed * 10
			uDef.maxacc = uDef.speed * 0.00166
			uDef.maxdec = uDef.speed * 0.00166
		elseif uDef.canfly then
				uDef.maxacc = 1
				uDef.maxdec = 0.25
				uDef.usesmoothmesh = true

				-- flightmodel
				uDef.maxaileron = 0.025
				uDef.maxbank = 0.8
				uDef.maxelevator = 0.025
				uDef.maxpitch = 0.75
				uDef.maxrudder = 0.025
				uDef.wingangle = 0.06593
				uDef.wingdrag = 0.835
				uDef.turnradius = 64
				uDef.turnrate = 1600
				uDef.speedtofront = 0.01
				--uDef.attackrunlength = 32
		end
	end

	--[[ Sanitize to whole frames (plus leeways because float arithmetic is bonkers).
         The engine uses full frames for actual reload times, but forwards the raw
         value to LuaUI (so for example calculated DPS is incorrect without sanitisation). ]]
	processWeapons(name, uDef)

	-- make los height a bit more forgiving	(20 is the default)
	--uDef.sightemitheight = (uDef.sightemitheight and uDef.sightemitheight or 20) + 20
	if true then
		local sightHeight = 0
		local radarHeight = 0

		if uDef.collisionvolumescales then
			local _, yScale = string.match(uDef.collisionvolumescales, "([^%s]+)%s+([^%s]+)")
			if yScale then
				local yVal = tonumber(yScale)
				sightHeight = sightHeight + yVal
				radarHeight = radarHeight + yVal
			end
		end

		if uDef.collisionvolumeoffsets then
			local _, yOffset = string.match(uDef.collisionvolumeoffsets, "([^%s]+)%s+([^%s]+)")
			if yOffset then
				local yVal = tonumber(yOffset)
				sightHeight = sightHeight + yVal
				radarHeight = radarHeight + yVal
			end
		end

		if sightHeight < 40 then
			sightHeight = 40
			radarHeight = 40
		end

		uDef.sightemitheight = sightHeight
		uDef.radaremitheight = radarHeight
	end

	-- Wreck and heap standardization
	if not uDef.customparams.iscommander and not uDef.customparams.iseffigy then
		if uDef.featuredefs and uDef.health then
			-- wrecks
			if uDef.featuredefs.dead then
				uDef.featuredefs.dead.damage = uDef.health
				if uDef.metalcost and uDef.energycost then
					uDef.featuredefs.dead.metal = math.floor(uDef.metalcost * 0.6)
				end
			end
			-- heaps
			if uDef.featuredefs.heap then
				uDef.featuredefs.heap.damage = uDef.health
				if uDef.metalcost and uDef.energycost then
					uDef.featuredefs.heap.metal = math.floor(uDef.metalcost * 0.25)
				end
			end
		end
	end

	if uDef.maxslope then
		uDef.maxslope = math.floor((uDef.maxslope * 1.5) + 0.5)
	end

	----------------------------------------------------------------------
	-- CATEGORY ASSIGNER
	----------------------------------------------------------------------
	local unitCategories = (uDef.category or ""):split()
	if table.contains(unitCategories, "OBJECT") then
		uDef.category = "OBJECT" -- must not be targetable and therefore have no other category
	else
		for categoryName, condition in pairs(categories) do
			if condition(uDef) then
				table.insert(unitCategories, categoryName)
			end
		end
		uDef.category = table.concat(unitCategories, " ")
	end

	if uDef.canfly then
		uDef.crashdrag = 0.01    -- default 0.005
		if not (string.find(name, "fepoch", 1, true) or string.find(name, "fblackhy", 1, true) or string.find(name, "corcrw", 1, true) or string.find(name, "legfort", 1, true)) then
			--(string.find(name, "liche") or string.find(name, "crw") or string.find(name, "fepoch") or string.find(name, "fblackhy")) then
			uDef.collide = false
		end
	end

	if uDef.metalcost and uDef.health and uDef.canmove == true and uDef.mass == nil then
		local healthmass = math.ceil(uDef.health/6)
		uDef.mass = math.max(uDef.metalcost, healthmass)
		if uDef.metalcost < 751 and uDef.mass > 750 then
			uDef.mass = 750
		end
		--if uDef.metalcost < healthmass then
		--	Spring.Echo(name, uDef.mass, uDef.metalcost, uDef.mass - uDef.metalcost)
		--end
	end

	-- Sets idleautoheal to 5hp/s after 1800 frames aka 1 minute. 
	if uDef.idleautoheal == nil then
		uDef.idleautoheal = 5
	end
	if uDef.idletime == nil then
		uDef.idletime = 1800
	end

	-- Unit reworks and balance proposals

	if modOptions.junorework == true and lookup(junoReworkUnit) then
		table.mergeInPlace(uDef, lookup(junoReworkUnit))
	end

	if modOptions.emprework == true and lookup(empReworkUnit) then
		table.mergeInPlace(uDef, lookup(empReworkUnit))
	end

	if modOptions.air_rework == true then
		uDef = airReworkUnit(name, uDef)
	end

	if modOptions.skyshift == true then
		uDef = skyshiftReworkUnit(name, uDef)
	end

	if modOptions.proposed_unit_reworks == true then
		uDef = proposedReworkUnit(name, uDef)
	end

	if modOptions.community_balance_patch ~= "disabled" then
		uDef = communityBalanceUnit(name, uDef, modOptions)
	end

	if modOptions.naval_balance_tweaks == true then
		uDef = navalBalanceUnit(name, uDef)
	end

	if modOptions.lategame_rebalance == true and lookup(lategameBalanceUnit) then
		table.mergeInPlace(uDef, lookup(lategameBalanceUnit))
	end

	if modOptions.factory_costs == true then
		uDef = factoryBalanceUnit(name, uDef)
	end

	if modOptions.techsplit == true then
		uDef = techSplitReworkUnit(name, uDef)
	end

	if modOptions.techsplit_balance == true then
		uDef = techSplitBalanceUnit(name, uDef)
	end

	-- Experimental Low Priority Pacifists
	if modOptions.experimental_low_priority_pacifists then
		if uDef.energycost and uDef.metalcost and (not uDef.weapons or #uDef.weapons == 0) and uDef.speed and uDef.speed > 0 and
		(string.find(name, "arm") or string.find(name, "cor") or string.find(name, "leg")) then
			uDef.power = uDef.power or ((uDef.metalcost + uDef.energycost / 60) * 0.1) --recreate the default power formula obtained from the spring wiki for target prioritization
		end
	end

	-- Multipliers Modoptions

	-- Max Speed
	if uDef.speed then
		local x = modOptions.multiplier_maxvelocity
		if x ~= 1 then
			uDef.speed = uDef.speed * x
			if uDef.maxdec then
				uDef.maxdec = uDef.maxdec * ((x - 1) / 2 + 1)
			end
			if uDef.maxacc then
				uDef.maxacc = uDef.maxacc * ((x - 1) / 2 + 1)
			end
		end
	end

	-- Turn Speed
	if uDef.turnrate then
		local x = modOptions.multiplier_turnrate
		if x ~= 1 then
			uDef.turnrate = uDef.turnrate * x
		end
	end

	-- Build Distance
	if uDef.builddistance then
		local x = modOptions.multiplier_builddistance
		if x ~= 1 then
			uDef.builddistance = uDef.builddistance * x
		end
	end

	-- Buildpower
	if uDef.workertime then
		local x = modOptions.multiplier_buildpower
		if x ~= 1 then
			uDef.workertime = uDef.workertime * x
		end

		-- increase terraformspeed to be able to restore ground faster
		uDef.terraformspeed = uDef.workertime * 30
	end

	--energystorage
	--metalstorage
	-- Metal Extraction Multiplier
	if (uDef.extractsmetal and uDef.extractsmetal > 0) and (uDef.customparams.metal_extractor and uDef.customparams.metal_extractor > 0) then
		local x = modOptions.multiplier_metalextraction * modOptions.multiplier_resourceincome
		uDef.extractsmetal = uDef.extractsmetal * x
		uDef.customparams.metal_extractor = uDef.customparams.metal_extractor * x
		if uDef.metalstorage then
			uDef.metalstorage = uDef.metalstorage * x
		end
	end

	-- Energy Production Multiplier
	if uDef.energymake then
		local x = modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome
		uDef.energymake = uDef.energymake * x
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end
	if uDef.windgenerator and uDef.windgenerator > 0 then
		local x = modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome
		uDef.windgenerator = uDef.windgenerator * x
		if uDef.customparams.energymultiplier then
			uDef.customparams.energymultiplier = tonumber(uDef.customparams.energymultiplier) * x
		else
			uDef.customparams.energymultiplier = x
		end
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end
	if uDef.tidalgenerator then
		local x = modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome
		uDef.tidalgenerator = uDef.tidalgenerator * x
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end
	if uDef.energyupkeep and uDef.energyupkeep < 0 then
		-- units with negative upkeep means they produce energy when "on".
		local x = modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome
		uDef.energyupkeep = uDef.energyupkeep * x
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end

	-- Energy Conversion Multiplier
	if uDef.customparams.energyconv_capacity and uDef.customparams.energyconv_efficiency then
		local x = modOptions.multiplier_energyconversion * modOptions.multiplier_resourceincome
		--uDef.customparams.energyconv_capacity = uDef.customparams.energyconv_capacity * x
		uDef.customparams.energyconv_efficiency = uDef.customparams.energyconv_efficiency * x
		if uDef.metalstorage then
			uDef.metalstorage = uDef.metalstorage * x
		end
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end

	-- Sensors range
	if uDef.sightdistance then
		local x = modOptions.multiplier_losrange
		if x ~= 1 then
			uDef.sightdistance = uDef.sightdistance * x
		end
	end

	if uDef.airsightdistance then
		local x = modOptions.multiplier_losrange
		if x ~= 1 then
			uDef.airsightdistance = uDef.airsightdistance * x
		end
	end

	if uDef.radardistance then
		local x = modOptions.multiplier_radarrange
		if x ~= 1 then
			uDef.radardistance = uDef.radardistance * x
		end
	end

	if uDef.sonardistance then
		local x = modOptions.multiplier_radarrange
		if x ~= 1 then
			uDef.sonardistance = uDef.sonardistance * x
		end
	end

	-- bounce shields
	if modOptions.experimentalshields == "bounceplasma" or modOptions.experimentalshields == "bounceeverything" then
		local shieldPowerMultiplier = 0.529 --converts to pre-shield rework vanilla integration
		if uDef.customparams and uDef.customparams.shield_power then
			uDef.customparams.shield_power = uDef.customparams.shield_power * shieldPowerMultiplier
		end
	end

	-- add model vertex displacement
	local vertexDisplacement = 5.5 + ((uDef.footprintx + uDef.footprintz) / 12)
	if vertexDisplacement > 10 then
		vertexDisplacement = 10
	end
	uDef.customparams.vertdisp = 1.0 * vertexDisplacement
	uDef.customparams.healthlookmod = 0

	-- Animation Cleanup
	if modOptions.animationcleanup  then
		if uDef.script then
			local oldscript = uDef.script:lower()
			if oldscript:find(".cob", nil, true) and (not oldscript:find("_clean.", nil, true)) then
				local newscript = string.sub(oldscript, 1, -5) .. "_clean.cob"
				if VFS.FileExists('scripts/'..newscript) then
					Spring.Echo("Using new script for", name, oldscript, '->', newscript)
					uDef.script = newscript
				else
					Spring.Echo("Unable to find new script for", name, oldscript, '->', newscript, "using old one")
				end
			end
		end
	end

	if uDef.buildoptions and next(uDef.buildoptions) then
		-- Remove invalid unit defs.
		for index, option in pairs(uDef.buildoptions) do
			if not UnitDefs[option] then
				Spring.Log("AllDefs", LOG.INFO, "Removed buildoption (unit not loaded?): " .. tostring(option))
				uDef.buildoptions[index] = nil
			end
		end
		-- Deduplicate buildoptions (various modoptions or later mods can add the same units)
		-- Multiple unit defs can share the same table reference, so we create a new table for each
		uDef.buildoptions = table.getUniqueArray(uDef.buildoptions)
	end
end

local function ProcessSoundDefaults(wd)
	local forceSetVolume = not wd.soundstartvolume or not wd.soundhitvolume or not wd.soundhitwetvolume
	if not forceSetVolume then
		return
	end

	local defaultDamage = wd.damage and wd.damage.default

	if not defaultDamage or defaultDamage <= 50 then
		-- old filter that gave small weapons a base-minumum sound volume, now fixed with noew math.min(math.max)
		-- if not defaultDamage then
		wd.soundstartvolume = 5
		wd.soundhitvolume = 5
		wd.soundhitwetvolume = 5
		return
	end

	local soundVolume = math.sqrt(defaultDamage * 0.5)

	if wd.weapontype == "LaserCannon" then
		soundVolume = soundVolume * 0.5
	end

	if not wd.soundstartvolume then
		wd.soundstartvolume = soundVolume
	end
	if not wd.soundhitvolume then
		wd.soundhitvolume = soundVolume
	end
	if not wd.soundhitwetvolume then
		if wd.weapontype == "LaserCannon" or "BeamLaser" then
			wd.soundhitwetvolume = soundVolume * 0.3
		else
			wd.soundhitwetvolume = soundVolume * 1.4
		end
	end
end

-- process weapondef
function WeaponDef_Post(name, wDef)
	if not isPostDataLoaded then
		loadAllDefsPostData()
	end

	wDef.customparams = wDef.customparams or {}

	if not SaveDefsToCustomParams then
		-------------- EXPERIMENTAL MODOPTIONS

		-- Standard Gravity
		local gravityOverwriteExemptions = { --add the name of the weapons (or just the name of the unit followed by _ ) to this table to exempt from gravity standardization.
			'cormship_', 'armmship_'
		}
		if wDef.gravityaffected == "true" and wDef.mygravity == nil then
			local isExempt = false

			for _, exemption in ipairs(gravityOverwriteExemptions) do
				if string.find(name, exemption) then
					isExempt = true
					break
				end
			end
			if not isExempt then
				wDef.mygravity = 0.1445
			end
		end

		-- Weapon reworks

		if modOptions.emprework and empReworkWeapon[name] then
			table.mergeInPlace(wDef, empReworkWeapon[name])
		end

		if modOptions.air_rework == true then
			airReworkWeapon(name, wDef)
		end

		-- Shields and shield interceptability

		if wDef.weapontype == "DGun" then
			wDef.interceptedbyshieldtype = 512 --make dgun (like behemoth) interceptable by shields, optionally
		elseif wDef.weapontype == "StarburstLauncher" and not string.find(name, "raptor") then
			wDef.interceptedbyshieldtype = 1024 --separate from combined MissileLauncher, except raptors
		end

		local shieldModOption = modOptions.experimentalshields
		local engineShields = shieldModOption == "bounceeverything" or shieldModOption == "bounceplasma" -- repulsion is engine-based
		if engineShields then
			local shieldPowerMultiplier = 0.529 --converts to pre-shield rework vanilla integration
			local shieldRegenMultiplier = 0.4 --converts to pre-shield rework vanilla integration
			if wDef.shield then
				wDef.shield.power = wDef.shield.power * shieldPowerMultiplier
				wDef.shield.powerregen = wDef.shield.powerregen * shieldRegenMultiplier
				wDef.shield.startingpower = wDef.shield.startingpower * shieldPowerMultiplier
				wDef.shield.repulser = true
			elseif shieldModOption == "bounceeverything" then
				wDef.interceptedbyshieldtype = 1
			end
		elseif wDef.shield then
			wDef.shield.repulser = false -- disabled for custom/lua shields
		else
			if shieldModOption == "absorbeverything" then
				wDef.interceptedbyshieldtype = 1
			elseif wDef.interceptedbyshieldtype ~= 1 and wDef.weapontype ~= "Cannon" then
				wDef.customparams.shield_aoe_penetration = true -- allows unblocked weapons' aoe to reach inside shields
			end

			if wDef.damage ~= nil then
				-- For balance, paralyzers need to do reduced damage to shields, as their raw raw damage is outsized
				local paralyzerShieldDamageMultiplier = 0.25
				-- VTOL's may or may not do full damage to shields if not defined in weapondefs
				local vtolShieldDamageMultiplier = 0

				if wDef.damage.shields then
					wDef.customparams.shield_damage = wDef.damage.shields
				elseif wDef.damage.default then
					wDef.customparams.shield_damage = wDef.damage.default
				elseif wDef.damage.vtol then
					wDef.customparams.shield_damage = wDef.damage.vtol * vtolShieldDamageMultiplier
				else
					wDef.customparams.shield_damage = 0
				end

				if wDef.paralyzer then
					wDef.customparams.shield_damage = wDef.customparams.shield_damage * paralyzerShieldDamageMultiplier
				end

				-- Set damage to 0 so projectiles always collide with shield. Without this, if damage > shield charge then it passes through.
				-- Applying damage is instead handled in unit_shield_behavior.lua
				wDef.damage.shields = 0

				if wDef.beamtime and wDef.beamtime > 1 / Game.gameSpeed then
					-- This splits up the damage of hitscan weapons over the duration of beamtime, as each frame counts as a hit in ShieldPreDamaged() callin
					-- Math.floor is used to sheer off the extra digits of the number of frames that the hits occur
					wDef.customparams.beamtime_damage_reduction_multiplier = 1 / math.floor(wDef.beamtime * Game.gameSpeed)
				end
			end
		end

		----------------------------------------

		--Controls whether the weapon aims for the center or the edge of its target's collision volume. Clamped between -1.0 - target the far border, and 1.0 - target the near border.
		if wDef.targetborder == nil then
			wDef.targetborder = 1 --Aim for just inside the hitsphere

			if Engine.FeatureSupport.targetBorderBug and wDef.weapontype == "BeamLaser" or wDef.weapontype == "LightningCannon" then
				wDef.targetborder = 0.33 --approximates in current engine with bugged calculation, to targetborder = 1.
			end
		end

		-- Prevent weapons from aiming only at auto-generated targets beyond their own range.
		if wDef.proximitypriority then
			local range = math.max(wDef.range or 10, 1) -- prevent div0 -- todo: account for multiplier_weaponrange
			local rangeBoost = math.max(range + ((wDef.customparams.exclude_preaim and 0) or (wDef.customparams.preaim_range or math.max(range * 0.1, 20))), range) -- see unit_preaim
			local proximity = math.max(wDef.proximitypriority, (-0.4 * rangeBoost - 100) / range) -- see CGameHelper::GenerateWeaponTargets
			wDef.proximitypriority = math.clamp(proximity, -1, 10) -- upper range allowed for targeting weapons for drone bombers which can overrange massively
		end

		if wDef.craterareaofeffect then
			wDef.cratermult = (wDef.cratermult or 0) + wDef.craterareaofeffect / 2000
		end

		if wDef.weapontype == "Cannon" then
			if not wDef.model then
				-- do not cast shadows on plasma shells
				wDef.castshadow = false
			end

			if wDef.stages == nil then
				wDef.stages = 10
				if wDef.damage ~= nil and wDef.damage.default ~= nil and wDef.areaofeffect ~= nil then
					wDef.stages = math.floor(7.5 + math.min(wDef.damage.default * 0.0033, wDef.areaofeffect * 0.13))
					wDef.alphadecay = 1 - ((1 / wDef.stages) / 1.5)
					wDef.sizedecay = 0.4 / wDef.stages
				end
			end

		elseif wDef.weapontype == "StarburstLauncher" then
			if holidays.xmas and wDef.model and VFS.FileExists('objects3d\\candycane_' .. wDef.model) then
				wDef.model = 'candycane_' .. wDef.model
			end

		elseif wDef.weapontype == "BeamLaser" then
			if wDef.beamttl == nil then
				wDef.beamttl = 3
				wDef.beamdecay = 0.7
			end
			if wDef.corethickness then
				wDef.corethickness = wDef.corethickness * 1.21
			end
			if wDef.thickness then
				wDef.thickness = wDef.thickness * 1.27
			end
			if wDef.laserflaresize then
				wDef.laserflaresize = wDef.laserflaresize * 1.15        -- note: thickness affects this too
			end
			wDef.texture1 = "largebeam"        -- The projectile texture
			wDef.texture3 = "flare2"    -- Flare texture for #BeamLaser
			wDef.texture4 = "flare2"    -- Flare texture for #BeamLaser with largeBeamLaser = true
		end

		-- prepared to strip these customparams for when we remove old deferred lighting widgets
		--if wDef.customparams then
		--	wDef.customparams.expl_light_opacity = nil
		--	wDef.customparams.expl_light_heat_radius = nil
		--	wDef.customparams.expl_light_radius = nil
		--	wDef.customparams.expl_light_color = nil
		--	wDef.customparams.expl_light_nuke = nil
		--	wDef.customparams.expl_light_skip = nil
		--	wDef.customparams.expl_light_heat_life_mult = nil
		--	wDef.customparams.expl_light_heat_radius_mult = nil
		--	wDef.customparams.expl_light_heat_strength_mult = nil
		--	wDef.customparams.expl_light_life = nil
		--	wDef.customparams.expl_light_life_mult = nil
		--	wDef.customparams.expl_noheatdistortion = nil
		--	wDef.customparams.light_skip = nil
		--	wDef.customparams.light_fade_time = nil
		--	wDef.customparams.light_fade_offset = nil
		--	wDef.customparams.light_beam_mult = nil
		--	wDef.customparams.light_beam_start = nil
		--	wDef.customparams.light_beam_mult_frames = nil
		--	wDef.customparams.light_camera_height = nil
		--	wDef.customparams.light_ground_height = nil
		--	wDef.customparams.light_color = nil
		--	wDef.customparams.light_radius = nil
		--	wDef.customparams.light_radius_mult = nil
		--	wDef.customparams.light_mult = nil
		--	wDef.customparams.fake_Weapon = nil
		--end

		if wDef.damage ~= nil then
			wDef.damage.indestructable = 0
		end

		-- scavengers
		if string.find(name, '_scav', 1, true) then
			VFS.Include("gamedata/scavengers/weapondef_post.lua")
			wDef = scav_Wdef_Post(name, wDef)
		end

		ProcessSoundDefaults(wDef)
	end

	-- Multipliers

	if wDef.shield then
		local powerMult = modOptions.multiplier_shieldpower
		if powerMult ~= 1 then
			if wDef.shield.power then
				wDef.shield.power = wDef.shield.power * powerMult
			end
			if wDef.shield.powerregen then
				wDef.shield.powerregen = wDef.shield.powerregen * powerMult
			end
			if wDef.shield.powerregenenergy then
				wDef.shield.powerregenenergy = wDef.shield.powerregenenergy * powerMult
			end
			if wDef.shield.startingpower then
				wDef.shield.startingpower = wDef.shield.startingpower * powerMult
			end
		end
	end

	-- Weapon Range
	local rangeMult = modOptions.multiplier_weaponrange
	if rangeMult ~= 1 then
		if wDef.range then
			wDef.range = wDef.range * rangeMult
		end
		if wDef.flighttime then
			wDef.flighttime = wDef.flighttime * (rangeMult * 1.5)
		end
		if wDef.weaponvelocity and wDef.weapontype == "Cannon" and wDef.gravityaffected == "true" then
			wDef.weaponvelocity = wDef.weaponvelocity * math.sqrt(rangeMult)
		end
		if wDef.weapontype == "StarburstLauncher" and wDef.weapontimer then
			wDef.weapontimer = wDef.weapontimer + (wDef.weapontimer * ((rangeMult - 1) * 0.4))
		end
		if wDef.customparams.overrange_distance then
			wDef.customparams.overrange_distance = wDef.customparams.overrange_distance * rangeMult
		end
		if wDef.customparams.preaim_range then
			wDef.customparams.preaim_range = wDef.customparams.preaim_range * rangeMult
		end
	end

	-- Weapon Damage
	local damageMult = modOptions.multiplier_weapondamage
	if damageMult ~= 1 then
		if wDef.damage then
			for damageClass, damageValue in pairs(wDef.damage) do
				wDef.damage[damageClass] = damageValue * damageMult
			end
		end
	end

	-- ExplosionSpeed is calculated same way engine does it, and then doubled
	-- Note that this modifier will only effect weapons fired from actual units, via super clever hax of using the weapon name as prefix
	if wDef.damage and wDef.damage.default then
		if string.find(name, '_', 1, true) then
			local prefix = string.sub(name, 1, 3)
			if prefix == 'arm' or prefix == 'cor' or prefix == 'leg' or prefix == 'rap' then
				local globaldamage = math.max(30, wDef.damage.default / 20)
				local defExpSpeed = (8 + (globaldamage * 2.5)) / (9 + (math.sqrt(globaldamage) * 0.70)) * 0.5
				wDef.explosionSpeed = defExpSpeed * 2
			end
		end
	end
end

-- process effects
function ExplosionDef_Post(name, eDef)

end

--------------------------
-- MODOPTIONS
-------------------------

-- process modoptions (last, because they should not get baked)
function ModOptions_Post (UnitDefs, WeaponDefs)

	-- transporting enemy coms
	if Spring.GetModOptions().transportenemy == "notcoms" then
		for name, ud in pairs(UnitDefs) do
			if ud.customparams.iscommander then
				ud.transportbyenemy = false
			end
		end
	elseif Spring.GetModOptions().transportenemy == "none" then
		for name, ud in pairs(UnitDefs) do
			ud.transportbyenemy = false
		end
	end

	-- For Decals GL4, disables default groundscars for explosions
	for _, wDef in pairs(WeaponDefs) do
		wDef.explosionScar = false
	end
end
