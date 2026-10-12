----------------------------------------------------------------
--- Offline loader for the Mission API definition files ---------

-- Definition files run at includeFile time against the engine environment that api_missions.lua
-- builds, so this installs only the parts of it that they read at includeFile time. Every other
-- module is a permissive stand-in, because only ParameterTypes is read for its data.

local ACTIONS_DIR = "luarules/mission_api/actions/"
local TRIGGERS_DIR = "luarules/mission_api/triggers/"
local PARAMETER_TYPES_FILE = "luarules/mission_api/parameter_types.lua"
local UNIT_ATTRIBUTES_FILE = "luarules/gadgets/include/unit_attributes.lua"

local ENV_DAMAGE_TYPES = {
	Debris = -1,
	GroundCollision = -2,
	ObjectCollision = -3,
	Fire = -4,
	Water = -5,
	Killed = -6,
	Crushed = -7,
	AircraftCrashed = -8,
	SetNegativeHealth = -9,
	SelfD = -10,
	KilledByCheat = -11,
	Reclaimed = -12,
	OutOfBounds = -13,
	TransportKilled = -14,
	FactoryKilled = -15,
	FactoryCancel = -16,
	UnitScript = -17,
	Kamikaze = -18,
	ConstructionDecay = -19,
	TurnedIntoFeature = -20,
	KilledByLua = -21,
}

----------------------------------------------------------------
--- Environment ---------------------------------------------------

local function readFile(path)
	local file, message = io.open(path, "rb")
	if not file then
		error("cannot read " .. path .. ": " .. tostring(message), 0)
	end
	local text = file:read("*a")
	file:close()
	return text
end

local function stubFunction()
	return nil
end

-- Any field read yields a function, so a load-time alias of a module function never fails.
local function permissiveTable()
	return setmetatable({}, {
		__index = function()
			return stubFunction
		end,
	})
end

-- Command ids are read into locals and used as table keys, so each name needs its own number.
local function commandTable()
	local nextID = 1000
	return setmetatable({}, {
		__index = function(self, key)
			nextID = nextID + 1
			rawset(self, key, nextID)
			return nextID
		end,
	})
end

local function installGlobals(globals)
	for name, value in pairs(globals) do
		_G[name] = value
	end
end

local function installEnvironment(root, json)
	local function includeFile(path)
		local chunk, message = loadstring(readFile(root .. "/" .. path), "@" .. path)
		if not chunk then
			error("cannot compile " .. path .. ": " .. tostring(message), 0)
		end
		return chunk()
	end

	local spring = permissiveTable()
	spring.Echo = print
	spring.Log = stubFunction

	installGlobals({
		Json = json,
		VFS = {
			Include = includeFile,
			LoadFile = function(path)
				return readFile(root .. "/" .. path)
			end,
			FileExists = function(path)
				local file = io.open(root .. "/" .. path, "rb")
				if file then
					file:close()
				end
				return file ~= nil
			end,
			DirList = function()
				error("VFS.DirList is not available offline; the file list comes from doc.json", 0)
			end,
			SubDirs = function()
				error("VFS.SubDirs is not available offline; the file list comes from doc.json", 0)
			end,
			MAP = 1,
			MOD = 2,
			BASE = 4,
		},
		require = function(path)
			return includeFile(path:gsub("%.lua$", "") .. ".lua")
		end,
		Spring = spring,
		LOG = { ERROR = "ERROR", WARNING = "WARNING", INFO = "INFO", DEBUG = "DEBUG" },
		Game = { gameSpeed = 30, maxUnits = 32000, envDamageTypes = ENV_DAMAGE_TYPES },
		CMD = commandTable(),
		GameCMD = commandTable(),
		UnitDefs = {},
		UnitDefNames = {},
		WeaponDefs = {},
		WeaponDefNames = {},
		FeatureDefs = {},
		FeatureDefNames = {},
		SendToUnsynced = stubFunction,
	})

	local parameterTypes = includeFile(PARAMETER_TYPES_FILE)
	installGlobals({
		GG = {
			MissionAPI = {
				Modules = setmetatable({ ParameterTypes = parameterTypes }, {
					__index = function()
						return permissiveTable()
					end,
				}),
				trackedUnitIDs = {},
				trackedFeatureIDs = {},
			},
		},
	})
	return includeFile, parameterTypes
end

----------------------------------------------------------------
--- Definitions ---------------------------------------------------

local function parameterRows(definition)
	local rows = {}
	for _, parameter in ipairs(definition.parameters or {}) do
		rows[#rows + 1] = { name = parameter.name, required = parameter.required == true, type = parameter.type }
	end
	return rows
end

local function loadActions(includeFile, files)
	local actions = {}
	for _, path in ipairs(files) do
		local category = path:sub(#ACTIONS_DIR + 1):match("^([^/]+)/[^/]+%.lua$")
		if category then
			for _, definition in ipairs(includeFile(path)) do
				if actions[definition.type] then
					error("action type defined twice: " .. definition.type, 0)
				end
				actions[definition.type] = {
					file = path,
					category = category,
					parameters = parameterRows(definition),
					requiresOneOf = (definition.parameters or {}).requiresOneOf,
				}
			end
		end
	end
	return actions
end

local function loadTriggers(includeFile, files)
	local triggers = {}
	for _, path in ipairs(files) do
		if path:match("^" .. TRIGGERS_DIR .. "[^/]+%.lua$") then
			local definition = includeFile(path)
			if triggers[definition.type] then
				error("trigger type defined twice: " .. definition.type, 0)
			end
			triggers[definition.type] = {
				file = path,
				parameters = parameterRows(definition),
				requiresOneOf = (definition.parameters or {}).requiresOneOf,
			}
		end
	end
	return triggers
end

-- A set whose members are all numbered keeps that numbering, as the difficulties do.
local function sortedValues(set, compare)
	local values = {}
	local numbered = true
	for value, rank in pairs(set) do
		values[#values + 1] = value
		numbered = numbered and type(rank) == "number"
	end
	table.sort(values, function(a, b)
		if numbered and set[a] ~= set[b] then
			return set[a] < set[b]
		end
		return compare(a, b)
	end)
	return values
end

local function keyList(definitions)
	local keys = {}
	for key in pairs(definitions) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

-- Enum sets keep their array order; the other enums are keyed sets, which are sorted here.
local function enumValues(includeFile, parameterTypes, compare)
	local values = {}
	for name, items in pairs(parameterTypes.EnumSets) do
		local list = {}
		for index, item in ipairs(items) do
			list[index] = item
		end
		values[name] = list
	end
	for name, set in pairs(parameterTypes.Enums) do
		if not values[name] then
			values[name] = sortedValues(set, compare)
		end
	end
	local types = parameterTypes.Types
	if types.UnitAttribute or types.WeaponAttribute then
		local attributes = includeFile(UNIT_ATTRIBUTES_FILE)
		if types.UnitAttribute then
			values[types.UnitAttribute] = keyList(attributes.UnitAttributeDefinitions)
		end
		if types.WeaponAttribute then
			values[types.WeaponAttribute] = keyList(attributes.WeaponAttributeDefinitions)
		end
	end
	return values
end

----------------------------------------------------------------
--- Exports -------------------------------------------------------

-- `files` lists repository-relative Lua paths; `compare` orders enum values.
return function(root, json, files, compare)
	local includeFile, parameterTypes = installEnvironment(root, json)
	return {
		ParameterTypes = parameterTypes,
		EnumValues = enumValues(includeFile, parameterTypes, compare),
		Actions = loadActions(includeFile, files),
		Triggers = loadTriggers(includeFile, files),
	}
end
