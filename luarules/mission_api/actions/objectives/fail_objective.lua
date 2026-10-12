local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function failObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.FailObjective(objectiveID)
end

return {
	---Marks an objective as failed.
	---
	---Nothing happens when the objective is already completed or failed. Failing fires the objective's onFailed event trigger and then, unless that trigger changed the stage, advances to the objective's nextStage under the same conditions as completion. A failed objective counts as finished for stage advancement and cannot be activated again.
	---@class FailObjectiveAction
	---@field objectiveID ObjectiveID The objective to fail.
	{
		type = 'FailObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = failObjective,
	}
}
