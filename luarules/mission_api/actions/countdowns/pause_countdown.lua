local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function pauseCountdown(countdownID)
	GG['MissionAPI'].Modules.Countdowns.PauseCountdown(countdownID)
end

return {
	---Freezes the remaining time of a countdown until UnpauseCountdown resumes it. Does nothing when the countdown has ended or been canceled.
	---@class PauseCountdownAction
	---@field countdownID CountdownID The countdown to pause.
	{
		type = 'PauseCountdown',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
		},
		actionFunction = pauseCountdown,
	}
}
