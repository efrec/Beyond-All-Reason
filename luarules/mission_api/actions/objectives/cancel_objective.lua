local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function cancelObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.CancelObjective(objectiveID)
end

return {
	---Cancels an objective, deactivating it without completing or failing it.
	---
	---Nothing happens when the objective is already completed or already canceled. Canceling fires the objective's onCanceled event trigger. A canceled objective can be activated again with ActivateObjective.
	---@class CancelObjectiveAction
	---@field objectiveID ObjectiveID The objective to cancel.
	{
		type = 'CancelObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = cancelObjective,
	}
}
