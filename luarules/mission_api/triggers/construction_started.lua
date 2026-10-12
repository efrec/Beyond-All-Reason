local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function matchesBuild(trigger, context, unitDefID, unitTeam, builderID)
	local parameters = trigger.parameters
	if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if parameters.teamID and unitTeam ~= parameters.teamID then
		return false
	end
	if parameters.builderName and not context.DoesUnitHaveName(builderID, parameters.builderName) then
		return false
	end
	if parameters.builderDefName and parameters.builderDefName ~= UnitDefs[Spring.GetUnitDefID(builderID)].name then
		return false
	end
	return true
end

-- ConstructionStarted activates once per buildee: on its own build frame, or on the first
-- build-assist the filters take. Only an activation that goes through claims the buildee.
local function startConstruction(trigger, triggerID, context, buildeeID)
	if not context.HasConstructionStarted(buildeeID, triggerID) and context.ActivateTrigger(trigger) then
		context.ClaimConstructionStart(buildeeID, triggerID)
	end
end

---Fires when a unit of the given definition starts being built, either as a new build frame or when the first builder matching the filters assists an existing one. Each unit under construction fires the trigger at most once, and units spawned by the mission while under construction count as started.
---@class ConstructionStartedTrigger
---@field unitDefName UnitDefName The unit definition being built.
---@field teamID? TeamID Only units under construction owned by this team.
---@field builderName? UnitName Only construction by the builder with this name.
---@field builderDefName? UnitDefName Only construction by builders of this unit definition.

return {
	type = 'ConstructionStarted',
	parameters = {
		{ name = 'unitDefName',    required = true,  type = ParameterTypes.UnitDefName },
		{ name = 'teamID',         required = false, type = ParameterTypes.TeamID },
		{ name = 'builderName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
	},
	callins = {
		UnitCreated = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, builderID)
			-- Catch for spawned units and resurrected units. Unit loadouts can include in-progress constructions.
			if not (builderID or GG['MissionAPI'].spawnedUnitIsBeingBuilt) or not Spring.GetUnitIsBeingBuilt(unitID) then
				return
			end
			if not matchesBuild(trigger, context, unitDefID, unitTeam, builderID) then
				return
			end
			startConstruction(trigger, triggerID, context, unitID)
		end,
		-- The triggers gadget resolves matching build placements into potential trigger subjects.
		BuildAssisted = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, builderID)
			if not matchesBuild(trigger, context, unitDefID, unitTeam, builderID) then
				return
			end
			startConstruction(trigger, triggerID, context, unitID)
		end,
	},
}
