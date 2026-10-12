local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function reclaimUnits(unitName, reclaimerTeam)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    -- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
    local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])
	for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            if not reclaimerTeam then
                reclaimerTeam = Spring.GetUnitTeam(unitID)
            end
            local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
            Spring.AddTeamResource(reclaimerTeam, "metal", unitDef.metalCost) 
            -- We don't give energy from reclaims, but putting it here just in case someone needs it later.
            -- Spring.AddTeamResource(reclaimerTeam, "energy", unitDef.energyCost)
            GG['MissionAPI'].reclaimingUnits = true
            Spring.DestroyUnit(unitID, false, true)
            GG['MissionAPI'].reclaimingUnits = nil
        end
	end
end

return {
    ---Removes the units with a name as if they were reclaimed, refunding their metal cost to a team.
    ---
    ---Each unit's full metal cost is added to the receiving team's storage; no energy is refunded. The units leave no wreck and no explosion. UnitReclaimed triggers ignore this action unless they set ignoreMissionActions = false. Nothing happens when no living unit has the name.
    ---@class ReclaimUnitsAction
    ---@field unitName UnitName The name whose units are reclaimed.
    ---@field reclaimerTeam? TeamID The team that receives the metal. When omitted, the team that owns the units receives it.
    {
	    type = 'ReclaimUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
	    	{ name = 'reclaimerTeam', required = false, type = ParameterTypes.TeamID },
	    },
	    actionFunction = reclaimUnits,
    },
}