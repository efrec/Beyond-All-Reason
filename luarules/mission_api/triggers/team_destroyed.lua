local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires when the given team is eliminated.
---@class TeamDestroyedTrigger
---@field teamID Number The team to watch.

return {
	type = 'TeamDestroyed',
	parameters = {
		{ name = 'teamID', required = true, type = ParameterTypes.Number },
	},
	callins = {
		TeamDied = function(trigger, triggerID, context, teamID)
			if teamID == trigger.parameters.teamID then
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
