local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addCountdown(countdownID, seconds, displayed)
	GG['MissionAPI'].Modules.Countdowns.AddCountdown(countdownID, seconds, displayed)
end

return {
	---Starts a countdown that runs down one second at a time and ends when it reaches zero. Countdown triggers and the other countdown actions refer to it by its countdownID.
	---
	---Adding a countdown with the ID of a running one replaces it.
	---@class AddCountdownAction
	---@field countdownID CountdownID The name the countdown is known by.
	---@field seconds Quantity The duration in seconds, rounded to whole seconds.
	---@field displayed? Boolean Whether the countdown is meant to be shown to the player. Displayed countdowns tick together on whole seconds and hold their time through their first tick; others time their duration exactly from when they are added.
	---@default displayed true
	---@declares countdownID
	{
		type = 'AddCountdown',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
			{ name = 'seconds', required = true, type = ParameterTypes.Quantity },
			{ name = 'displayed', required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = addCountdown,
	}
}
