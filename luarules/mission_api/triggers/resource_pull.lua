local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Return value index as on https://recoilengine.org/docs/lua-api/#Spring.GetTeamResources
local RESOURCE_PULL_INDEX = 3

---Fires when a team's demand for metal, energy, or both is at or above the given amounts per second. Demand is checked once per second, and both thresholds must be met when both are given. While repeating, it fires again every second the thresholds hold.
---@class ResourcePullTrigger
---@field teamID TeamID The team whose demand is measured.
---@field metal? Number The metal demand per second to reach.
---@field energy? Number The energy demand per second to reach.
---@requiresOneOf metal energy

return {
	type = 'ResourcePull',
	parameters = {
		{ name = 'teamID', required = true,  type = ParameterTypes.TeamID },
		{ name = 'metal',  required = false, type = ParameterTypes.Number },
		{ name = 'energy', required = false, type = ParameterTypes.Number },
		requiresOneOf = { 'metal', 'energy' },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, frameNumber)
			-- Pull is evaluated once per second (matches income accounting).
			if frameNumber % Game.gameSpeed ~= 0 then
				return
			end
			if trigger.parameters.metal and select(RESOURCE_PULL_INDEX, Spring.GetTeamResources(trigger.parameters.teamID, "metal")) < trigger.parameters.metal then
				return
			end
			if trigger.parameters.energy and select(RESOURCE_PULL_INDEX, Spring.GetTeamResources(trigger.parameters.teamID, "energy")) < trigger.parameters.energy then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
