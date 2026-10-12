local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function disableTrigger(triggerID)
	GG['MissionAPI'].Triggers[triggerID].settings.active = false
end

return {
	---Turns a trigger off so that it stops firing until an EnableTrigger action turns it back on.
	---
	---A disabled trigger ignores its events entirely, so an event that happens while it is disabled is missed rather than held. Disabling does not reset the trigger's repeat count.
	---@class DisableTriggerAction
	---@field triggerID TriggerID The trigger to disable.
	{
		type = 'DisableTrigger',
		parameters = {
			{ name = 'triggerID', required = true, type = ParameterTypes.TriggerID },
		},
		actionFunction = disableTrigger,
	}
}
