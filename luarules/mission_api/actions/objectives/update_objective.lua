local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function updateObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.UpdateObjective(objectiveID)
end

return {
	---Advances an objective by one step of progress.
	---
	---Only an active, unfinished objective advances. The objective completes when its progress reaches its amount, or immediately when it has no amount; otherwise its onProgress event trigger fires. Objectives whose trigger has a quantity track their own progress and are not meant to be advanced this way.
	---@class UpdateObjectiveAction
	---@field objectiveID ObjectiveID The objective to advance.
	{
		type = 'UpdateObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = updateObjective,
	}
}
