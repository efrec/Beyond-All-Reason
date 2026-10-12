local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function removeTime(countdownID, seconds)
	GG['MissionAPI'].Modules.Countdowns.RemoveTime(countdownID, seconds)
end

return {
	---Takes seconds off the remaining time of a countdown. The remaining time never goes below zero, and a countdown left at zero ends on its next tick. Does nothing when the countdown has ended or been canceled.
	---@class RemoveTimeAction
	---@field countdownID CountdownID The countdown to shorten.
	---@field seconds Quantity The seconds to remove; the result is rounded to whole seconds.
	{
		type = 'RemoveTime',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
			{ name = 'seconds', required = true, type = ParameterTypes.Quantity },
		},
		actionFunction = removeTime,
	}
}
