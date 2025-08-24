local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "Only Target onlytargetcategory",
		desc	= "Prevents attacking anything other than the only target category",
		author	= "Floris",
		date	= "September 2020",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
	}
end

local unitCategories = Game.UnitInfo.Cache.modCategories
local unitOnlyTargetsCategory = Game.UnitInfo.Cache.onlyTargetCategory
local unitDontAttackGround = {}
for udid, category in pairs(unitOnlyTargetsCategory) do
	if category == "vtol" then
		unitDontAttackGround[udid] = true
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD.ATTACK
	if cmdParams[2] == nil
	and unitOnlyTargetsCategory[unitDefID]
	and type(cmdParams[1]) == 'number'
	and not (unitCategories[Spring.GetUnitDefID(cmdParams[1])] and unitCategories[Spring.GetUnitDefID(cmdParams[1])][unitOnlyTargetsCategory[unitDefID]]) then
		return false
	else
		if cmdParams[2] and unitDontAttackGround[unitDefID] then
			return false
		else
			return true
		end
	end
end
