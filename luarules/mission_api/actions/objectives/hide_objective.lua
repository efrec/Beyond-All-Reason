local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function hideObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.HideObjective(objectiveID)
end

return {
	---Marks an objective as hidden so that it is not presented to the player.
	---
	---Hiding changes presentation only: a hidden objective still tracks progress and can still complete or fail. Nothing happens when it is already hidden. Hiding fires the objective's onHidden event trigger.
	---@class HideObjectiveAction
	---@field objectiveID ObjectiveID The objective to hide.
	{
		type = 'HideObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = hideObjective,
	}
}
