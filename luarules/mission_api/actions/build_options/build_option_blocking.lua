-- Greys a build option out for a team, optionally for one builder type only (GG.BuildBlocking, reason 'mission').
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local MISSION_REASON = 'mission'

local function disableBuildOption(builtDefName, builderDefName, teamID)
	local builderUnitDefID = builderDefName and UnitDefNames[builderDefName].id
	GG.BuildBlocking.AddBlockedUnit(UnitDefNames[builtDefName].id, teamID, MISSION_REASON, builderUnitDefID)
end

local function enableBuildOption(builtDefName, builderDefName, teamID)
	local builderUnitDefID = builderDefName and UnitDefNames[builderDefName].id
	GG.BuildBlocking.RemoveBlockedUnit(UnitDefNames[builtDefName].id, teamID, MISSION_REASON, builderUnitDefID)
end

return {
	---Grays out a unit type in the build menus of a team so it cannot be built, either for every builder of the team or for one builder or factory type only.
	---
	---The block applies to the team's current and future builders and stays until EnableBuildOption lifts it.
	---@class DisableBuildOptionAction
	---@field builtDefName UnitDefName The unit type that can no longer be built.
	---@field builderDefName? UnitDefName Limits the block to this builder or factory type.
	---@field teamID TeamID The team whose build menus are affected.
	---@default builderDefName every builder of the team
	{
		type = 'DisableBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = disableBuildOption,
	},
	---Lifts a block placed by DisableBuildOption. The builderDefName must match the one the block was placed with: a team-wide block is lifted only by a team-wide enable.
	---
	---Blocks the game places for its own reasons, such as water or wind restrictions, are not affected.
	---@class EnableBuildOptionAction
	---@field builtDefName UnitDefName The unit type to make buildable again.
	---@field builderDefName? UnitDefName The builder or factory type the block was placed for.
	---@field teamID TeamID The team whose build menus are affected.
	---@default builderDefName every builder of the team
	{
		type = 'EnableBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = enableBuildOption,
	},
}
