-- Pauses the game through GG.ScriptedPause (api_scripted_pause.lua): players
-- cannot undo the pause, and the pause screen does not show for it.
local function pause()
	GG.ScriptedPause.Pause()
end

return {
	---Pauses the game in a way players cannot undo; only Unpause ends it. The usual pause overlay is not shown.
	---@class PauseAction
	{
		type = 'Pause',
		parameters = {},
		actionFunction = pause,
	}
}
