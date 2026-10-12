local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Return value index as on https://recoilengine.org/docs/lua-api/#Spring.GetTeamResources
local CURRENT_RESOURCE_LEVEL_INDEX = 1

---Fires when a team has at least the given amounts of metal, energy, or both in storage. Storage is checked every game frame, and both thresholds must be met when both are given. While repeating, it fires again every game frame the thresholds hold.
---@class ResourceStoredTrigger
---@field teamID TeamID The team whose storage is measured.
---@field metal? Number The stored metal to reach.
---@field energy? Number The stored energy to reach.
---@requiresOneOf metal energy

return {
	type = 'ResourceStored',
	parameters = {
		{ name = 'teamID', required = true,  type = ParameterTypes.TeamID },
		{ name = 'metal',  required = false, type = ParameterTypes.Number },
		{ name = 'energy', required = false, type = ParameterTypes.Number },
		requiresOneOf = { 'metal', 'energy' },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context)
			if trigger.parameters.metal and select(CURRENT_RESOURCE_LEVEL_INDEX, Spring.GetTeamResources(trigger.parameters.teamID, "metal")) < trigger.parameters.metal then
				return
			end
			if trigger.parameters.energy and select(CURRENT_RESOURCE_LEVEL_INDEX, Spring.GetTeamResources(trigger.parameters.teamID, "energy")) < trigger.parameters.energy then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
