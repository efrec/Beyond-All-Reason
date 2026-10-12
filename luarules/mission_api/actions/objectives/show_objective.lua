local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function showObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.ShowObjective(objectiveID)
end

return {
	---Clears an objective's hidden mark so that it is presented to the player again.
	---
	---Nothing happens when the objective is not hidden. Showing fires the objective's onShown event trigger.
	---@class ShowObjectiveAction
	---@field objectiveID ObjectiveID The objective to show.
	{
		type = 'ShowObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = showObjective,
	}
}
