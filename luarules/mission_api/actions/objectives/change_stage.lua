local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function changeStage(stageID)
	GG['MissionAPI'].Modules.Objectives.ChangeStage(stageID)
end

return {
	---Moves the mission to another stage.
	---
	---Objectives listed by the current stage that are not completed are canceled, except those also listed by the new stage, which continue unchanged. Every other objective listed by the new stage is activated. Changing to the stage that is already current changes nothing.
	---@class ChangeStageAction
	---@field stageID StageID The stage to make current.
	{
		type = 'ChangeStage',
		parameters = {
			{ name = 'stageID', required = true, type = ParameterTypes.StageID },
		},
		actionFunction = changeStage,
	}
}
