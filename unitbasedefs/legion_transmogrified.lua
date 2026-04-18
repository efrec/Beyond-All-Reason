local data = {
	-- Bots
	legbart = {
		metalcost = 450,
		energycost = 5000,
		buildtime = 9000,
		health = 1600,
	},
	legshot = {
		energycost = 5000,
		buildtime = 12000,
		health = 4000,
		damagemodifier = 0.5,
		speed = 48,
		customparams = { reactive_armor_health = 600 },
		weapondefs = { legion_riot_cannon_t2 = {
			areaofeffect = 120,
			edgeeffectiveness = 0.8,
			soundhitvolume = 10.0,
			soundstartvolume = 12.0,
		}},
	},

	-- Vehicles
	legscout = {
		predictboost = 0.8,
	},
	leghades = {
		health = 400,
		weapondefs = { gauss = { impulsefactor = 0.246 }},
	},
	legbar = {
		metalcost = 200,
		energycost = 3000,
		buildtime = 3500,
		health = 1360,
		speed = 42,
		turnrate = 260,
		weapondefs = { clusternapalm = {
			range = 500,
			reloadtime = 7,
		}},
		weapons = { [1] = {
			maindir = "0 0 1",
			maxangledif = 240,
		}},
	},
	leggat = {
		metalcost = 360,
		energycost = 4000,
		buildtime = 5400,
		health = 3000,
	},
	leginf = {
		energycost = 25000,
		buildtime = 40000,
		customparams = {
			area_ondeath_ceg = "fire-area-75-repeat",
			area_ondeath_damageCeg = "burnflamexl-gen",
			area_ondeath_resistance = "fire",
			area_ondeath_damage = 60,
			area_ondeath_range = 75,
			area_ondeath_time = 7,
		},
		weapondefs = { rapidnapalm = {
			range = 1250,
			weaponvelocity = 360,
		}},
	},

	-- Air
	legfig = {
		energycost = 1800,
	},
	legcib = {
		weapondefs = { juno_pulse_mini = {
			energypershot = 400,
		}},
	},

	-- Sea
	

	-- Structures
	legacluster = {
		health = 3850,
	},
	legperdition = {
		customparams = {
			area_ondeath_ceg = "fire-area-150-repeat",
			area_ondeath_damageCeg = "burnflamexl-gen",
			area_ondeath_resistance = "fire",
			area_ondeath_damage = 120,
			area_ondeath_range = 150,
			area_ondeath_time = 10,
		},
	},
}

local function isMachineGun(weaponName, weaponDef)
	if weaponDef.weapontype == "LaserCannon" and (weaponDef.impulsefactor or 0) == 0 then
		return true
	elseif weaponName:lower():find("machine gun") then
		return true
	else
		return false
	end
end

local function getNapalmType(weaponDef)
	if weaponDef.customparams.area_onhit_resistance == "fire" then
		if weaponDef.damage.commanders then
			return "heavy"
		else
			return "normal"
		end
	end
end

local function tweaks(name, unitDef)
	if data[name] then
		table.mergeInPlace(unitDef, data[name], true)
	end

	for weaponName, weaponDef in pairs(unitDef.weapondefs) do
		if weaponDef.customparams.bogus then

		elseif isMachineGun(weaponName, weaponDef) then
			weaponDef.impulsefactor = 0.5

		elseif weaponDef.customparams.cluster_def then
			local count = weaponDef.customparams.cluster_number or 5
			weaponDef.customparams.cluster_number = count + 2
			for armor, damage in pairs(weaponDef.damage) do
				weaponDef.damage[armor] = math.floor(damage * 0.75)
			end

		elseif getNapalmType(weaponDef) == "normal" then
			weaponDef.range = weaponDef.range - 15
			local duration = weaponDef.customparams.area_onhit_time or weaponDef.reloadtime
			weaponDef.reloadtime = duration
			weaponDef.customparams.area_onhit_time = duration

		elseif getNapalmType(weaponDef) == "heavy" then
			weaponDef.edgeeffectiveness = 1.0

		end
	end
end

return {
	Tweaks = tweaks,
}
