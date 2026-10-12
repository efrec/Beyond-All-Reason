local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local MessageTypes = GG['MissionAPI'].Modules.ParameterTypes.Enums[ParameterTypes.MessageType]

local function sendMessage(messageKey, messageData)
	GG['MissionAPI'].Modules.BattleLog.AddMessage(MessageTypes.Message, messageKey, messageData)
end

return {
	---Adds a message to the battle log for the player to read.
	---
	---The text is translated on the player's side, so messageKey is a translation key rather than display text. The entry is logged as a plain message, as opposed to a briefing, objective, notification, or dialogue entry.
	---@class SendMessageAction
	---@field messageKey String The translation key of the message text.
	---@field messageData? Table Values substituted into the translated text, keyed by placeholder name.
	{
		type = 'SendMessage',
		parameters = {
			{ name = 'messageKey', required = true, type = ParameterTypes.String },
			{ name = 'messageData', required = false, type = ParameterTypes.Table },
		},
		actionFunction = sendMessage,
	}
}
