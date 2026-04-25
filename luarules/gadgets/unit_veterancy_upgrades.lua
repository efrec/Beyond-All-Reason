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

-- Unit veterancies ------------------------------------------------------------

---@alias Veterancy { add : (fun(unitDef:table, upgrades:VeterancyUpgrade[]):boolean), effect : VeterancyEffect }

---@alias VeterancyEffect fun(unitID:integer, upgrade:VeterancyUpgrade, experience:number) Applied on experience gain.

---@alias VeterancyUpgrade { [1]:VeterancyEffect, [2]:number|false, [3]:number|false } Compact upgrade information per-unitdef.

---@type table<string, Veterancy>
local veterancyEffects = {}

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
		local rangeScale = (1 + upgrade[2] * experience)
		spSetUnitMaxRange(unitID, math_floor(upgrade[3] * rangeScale))
		for index = 4, #upgrade do
			if upgrade[index] then
				spSetUnitWeaponState(unitID, index - 3, "range", math_floor(upgrade[index] * rangeScale))
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
				upgrade[index + offset] = weaponDef.range
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
		for index = 2, #upgrade do
			local weapon = index - 1
			if upgrade[index] then
				local reloadSpeed = spGetUnitWeaponState(unitID, weapon, "reloadTimeXP")
				-- spSetUnitWeaponState(unitID, weapon, "reloadTime", reloadSpeed) -- TODO: fix feedback loop, lazy
				callUnitScript(unitID, unitLuaEnv, "SetReloadTime" .. weapon, reloadSpeed * 1000)
				reloadMax = math_max(reloadMax, gameSpeedInverse, reloadSpeed)
			else
				reloadMax = math_max(reloadMax, gameSpeedInverse, spGetUnitWeaponState(unitID, weapon, "reloadTimeXP"))
			end
		end
		callUnitScript(unitID, unitLuaEnv, "SetMaxReloadTime", reloadMax * 1000)
	end,
}

-- Code ------------------------------------------------------------------------

local unitVeterancyUpgrades = table.new(#UnitDefs, 0)
local isMassiveAreaAttacker = table.new(#UnitDefs, 0)
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

-- Engine callins --------------------------------------------------------------

function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	if isMassiveAreaAttacker[unitDefID] then
		queuedExperienceGains[unitID] = unitDefID
		return
	end

	local upgrades = unitVeterancyUpgrades[unitDefID]

	if not upgrades then
		return
	end

	applyVeterancyUgrades(unitID, experience, upgrades)
end

function gadget:GameFramePost(frame)
	if next(queuedExperienceGains) then
		for unitID, unitDefID in pairs(queuedExperienceGains) do
			if spGetUnitIsDead(unitID) == false then
				applyVeterancyUgrades(unitID, spGetUnitExperience(unitID), unitVeterancyUpgrades[unitDefID])
			end
			queuedExperienceGains[unitID] = nil
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

	local function hasMassiveAreaWeapon(unitDef)
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef.customParams.bogus ~= "1" then
				if weaponDef.damages[0] > 100 and weaponDef.damageAreaOfEffect > 1000 then
					return true
				end
			end
		end
		return false
	end

	for unitDefID, unitDef in ipairs(UnitDefs) do
		local upgrades

		if type(unitDef.customParams.veterancy_upgrades) == "string" then
			upgrades = getUnitVeterancyUpgrade(unitDef)
		end

		if upgrades then
			unitVeterancyUpgrades[unitDefID] = upgrades
			isMassiveAreaAttacker[unitDefID] = hasMassiveAreaWeapon(unitDef)
		else
			unitVeterancyUpgrades[unitDefID] = false
			isMassiveAreaAttacker[unitDefID] = false
		end
	end

	if not table.any(unitVeterancyUpgrades, function(v) return v end) then
		gadgetHandler:RemoveGadget()
	end
end
