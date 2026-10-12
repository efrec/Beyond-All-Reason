local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function victory(winningAllyTeamIDs)
	Spring.GameOver({ unpack(winningAllyTeamIDs) })
end

return {
	---Ends the game with the listed ally teams as the winners.
	---@class VictoryAction
	---@field allyTeamIDs AllyTeamIDs The ally teams that win.
	{	
		type = 'Victory',
		parameters = {
			{ name = 'allyTeamIDs', required = true, type = ParameterTypes.AllyTeamIDs },
		},
		actionFunction = victory,
	}
}
