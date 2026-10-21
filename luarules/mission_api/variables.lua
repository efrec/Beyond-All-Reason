---
--- Mission variables, and the parameters that read them.
---
--- Parameters and fields in mission scripts can receive values like { variable = <key> }, including
--- inside table parameters. Such a field holds its variable's resolved value, which is refreshed
--- just before the trigger, action, or objective is used, so writing a variable is a plain
--- assignment. An unset variable reads as nil, like an omitted field. References resolve after
--- difficulties do (so cannot use difficulty as a name).
---

local objectiveFields = VFS.Include("luarules/mission_api/objectives_schema.lua").Settings

-- Each table with fields that reference variables, by table, as a list of
-- { field = <name>, raw = <value>, type = <parameter type>, seen = { [key] = <value last resolved> } }.
local lookupsByTable = {}
local processValue ---@type fun(parameterType:string, value:any):any

-- Stands in for nil in `seen`, so an unset variable that gets set still counts as a change.
local UNSET = {}

local function isVariableReference(value)
	return type(value) == "table" and value.variable ~= nil
end

local function hasVariableReference(value)
	if type(value) ~= "table" then
		return false
	elseif isVariableReference(value) then
		return true
	end
	for _, nested in pairs(value) do
		if hasVariableReference(nested) then
			return true
		end
	end
	return false
end

local function callOnVariableKeys(value, func)
	if isVariableReference(value) then
		func(value.variable)
	elseif type(value) == "table" then
		for _, nested in pairs(value) do
			callOnVariableKeys(nested, func)
		end
	end
end

local function resolveValue(value)
	if isVariableReference(value) then
		local variableValue = GG["MissionAPI"].Variables[value.variable]
		return type(variableValue) == "table" and table.copy(variableValue) or variableValue
	elseif type(value) ~= "table" then
		return value
	end
	local resolved = {}
	for key, nested in pairs(value) do
		resolved[key] = resolveValue(nested)
	end
	return resolved
end

--- Like resolveValue for validation. Returns `false` when any referenced variable is unset.
local function substituteKnownValues(value)
	if isVariableReference(value) then
		local variableValue = GG["MissionAPI"].Variables[value.variable]
		return variableValue, variableValue ~= nil
	elseif type(value) ~= "table" then
		return value, true
	end
	local substituted, areKnown = {}, true
	for key, nested in pairs(value) do
		local nestedValue, nestedKnown = substituteKnownValues(nested)
		substituted[key] = nestedValue
		areKnown = areKnown and nestedKnown
	end
	return substituted, areKnown
end

-- Whether any variable the lookup reads has a different value from when it last resolved.
local function hasChanged(lookup, variables)
	local changed = false
	for key, seen in pairs(lookup.seen) do
		local current = variables[key]
		if current == nil then
			current = UNSET
		end
		if current ~= seen then
			lookup.seen[key] = current
			changed = true
		end
	end
	return changed
end

--- Brings each field that references a variable up to date, so the caller reads plain values. A
--- table variable is compared by identity, so changing one means writing a new table.
local function refreshLookups(values)
	local fieldLookups = lookupsByTable[values]
	if fieldLookups == nil then
		return
	end
	local variables = GG["MissionAPI"].Variables
	for i = 1, #fieldLookups do
		local lookup = fieldLookups[i]
		if hasChanged(lookup, variables) then
			local value = resolveValue(lookup.raw)
			if value ~= nil and lookup.type ~= nil then
				value = processValue(lookup.type, value)
			end
			values[lookup.field] = value
		end
	end
end

--- Records each listed field that references a variable and resolves it.
---@param fields table<string, string|false> each field to check, with its parameter type or false
local function addLookups(values, fields)
	if values == nil or lookupsByTable[values] ~= nil then
		return
	end
	local fieldLookups
	for field, fieldType in pairs(fields) do
		local value = values[field]
		if hasVariableReference(value) then
			local lookup = { field = field, raw = value, type = fieldType or nil, seen = {} }
			callOnVariableKeys(value, function(key)
				lookup.seen[key] = false -- never equal to a value or to UNSET, so the first refresh resolves
			end)
			fieldLookups = fieldLookups or {}
			fieldLookups[#fieldLookups + 1] = lookup
		end
	end
	if fieldLookups ~= nil then
		lookupsByTable[values] = fieldLookups
		refreshLookups(values)
	end
end

local function addParameterLookups(parameters, schema)
	local fields = {}
	for _, parameter in ipairs(schema or {}) do
		fields[parameter.name] = parameter.type
	end
	addLookups(parameters, fields)
end

--- Whether the field reads a variable, which may be unset when this is asked.
local function hasLookup(values, field)
	for _, lookup in ipairs(lookupsByTable[values] or {}) do
		if lookup.field == field then
			return true
		end
	end
	return false
end

--- Gives every reference in triggers, actions, and objectives a lookup, after difficulties
--- and parameter processing. processValue(parameterType, value) processes each value it resolves.
local function addAllLookups(triggers, actions, objectives, processParameterValue)
	processValue = processParameterValue

	local triggerSchema = GG["MissionAPI"].TriggerDefinitions.Parameters
	for _, trigger in pairs(triggers) do
		addParameterLookups(trigger.parameters, triggerSchema[trigger.type])
	end
	local actionSchema = GG["MissionAPI"].ActionDefinitions.Parameters
	for _, action in pairs(actions) do
		addParameterLookups(action.parameters, actionSchema[action.type])
	end

	local fields = {}
	for field in pairs(objectiveFields) do
		if field ~= "trigger" then
			fields[field] = false
		end
	end
	for _, objective in pairs(objectives) do
		if type(objective.trigger) == "table" then
			addParameterLookups(objective.trigger.parameters, triggerSchema[objective.trigger.type])
		end
		addLookups(objective, fields)
	end
	for _, managedObjectives in pairs(GG["MissionAPI"].ManagedObjectives) do
		for _, metadata in ipairs(managedObjectives) do
			addLookups(metadata, { amount = false, nextStage = false })
		end
	end
end

return {
	IsVariableReference = isVariableReference,
	HasVariableReference = hasVariableReference,
	CallOnVariableKeys = callOnVariableKeys,
	SubstituteKnownValues = substituteKnownValues,
	AddLookups = addAllLookups,
	HasLookup = hasLookup,
	RefreshLookups = refreshLookups,
}
