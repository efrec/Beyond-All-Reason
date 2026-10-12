-- Enable/Disable UnitDefs for construction by AI teamID
local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function enableUnitDef(unitDefName, isEnabled, teamID)
	GG["CampaignAI"].SetUnitDefsEnabled({ UnitDefNames[unitDefName].id }, true, teamID)
end

local function disableUnitDef(unitDefName, isEnabled, teamID)
	GG["CampaignAI"].SetUnitDefsEnabled({ UnitDefNames[unitDefName].id }, false, teamID)
end

return {
	---Allows the campaign AI of a team to build a unit type.
	---
	---This only instructs the AI; it does not change which build options exist.
	---@class EnableUnitDefAction
	---@field unitDefName UnitDefName The unit type the AI may build.
	---@field teamID TeamID The AI team that receives the instruction.
	{
		type = "EnableUnitDef",
		parameters = {
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "teamID", required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = enableUnitDef,
	},
	---Stops the campaign AI of a team from building a unit type.
	---
	---This only instructs the AI; the build option itself stays available, so use DisableBuildOption to gray it out as well.
	---@class DisableUnitDefAction
	---@field unitDefName UnitDefName The unit type the AI must not build.
	---@field teamID TeamID The AI team that receives the instruction.
	{
		type = "DisableUnitDef",
		parameters = {
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "teamID", required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = disableUnitDef,
	},
}
