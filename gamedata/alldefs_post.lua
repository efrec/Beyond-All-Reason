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

---@type number The minimum speed required for units to suffer fall/collision damage.
local COLLISION_SPEED_MIN = 75 / Game.gameSpeed

local metaLowerkeys
do
	local function lower(key)
		return type(key) == "string" and key:lower() or key
	end
	metaLowerkeys = {
		__index = function (self, key)
			return rawget(self, lower(key))
		end,
		__newindex = function (self, key, value)
			return rawset(self, lower(key), value)
		end,
	}
end

-------------------------
-- UNIT CATEGORIES

local hoverList = {
	HOVER2 = true,
	HOVER3 = true,
	HHOVER4 = true,
	HOVER5 = true
}

local shipList = {
	BOAT3 = true,
	BOAT4 = true,
	BOAT5 = true,
	BOAT8 = true,
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
	ABOT2 = true,
	HABOT5 = true,
	ABOTBOMB2 = true,
	EPICBOT = true,
	EPICALLTERRAIN = true
}

local commanderList = {
	COMMANDERBOT = true,
	SCAVCOMMANDERBOT = true
}

local categories -- for lexical scope; see below

categories = {
	-- Manual categories: OBJECT T4AIR LIGHTAIRSCOUT GROUNDSCOUT RAPTOR
	-- Deprecated caregories: BOT TANK PHIB NOTLAND SPACE
	ALL = function() return true end,
	MOBILE = function(uDef)
		return uDef.speed and uDef.speed > 0
	end,
	NOTMOBILE = function(uDef)
		return not categories.MOBILE(uDef)
	end,
	WEAPON = function(uDef)
		return uDef.weapondefs ~= nil
	end,
	NOWEAPON = function(uDef)
		return not categories.WEAPON(uDef)
	end,
	VTOL = function(uDef)
		return uDef.canfly == true
	end,
	NOTAIR = function(uDef)
		return not categories.VTOL(uDef)
	end,
	-- convertible tank/boats have maxwaterdepth:
	HOVER = function(uDef)
		return hoverList[uDef.movementclass] and (uDef.maxwaterdepth == nil or uDef.maxwaterdepth < 1)
	end,
	NOTHOVER = function(uDef)
		return not categories.HOVER(uDef)
	end,
	SHIP = function(uDef)
		return shipList[uDef.movementclass]
			or (hoverList[uDef.movementclass] and uDef.maxwaterdepth and uDef.maxwaterdepth >= 1)
	end,
	NOTSHIP = function(uDef)
		return not categories.SHIP(uDef)
	end,
	NOTSUB = function(uDef)
		return not subList[uDef.movementclass]
	end,
	CANBEUW = function(uDef)
		return amphibList[uDef.movementclass] or uDef.cansubmerge == true
	end,
	UNDERWATER = function(uDef)
		return (uDef.minwaterdepth and uDef.waterline == nil)
			or (uDef.minwaterdepth and uDef.waterline > uDef.minwaterdepth and uDef.speed and uDef.speed > 0)
	end,
	SURFACE = function(uDef)
		return not (categories.UNDERWATER(uDef) and categories.MOBILE(uDef)) and not categories.VTOL(uDef)
	end,
	MINE = function(uDef)
		return uDef.weapondefs and uDef.weapondefs.minerange
	end,
	COMMANDER = function(uDef)
		return commanderList[uDef.movementclass]
	end,
	EMPABLE = function(uDef)
		return categories.SURFACE(uDef) and uDef.customparams and uDef.customparams.paralyzemultiplier ~= 0
	end,
}

-------------------------
-- RAPTOR DEFS

local function applyRaptorEffect(name, uDef)
	local raptorHealth = uDef.health
	uDef.activatewhenbuilt = true
	uDef.metalcost = raptorHealth * 0.5
	uDef.energycost = math.min(raptorHealth * 5, 16000000)
	uDef.buildtime = math.min(raptorHealth * 10, 16000000)
	uDef.hidedamage = true
	uDef.mass = raptorHealth
	uDef.canhover = true
	uDef.autoheal = math.ceil(math.sqrt(raptorHealth * 0.2))
	uDef.customparams.paralyzemultiplier = uDef.customparams.paralyzemultiplier or .2
	uDef.idleautoheal = math.ceil(math.sqrt(raptorHealth * 0.2))
	uDef.idletime = 1
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

-------------------------
-- UNIT DEF POST EFFECTS

---Sequence of effects that are applied during `UnitDef_Post`.
---@type function[]
local unitDefPostEffectList = {
	-- General transforms applied to all units:
	function(name, unitDef)
		-- Force all keys to lowercase. Only applies to the top-level keys.
		for k, v in pairs(unitDef) do
			if type(k) == "string" and k ~= k:lower() then
				unitDef[k:lower()] = v
				unitDef[k] = nil
			end
		end
		unitDef = setmetatable(unitDef, metaLowerkeys)

		-- Ensure subtables exist.
		unitDef.buildoptions = unitDef.buildoptions or {}
		unitDef.customparams = unitDef.customparams or {}

		-- Unit name and identity
		unitDef.basename = name:gsub("_scav$", "")
		unitDef.icontype = unitDef.icontype or name
		unitDef.customparams.israptorunit = name:match("^raptor")
		unitDef.customparams.isscavengerunit = name:match("_scav$")
		unitDef.customparams.subfolder = unitDef.customparams.subfolder or "none"
		unitDef.customparams.techlevel = unitDef.customparams.techlevel or 1
		unitDef.category = unitDef.category or ""
		if string.find(unitDef.category, "OBJECT") then
			-- Objects should not be targetable and therefore are not assigned any other category
			unitDef.category = "OBJECT"
		else
			for categoryName, condition in pairs(categories) do
				if unitDef.exemptcategory == nil or not string.find(unitDef.exemptcategory, categoryName) then
					if condition(unitDef) then
						unitDef.category = unitDef.category .. " " .. categoryName
					end
				end
			end
		end

		-- Global physics behaviors
		if unitDef.health then
			unitDef.minCollisionSpeed = COLLISION_SPEED_MIN
		end

		-- Remove overzealous sounds
		if unitDef.sounds then
			if unitDef.sounds.ok then
				unitDef.sounds.ok = nil
			end

			if unitDef.sounds.select then
				unitDef.sounds.select = nil
			end

			if unitDef.sounds.activate then
				unitDef.sounds.activate = nil
			end
			if unitDef.sounds.deactivate then
				unitDef.sounds.deactivate = nil
			end
			if unitDef.sounds.build then
				unitDef.sounds.build = nil
			end
		end

		-- Make LOS height more forgiving than the default (20).
		unitDef.sightemitheight = 0
		unitDef.radaremitheight = 0
		if unitDef.collisionvolumescales then
			local x = unitDef.collisionvolumescales
			local xtab = {}
			for i in string.gmatch(x, "%S+") do
				xtab[#xtab + 1] = i
			end
			unitDef.sightemitheight = unitDef.sightemitheight + tonumber(xtab[2])
			unitDef.radaremitheight = unitDef.radaremitheight + tonumber(xtab[2])
		end
		if unitDef.collisionvolumeoffsets then
			local x = unitDef.collisionvolumeoffsets
			local xtab = {}
			for i in string.gmatch(x, "%S+") do
				xtab[#xtab + 1] = i
			end
			unitDef.sightemitheight = unitDef.sightemitheight + tonumber(xtab[2])
			unitDef.radaremitheight = unitDef.radaremitheight + tonumber(xtab[2])
		end
		if unitDef.sightemitheight < 40 then
			unitDef.sightemitheight = 40
			unitDef.radaremitheight = 40
		end

		if unitDef.health and unitDef.customparams.israptorunit then
			applyRaptorEffect(name, unitDef)
		end

		-- Max slope standardization
		if unitDef.maxslope then
			unitDef.maxslope = math.floor((unitDef.maxslope * 1.5) + 0.5)
		end

		--[[ Sanitize to whole frames (plus leeways because float arithmetic is bonkers).
			The engine uses full frames for actual reload times, but forwards the raw
			value to LuaUI (so for example calculated DPS is incorrect without sanitisation). ]]
		processWeapons(name, unitDef)

		-- Wreck and heap standardization
		if not unitDef.customparams.iscommander and not unitDef.customparams.iseffigy then
			if unitDef.featuredefs and unitDef.health then
				-- wrecks
				if unitDef.featuredefs.dead then
					unitDef.featuredefs.dead.damage = unitDef.health
					if unitDef.metalcost and unitDef.energycost then
						unitDef.featuredefs.dead.metal = math.floor(unitDef.metalcost * 0.6)
					end
				end
				-- heaps
				if unitDef.featuredefs.heap then
					unitDef.featuredefs.heap.damage = unitDef.health
					if unitDef.metalcost and unitDef.energycost then
						unitDef.featuredefs.heap.metal = math.floor(unitDef.metalcost * 0.25)
					end
				end
			end
		end

		-- Air unit physics standardization
		if unitDef.canfly then
			unitDef.crashdrag = 0.01    -- default 0.005
			if string.find(name, "fepoch") or string.find(name, "fblackhy") or string.find(name, "corcrw") or string.find(name, "legfort") then
				unitDef.collide = true
			else
				unitDef.collide = false
			end
		end

		-- Mass standardization
		if unitDef.metalcost and unitDef.health and unitDef.canmove == true and unitDef.mass == nil then
			unitDef.mass = math.max(unitDef.metalcost, math.ceil(unitDef.health/6))
			if unitDef.mass > 750 and unitDef.metalcost < 751 then
				unitDef.mass = 750
			end
		end

		-- Build power standardization
		if unitDef.workertime and not unitDef.terraformspeed then
			unitDef.terraformspeed = unitDef.workertime * 30
		end
	end,
}

-- UNIT MODOPTION EFFECTS

local modOptions = Spring.GetModOptions()

if modOptions.unithats == "april" then
	local unitHatApril = {
		corak    = "apf/CORAK.s3o",
		corllt   = "apf/CORllt.s3o",
		corhllt  = "apf/CORhllt.s3o",
		corack   = "apf/CORACK.s3o",
		corck    = "apf/CORCK.s3o",
		armpw    = "apf/ARMPW.s3o",
		cordemon = "apf/cordemon.s3o",
		correap  = "apf/correap.s3o",
		corstorm = "apf/corstorm.s3o",
		armcv    = "apf/armcv.s3o",
		armrock  = "apf/armrock.s3o",
		armbull  = "apf/armbull.s3o",
		armllt   = "apf/armllt.s3o",
		armwin   = "apf/armwin.s3o",
		armham   = "apf/armham.s3o",
		corwin   = "apf/corwin.s3o",
		corthud  = "apf/corthud.s3o",
	}
	table.insert(unitDefPostEffectList, function(name, uDef)
		uDef.objectname = unitHatApril[name] or uDef.objectname -- name => basename?
	end)
end

if table.any(modOptions, function(value, key)
		return value and type(key) == "string" and key:match("^unit_restrictions_%w+$")
	end)
then
	local unitRestrictions = {}

	table.insert(unitDefPostEffectList, function(name, unitDef)
		for _, test in ipairs(unitRestrictions) do
			if test(name, unitDef) then
				unitDef.maxthisunit = 0
				break
			end
		end
	end)

	table.insert(unitRestrictions, function(name, unitDef)
		return unitDef.maxthisunit == 0 -- short-circuit check
	end)

	if modOptions.unit_restrictions_notech15 then
		-- Tech 1.5 is a semi offical thing, modoption ported from teiserver meme commands
		local tech15 = {
			corhp		= true,
			corfhp		= true,
			corplat		= true,
			coramsub	= true,

			armhp		= true,
			armfhp		= true,
			armplat		= true,
			armamsub	= true,

			leghp		= true,
			legfhp		= true,
			legplat		= true,
			legamsub	= true,
		}
		table.insert(unitRestrictions, function(name, uDef) return tech15[uDef.basename] end)
	end

	if modOptions.unit_restrictions_noair then
		local isAirFactory = {
			armaap = true,
			armap = true,
			armapt3 = true,
			armplat = true,
			coraap = true,
			corap = true,
			corapt3 = true,
			corplat = true,
			legaap = true,
			legap = true,
			legapt3 = true,
		}

		table.insert(unitRestrictions, function(name, unitDef)
			if unitDef.customparams.ignore_noair then
				return false
			elseif unitDef.customparams.disable_when_no_air then -- Remove drone carriers with no other purpose (ex. leghive but not rampart).
				return true
			elseif string.find(unitDef.customparams.subfolder, "Aircraft") then
				return true
			elseif unitDef.customparams.unitgroup and unitDef.customparams.unitgroup == "aa" then
				return true
			elseif unitDef.canfly then
				return true
			elseif isAirFactory[unitDef.basename] then
				return true
			end
		end)
	end

	if modOptions.unit_restrictions_notech2 then
		table.insert(unitRestrictions, function(name, unitDef)
			return tonumber(unitDef.customparams.techlevel) >= 2
		end)
	elseif modOptions.unit_restrictions_notech3 then
		table.insert(unitRestrictions, function(name, unitDef)
			return tonumber(unitDef.customparams.techlevel) >= 3
		end)
	end

	if modOptions.unit_restrictions_noextractors then
		table.insert(unitRestrictions, function(name, uDef)
			return uDef.extractsmetal and uDef.extractsmetal > 0
				and uDef.customparams.metal_extractor and uDef.customparams.metal_extractor > 0
		end)
	end

	if modOptions.unit_restrictions_noconverters then
		table.insert(unitRestrictions, function(name, uDef)
			return uDef.customparams.energyconv_capacity and uDef.customparams.energyconv_efficiency
		end)
	end

	if modOptions.unit_restrictions_nofusion then
		table.insert(unitRestrictions, function(name, uDef)
			return uDef.basename == "armdf" or uDef.basename:match("fus$")
		end)
	end

	if modOptions.unit_restrictions_nonukes then
		table.insert(unitRestrictions, function(name, uDef)
			if uDef.weapondefs then
				for _, weapon in pairs(uDef.weapondefs) do
					if (weapon.interceptor and weapon.interceptor == 1) or (weapon.targetable and weapon.targetable == 1) then
						return true
					end
				end
				return false
			end
		end)
	end

	if modOptions.unit_restrictions_nodefence then
		local legalized = {
			armllt	= true,
			armrl	= true,
			armfrt	= true,
			armtl	= true,

			corllt	= true,
			corrl	= true,
			cortl	= true,
			corfrt	= true,
			legfrl	= true,

			leglht	= true,
			legrl	= true,
			--sea tl= true,
			--sea aa= true,
		}

		table.insert(unitRestrictions, function(name, uDef)
			if uDef.weapondefs then
				-- "defense" or "defence", as legion doesn't follow convention
				return uDef.customparams.subfolder:lower():match("defen[cs]e")
					and not legalized[name]
			end
		end)
	end

	if modOptions.unit_restrictions_noantinuke then
		local function isAntiNukeWeapon(weapon)
			return weapon.interceptor == 1
		end
		local function isNotAntiNukeWeapon(weapon)
			return weapon.interceptor ~= 1
		end

		table.insert(unitRestrictions, function(name, uDef)
			if uDef.weapondefs and table.any(uDef.weapondefs, isAntiNukeWeapon) then
				uDef.weapondefs = table.filterArray(uDef.weapondefs, isNotAntiNukeWeapon)
				if next(uDef.weapondefs) or (uDef.radardistance and uDef.radardistance >= 1500) then
					if uDef.metalcost then -- give a discount for removing anti-nuke
						uDef.metalcost = math.floor(uDef.metalcost * 0.6)
						uDef.energycost = math.floor(uDef.energycost * 0.6)
					end
					return false
				else
					return true
				end
			end
		end)
	end

	if modOptions.unit_restrictions_notacnukes then
		local isTacticalNuke = {
			armemp = true,
			cortron = true,
			legperdition = true,
		}
		table.insert(unitRestrictions, function(name, uDef)
			return isTacticalNuke[uDef.basename]
		end)
	end

	if modOptions.unit_restrictions_nolrpc then
		local isLRPC = {
			armbotrail = true,
			armbrtha = true,
			armvulc = true,
			corint = true,
			corbuzz = true,
			leglrpc = true,
			legelrpcmech = true,
			legstarfall = true,
		}
		table.insert(unitRestrictions, function(name, uDef)
			return isLRPC[uDef.basename]
		end)
	end

	if modOptions.unit_restrictions_noendgamelrpc then
		local isLolCannon = {
			armvulc = true,
			corbuzz = true,
			legstarfall = true,
			armvulc_scav = true,
			corbuzz_scav = true,
			legstarfall_scav = true,
		}
		table.insert(unitRestrictions, function(name, uDef)
			return isLolCannon[uDef.basename]
		end)
	end
end

if modOptions.evocom then
	local xpMultiplier = modOptions.evocomxpmultiplier
	local powerMultiplier = modOptions.evocomlevelupmultiplier
	local levelUpMethod = modOptions.evocomlevelupmethod
	local levelUpTime = modOptions.evocomleveluptime * 60
	local levelOnePower = 10000
	local levelLimit = modOptions.evocomlevelcap
	local canRespawnWithEffigy = modOptions.comrespawn == "all" or modOptions.comrespawn == "evocom"
	local addEffigyOption = {
		[2]  = "comeffigylvl1",
		[3]  = "comeffigylvl2",
		[4]  = "comeffigylvl2",
		[5]  = "comeffigylvl3",
		[6]  = "comeffigylvl3",
		[7]  = "comeffigylvl4",
		[8]  = "comeffigylvl4",
		[9]  = "comeffigylvl5",
		[10] = "comeffigylvl5",
	}

	table.insert(unitDefPostEffectList, function(name, uDef)
		if uDef.customparams.evocomlvl or name == "armcom" or name == "corcom" or name == "legcom" then
			local comLevel = uDef.customparams.evocomlvl or 1

			uDef.customparams.combatradius = 0
			uDef.customparams.evolution_health_transfer = "percentage"

			if uDef.power then
				uDef.power = uDef.power / xpMultiplier
			else
				uDef.power = (uDef.metalcost + uDef.energycost / 60) / xpMultiplier
			end

			if name == "armcom" then
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

			if levelUpMethod == "dynamic" then
				uDef.customparams.evolution_condition = "power"
				uDef.customparams.evolution_power_multiplier = 1
				uDef.customparams.evolution_power_threshold = (uDef.customparams.evolution_power_threshold or levelOnePower) * powerMultiplier
			elseif levelUpMethod == "timed" then
				uDef.customparams.evolution_condition = "timer_global"
				uDef.customparams.evolution_timer = uDef.customparams.evocomlvl * levelUpTime
			end

			if levelLimit <= comLevel then
				uDef.customparams.evolution_condition = nil
				uDef.customparams.evolution_health_transfer = nil
				uDef.customparams.evolution_power_multiplier = nil
				uDef.customparams.evolution_power_threshold = nil
				uDef.customparams.evolution_target = nil
				uDef.customparams.evolution_timer = nil
			end

			if canRespawnWithEffigy then
				uDef.customparams.respawn_condition = "health"
				table.insert(uDef.buildoptions, addEffigyOption[comLevel])
			end
		end
	end)
end

table.insert(unitDefPostEffectList, function(name, uDef)
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
end)

if modOptions.experimentalextraunits then
	table.insert(unitDefPostEffectList, function(name, uDef)
		local bo = uDef.buildoptions
		local count = #bo

		-- Armada T1 Land Constructors
		if name == "armca" or name == "armck" or name == "armcv" then

		-- Armada T1 Sea Constructors
		elseif name == "armcs" or name == "armcsa" then
			bo[count + 1] = "armgplat" -- Gun Platform - Light Plasma Defense
			bo[count + 2] = "armfrock" -- Scumbag - Anti Air Missile Battery

		-- Armada T1 Vehicle Factory
		elseif name == "armvp" then
			bo[count + 1] = "armzapper" -- Zapper - Light EMP Vehicle

		-- Armada T1 Aircraft Plant
		elseif name == "armap" then
			bo[count + 1] = "armfify" -- Firefly - Resurrection Aircraft

		-- Armada T2 Land Constructors
		elseif name == "armaca" or name == "armack" or name == "armacv" then
			bo[count + 1] = "armshockwave" -- Shockwave - T2 EMP Armed Metal Extractor
			bo[count + 2] = "armwint2" -- T2 Wind Generator
			bo[count + 3] = "armnanotct2" -- T2 Constructor Turret
			bo[count + 4] = "armlwall" -- Dragon's Fury - T2 Pop-up Wall Turret
			bo[count + 5] = "armgatet3" -- Asylum - Advanced Shield Generator

		-- Armada T2 Sea Constructors
		elseif name == "armacsub" then
			bo[count + 1] = "armfgate" -- Aurora - Floating Plasma Deflector
			bo[count + 2] = "armnanotc2plat" -- Floating T2 Constructor Turret

		-- Armada T2 Shipyard
		elseif name == "armasy" then
			bo[count + 1] = "armexcalibur" -- Excalibur - Coastal Assault Submarine
			bo[count + 2] = "armseadragon" -- Seadragon - Nuclear ICBM Submarine

		-- Armada T3 Gantry
		elseif name == "armshltx" then
			bo[count + 1] = "armmeatball" -- Meatball - Amphibious Assault Mech
			bo[count + 2] = "armassimilator" -- Assimilator - Amphibious Battle Mech

		-- Armada T3 Underwater Gantry
		elseif name == "armshltxuw" then
			bo[count + 1] = "armmeatball" -- Meatball - Amphibious Assault Mech
			bo[count + 2] = "armassimilator" -- Assimilator - Amphibious Battle Mech

		-- Cortex T1 Land Constructors
		elseif name == "corca" or name == "corck" or name == "corcv" then

		-- Cortex T1 Sea Constructors
		elseif name == "corcs" or name == "corcsa" then
			bo[count + 1] = "corgplat" -- Gun Platform - Light Plasma Defense
			bo[count + 2] = "corfrock" -- Janitor - Anti Air Missile Battery

		-- Cortex T1 Bots Factory
		elseif name == "corlab" then

		-- Cortex T2 Land Constructors
		elseif name == "coraca" or name == "corack" or name == "coracv" then
			bo[count + 1] = "corwint2" -- T2 Wind Generator
			bo[count + 2] = "cornanotct2" -- T2 Constructor Turret
			bo[count + 3] = "cormwall" -- Dragon's Rage - T2 Pop-up Wall Turret
			bo[count + 4] = "corgatet3" -- Sanctuary - Advanced Shield Generator

		-- Cortex T2 Sea Constructors
		elseif name == "coracsub" then
			bo[count + 1] = "corfgate" -- Atoll - Floating Plasma Deflector
			bo[count + 2] = "cornanotc2plat" -- Floating T2 Constructor Turret

		-- Cortex T2 Bots Factory
		elseif name == "coralab" then
			bo[count+1] = "cordeadeye"

		-- Cortex T2 Vehicle Factory
		elseif name == "coravp" then
			bo[count + 1] = "corvac" -- Printer - Armored Field Engineer
			bo[count + 2] = "corphantom" -- Phantom - Amphibious Stealth Scout
			bo[count + 3] = "corsiegebreaker" -- Siegebreaker - Heavy Long Range Destroyer
			bo[count + 4] = "corforge" -- Forge - Flamethrower Combat Engineer
			bo[count + 5] = "cortorch" -- Torch - Fast Flamethrower Tank

		-- Cortex T2 Aircraft Plant
		elseif name == "coraap" then

		-- Cortex T2 Shipyard
		elseif name == "corasy" then
			bo[count + 1] = "coresuppt3" -- Adjudictator - Heavy Heatray Battleship
			bo[count + 2] = "coronager" -- Onager - Coastal Assault Submarine
			bo[count + 3] = "cordesolator" -- Desolator - Nuclear ICBM Submarine
			bo[count + 4] = "corprince" -- Black Prince - Shore bombardment battleship

		-- Cortex T3 Gantry
		elseif name == "corgant" then

		-- Cortex T3 Underwater Gantry
		elseif name == "corgantuw" then

		-- Legion T1 Land Constructors
		elseif name == "legca" or name == "legck" or name == "legcv" then

		-- Legion T2 Land Constructors
		elseif name == "legaca" or name == "legack" or name == "legacv" then
			bo[count + 1] = "legmohocon" -- Advanced Metal Fortifier - Metal Extractor with Constructor Turret
			bo[count + 2] = "legwint2" -- T2 Wind Generator
			bo[count + 3] = "legnanotct2" -- T2 Constructor Turret
			bo[count + 4] = "legrwall" -- Dragon's Constitution - T2 (not Pop-up) Wall Turret
			bo[count + 5] = "leggatet3" -- Elysium - Advanced Shield Generator

		-- Legion T3 Gantry
		elseif name == "leggant" then
			bo[count + 1] = "legbunk" -- Pilum - Fast Assault Mech
		end
	end)
end

if modOptions.scavunitsforplayers then
	table.insert(unitDefPostEffectList, function(name, uDef)
		local bo = uDef.buildoptions
		local count = #bo

		-- Armada T1 Land Constructors
		if name == "armca" or name == "armck" or name == "armcv" then

		-- Armada T1 Sea Constructors
		elseif name == "armcs" or name == "armcsa" then

		-- Armada T1 Vehicle Factory
		elseif name == "armvp" then

		-- Armada T1 Aircraft Plant
		elseif name == "armap" then

		-- Armada T2 Constructors
		elseif name == "armaca" or name == "armack" or name == "armacv" then
			bo[count + 1] = "armapt3" -- T3 Aircraft Gantry
			bo[count + 2] = "armminivulc" -- Mini Ragnarok
			bo[count + 3] = "armbotrail" -- Pawn Launcher
			bo[count + 4] = "armannit3" -- Epic Pulsar
			bo[count + 5] = "armafust3" -- Epic Fusion Reactor
			bo[count + 6] = "armmmkrt3" -- Epic Energy Converter

		-- Armada T2 Shipyard
		elseif name == "armasy" then
			bo[count + 1] = "armdronecarry" -- Nexus - Drone Carrier
			bo[count + 2] = "armptt2" -- Epic Skater
			bo[count + 3] = "armdecadet3" -- Epic Dolphin
			bo[count + 4] = "armpshipt3" -- Epic Ellysaw
			bo[count + 5] = "armserpt3" -- Epic Serpent
			bo[count + 6] = "armtrident" -- Trident - Depth Charge Drone Carrier

		-- Armada T3 Gantry
		elseif name == "armshltx" then
			bo[count + 1] = "armrattet4" -- Ratte - Very Heavy Tank
			bo[count + 2] = "armsptkt4" -- Epic Recluse
			bo[count + 3] = "armpwt4" -- Epic Pawn
			bo[count + 4] = "armvadert4" -- Epic Tumbleweed - Nuclear Rolling Bomb
			bo[count + 5] = "armdronecarryland" -- Nexus Terra - Drone Carrier

		-- Armada T3 Underwater Gantry
		elseif name == "armshltxuw" then
			bo[count + 1] = "armrattet4" -- Ratte - Very Heavy Tank
			bo[count + 2] = "armsptkt4" -- Epic Recluse
			bo[count + 3] = "armpwt4" -- Epic Pawn
			bo[count + 4] = "armvadert4" -- Epic Tumbleweed - Nuclear Rolling Bomb

		-- Cortex T1 Bots Factory
		elseif name == "corlab" then
			bo[count+1] = "corkark" -- Archaic Karkinos

		-- Cortex T2 Land Constructors
		elseif name == "coraca" or name == "corack" or name == "coracv" then
			bo[count + 1] = "corapt3" -- T3 Aircraft Gantry
			bo[count + 2] = "corminibuzz" -- Mini Calamity
			bo[count + 3] = "corhllllt" -- Quad Guard - Quad Light Laser Turret
			bo[count + 4] = "cordoomt3" -- Epic Bulwark
			bo[count + 5] = "corafust3" -- Epic Fusion Reactor
			bo[count + 6] = "cormmkrt3" -- Epic Energy Converter

		-- Cortex T2 Sea Constructors
		elseif name == "coracsub" then

		-- Cortex T2 Bots Factory
		elseif name == "coralab" then

		-- Cortex T2 Vehicle Factory
		elseif name == "coravp" then
			bo[count+1] = "corgatreap" -- Laser Tiger
			bo[count+2] = "corftiger" -- Heat Tiger

		-- Cortex T2 Aircraft Plant
		elseif name == "coraap" then
			bo[count+1] = "corcrw" -- Archaic Dragon

		-- Cortex T2 Shipyard
		elseif name == "corasy" then
			bo[count + 1] = "cordronecarry" -- Dispenser - Drone Carrier
			bo[count + 2] = "corslrpc" -- Leviathan - LRPC Ship
			bo[count + 3] = "corsentinel" -- Sentinel - Depth Charge Drone Carrier

		-- Cortex T3 Gantry
		elseif name == "corgant" then
			bo[count + 1] = "corkarganetht4" -- Epic Karganeth
			bo[count + 2] = "corgolt4" -- Epic Tzar
			bo[count + 3] = "corakt4" -- Epic Grunt
			bo[count + 4] = "corthermite" -- Thermite/Epic Termite
			bo[count + 5] = "cormandot4" -- Epic Commando

		-- Cortex T3 Underwater Gantry
		elseif name == "corgantuw" then
			bo[count + 1] = "corkarganetht4" -- Epic Karganeth
			bo[count + 2] = "corgolt4" -- Epic Tzar
			bo[count + 3] = "corakt4" -- Epic Grunt
			bo[count + 4] = "cormandot4" -- Epic Commando

		-- Legion T1 Land Constructors
		elseif name == "legca" or name == "legck" or name == "legcv" then

		-- Legion T2 Land Constructors
		elseif name == "legaca" or name == "legack" or name == "legacv" then
			bo[count + 1] = "legapt3" -- T3 Aircraft Gantry
			bo[count + 2] = "legministarfall" -- Mini Starfall
			bo[count + 3] = "legafust3" -- Epic Fusion Reactor
			bo[count + 4] = "legadveconvt3" -- Epic Energy Converter

		-- Legion T3 Gantry
		elseif name == "leggant" then
			bo[count + 1] = "legsrailt4" -- Epic Arquebus
			bo[count + 2] = "leggobt3" -- Epic Goblin
			bo[count + 3] = "legpede" -- Mukade - Heavy Multi Weapon Centipede
			bo[count + 4] = "legeheatraymech_old" -- Old Sol Invictus - Quad Heatray Mech
		end
	end)
end

if modOptions.releasecandidates then

end

-------------------------
-- UNIT REWORKS AND TESTS

---Sequence of effects that are applied during `UnitDef_Post`.
--
-- Units are mostly done with post-processing by this step, except for
-- modoptions that apply general stat multipliers, e.g. to unit speed.
---@type function[]
local unitDefPostReworkList = {}

if modOptions.junorework then
	table.insert(unitDefPostReworkList, function(name, uDef)
		if name == "armjuno" then
			uDef.metalcost = 500
			uDef.energycost = 12000
			uDef.buildtime = 15000
			uDef.weapondefs.juno_pulse.energypershot = 7000
			uDef.weapondefs.juno_pulse.metalpershot = 100
		elseif name == "corjuno" then
			uDef.metalcost = 500
			uDef.energycost = 12000
			uDef.buildtime = 15000
			uDef.weapondefs.juno_pulse.energypershot = 7000
			uDef.weapondefs.juno_pulse.metalpershot = 100
		end
	end)
end

if modOptions.shieldsrework then
	-- Compensate for taking full damage from projectiles; c.f. bounce-style taking partial.
	local shieldPowerMultiplier = 1.9
	table.insert(unitDefPostReworkList, function(name, uDef)
		if uDef.weapondefs then
			for _, weapon in pairs(uDef.weapondefs) do
				if weapon.shield and weapon.shield.repulser then
					uDef.onoffable = true
				end
			end
			if uDef.customparams.shield_power then
				uDef.customparams.shield_power = uDef.customparams.shield_power * shieldPowerMultiplier
			end
		end
	end)
end

if modOptions.emprework then
	table.insert(unitDefPostReworkList, function(name, uDef)
		if name == "armstil" then
			uDef.weapondefs.stiletto_bomb.areaofeffect = 250
			uDef.weapondefs.stiletto_bomb.burst = 3
			uDef.weapondefs.stiletto_bomb.burstrate = 0.3333
			uDef.weapondefs.stiletto_bomb.edgeeffectiveness = 0.30
			uDef.weapondefs.stiletto_bomb.damage.default = 3000
			uDef.weapondefs.stiletto_bomb.paralyzetime = 1
		elseif name == "armspid" then
			uDef.weapondefs.spider.paralyzetime = 2
			uDef.weapondefs.spider.damage.vtol = 100
			uDef.weapondefs.spider.damage.default = 600
			uDef.weapondefs.spider.reloadtime = 1.495
		elseif name == "armdfly" then
			uDef.weapondefs.armdfly_paralyzer.paralyzetime = 1
			uDef.weapondefs.armdfly_paralyzer.beamdecay = 0.05
			uDef.weapondefs.armdfly_paralyzer.beamtime = 0.1
			uDef.weapondefs.armdfly_paralyzer.areaofeffect = 8
			uDef.weapondefs.armdfly_paralyzer.targetmoveerror = 0.05
		elseif name == "armemp" then
			uDef.weapondefs.armemp_weapon.areaofeffect = 512
			uDef.weapondefs.armemp_weapon.burstrate = 0.3333
			uDef.weapondefs.armemp_weapon.edgeeffectiveness = -0.10
			uDef.weapondefs.armemp_weapon.paralyzetime = 22
			uDef.weapondefs.armemp_weapon.damage.default = 60000
		elseif name == "armshockwave" then
			uDef.weapondefs.hllt_bottom.areaofeffect = 150
			uDef.weapondefs.hllt_bottom.edgeeffectiveness = 0.15
			uDef.weapondefs.hllt_bottom.reloadtime = 1.4
			uDef.weapondefs.hllt_bottom.paralyzetime = 5
			uDef.weapondefs.hllt_bottom.damage.default = 800
		elseif name == "armthor" then
			uDef.weapondefs.empmissile.areaofeffect = 250
			uDef.weapondefs.empmissile.edgeeffectiveness = -0.50
			uDef.weapondefs.empmissile.damage.default = 20000
			uDef.weapondefs.empmissile.paralyzetime = 5
			uDef.weapondefs.emp.damage.default = 200
			uDef.weapondefs.emp.reloadtime = .5
			uDef.weapondefs.emp.paralyzetime = 1
		elseif name == "corbw" then
			uDef.weapondefs.bladewing_lyzer.damage.default = 300
			uDef.weapondefs.bladewing_lyzer.paralyzetime = 1
		elseif (name =="corfmd" or name =="armamd" or name =="cormabm" or name =="armscab") then
			uDef.customparams.paralyzemultiplier = 1.5
		elseif (name == "armvulc" or name == "corbuzz" or name == "legstarfall" or name == "corsilo" or name == "armsilo") then
			uDef.customparams.paralyzemultiplier = 2
		elseif name == "armmar" then
			uDef.customparams.paralyzemultiplier = 0.8
		elseif name == "armbanth" then
			uDef.customparams.paralyzemultiplier = 1.6
		end
	end)
end

if modOptions.air_rework then
	local airReworkUnits = VFS.Include("unitbasedefs/air_rework_defs.lua")
	table.insert(unitDefPostReworkList, airReworkUnits.airReworkTweaks)
end

if modOptions.skyshift then
	local skyshiftUnits = VFS.Include("unitbasedefs/skyshiftunits_post.lua")
	table.insert(unitDefPostReworkList, skyshiftUnits.skyshiftUnitTweaks)
end

if modOptions.proposed_unit_reworks then
	local proposed_unit_reworks = VFS.Include("unitbasedefs/proposed_unit_reworks_defs.lua")
	table.insert(unitDefPostReworkList, proposed_unit_reworks.proposed_unit_reworksTweaks)
end

if modOptions.naval_balance_tweaks then
	local buildOptionReplacements = {
		armcs = { armfhlt = "armnavaldefturret" },
		armch = { armfhlt = "armnavaldefturret" },
		armbeaver = { armfhlt = "armnavaldefturret" },
		armcsa = { armfhlt = "armnavaldefturret" },
		corcs = { corfhlt = "cornavaldefturret" },
		corch = { corfhlt = "cornavaldefturret" },
		cormuskrat = { corfhlt = "cornavaldefturret" },
		corcsa = { corfhlt = "cornavaldefturret" },
		legcs = { legfmg = "legnavaldefturret" },
		legch = { legfmg = "legnavaldefturret" },
		legotter = { legfmg = "legnavaldefturret" },
		armacsub = { armkraken = "armanavaldefturret" },
		armmls = {
			armfhlt   = "armnavaldefturret",
			armkraken = "armanavaldefturret",
		},
		coracsub = { corfdoom = "coranavaldefturret" },
		cormls = {
			corfhlt  = "cornavaldefturret",
			corfdoom = "coranavaldefturret",
		},
	}
	local isAdvancedNavalRadar = {
		armfrad = true,
		corfrad = true,
		legfrad = true,
	}

	table.insert(unitDefPostReworkList, function(name, uDef)
		local baseName = uDef.basename
		if buildOptionReplacements[baseName] then
			local replacements = buildOptionReplacements[baseName]
			for i, buildOption in ipairs(uDef.buildoptions) do
				if replacements[buildOption] then
					uDef.buildoptions[i] = replacements[buildOption]
				end
			end
		elseif isAdvancedNavalRadar[baseName] then
			uDef.sightdistance = 800
		end
	end)
end

if modOptions.lategame_rebalance then
	table.insert(unitDefPostReworkList, function(name, uDef)
		local baseName = uDef.basename
		if baseName == "armamb" then
			uDef.weapondefs.armamb_gun.reloadtime = 2
			uDef.weapondefs.armamb_gun_high.reloadtime = 7.7
		elseif baseName == "cortoast" then
			uDef.weapondefs.cortoast_gun.reloadtime = 2.35
			uDef.weapondefs.cortoast_gun_high.reloadtime = 8.8
		elseif baseName == "armpb" then
			uDef.weapondefs.armpb_weapon.reloadtime = 1.7
			uDef.weapondefs.armpb_weapon.range = 700
		elseif baseName == "corvipe" then
			uDef.weapondefs.vipersabot.reloadtime = 2.1
			uDef.weapondefs.vipersabot.range = 700
		elseif baseName == "armanni" then
			uDef.metalcost = 4000
			uDef.energycost = 85000
			uDef.buildtime = 59000
		elseif baseName == "corbhmth" then
			uDef.metalcost = 3600
			uDef.energycost = 40000
			uDef.buildtime = 70000
		elseif baseName == "armbrtha" then
			uDef.metalcost = 5000
			uDef.energycost = 71000
			uDef.buildtime = 94000
		elseif baseName == "corint" then
			uDef.metalcost = 5100
			uDef.energycost = 74000
			uDef.buildtime = 103000
		elseif baseName == "armvulc" then
			uDef.metalcost = 75600
			uDef.energycost = 902400
			uDef.buildtime = 1680000
		elseif baseName == "corbuzz" then
			uDef.metalcost = 73200
			uDef.energycost = 861600
			uDef.buildtime = 1680000
		elseif baseName == "armmar" then
			uDef.metalcost = 1070
			uDef.energycost = 23000
			uDef.buildtime = 28700
		elseif baseName == "armraz" then
			uDef.metalcost = 4200
			uDef.energycost = 75000
			uDef.buildtime = 97000
		elseif baseName == "armthor" then
			uDef.metalcost = 9450
			uDef.energycost = 255000
			uDef.buildtime = 265000
		elseif baseName == "corshiva" then
			uDef.metalcost = 1800
			uDef.energycost = 26500
			uDef.buildtime = 35000
			uDef.speed = 50.8
			uDef.weapondefs.shiva_rocket.tracks = true
			uDef.weapondefs.shiva_rocket.turnrate = 7500
		elseif baseName == "corkarg" then
			uDef.metalcost = 2625
			uDef.energycost = 60000
			uDef.buildtime = 79000
		elseif baseName == "cordemon" then
			uDef.metalcost = 6300
			uDef.energycost = 94500
			uDef.buildtime = 94500
		elseif baseName == "armstil" then
			uDef.health = 1300
			uDef.weapondefs.stiletto_bomb.burst = 3
			uDef.weapondefs.stiletto_bomb.burstrate = 0.2333
			uDef.weapondefs.stiletto_bomb.damage = {
				default = 3000
			}
		elseif baseName == "armlance" then
			uDef.health = 1750
		elseif baseName == "cortitan" then
			uDef.health = 1800
		elseif baseName == "armyork" then
			uDef.weapondefs.mobileflak.reloadtime = 0.8333
		elseif baseName == "corsent" then
			uDef.weapondefs.mobileflak.reloadtime = 0.8333
		elseif baseName == "armaas" then
			uDef.weapondefs.mobileflak.reloadtime = 0.8333
		elseif baseName == "corarch" then
			uDef.weapondefs.mobileflak.reloadtime = 0.8333
		elseif baseName == "armflak" then
			uDef.weapondefs.armflak_gun.reloadtime = 0.6
		elseif baseName == "corflak" then
			uDef.weapondefs.armflak_gun.reloadtime = 0.6
		elseif baseName == "armmercury" then
			uDef.weapondefs.arm_advsam.reloadtime = 11
			uDef.weapondefs.arm_advsam.stockpile = false
		elseif baseName == "corscreamer" then
			uDef.weapondefs.cor_advsam.reloadtime = 11
			uDef.weapondefs.cor_advsam.stockpile = false
		elseif baseName == "armfig" then
			uDef.metalcost = 77
			uDef.energycost = 3100
			uDef.buildtime = 3700
		elseif baseName == "armsfig" then
			uDef.metalcost = 95
			uDef.energycost = 4750
			uDef.buildtime = 5700
		elseif baseName == "armhawk" then
			uDef.metalcost = 155
			uDef.energycost = 6300
			uDef.buildtime = 9800
		elseif baseName == "corveng" then
			uDef.metalcost = 77
			uDef.energycost = 3000
			uDef.buildtime = 3600
		elseif baseName == "corsfig" then
			uDef.metalcost = 95
			uDef.energycost = 4850
			uDef.buildtime = 5400
		elseif baseName == "corvamp" then
			uDef.metalcost = 150
			uDef.energycost = 5250
			uDef.buildtime = 9250
		end
	end)
end

if modOptions.factory_costs then
	table.insert(unitDefPostReworkList, function(name, uDef)
		if name == "armmoho" or name == "cormoho" or name == "cormexp" then
			uDef.metalcost = uDef.metalcost + 50
			uDef.energycost = uDef.energycost + 2000
		elseif name == "armageo" or name == "corageo" then
			uDef.metalcost = uDef.metalcost + 100
			uDef.energycost = uDef.energycost + 4000
		elseif name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy" then
			uDef.metalcost = uDef.metalcost - 1000
			uDef.workertime = 600
			uDef.buildtime = uDef.buildtime * 2
		elseif name == "armvp" or name == "corvp" or name == "armlab" or name == "corlab" or name == "armsy" or name == "corsy"then
			uDef.metalcost = uDef.metalcost - 50
			uDef.buildtime = uDef.buildtime - 1500
			uDef.energycost = uDef.energycost - 280
		elseif name == "armap" or name == "corap" or name == "armhp" or name == "corhp" or name == "armfhp" or name == "corfhp" or name == "armplat" or name == "corplat" then
			uDef.metalcost = uDef.metalcost - 100
			uDef.buildtime = uDef.buildtime - 600
			uDef.energycost = uDef.energycost - 100
		elseif name == "armshltx" or name == "corgant" or name == "armshltxuw" or name == "corgantuw" then
			uDef.workertime = 2000
			uDef.buildtime = uDef.buildtime * 1.33
		elseif name == "armnanotc" or name == "cornanotc" or name == "armnanotcplat" or name == "cornanotcplat" then
			uDef.metalcost = uDef.metalcost + 40
		end

		if tonumber(uDef.customparams.techlevel) == 2 and uDef.energycost and uDef.metalcost and uDef.buildtime and not (name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy") then
			uDef.buildtime = math.ceil(uDef.buildtime * 0.015 / 5) * 500
		elseif tonumber(uDef.customparams.techlevel) == 3 and uDef.energycost and uDef.metalcost and uDef.buildtime then
			uDef.buildtime = math.ceil(uDef.buildtime * 0.0015) * 1000
		end
	end)
end

if modOptions.techsplit then
	local techsplitUnits = VFS.Include("unitbasedefs/techsplit_defs.lua")
	table.insert(unitDefPostReworkList, techsplitUnits.techsplitTweaks)
end

if modOptions.techsplit_balance then
	local techsplit_balanceUnits = VFS.Include("unitbasedefs/techsplit_balance_defs.lua")
	table.insert(unitDefPostReworkList, techsplit_balanceUnits.techsplit_balanceTweaks)
end

-------------------------
-- UNIT MULTIPLIERS

---Sequence of effects that are applied last during `UnitDef_Post`.
---@type function[]
local unitPostDefMultiplierList = {}

if modOptions.multiplier_maxvelocity ~= 1 then
	local x = modOptions.multiplier_maxvelocity
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if uDef.speed then
			uDef.speed = uDef.speed * x
			if uDef.maxdec then
				uDef.maxdec = uDef.maxdec * ((x - 1) / 2 + 1)
			end
			if uDef.maxacc then
				uDef.maxacc = uDef.maxacc * ((x - 1) / 2 + 1)
			end
		end
	end)
end

if modOptions.multiplier_turnrate ~= 1 then
	local x = modOptions.multiplier_turnrate
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if uDef.turnrate then
			uDef.turnrate = uDef.turnrate * x
		end
	end)
end

if modOptions.multiplier_builddistance ~= 1 then
	local x = modOptions.multiplier_builddistance
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if uDef.builddistance then
			uDef.builddistance = uDef.builddistance * x
		end
	end)
end

if modOptions.multiplier_buildpower ~= 1 then
	local x = modOptions.multiplier_buildpower
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if uDef.workertime then
			uDef.workertime = uDef.workertime * x
		end
		if uDef.terraformspeed then
			uDef.terraformspeed = uDef.terraformspeed * x
		end
	end)
end

if modOptions.multiplier_metalextraction * modOptions.multiplier_resourceincome ~= 1 then
	local x = modOptions.multiplier_metalextraction * modOptions.multiplier_resourceincome
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if (uDef.extractsmetal and uDef.extractsmetal > 0) and (uDef.customparams.metal_extractor and uDef.customparams.metal_extractor > 0) then
			uDef.extractsmetal = uDef.extractsmetal * x
			uDef.customparams.metal_extractor = uDef.customparams.metal_extractor * x
			if uDef.metalstorage then
				uDef.metalstorage = uDef.metalstorage * x
			end
		end
	end)
end

if modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome ~= 1 then
	local x = modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if uDef.energymake then
			uDef.energymake = uDef.energymake * x
			if uDef.energystorage then
				uDef.energystorage = uDef.energystorage * x
			end
		end
		if uDef.windgenerator and uDef.windgenerator > 0 then
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
			uDef.tidalgenerator = uDef.tidalgenerator * x
			if uDef.energystorage then
				uDef.energystorage = uDef.energystorage * x
			end
		end
		if uDef.energyupkeep and uDef.energyupkeep < 0 then
			-- units with negative upkeep means they produce energy when "on".
			uDef.energyupkeep = uDef.energyupkeep * x
			if uDef.energystorage then
				uDef.energystorage = uDef.energystorage * x
			end
		end
	end)
end

if modOptions.multiplier_energyconversion * modOptions.multiplier_resourceincome ~= 1 then
	local x = modOptions.multiplier_energyconversion * modOptions.multiplier_resourceincome
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if uDef.customparams.energyconv_capacity and uDef.customparams.energyconv_efficiency then
			--uDef.customparams.energyconv_capacity = uDef.customparams.energyconv_capacity * x
			uDef.customparams.energyconv_efficiency = uDef.customparams.energyconv_efficiency * x
			if uDef.metalstorage then
				uDef.metalstorage = uDef.metalstorage * x
			end
			if uDef.energystorage then
				uDef.energystorage = uDef.energystorage * x
			end
		end
	end)
end

if modOptions.multiplier_losrange ~= 1 then
	local x = modOptions.multiplier_losrange
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if uDef.sightdistance then
			uDef.sightdistance = uDef.sightdistance * x
		end
	end)
end

if modOptions.multiplier_losrange ~= 1 then
	local x = modOptions.multiplier_losrange
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if uDef.airsightdistance then
			uDef.airsightdistance = uDef.airsightdistance * x
		end
	end)
end

if modOptions.multiplier_radarrange ~= 1 then
	local x = modOptions.multiplier_radarrange
	table.insert(unitPostDefMultiplierList, function(name, uDef)
		if uDef.radardistance then
			uDef.radardistance = uDef.radardistance * x
		end
		if uDef.sonardistance then
			uDef.sonardistance = uDef.sonardistance * x
		end
	end)
end

function UnitDef_Post(name, uDef)
	for index, effect in ipairs(unitDefPostEffectList) do
		effect(name, uDef)
	end

	for index, effect in ipairs(unitDefPostReworkList) do
		effect(name, uDef)
	end

	for index, effect in ipairs(unitPostDefMultiplierList) do
		effect(name, uDef)
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
	local modOptions = Spring.GetModOptions()

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

		----EMP rework

		if modOptions.emprework then
			if name == 'empblast' then
				wDef.areaofeffect = 350
				wDef.edgeeffectiveness = 0.6
				wDef.paralyzetime = 12
				wDef.damage.default = 50000
			end
			if name == 'spybombx' then
				wDef.areaofeffect = 350
				wDef.edgeeffectiveness = 0.4
				wDef.paralyzetime = 20
				wDef.damage.default = 16000
			end
			if name == 'spybombxscav' then
				wDef.edgeeffectiveness = 0.50
				wDef.paralyzetime = 12
				wDef.damage.default = 35000
			end
		end

		--Air rework
		if modOptions.air_rework == true then
			if wDef.weapontype == "BeamLaser" then
				wDef.damage.vtol = wDef.damage.default * 0.25
			end
			if wDef.range == 300 and wDef.reloadtime == 0.4 then
				--comm lasers
				wDef.damage.vtol = wDef.damage.default
			end
			if wDef.weapontype == "Cannon" and wDef.damage.default ~= nil then
				wDef.damage.vtol = wDef.damage.default * 0.35
			end
		end

		--[[Skyshift: Air rework
		if Spring.GetModOptions().skyshift == true then
			skyshiftUnits = VFS.Include("unitbasedefs/skyshiftunits_post.lua")
			wDef = skyshiftUnits.skyshiftWeaponTweaks(name, wDef)
		end]]

		---- SHIELD CHANGES

		if wDef.weapontype == "DGun" then
			wDef.interceptedbyshieldtype = 512 --make dgun (like behemoth) interceptable by shields, optionally
		elseif wDef.weapontype == "StarburstLauncher" and not string.find(name, "raptor") then
			wDef.interceptedbyshieldtype = 1024 --separate from combined MissileLauncher, except raptors
		end

		local shieldModOption = modOptions.experimentalshields

		if shieldModOption == "absorbplasma" then
			if wDef.shield and wDef.shield.repulser and wDef.shield.repulser ~= false then
				wDef.shield.repulser = false
			end
		elseif shieldModOption == "absorbeverything" then
			if wDef.shield and wDef.shield.repulser and wDef.shield.repulser ~= false then
				wDef.shield.repulser = false
			end
			if (not wDef.interceptedbyshieldtype) or wDef.interceptedbyshieldtype ~= 1 then
				wDef.interceptedbyshieldtype = 1
			end
		elseif shieldModOption == "bounceeverything" then
			if wDef.shield then
				wDef.shield.repulser = true
			end
			if (not wDef.interceptedbyshieldtype) or wDef.interceptedbyshieldtype ~= 1 then
				wDef.interceptedbyshieldtype = 1
			end
		end

		--Shields Rework
		if modOptions.shieldsrework == true then
			-- To compensate for always taking full damage from projectiles in contrast to bounce-style only taking partial
			local shieldPowerMultiplier = 1.9
			local shieldRegenMultiplier = 2.5
			local shieldRechargeCostMultiplier = 1

			-- For balance, paralyzers need to do reduced damage to shields, as their raw raw damage is outsized
			local paralyzerShieldDamageMultiplier = 0.25

			-- VTOL's may or may not do full damage to shields if not defined in weapondefs
			local vtolShieldDamageMultiplier = 0

			local shieldCollisionExemptions = { --add the name of the weapons (or just the name of the unit followed by _ ) to this table to exempt from shield collision.
			'corsilo_', 'armsilo_', 'armthor_empmissile', 'armemp_', 'cortron_', 'corjuno_', 'armjuno_',
			}

			if wDef.damage ~= nil then
				-- Due to the engine not handling overkill damage, we have to store the original shield damage values as a customParam for unit_shield_behavior.lua to reference
				wDef.customparams = wDef.customparams or {}
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

			if wDef.shield then
				wDef.shield.exterior = true
				if wDef.shield.repulser == true then --isn't an evocom
					wDef.shield.powerregen = wDef.shield.powerregen * shieldRegenMultiplier
					wDef.shield.power = wDef.shield.power * shieldPowerMultiplier
					wDef.shield.powerregenenergy = wDef.shield.powerregenenergy * shieldRechargeCostMultiplier
				end
				wDef.shield.repulser = false
			end

			if ((not wDef.interceptedbyshieldtype or wDef.interceptedbyshieldtype ~= 1) and wDef.weapontype ~= "Cannon") then
				wDef.customparams = wDef.customparams or {}
				wDef.customparams.shield_aoe_penetration = true
			end

			for _, exemption in ipairs(shieldCollisionExemptions) do
				if string.find(name, exemption) then
					wDef.interceptedbyshieldtype = 0
					wDef.customparams.shield_aoe_penetration = true
					break
				end
			end
		end

		if modOptions.multiplier_shieldpower then
			if wDef.shield then
				local multiplier = modOptions.multiplier_shieldpower
				if wDef.shield.power then
					wDef.shield.power = wDef.shield.power * multiplier
				end
				if wDef.shield.powerregen then
					wDef.shield.powerregen = wDef.shield.powerregen * multiplier
				end
				if wDef.shield.powerregenenergy then
					wDef.shield.powerregenenergy = wDef.shield.powerregenenergy * multiplier
				end
				if wDef.shield.startingpower then
					wDef.shield.startingpower = wDef.shield.startingpower * multiplier
				end
			end
		end
		----------------------------------------

		--Use targetborderoverride in weapondef customparams to override this global setting
		--Controls whether the weapon aims for the center or the edge of its target's collision volume. Clamped between -1.0 - target the far border, and 1.0 - target the near border.
		if wDef.customparams and wDef.customparams.targetborderoverride == nil then
			wDef.targetborder = 1 --Aim for just inside the hitsphere
		elseif wDef.customparams and wDef.customparams.targetborderoverride ~= nil then
			wDef.targetborder = tonumber(wDef.customparams.targetborderoverride)
		end

		if wDef.craterareaofeffect then
			wDef.cratermult = (wDef.cratermult or 0) + wDef.craterareaofeffect / 2000
		end

		-- Target borders of unit hitboxes rather than center (-1 = far border, 0 = center, 1 = near border)
		-- wDef.targetborder = 1.0

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
		end

		if modOptions.xmas and wDef.weapontype == "StarburstLauncher" and wDef.model and VFS.FileExists('objects3d\\candycane_' .. wDef.model) then
			wDef.model = 'candycane_' .. wDef.model
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

		if wDef.weapontype == "BeamLaser" then
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

		-- scavengers
		if string.find(name, '_scav') then
			VFS.Include("gamedata/scavengers/weapondef_post.lua")
			wDef = scav_Wdef_Post(name, wDef)
		end

		ProcessSoundDefaults(wDef)
	end

	-- Multipliers

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
		if wDef.customparams and wDef.customparams.overrange_distance then
			wDef.customparams.overrange_distance = wDef.customparams.overrange_distance * rangeMult
		end
	end

	-- Weapon Damage
	local damageMult = modOptions.multiplier_weapondamage
	if damageMult ~= 1 then
		if wDef.damage then
			for damageClass, damageValue in pairs(wDef.damage) do
				wDef.damage[damageClass] = wDef.damage[damageClass] * damageMult
			end
		end
	end

	-- ExplosionSpeed is calculated same way engine does it, and then doubled
	-- Note that this modifier will only effect weapons fired from actual units, via super clever hax of using the weapon name as prefix
	if wDef.damage and wDef.damage.default then
		if string.find(name, '_', nil, true) then
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
