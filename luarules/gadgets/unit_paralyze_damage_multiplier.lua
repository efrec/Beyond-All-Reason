local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Paralyze Damage Multiplier',
        desc      = 'Applies Paralyze damage resistance',
        author    = 'Niobium',
        version   = 'v1.0',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local paralyzeMultipliers = Game.UnitInfo.Cache.paralyzeMultiplier

function gadget:UnitPreDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, projID, aID, aDefID, aTeam)
    if paralyzer then
        -- apply customParams paralyse multiplier
        local paralyzeMultiplier = paralyzeMultipliers[uDefID]
		return damage * paralyzeMultiplier, paralyzeMultiplier
    end
    return damage, 1
end
