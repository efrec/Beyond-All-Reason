local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addTime(countdownID, seconds)
	GG['MissionAPI'].Modules.Countdowns.AddTime(countdownID, seconds)
end

return {
	---Adds seconds to the remaining time of a countdown. Does nothing when the countdown has ended or been canceled.
	---@class AddTimeAction
	---@field countdownID CountdownID The countdown to lengthen.
	---@field seconds Quantity The seconds to add; the result is rounded to whole seconds.
	{
		type = 'AddTime',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
			{ name = 'seconds', required = true, type = ParameterTypes.Quantity },
		},
		actionFunction = addTime,
	}
}
