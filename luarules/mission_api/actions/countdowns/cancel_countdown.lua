local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function cancelCountdown(countdownID)
	GG['MissionAPI'].Modules.Countdowns.CancelCountdown(countdownID)
end

return {
	---Removes a countdown without ending it, so no countdown-ended trigger fires for it.
	---@class CancelCountdownAction
	---@field countdownID CountdownID The countdown to remove.
	{
		type = 'CancelCountdown',
		parameters = {
			{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
		},
		actionFunction = cancelCountdown,
	}
}
