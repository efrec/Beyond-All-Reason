local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function unpauseCountdown(countdownID)
	GG['MissionAPI'].Modules.Countdowns.UnpauseCountdown(countdownID)
end

return {
	---Resumes a countdown paused by PauseCountdown. Does nothing when the countdown has ended or been canceled.
	---@class UnpauseCountdownAction
	---@field countdownID CountdownID The countdown to resume.
	{
		type = 'UnpauseCountdown',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
		},
		actionFunction = unpauseCountdown,
	}
}
