local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Paralyze On Off Behavior',
        desc      = 'Turns units off if stunned in 1 hit',
        author    = 'Itanthias',
        version   = 'v1.0',
        date      = 'May 2023',
        license   = 'GNU GPL, v2 or later',
        layer     = 12, -- check after all paralyze damage modifiers
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

-- These units must handle activation in their unit script:
local off_on_stun = Game.UnitInfo.Cache.off_on_stun

function gadget:UnitPreDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, projID, aID, aDefID, aTeam)
    if paralyzer and off_on_stun[uDefID] then
		local health, maxHealth, paralyzeDamage = Spring.GetUnitHealth(uID)
		if paralyzeDamage + damage > maxHealth then
			-- turn off unit if it will stun
			Spring.SetUnitCOBValue(uID, COB.ACTIVATION, 0)
		end
    end
    return damage, 1
end
