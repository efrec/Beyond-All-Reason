local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function completeObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.CompleteObjective(objectiveID)
end

return {
	---Completes an objective as a success, regardless of its own trigger.
	---
	---Nothing happens when the objective is already completed or failed. Completing fires the objective's onCompleted event trigger and then, unless that trigger changed the stage, advances to the objective's nextStage once every objective of the current stage sharing that nextStage is complete. A completed objective cannot be activated again.
	---@class CompleteObjectiveAction
	---@field objectiveID ObjectiveID The objective to complete.
	{
		type = 'CompleteObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = completeObjective,
	}
}
