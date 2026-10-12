-- Enable/Disable AI's direct control over its units
local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
local tracking = GG["MissionAPI"].Modules.Tracking
local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs

local function collectUnitIDs(unitName)
	if tracking.IsUnitNameUntracked(unitName) then
		return false
	end

	local unitIDs = {}
	for id in pairs(trackedUnitIDs[unitName]) do
		table.insert(unitIDs, id)
	end
	return unitIDs
end

local function enableUnitsControl(unitName, teamID)
	local unitIDs = collectUnitIDs(unitName)
	if not unitIDs then
		return
	end
	GG["CampaignAI"].SetUnitsCtrlEnabled(unitIDs, true, teamID)
end

local function disableUnitsControl(unitName, teamID)
	local unitIDs = collectUnitIDs(unitName)
	if not unitIDs then
		return
	end
	GG["CampaignAI"].SetUnitsCtrlEnabled(unitIDs, false, teamID)
end

return {
	---Tells the campaign AI of a team that it may control the units carrying a mission unit name.
	---
	---Only units that exist when the action runs are affected.
	---@class EnableUnitsControlAction
	---@field unitName UnitName The mission unit name of the units to hand to the AI.
	---@field teamID TeamID The AI team that receives the instruction.
	{
		type = "EnableUnitsControl",
		parameters = {
			{ name = "unitName", required = true, type = ParameterTypes.UnitName },
			{ name = "teamID", required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = enableUnitsControl,
	},
	---Tells the campaign AI of a team to leave alone the units carrying a mission unit name.
	---
	---Only units that exist when the action runs are affected.
	---@class DisableUnitsControlAction
	---@field unitName UnitName The mission unit name of the units to take from the AI.
	---@field teamID TeamID The AI team that receives the instruction.
	{
		type = "DisableUnitsControl",
		parameters = {
			{ name = "unitName", required = true, type = ParameterTypes.UnitName },
			{ name = "teamID", required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = disableUnitsControl,
	},
}
