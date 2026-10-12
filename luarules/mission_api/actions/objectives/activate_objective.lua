local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function activateObjective(objectiveID)
	local objectives = GG['MissionAPI'].Modules.Objectives
	objectives.ActivateObjective(objectiveID)
	objectives.EchoObjectiveUpdate(objectiveID, GG['MissionAPI'].Objectives[objectiveID]) -- temp
end

return {
	---Makes an objective active so that it can progress and complete.
	---
	---Nothing happens when the objective is already active or already completed, or when the objective is restricted to stages that do not include the current stage. Activating clears an earlier cancellation and fires the objective's onActivated event trigger.
	---@class ActivateObjectiveAction
	---@field objectiveID ObjectiveID The objective to activate.
	{
		type = 'ActivateObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = activateObjective,
	}
}
