-- Ends a pause started by the Pause action. Does nothing for a player pause.
local function unpause()
	GG.ScriptedPause.Unpause()
end

return {
	---Ends a pause started by Pause. A pause made by a player is left alone.
	---@class UnpauseAction
	{
		type = 'Unpause',
		parameters = {},
		actionFunction = unpause,
	}
}
