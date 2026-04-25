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
---@alias VeterancyUpgrade { [1]:VeterancyEffect, [2]:number|false, [3]:number|false } Compact upgrade information per-unitdef.

local table_new = table.new
local math_floor = math.floor
local math_max = math.max

local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitIsDead = Spring.GetUnitIsDead
local spSetUnitWeaponState = Spring.SetUnitWeaponState
local spSetUnitMaxRange = Spring.SetUnitMaxRange

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

-- Code ------------------------------------------------------------------------

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

-- Unit veterancies ------------------------------------------------------------

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

local mtAppendKeyToName = {
	__index = function(self, key)
		local result = self.name .. tostring(key)
		self[key] = result
		return result
	end
}

-- Cache strings rather than creating garbage in a hot loop.
local calls = setmetatable({}, {
	__index = function(self, key)
		local tbl = table_new(6, 1)
		tbl.name = key
		self[key] = tbl
		setmetatable(tbl, mtAppendKeyToName)
		return tbl
	end
})

---@type table<string, Veterancy>
local veterancyEffects = {}

if not useEngineXP then
	local spSetUnitMaxHealth = Spring.SetUnitMaxHealth

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
			if healthScale > 0 then
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
			if reloadScale <= 0 then
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
end

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
				upgrade[3] = math.max(weaponDef.range, upgrade[3])
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
