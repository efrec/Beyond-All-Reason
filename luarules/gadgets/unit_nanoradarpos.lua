
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Nano Radar Pos",
        desc      = "Removes radar icon wobble for nanos since these units are technically not buildings (no yardmap)",
        author    = "Floris",
        date      = "November 2019",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end


if (gadgetHandler:IsSyncedCode()) then
	-- may include more than nanos:
    local isImmobileUnit = Game.UnitInfo.Cache.isImmobileUnit

    function gadget:UnitCreated(uid, udid)
        if isImmobileUnit[udid] then
            Spring.SetUnitPosErrorParams(udid, 0,0,0, 0,0,0, math.huge)
        end
    end

end
