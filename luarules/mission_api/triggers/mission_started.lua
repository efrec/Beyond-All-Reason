-- Immediately after the UI is present and usable and before any interactive gameplay.
-- PreGame happened already, so loadouts are spawned and the initial stage is active.
-- Some effects may take a single frame to occur; we may miss them here at frame 0.

---Fires once when the mission starts, after the starting units are placed and the first stage is active, and before any interactive gameplay.
---
---Some effects of the mission setup may not have taken place yet when it fires.
---@class MissionStartedTrigger

return {
	type = 'MissionStarted',
	parameters = {},
	callins = {
		GameStart = function(trigger, triggerID, context)
			context.ActivateTrigger(trigger)
		end,
	},
}
