-- Some unit scripts have requirements for their input defs. This tries to apply those constraints.

local gameSpeed = Game.gameSpeed
local gameSpeedInv = 1 / gameSpeed

local function sweepfireBurst(name, weaponDef)
	if weaponDef.weapontype ~= "BeamLaser" then
		return
	end

	local customparams = table.ensureTable(weaponDef, "customparams")
	customparams.unitscript_sweepfire = true

	-- We want a per-frame energy drain for an interruptible firing duration,
	-- not an upfront firing cost followed by a fixed firing time beam burst:
	local time = (weaponDef.beamburst and (weaponDef.burst or 1) * (weaponDef.burstrate or 0.1)) or (weaponDef.beamtime or 1.0)
	local frames = math.max(math.round(time * gameSpeed), 1)
	customparams.burst = frames
	customparams.reload = weaponDef.reloadtime or 1.0

	local timeScale = 1 / frames
	local damageScale = weaponDef.beamburst and timeScale or 1
	weaponDef.beamburst = nil
	weaponDef.burst = nil
	weaponDef.burstrate = nil
	weaponDef.beamtime = gameSpeedInv
	weaponDef.reloadtime = gameSpeedInv
	weaponDef.energypershot = weaponDef.energypershot * timeScale -- ! not rounded
	for armor, damage in pairs(weaponDef.damage) do
		weaponDef.damage[armor] = damage * damageScale
	end
	if customparams.shield_damage then
		customparams.shield_damage = customparams.shield_damage * damageScale
	end
end

local function sweepfireBurstReload(name, weaponDef)
	if weaponDef.weapontype ~= "BeamLaser" then
		return
	end
	local reloadBefore = weaponDef.reloadtime or 1.0
	sweepfireBurst(name, weaponDef)
	weaponDef.reloadtime = reloadBefore
	weaponDef.customparams.reload = nil
end

-- Map specific scripts to specific weapons (not weapondefs).
local scriptedWeapons = {
	["units/legamph.cob"           ] = { [1] = sweepfireBurst }, -- goofball
	["units/legaheattank_clean.cob"] = { [1] = sweepfireBurstReload },
	["units/legphoenix.cob"        ] = { [2] = sweepfireBurstReload },
	["units/legbastion.cob"        ] = { [1] = sweepfireBurstReload },
	["units/legehovertank.cob"     ] = { [1] = sweepfireBurstReload },
}

local function post(name, unitDef)
	local weapons = scriptedWeapons[(unitDef.script or ("units/" .. name .. ".cob")):lower()]
	if not weapons then
		return
	end

	for index, effect in pairs(weapons) do
		local weapon = unitDef.weapons[index]
		if not weapon then
			return
		end

		local weaponDefName = weapon.def
		if not weaponDefName then
			return
		end

		weaponDefName = weaponDefName:lower()
		local weaponDef = unitDef.weapondefs[weaponDefName]
		if not weaponDef then
			return
		end

		effect(weaponDefName, weaponDef)
	end
end

return {
	Post = post,
}
