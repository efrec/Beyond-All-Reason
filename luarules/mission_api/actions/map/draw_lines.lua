local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function drawLines(positions, lineName)
	GG['MissionAPI'].Modules.MapLines.DrawLine(lineName, positions)
end

return {
	---Draws a line through the positions in order, visible to every player, and records it under lineName. Drawing again with the same name replaces the earlier line.
	---@class DrawLinesAction
	---@field positions Positions At least two positions, with x and z in elmos; y defaults to the ground height.
	---@field lineName String The name the line is known by.
	---@declares lineName
	{
		type = 'DrawLines',
		parameters = {
			{ name = 'positions', required = true, type = ParameterTypes.Positions },
			{ name = 'lineName',  required = true, type = ParameterTypes.String },
		},
		actionFunction = drawLines,
	}
}
