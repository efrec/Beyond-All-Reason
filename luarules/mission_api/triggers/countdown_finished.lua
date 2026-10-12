local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires when the named countdown reaches zero.
---@class CountdownFinishedTrigger
---@field countdownID CountdownID The countdown to watch.

return {
	type = 'CountdownFinished',
	parameters = {
		{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
	},
	callins = {
		CountdownEnded = function(trigger, triggerID, context, countdownID)
			if trigger.parameters.countdownID ~= countdownID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
