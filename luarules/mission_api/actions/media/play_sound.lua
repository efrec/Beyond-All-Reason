local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function playSound(soundfile, volume, position, enqueue)
	local sounds = GG['MissionAPI'].Modules.Sounds
	if enqueue then
		sounds.EnqueueSound(soundfile, volume, position)
	else
		sounds.PlaySound(soundfile, volume, position)
	end
end

return {
	---Plays a sound once, either right away or queued behind other queued sounds so that they do not overlap.
	---
	---While a queued sound plays, the game's spoken notifications are held back for its length.
	---@class PlaySoundAction
	---@field soundfile SoundFile The path of a .wav file within the game's files; checked when the mission loads.
	---@field volume? Number The playback volume, where 1 is full volume.
	---@field position? Position Plays the sound from this point in the world, with x and z in elmos and y defaulting to the ground height, instead of everywhere.
	---@field enqueue? Boolean Whether to queue the sound after the queued sounds before it; false plays it immediately, over anything else.
	---@default volume 1
	---@default enqueue false
	{
		type = 'PlaySound',
		parameters = {
			{ name = 'soundfile', required = true, type = ParameterTypes.SoundFile },
			{ name = 'volume', required = false, type = ParameterTypes.Number },
			{ name = 'position', required = false, type = ParameterTypes.Position },
			{ name = 'enqueue', required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = playSound,
	}
}
