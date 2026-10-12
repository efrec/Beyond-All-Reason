-- Adds or removes a build option of a builder or factory type, for its current and future units (GG.DynamicBuildOptions).
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addBuildOption(builtDefName, builderDefName, buildMenuPosition)
	GG.DynamicBuildOptions.Add(UnitDefNames[builtDefName].id, UnitDefNames[builderDefName].id, buildMenuPosition)
end

local function removeBuildOption(builtDefName, builderDefName)
	GG.DynamicBuildOptions.Remove(UnitDefNames[builtDefName].id, UnitDefNames[builderDefName].id)
end

return {
	---Adds a unit type to the build options of a builder or factory type, for its current units and for every unit of that type built later, on every team.
	---@class AddBuildOptionAction
	---@field builtDefName UnitDefName The unit type to add as a build option.
	---@field builderDefName UnitDefName The builder or factory type that receives the option.
	---@field buildMenuPosition? PositiveInteger The slot the option takes among the builder's build options, counted from 1. Build menus that sort their options ignore it.
	---@default buildMenuPosition last
	{
		type = 'AddBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'buildMenuPosition', required = false, type = ParameterTypes.PositiveInteger },
		},
		actionFunction = addBuildOption,
	},
	---Takes a unit type out of the build options of a builder or factory type, for its current units and for every unit of that type built later, on every team. Queued orders to build it are dropped.
	---
	---The option may be one the builder has by default or one added by AddBuildOption.
	---@class RemoveBuildOptionAction
	---@field builtDefName UnitDefName The unit type to remove as a build option.
	---@field builderDefName UnitDefName The builder or factory type that loses the option.
	{
		type = 'RemoveBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = true, type = ParameterTypes.UnitDefName },
		},
		actionFunction = removeBuildOption,
	},
}
