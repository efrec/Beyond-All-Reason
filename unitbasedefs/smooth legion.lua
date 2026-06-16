----------------------------------------------------- [ smooth_legion.lua ] ----
--------------------------------------------------------------------------------

local UD = UnitDefs

if not UD.legcom then
	Spring.Echo('Error in small teams tweadefs: Legion not enabled.')
end

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local function deep(tbl)
	local new = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			new[k] = deep(v)
		else
			new[k] = v
		end
	end
	return new
end

local function equal(old, new)
	return
		(type(old) == "string" and tonumber(old) and tonumber(old) ~= new) or
		((old == 0 or old == "false") and new ~= false) or
		((old == 1 or old == "true") and new ~= true)
end

local function tweak(old, new)
	local d = {}
	for k, v_o in pairs(old) do
		if type(k) ~= "number" then
			local v_n = new[k]
			if v_n == nil then
				d[k] = "nil"
			elseif type(v_o) == "table" and type(v_n) == "table" then
				d[k] = tweak(v_o, v_n)
			elseif v_o ~= v_n and (type(v_o) == type(v_n) or equal(v_o, v_n)) then
				d[k] = v_n
			end
		end
	end
	for k, v_n in pairs(new) do
		if old[k] == nil then
			d[k] = v_n
		end
	end
	if next(d) then
		return d
	end
end

local unitDef, weaponDef, cparams, ref
local units = {}
local divisors = { 2, 4, 5, 8, 12, 20, 50, 125, 250 }
local m2e, m2b = 20, 30

local function unit(name)
	unitDef = UD[name]
	if unitDef and not units[name] then
		units[name] = deep(unitDef)
	elseif not unitDef then
		Spring.Echo("error: missing unitdef", name)
	end
	return unitDef
end

local function weapon(name)
	if not unitDef then
		Spring.Echo("error: no unitdef for weapon", name)
	end
	weaponDef = unitDef.weapondefs[name]
	if not weaponDef then
		Spring.Echo("error: missing weapondef", name)
	end
	return weaponDef
end

local function custom(def)
	cparams = def.customparams or {}
	def.customparams = cparams
	return cparams
end

local function copy(def, ...)
	for _, property in ipairs({ ... }) do
		def[property] = ref[property]
	end
end

local function neat(value, precision)
	if precision then
		value = value / precision
	else
		precision = 1
	end
	if value <= 30 then
		return math.floor(value + 0.5) * precision
	end
	local values = {}
	for _, v in ipairs(divisors) do
		values[v] = math.floor(value / v + 0.5) * v
	end
	local neatest = values[divisors[1]]
	local fitness = neatest - value
	fitness = fitness * fitness / divisors[1]
	for i = 2, #divisors do
		local divisor = divisors[i]
		local fitness2 = values[divisor] - value
		fitness2 = fitness2 * fitness2 / divisors[i]
		if fitness > fitness2 then
			neatest = values[divisor]
			fitness = fitness2
		end
	end
	return neatest * precision
end

local function set(tbl, key, mult, add, precision)
	local value = tonumber(tbl[key])
	if type(value) == "number" then
		tbl[key] = neat(value * (mult or 1) + (add or 0), precision)
	end
end

local function costs(mult, add_m, add_e, add_bp)
	local u = unitDef
	if not add_m then add_m = 0 end
	if not add_e then
		add_e = add_m * (u.metalcost and u.metalcost > 0 and u.energycost / u.metalcost or m2e)
	end
	if not add_bp then
		add_bp = add_m * (u.metalcost and u.metalcost > 0 and u.buildtime / u.metalcost or m2b)
	end
	local metal = neat(u.metalcost * mult + add_m, 10)
	local ratio = metal / u.metalcost
	u.metalcost = metal
	set(u, "energycost", mult, add_e, 10)
	set(u, "buildtime", mult, add_bp, 10)
	for _, fd in pairs(u.featuredefs or {}) do
		fd.metal = math.floor(ratio * fd.metal + 0.5)
	end
end

local function damages(mult, base)
	if not base then base = 0 end
	for armor in pairs(weaponDef.damage) do
		set(weaponDef.damage, armor, mult, base)
	end
end

--------------------------------------------------------------------------------
-- Commander -------------------------------------------------------------------

UD.legcom.weapons[1].onlytargetcategory = "NOTSUB"
UD.legcom.weapons[1].fastautoretargeting = true
UD.legcom.weapondefs.legcomlaser = table.copy(UD.armcom.weapondefs.armcomlaser)
UD.legcom.weapondefs.torpedo = table.copy(UD.armcom.weapondefs.armcomsealaser)
UD.legcom.weapons[4] = nil

--------------------------------------------------------------------------------
-- Basic economy ---------------------------------------------------------------

UD.legmex.extractsmetal = 0.001
UD.legmex.energyupkeep = 3

--------------------------------------------------------------------------------
-- Make T1.5 units smoother ----------------------------------------------------

unit("legkark")
costs(0.9)
set(unitDef, "health", 0.9)
set(unitDef, "speed", 1.09)

unit("leggat")
costs(1.12)
set(unitDef, "health", 1.1)

--------------------------------------------------------------------------------
-- Weapon conversions ----------------------------------------------------------

-- These are total conversions that otherwise preserve the stats of the weapon.
-- Overall stat changes (eg total burst size) should be done in other sections.

-- Heat rays
ref = UD.cormaw.weapondefs.dmaw
UD.legamph.weapondefs.heat_ray = table.copy(ref)
-- more? maybe?

ref = UD.armbeamer.weapondefs.armbeamer_weapon
for name, wname in pairs { legheavydrone = "heat_ray", leginc = "heatraylarge", leginfestor = "festorbeam", legkark = "heat_ray", legbastion = "t2heatray", leglht = "heat_ray", legsh = "heat_ray", leganavyflagship = "leg_experimental_heatray", legnavydestro = "leg_medium_heatray", legeheatraymech = "heatray1", legehovertank = "heat_ray", legaheattank = "heat_ray", leghelios = "heat_ray" } do
	unit(name) weapon(wname)
	copy(weaponDef, "impactonly", "areaofeffect",
		"corethickness", "explosiongenerator", "intensity", "laserflaresize", "rgbcolor", "thickness", "size",
		"soundhitdry", "soundhitwet", "soundstart")
	-- todo: rescale beam thickness, etc.
end

-- Railguns
ref = UD.corhlt.weapondefs.cor_laserh1
for name, wname in pairs { legrail = "railgun", legsrail = "railgunt2", leganavyflagship = "leg_experimental_railgun", legerailtank = "t3_rail_accelerator" } do
	unit(name) weapon(wname) custom(weaponDef)
	weaponDef.name = "Heavy Laser"
	copy(weaponDef, "weapontype", "beamtime", "impulsefactor", "noexplode",
		"corethickness", "explosiongenerator", "intensity", "laserflaresize", "rgbcolor", "thickness", "size",
		"soundhitdry", "soundhitwet", "soundstart",
		"cylindertargeting", "impactonly", "predictboost")
	weaponDef.weaponvelocity = weaponDef.range + 100
	cparams.overpenetrate = nil
	damages(1.3)
end

ref = UD.armaak.weapondefs.longrangemissile
for name, wname in pairs { legrail = "aa_railgun", legadvaabot = "aa_railgun" } do
	unit(name) weapon(wname)
	weaponDef.name = "Long-Range Anti-Air Missile Launcher"
	local range = weaponDef.range
	local vtol = weaponDef.damage.vtol
	local reloadtime = weaponDef.reloadtime
	local new = table.copy(ref)
	new.range = range
	new.vtol = vtol
	new.reloadtime = reloadtime
	unitDef.weapondefs[wname] = new
end

-- Burst plasma
ref = UD.correap.weapondefs.cor_reap
for name, wname in pairs { legcen = "gauss", legaskirmtank = "legmgplasma", leganavybattleship = "burst_plasma_t2", } do
	unit(name) weapon(wname)
	weaponDef.name = "Medium Plasma Cannon"
	weaponDef.impactonly = false
	local area = weaponDef.areaofeffect
	local burst = weaponDef.burst
	local damage = weaponDef.damage.default * burst
	copy(weaponDef, "impactonly", "impulsefactor", "weaponvelocity", "edgeeffectiveness")
	damages(burst)
	weaponDef.burst = nil
	weaponDef.areaofeffect = ref.areaofeffect * damage / ref.damage.default
end

-- Cluster plasma
ref = UD.armamb.weapondefs.armamb_gun
local function toplasma(name, wname)
	unit(name) weapon(wname) custom(weaponDef)
	copy(weaponDef, "cegtag", "explosiongenerator")
	local count = cparams.cluster_number or 5
	local damage = unitDef.weapondefs.cluster_munition.damage.default
	damages(1 + math.sqrt(count * damage / weaponDef.damage.default))
	cparams.cluster_def, cparams.cluster_number = nil, nil
end
for name, wname in pairs { legamcluster = "cluster_artillery", legcluster = "plasma", legacluster = "plasma", leglrpc = "lrpc", legeallterrainmech = "plasma_low" } do
	toplasma(name, wname)
end
for name, wname in pairs { legcluster = "plasma_high", legacluster = "plasma_high", legeallterrainmech = "plasma_high" } do
	toplasma(name, wname)
end

-- Napalm
unit("legbar").weapondefs.clusternapalm = table.copy(UD.legehovertank.weapondefs.parabolic_rockets)
weapon("clusternapalm")
weaponDef.areaofeffect = 48
weaponDef.explosiongenerator = "custom:genericshellexplosion-small-bomb"
weaponDef.burst = 3
weaponDef.burstrate = 0.4
weaponDef.range = 535
weaponDef.weaponvelocity = 240
damages(0.4)

unit("legbart").weapondefs.clusternapalm = table.copy(UD.armfido.weapondefs.bfido)
costs(0.85)

unit("leginf").weapondefs.rapidnapalm = table.copy(UD.cortrem.weapondefs.tremor_spread_fire)
weapon("rapidnapalm")
weaponDef.burst = 3
weaponDef.burstrate = 0.3333
weaponDef.reloadtime = 2
weaponDef.mygravity = 0.2
weaponDef.range = 1200
weaponDef.weaponvelocity = 460

UD.legperdition.weapondefs.napalmmissile = table.copy(UD.cortron.weapondefs.cortron_weapon)

--------------------------------------------------------------------------------
-- Reactive armor --------------------------------------------------------------

for _, name in ipairs { "legkark", "legamph", "legshot" } do
	unit(name) custom(unitDef)
	local armoredMult = 1 / unitDef.damagemodifier
	local armorHealth = cparams.reactive_armor_health
	local healthBonus = armorHealth * (0.5 + math.sqrt(armorHealth * armoredMult / unitDef.health) * (armoredMult - 1))
	unitDef.health = unitDef.health + healthBonus
end

--------------------------------------------------------------------------------
-- Nuh-uh ----------------------------------------------------------------------

UD.leghive, UD.legfhive = nil, nil

unit("legnavydestro").weapons[2] = nil
costs(0.82)

unit("legrampart").radardistancejam = nil
unitDef.weapons[2] = nil
costs(0.9)

UD.legfloat.movementclass = "MTANK3"
UD.legfloat.waterline = nil
UD.legfloat.floater = nil

unit("leganavybattleship").movementclass = "BOAT9"
costs(0.88)

UD.legelrpcmech = nil

UD.legeallterrainmech.weapons[5] = nil

--------------------------------------------------------------------------------
-- Convert to tweakunits -------------------------------------------------------

local tweaks = {}
for name, old in pairs(units) do
	tweaks[name] = tweak(old, UD[name])
end
Spring.Echo(tweaks)