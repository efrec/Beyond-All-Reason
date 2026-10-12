local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function moveUnits(unitName, position, direction)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs[unitName]

    for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            Spring.SetUnitPosition(unitID, position.x, position.y, position.z)
            if direction then
                if direction.x then
                    local testposx, _, testposz = Spring.GetUnitPosition(unitID)
                    if math.abs(direction.x-testposx) >= 0.001 or math.abs(direction.z-testposz) >= 0.001 then
                        Spring.SetUnitDirection(unitID, direction.x-testposx, direction.y, direction.z-testposz)
                    end
                elseif direction.angle then
                    -- TODO: refactor to call CompassAngleToHeading when it is merged
                    local heading = math.floor( (direction.angle % 360 - 180) / 360  * -65535 )
                    Spring.SetUnitHeadingAndUpDir(unitID, heading, 0, 1, 0)
                end
            end
        end
    end
end

return {
    ---Teleports the units with a name to a position, optionally turning them to face a direction.
    ---
    ---Every unit with the name is placed at the same position. The direction is either { angle = degrees }, a compass angle with 0 facing north and 90 facing east, or a point { x, z } that each unit turns to face; a unit placed exactly on that point keeps its facing. Nothing happens when no living unit has the name.
    ---@class MoveUnitsAction
    ---@field unitName UnitName The name whose units are moved.
    ---@field position Position The destination in elmos. When y is omitted, the ground height at (x, z) is used.
    ---@field direction? Direction The facing after the move. Units keep their facing when omitted.
    {
	    type = 'MoveUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
            { name = 'position', required = true, type = ParameterTypes.Position },
            { name = 'direction', required = false, type = ParameterTypes.Direction },
	    },
	    actionFunction = moveUnits,
    },
}