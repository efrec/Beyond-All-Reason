local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function selfDestructUnits(unitName)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    -- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
    local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])
	for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            Spring.DestroyUnit(unitID, true, false)
        end
	end
end

return {
    ---Self-destructs the units with a name immediately, with their self-destruct explosion and wreck.
    ---
    ---The units count as lost for the owning team, no team is credited with the kill, and UnitKilled triggers watching them fire. Nothing happens when no living unit has the name.
    ---@class SelfDestructUnitsAction
    ---@field unitName UnitName The name whose units self-destruct.
    {
	    type = 'SelfDestructUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
	    },
	    actionFunction = selfDestructUnits,
    },
}