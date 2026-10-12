local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function playMusic(soundfile)
    if not GG["music"] then
        error("[Mission API] Music API unavailable (api_music.lua gadget not loaded), cannot play: " .. tostring(soundfile))
    end

    GG["music"].GadgetPlayMusicTrack(soundfile)
end

return {
	---Plays a music track, interrupting the track that is playing.
	---
	---The path is not checked when the mission loads.
	---@class PlayMusicAction
	---@field soundfile String The path of the music file within the game's files.
	{
		type = 'PlayMusic',
		parameters = {
			{ name = 'soundfile', required = true, type = ParameterTypes.String },
		},
		actionFunction = playMusic,
	}
}
