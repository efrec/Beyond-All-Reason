local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name    = "Unit Veterancy Upgrades",
		desc    = "Applies unit and weapon bonuses when units earn XP",
		author  = "efrec",
		version = "0.0",
		date    = "2026-03",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

-- TODO: The GDD outlines veterancy effects as level-up effects that occur one at a time.

local math_floor = math.floor
local math_max = math.max

local spGetUnitDefID = Spring.GetUnitDefID

local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitHealth = Spring.SetUnitHealth
local spSetUnitMaxHealth = Spring.SetUnitMaxHealth

local spGetUnitWeaponState = Spring.GetUnitWeaponState
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

---@type table<string, { add:(fun(unitDef:table, upgrades:table):boolean), effect:fun(unitID:integer, upgrade:table, experience:number) }>
local veterancyEffects = {}

-- TODO: Remove the engine xp gains.
-- TODO: Or else batch these updates in a GameFramePost and use UnitCreated/UnitDestroyed.
-- TODO: The potential performance cost of resetting 1000s of tiny XP gains is ridiculous.
veterancyEffects.none = {
	add = function(unitDef, upgrades)
		local upgrade = { veterancyEffects.none.effect }
		local offset = #upgrade
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			upgrade[index + offset] = weaponDef.reloadTime
		end
		upgrades[#upgrades + 1] = upgrade
		return true
	end,

	effect = function(unitID, upgrade, experience)
		local health, healthMax = spGetUnitHealth(unitID)
		if healthMax == 0 then
			-- ?
		else
			local unitDef = UnitDefs[spGetUnitDefID(unitID)] -- TODO: cache
			if healthMax > unitDef.health then
				spSetUnitHealth(unitID, health * (unitDef.health / healthMax))
				spSetUnitMaxHealth(unitID, healthMax)
			end
		end
		for index = 1, #upgrade - 1 do
			-- TODO: Accuracy, target lead prediction, ...
			spSetUnitWeaponState(unitID, index - 1, "reloadSpeed", upgrade[index])
			spSetUnitWeaponState(unitID, index - 1, "", upgrade[index])
		end
	end,
}

-- Just the Gunslinger. But working now on multi-weapon units.
-- You can skip weapons with the "norangexpscale" customparam.
veterancyEffects.range = {
	add = function(unitDef, upgrades)
		local upgrade = {
			veterancyEffects.range.effect,
			tonumber(unitDef.customParams.veterancy_range_scale),
			0, -- max range, see below
		}
		local offset = #upgrade

		local hasUpgradeWeapon = false
		local rangeMax = 0
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if not weaponDef.customParams.norangexpscale then
				hasUpgradeWeapon = true
				upgrade[index + offset] = weaponDef.range
				rangeMax = math.max(weaponDef.range, rangeMax)
			else
				upgrade[index + offset] = false
			end
		end
		upgrade[3] = tonumber(unitDef.customParams.maxrange or rangeMax)

		if hasUpgradeWeapon then
			upgrades[#upgrades + 1] = upgrade
			return true
		else
			return false
		end
	end,

	effect = function(unitID, upgrade, experience)
		local rangeScale = (1 + upgrade[2] * experience)
		local engageRangeBase = upgrade[3]
		for index = 3, #upgrade do
			if upgrade[index] then
				spSetUnitWeaponState(unitID, index - 2, "range", math_floor(upgrade[index] * rangeScale))
			end
		end
		spSetUnitMaxRange(unitID, math_floor(engageRangeBase * rangeScale))
	end,
}

-- Units with scripted reload times need to be scaled via this method.
-- Other upgrade effects that modify reload time should be before this.
veterancyEffects.scripted_reload = {
	add = function(unitDef, upgrades)
		local upgrade = { veterancyEffects.scripted_reload.effect }
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
				spSetUnitWeaponState(unitID, weapon, "reloadTime", reloadSpeed) -- TODO: fix feedback loop, lazy
				callUnitScript(unitID, unitLuaEnv, "SetReloadTime" .. weapon, reloadSpeed * 1000)
			end
			reloadMax = math_max(reloadMax, gameSpeedInverse, spGetUnitWeaponState(unitID, weapon, "reloadTimeXP"))
		end
		callUnitScript(unitID, unitLuaEnv, "SetMaxReloadTime", reloadMax * 1000)
	end,
}

-- Code ------------------------------------------------------------------------

local unitVeterancyUpgrades = table.new(#UnitDefs, 0)
do
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
end

function gadget:Initialize()
	-- Without this, many XP gains may be too small to reach g:UnitExperience.
	-- We still do not capture some updates, e.g. nuclear explosions vs walls.
	-- TODO: Move this into the game setup? Or something? Why in a gadget?
	Spring.SetExperienceGrade(0.01)

	if not table.any(unitVeterancyUpgrades, function(v) return v end) then
		gadgetHandler:RemoveGadget()
	end
end

function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	local upgrades = unitVeterancyUpgrades[unitDefID]

	if not upgrades then
		return
	end

	-- Canonical BAR experience limit curve. Gaze upon it.
	local experienceCurved = ((3 * experience) / (1 + 3 * experience))

	for index = 1, #upgrades do
		local upgrade = upgrades[index]
		local effect = upgrade[1]
		effect(unitID, upgrade, experienceCurved)
	end
end
