local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Docking drones, hats, and attached turrets raise UnitLoaded as well.
-- A transportName is checked whether it's an actual transport. A transportDefName is not.
-- A transport that dies unloads its passengers in the engine, and BAR (usually) kills them.

---Fires when a transport drops off a passenger. Units undocking from other kinds of units count only when transportDefName names that unit definition, and a destroyed transport drops off its passengers as well.
---@class TransportUnloadedTrigger
---@field transportName? UnitName Only the transport with this name.
---@field transportDefName? UnitDefName Only transports of this unit definition.
---@field teamID? TeamID Only transports owned by this team.
---@field passengerName? UnitName Only the passenger with this name.
---@field passengerDefName? UnitDefName Only passengers of this unit definition.
---@requiresOneOf transportName transportDefName

return {
	type = 'TransportUnloaded',
	parameters = {
		{ name = 'transportName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'transportDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',           required = false, type = ParameterTypes.TeamID },
		{ name = 'passengerName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'passengerDefName', required = false, type = ParameterTypes.UnitDefName },
		requiresOneOf = { 'transportName', 'transportDefName' },
	},
	callins = {
		UnitUnloaded = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, transportID, transportDefID, transportTeam)
			local parameters = trigger.parameters
			if parameters.transportDefName then
				if parameters.transportDefName ~= UnitDefs[transportDefID].name then
					return
				end
			elseif not UnitDefs[transportDefID].isTransport then
				return
			end

			if parameters.transportName and not context.DoesUnitHaveName(transportID, parameters.transportName) then
				return
			end
			if parameters.teamID and parameters.teamID ~= transportTeam then
				return
			end
			if parameters.passengerName and not context.DoesUnitHaveName(unitID, parameters.passengerName) then
				return
			end
			if parameters.passengerDefName and parameters.passengerDefName ~= UnitDefs[unitDefID].name then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
