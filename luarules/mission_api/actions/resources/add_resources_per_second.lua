local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addResourcesPerSecond(teamID, metal, energy)
	if metal then
		GG["MissionAPIActionHelper"].addMetalPerSecond(teamID, metal)
	end
	if energy then
		GG["MissionAPIActionHelper"].addEnergyPerSecond(teamID, energy)
	end
end

return {
	---Changes a team's ongoing income by a fixed amount of metal and energy per second for the rest of the game.
	---
	---The income is delivered in two installments per second. Repeating the action adds to the rate already in effect, so a negative amount reduces or cancels an earlier rate; there is no other way to stop it. An omitted resource is left unchanged.
	---@class AddResourcesPerSecondAction
	---@field teamID TeamID The team whose income changes.
	---@field metal? Number Metal per second to add to the team's income, or to drain from it when negative.
	---@field energy? Number Energy per second to add to the team's income, or to drain from it when negative.
	---@requiresOneOf metal energy
	{
		type = 'AddResourcesPerSecond',
		parameters = {
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
			{ name = 'metal', required = false, type = ParameterTypes.Number },
			{ name = 'energy', required = false, type = ParameterTypes.Number },
			requiresOneOf = { 'metal', 'energy' },
		},
		actionFunction = addResourcesPerSecond,
	}
}
