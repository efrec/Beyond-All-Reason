local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setTime(countdownID, seconds)
	GG['MissionAPI'].Modules.Countdowns.SetTime(countdownID, seconds)
end

return {
	---Sets the remaining time of a countdown and restarts its ticking from now. Does nothing when the countdown has ended or been canceled.
	---@class SetTimeAction
	---@field countdownID CountdownID The countdown to change.
	---@field seconds Quantity The new remaining time in seconds, rounded to whole seconds.
	{
		type = 'SetTime',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
			{ name = 'seconds', required = true, type = ParameterTypes.Quantity },
		},
		actionFunction = setTime,
	}
}
