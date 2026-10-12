local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function enableTrigger(triggerID)
	GG['MissionAPI'].Triggers[triggerID].settings.active = true
end

return {
	---Turns a trigger on so that it fires when its event next happens.
	---
	---Enabling does not reset a trigger that has already fired: a non-repeating trigger that fired once stays spent, and a repeating trigger keeps its count against maxRepeats. Use this to start triggers authored with active = false.
	---@class EnableTriggerAction
	---@field triggerID TriggerID The trigger to enable.
	{
		type = 'EnableTrigger',
		parameters = {
			{
				name = 'triggerID',
				required = true,
				type = ParameterTypes.TriggerID
			}
		},
		actionFunction = enableTrigger
	}
}
