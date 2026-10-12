local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function removeLine(lineName)
	GG['MissionAPI'].Modules.MapLines.RemoveLine(lineName)
end

return {
	---Erases a line drawn by DrawLines. Does nothing for a name that is not drawn.
	---@class RemoveLineAction
	---@field lineName String The line to erase.
	{
		type = 'RemoveLine',
		parameters = {
			{ name = 'lineName', required = true, type = ParameterTypes.String },
		},
		actionFunction = removeLine,
	}
}
