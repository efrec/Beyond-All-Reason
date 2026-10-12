local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local DetectionLevels = GG['MissionAPI'].Modules.DetectionLevels

-- Fires when a matching unit's detection level falls from the sensor set watched by the trigger.
-- Sensors progress from least to most accurate: unseen -> seismic ping -> in radar -> in vision.

-- Seismic has no engine "left range" event, and radar and vision both report leaving one sensor
-- while another still holds the unit, so the fall is taken against the full "level" rather than
-- against any single callin. Dropping out of vision and into radar is not a detection loss for
-- a trigger that watches both sensor types but stays in the bit set. See detection_levels.lua.

-- Death is not a loss of detection. A killed unit drops from sensor tracking without reporting.

local FIRES_ON_UNDETECTED = false

local function matchesUnit(parameters, context, unitID, unitDefID)
	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
		return false
	end
	if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if parameters.owningTeamID and parameters.owningTeamID ~= Spring.GetUnitTeam(unitID) then
		return false
	end
	return true
end

---Fires when a matching unit drops out of the watched sensors of other ally teams: no longer seen, on radar, or heard by seismic detectors. A unit held by several of the watched sensors is lost only when it leaves all of them, and a destroyed unit does not count as lost.
---@class UnitUndetectedTrigger
---@field unitName? UnitName Only the lost unit with this name.
---@field unitDefName? UnitDefName Only lost units of this unit definition.
---@field owningTeamID? TeamID Only lost units owned by this team.
---@field sensorAllyTeam? AllyTeamID Only loss from this ally team's sensors. When omitted, the sensors of every ally team other than the unit's own count, and Gaia's sensors are excluded.
---@field sensorTypes? SensorTypes The sensors that count: 'vision', 'radar', 'seismic', or any combination. When omitted, every sensor counts.
---@default sensorTypes { 'vision', 'radar', 'seismic' }
---@requiresOneOf unitName unitDefName

return {
	type = 'UnitUndetected',
	parameters = {
		{ name = 'unitName',       required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',    required = false, type = ParameterTypes.UnitDefName },
		{ name = 'owningTeamID',   required = false, type = ParameterTypes.TeamID },
		{ name = 'sensorAllyTeam', required = false, type = ParameterTypes.AllyTeamID },
		{ name = 'sensorTypes',    required = false, type = ParameterTypes.SensorTypes },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- Artificial callin raised once a frame, for units whose sensor state was touched.
		DetectionUpdate = DetectionLevels.NewDetectionUpdate(FIRES_ON_UNDETECTED, matchesUnit),

		UnitDestroyed = function(trigger, triggerID, context, unitID)
			DetectionLevels.Clear(triggerID, unitID)
		end,
	},
}
