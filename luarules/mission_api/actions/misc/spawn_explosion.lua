local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function spawnExplosion(weaponDefName, position, direction)
	direction = direction or { x = 0, y = 0, z = 0 }
	local weaponDef = WeaponDefNames[weaponDefName]
	local params = {
		weaponDef = weaponDef.id,
		owner = -1,
		damages = weaponDef.damages,
		hitUnit = 1,
		hitFeature = 1,
		craterAreaOfEffect = weaponDef.craterAreaOfEffect,
		damageAreaOfEffect = weaponDef.damageAreaOfEffect,
		edgeEffectiveness = weaponDef.edgeEffectiveness,
		explosionSpeed = weaponDef.explosionSpeed,
		impactOnly = weaponDef.impactOnly,
		ignoreOwner = weaponDef.noSelfDamage,
		damageGround = true,
	}
	Spring.SpawnExplosion(position.x, position.y, position.z, direction.x, direction.y, direction.z, params)
end

return {
	---Detonates a weapon's explosion at a position, as if that weapon had hit there.
	---
	---The explosion uses the weapon's damage, area of effect, and crater settings, damages units, features, and the ground, and has no owner, so no team is credited with its kills.
	---@class SpawnExplosionAction
	---@field weaponDefName WeaponDefName The weapon whose explosion is spawned.
	---@field position Position Where the explosion happens, in elmos. When y is omitted, the ground height at (x, z) is used.
	---@field direction? Position The direction the explosion travels, as a vector. Always give y, because an omitted y is filled with the ground height at (x, z) as for any position.
	---@default direction { x = 0, y = 0, z = 0 }
	{
		type = 'SpawnExplosion',
		parameters = {
			{ name = 'weaponDefName', required = true, type = ParameterTypes.WeaponDefName },
			{ name = 'position', required = true, type = ParameterTypes.Position },
			{ name = 'direction', required = false, type = ParameterTypes.Position },
		},
		actionFunction = spawnExplosion,
	}
}
