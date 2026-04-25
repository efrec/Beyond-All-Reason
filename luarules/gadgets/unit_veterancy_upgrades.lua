local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name    = "Unit Veterancy Upgrades",
		desc    = "Applies special unit and weapon bonuses when units earn XP",
		author  = "efrec",
		version = "1.0",
		date    = "2026-03",
		license = "GNU GPL, v2 or later",
		layer   = 1000, -- delay until after damaging effects resolve to xp gain
		enabled = true,
	}
end

-- TODO: The GDD outlines veterancy effects as level-up effects that occur one at a time.
-- These upgrades apply every time that XP is gained, provided the amount gained is >= 0.01.
-- Since some XP gains are below this threshold, upgrades should never consider an XP-delta.

---@alias Veterancy { add:(fun(unitDef:table, upgrades:VeterancyUpgrade[]):boolean), effect:VeterancyEffect }
---@alias VeterancyEffect fun(unitID:integer, upgrade:VeterancyUpgrade, experience:number) Applied on experience gain.
---@alias VeterancyUpgrade { [1]:VeterancyEffect, [2]:any|false, [3]:any|false } Compact upgrade information per-unitdef.

local table_new = table.new
local math_floor = math.floor
local math_round = math.round
local math_max = math.max
local math_min = math.min

local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitWeaponDamages = Spring.GetUnitWeaponDamages
local spGetUnitWeaponState = Spring.GetUnitWeaponState

local spSetUnitMaxHealth = Spring.SetUnitMaxHealth
local spSetUnitMaxRange = Spring.SetUnitMaxRange
local spSetUnitWeaponDamages = Spring.SetUnitWeaponDamages
local spSetUnitWeaponState = Spring.SetUnitWeaponState

local spGetCOBScriptID = Spring.GetCOBScriptID
local spCallCOBScript = Spring.CallCOBScript
local spGetScriptEnv = Spring.UnitScript.GetScriptEnv
local spCallLuaScript = Spring.UnitScript.CallAsUnit

local function callUnitScript(unitID, luaEnv, methodName, ...)
	if luaEnv then
		if luaEnv[methodName] then
			spCallLuaScript(unitID, luaEnv[methodName], ...)
		end
	elseif spGetCOBScriptID(unitID, methodName) then
		spCallCOBScript(unitID, methodName, 0, ...)
	end
end

local gameSpeedInverse = 1 / Game.gameSpeed
local armorTypeMin = 0
local armorTypeMax = #Game.armorTypes
local armorTypeTargets = { default = true, vtol = true, sub = true, mine = true }

local autoHealInterval = math_round(Game.gameSpeed * 0.5) -- match engine update rate

-- Code ------------------------------------------------------------------------

local useEngineXP = true
local powerScale = 0
local healthScale = 0
local reloadScale = 0
do
	local modrules = VFS.Include("gamedata/modrules")
	if modrules and modrules.experience then
		if modrules.experience.experienceMult == 0 then
			useEngineXP = false
		end
		powerScale = modrules.experience.powerScale or powerScale
		healthScale = modrules.experience.healthScale or healthScale
		reloadScale = modrules.experience.reloadScale or reloadScale
	end
end

local unitVeterancyUpgrades = table_new(#UnitDefs, 0)
local queuedExperienceGains = {}

local function applyVeterancyUgrades(unitID, experience, upgrades)
	-- Canonical BAR experience limit curve. Gaze upon it.
	local experienceCurved = (3 * experience) / (1 + 3 * experience)

	for index = 1, #upgrades do
		local upgrade = upgrades[index]
		local effect = upgrade[1]
		effect(unitID, upgrade, experienceCurved)
	end
end

-- Cache strings rather than creating garbage in a hot loop.
local mtAppendKeyToName = {
	__index = function(self, key)
		local result = self.name .. tostring(key)
		self[key] = result
		return result
	end
}
local calls = setmetatable({}, {
	__index = function(self, key)
		local tbl = table_new(6, 1)
		tbl.name = key
		self[key] = tbl
		setmetatable(tbl, mtAppendKeyToName)
		return tbl
	end
})

-- Increases to autoheal and idle autoheal have to be handled in game code.
local unitAutoHeal = {}

-- Unit veterancies ------------------------------------------------------------

local veterancyEffects = {} ---@type table<string, Veterancy>

-- Some effects are duplicated in-engine so are conditional on our modrules:

veterancyEffects.power = {
	add = function(unitDef, upgrades)
		return false -- TODO: cannot set unit power directly via engine api
	end,

	effect = function(unitID, upgrade, experience)
		spSetUnitMaxHealth(unitID, math_floor(upgrade[2] * (1 + healthScale * experience)))
	end,
}

veterancyEffects.health = {
	add = function(unitDef, upgrades)
		if not useEngineXP and healthScale > 0 then
			upgrades[#upgrades + 1] = { veterancyEffects.health.effect, unitDef.health }
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		spSetUnitMaxHealth(unitID, math_floor(upgrade[2] * (1 + healthScale * experience)))
	end,
}

veterancyEffects.reload = {
	add = function(unitDef, upgrades)
		if useEngineXP or reloadScale <= 0 then
			return false
		end

		local upgrade = { veterancyEffects.reload.effect }
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not weaponDef.customParams.noreloadxpscale then
				hasUpgradeWeapon = true
				upgrade[index + offset] = weaponDef.reload
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local reloadMult = 1 + reloadScale * experience
		for index = 2, #upgrade do
			if upgrade[index] then
				spSetUnitWeaponState(unitID, index - 1, "reloadTimeXP", upgrade[index] * reloadMult)
			end
		end
	end,
}

-- The rest of the veterancy effects have no equivalent function in the engine:

veterancyEffects.autoheal = {
	add = function(unitDef, upgrades)
		local upgrade = {
			veterancyEffects.autoheal.effect,
			tonumber(unitDef.customParams.veterancy_autoheal_scale or 0) or 0,
			unitDef.health, -- NB: Not scaled against autoheal
		}
		if upgrade[2] > 0 and upgrade[3] > 0 then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local healScale = 1 + upgrade[2] * experience
		local autoHealExtra = upgrade[3] * healScale -- May be in addition to base autoheal
		unitAutoHeal[unitID] = autoHealExtra
	end,
}

local armorTargetIndex = -1
local armorTemp = table.new(armorTypeMax, 1)
local function setDamages(unitID, damageMult, weapon, damages)
	-- Avoid updates that do not change damage to the primary armor target:
	local armorTarget = damages[armorTargetIndex]
	local armorDamage = spGetUnitWeaponDamages(unitID, weapon, armorTarget)
	if armorDamage == math_round(damages[armorTarget] * damageMult) then
		return
	end
	-- Avoid nArmorTypes engine calls that repeat parsing of simple inputs:
	local a = armorTemp
	for i = armorTypeMin, armorTypeMax do
		a[i] = math_round(damages[i] * damageMult)
	end
	spSetUnitWeaponDamages(unitID, weapon, a)
end

-- Dynamic damages per-weapon are scaled with a unit-level customparam.
veterancyEffects.damage = {
	add = function(unitDef, upgrades)
		---@type VeterancyUpgrade
		local upgrade = {
			veterancyEffects.damage.effect,
			tonumber(unitDef.customParams.veterancy_damage_scale or 0) or 0,
		}
		local offset = #upgrade

		if upgrade[2] <= 0 then
			return false
		end

		local hasUpgradeWeapon = false

		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			local damages = nil

			if not weaponDef.customParams.nodamagexpscale and weaponDef.customParams.bogus ~= "1" then
				damages = table.new(armorTypeMax, 1) -- [0] is hashed
				damages[armorTargetIndex] = 0
				local armorDamage = weaponDef.damages[0]
				for i = armorTypeMin, armorTypeMax do
					damages[i] = weaponDef.damages[i]
					if damages[i] > armorDamage and armorTypeTargets[Game.armorTypes[i]] then
						damages[armorTargetIndex], armorDamage = i, damages[i]
					end
				end
				if armorDamage <= 0 then
					damages = nil
				end
			end

			if damages then
				hasUpgradeWeapon = true
				upgrade[index + offset] = damages
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local damageMult = (1 + upgrade[2] * experience)
		for index = 3, #upgrade do
			if upgrade[index] then
				setDamages(unitID, damageMult, index - 2, upgrade[index])
			end
		end
	end,
}

-- Dynamic ranges per-weapon are scaled with a unit-level customparam.
veterancyEffects.range = {
	add = function(unitDef, upgrades)
		---@type VeterancyUpgrade
		local upgrade = {
			veterancyEffects.range.effect,
			tonumber(unitDef.customParams.veterancy_range_scale or 0) or 0,
			0,
		}
		local offset = #upgrade

		if upgrade[2] <= 0 then
			return false
		end

		local hasUpgradeWeapon = false

		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not weaponDef.customParams.norangexpscale then
				hasUpgradeWeapon = true
				upgrade[index + offset] = weaponDef.range
				upgrade[3] = math_max(weaponDef.range, upgrade[3])
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local rangeMult = (1 + upgrade[2] * experience)
		spSetUnitMaxRange(unitID, math_floor(upgrade[3] * rangeMult))
		for index = 4, #upgrade do
			if upgrade[index] then
				spSetUnitWeaponState(unitID, index - 3, "range", math_floor(upgrade[index] * rangeMult))
			end
		end
	end,
}

-- Units with scripted reload times need to be scaled via this method.
-- Other upgrade effects that modify reload time should be before this.
veterancyEffects.scripted_reload = {
	add = function(unitDef, upgrades)
		local upgrade = { veterancyEffects.scripted_reload.effect } ---@type VeterancyUpgrade
		local offset = #upgrade

		local hasUpgradeWeapon = false
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not weaponDef.customParams.noreloadxpscale then
				hasUpgradeWeapon = true
				upgrade[index + offset] = weaponDef.reload
			else
				upgrade[index + offset] = false
			end
		end

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local unitLuaEnv = spGetScriptEnv(unitID)
		local reloadMax = 0
		local reloadMult = 1 + reloadScale * experience
		for index = 2, #upgrade do
			local weapon = index - 1
			if upgrade[index] then
				local reloadSpeed = upgrade[index] * reloadMult
				callUnitScript(unitID, unitLuaEnv, calls.SetReloadTime[weapon], reloadSpeed * 1000)
				reloadMax = math_max(reloadMax, gameSpeedInverse, reloadSpeed)
			else
				reloadMax = math_max(reloadMax, gameSpeedInverse, spGetUnitWeaponState(unitID, weapon, "reloadTimeXP"))
			end
		end
		callUnitScript(unitID, unitLuaEnv, "SetMaxReloadTime", reloadMax * 1000)
	end,
}

-- Engine callins --------------------------------------------------------------

function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	if unitVeterancyUpgrades[unitDefID] then
		queuedExperienceGains[unitID] = unitDefID
	end
end

function gadget:GameFramePost(frame)
	local gains = queuedExperienceGains
	for unitID, unitDefID in pairs(gains) do
		if spGetUnitIsDead(unitID) == false then
			applyVeterancyUgrades(unitID, spGetUnitExperience(unitID), unitVeterancyUpgrades[unitDefID])
		end
		gains[unitID] = nil
	end

	if frame % autoHealInterval == 0 then
		for unitID, autoHeal in pairs(unitAutoHeal) do
			if spGetUnitIsDead(unitID) == false then
				local health, healthMax = Spring.GetUnitHealth(unitID)
				if health < healthMax then
					Spring.SetUnitHealth(unitID, math_min(health + autoHeal, healthMax))
				end
			end
		end
	end
end

function gadget:Initialize()
	-- Without this, many XP gains may be too small to reach g:UnitExperience.
	-- We still do not capture some updates, e.g. nuclear explosions vs walls.
	-- TODO: Move this into the game setup? Or something? Why in a gadget?
	Spring.SetExperienceGrade(0.01)

	local function getUnitVeterancyUpgrade(unitDef)
		local upgrades = {}
		local veterancies = unitDef.customParams.veterancy_upgrades:split(", ")
		local addedEffect = {}
		for _, name in ipairs(table.getUniqueArray(veterancies)) do
			if addedEffect[name] == nil and veterancyEffects[name] then
				addedEffect[name] = veterancyEffects[name].add(unitDef, upgrades)
			end
		end
		return next(upgrades) and upgrades or false
	end

	for unitDefID, unitDef in ipairs(UnitDefs) do
		if type(unitDef.customParams.veterancy_upgrades) == "string" then
			unitVeterancyUpgrades[unitDefID] = getUnitVeterancyUpgrade(unitDef)
		else
			unitVeterancyUpgrades[unitDefID] = false
		end
	end

	if not table.any(unitVeterancyUpgrades, function(v) return v end) then
		gadgetHandler:RemoveGadget()
	end
end
