local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addResources(teamID, metal, energy)
	if metal then
		if metal > 0 then
            Spring.AddTeamResource(teamID, "metal", metal)
        elseif metal < 0 then
            Spring.UseTeamResource(teamID, "metal", -metal)
        end
	end
	if energy then
		if energy > 0 then
            Spring.AddTeamResource(teamID, "energy", energy)
        elseif energy < 0 then
            Spring.UseTeamResource(teamID, "energy", -energy)
        end
	end
end

return {
	---Gives a team metal and energy at once, or takes them away.
	---
	---Positive amounts are added to the team's storage, and negative amounts are spent from it. Each resource is applied separately, and an omitted resource is left unchanged.
	---@class AddResourcesAction
	---@field teamID TeamID The team whose storage changes.
	---@field metal? Number Metal to add, or to remove when negative.
	---@field energy? Number Energy to add, or to remove when negative.
	---@requiresOneOf metal energy
	{
		type = 'AddResources',
		parameters = {
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
			{ name = 'metal', required = false, type = ParameterTypes.Number },
			{ name = 'energy', required = false, type = ParameterTypes.Number },
			requiresOneOf = { 'metal', 'energy' },
		},
		actionFunction = addResources,
	}
}
