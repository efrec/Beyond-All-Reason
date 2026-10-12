local function removeAllLines()
	GG['MissionAPI'].Modules.MapLines.RemoveAllLines()
end

return {
	---Erases every line drawn by DrawLines.
	---@class RemoveAllLinesAction
	{
		type = 'RemoveAllLines',
		parameters = {},
		actionFunction = removeAllLines,
	}
}
