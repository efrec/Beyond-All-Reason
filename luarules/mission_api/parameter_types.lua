---
--- Data types for Mission API action and trigger parameters.
---

----------------------------------------------------------------
--- Parameter type annotations ---------------------------------

-- Lua types

---Any Lua table. The action or trigger that takes it describes its contents.
---@alias Table table
---@panel

---A Lua function. It runs inside the mission with no arguments.
---@alias Function function
---@panel

---A text value.
---@alias String string

---A numeric value, whole or fractional.
---@alias Number number

---A true or false value.
---@alias Boolean boolean

-- Positions, areas, and directions

---A location on the map, in elmos. The height defaults to the terrain height at that point.
---@class Position
---@field x Number The east-west coordinate, in elmos.
---@field z Number The north-south coordinate, in elmos.
---@field y? Number The height, in elmos. Defaults to the terrain height at (x, z).
---@pick point

---A list of at least two map positions, in order.
---@alias Positions Position[]
---@pick points

---A rectangle on the map, in elmos. The first corner must lie west and north of the second, so x1 is less than x2, and z1 is less than z2.
---@class AreaRectangle
---@field x1 Number The west edge, in elmos.
---@field z1 Number The north edge, in elmos.
---@field x2 Number The east edge, in elmos. Must be greater than x1.
---@field z2 Number The south edge, in elmos. Must be greater than z1.

---A circle on the map, in elmos.
---@class AreaCircle
---@field x Number The east-west coordinate of the center, in elmos.
---@field z Number The north-south coordinate of the center, in elmos.
---@field radius Number The radius, in elmos.

---A region of the map, given either as a rectangle or as a circle.
---@alias Area AreaRectangle|AreaCircle
---@pick area

---A heading given as a compass angle in degrees, measured clockwise from north, so 0 faces north, 90 faces east, 180 faces south, and 270 faces west.
---@class DirectionAngle
---@field angle Number The compass angle, in degrees.

---A heading given as a point on the map. The affected units turn to face toward that point.
---@class DirectionVector
---@field x Number The east-west coordinate of the point faced, in elmos.
---@field z Number The north-south coordinate of the point faced, in elmos.
---@field y? Number An optional height, in elmos. Defaults to the terrain height at (x, z).

---The way units face, given either as a compass angle or as a point to face toward, never both.
---@alias Direction DirectionAngle|DirectionVector

-- Orders

---One order for a unit, written as an array: the command, its parameters, and its options.
---The command is a command ID from CMD or GameCMD, or the name of a unit definition to build.
---The parameters depend on the command. Movement and attack commands take three numbers { x, y, z }. Area commands take four numbers { x, y, z, radius }. Build orders take { x, y, z } with an optional facing as a fourth number, or nothing for a factory. Commands that act on a unit or a feature may instead take { unitName = "name" } or { featureName = "name" }, which applies the order to every unit or feature with that name. State commands take a single number.
---The options are an optional list of modifier names: "right", "alt", "ctrl", "shift", or "meta".
---@class Order
---@field [1] integer|string The command: a command ID, or the name of a unit definition to build.
---@field [2]? table The command's parameters: an array of numbers, or a table naming a unit or a feature.
---@field [3]? string[] The order's modifier options, if any.

---A list of at least one order, issued to units in sequence.
---@alias Orders Order[]
---@panel

-- Loadouts

---One group of units to place on the map. One unit is placed at the position, or several copies are arranged in a grid around it.
---@class UnitLoadoutEntry
---@field unitDefName UnitDefName The unit definition to place.
---@field x Number The east-west coordinate of the placement, in elmos.
---@field z Number The north-south coordinate of the placement, in elmos.
---@field y? Number The height, in elmos. Defaults to the terrain height at (x, z).
---@field team TeamID The team that owns the units.
---@field facing? Facing The direction the units face. Defaults to south.
---@field unitName? UnitName A name for the units, so that triggers and actions can refer to them.
---@field construction? Boolean Whether the units are placed unfinished, still to be built.
---@field quantity? Number How many units to place. Defaults to one. Several units are arranged in a grid centered on the position.
---@field spacing? Number Extra distance between units in the grid, in elmos. Defaults to zero.
---@field neutral? Boolean Whether the units are neutral, so that no team attacks them automatically.
---@field orders? Orders Orders given to each unit as soon as it is placed.

---Units to place on the map, as a list of unit groups.
---@alias UnitLoadout UnitLoadoutEntry[]
---@panel

---One feature to place on the map, such as a wreck or a rock.
---@class FeatureLoadoutEntry
---@field featureDefName FeatureDefName The feature definition to place.
---@field x Number The east-west coordinate of the placement, in elmos.
---@field z Number The north-south coordinate of the placement, in elmos.
---@field y? Number Accepted but not used. Features are placed at the terrain height.
---@field facing? Facing The direction the feature faces. Defaults to south.
---@field featureName? FeatureName A name for the feature, so that triggers and actions can refer to it.

---Features to place on the map, as a list of features.
---@alias FeatureLoadout FeatureLoadoutEntry[]
---@panel

-- Enum sets

---The kinds of resource income to count, as a list of names. An empty list counts every kind.
---@alias ResourceIncomeSources string[]

---The kinds of sensor that count as detecting a unit, as a list of names. An empty list counts every kind.
---@alias SensorTypes string[]

-- References declared inside the mission

---The ID of a stage declared in the mission.
---@alias StageID string
---@references mission.stages

---The ID of an objective declared in the mission.
---@alias ObjectiveID string
---@references mission.objectives

---The ID of a countdown. A countdown exists once an action adds it.
---@alias CountdownID string
---@references mission.countdowns

---The ID of a trigger declared in the mission.
---@alias TriggerID string
---@references mission.triggers

---A name given to one or more units by the mission. Units get names when they are placed by a loadout, spawned by an action, or named by an action.
---@alias UnitName string
---@references mission.unitNames

---A name given to one or more features by the mission. Features get names when they are placed by a loadout or created by an action.
---@alias FeatureName string
---@references mission.featureNames

-- References to game data

---The internal name of a unit definition, such as "armcom".
---@alias UnitDefName string
---@references engine.UnitDefNames

---The internal name of a feature definition, such as "armcom_dead".
---@alias FeatureDefName string
---@references engine.FeatureDefNames

---The internal name of a weapon definition.
---@alias WeaponDefName string
---@references engine.WeaponDefNames

---The path of a .wav sound file inside the game's or the map's files.
---@alias SoundFile string
---@references engine.VFS

---The ID of a team in the game.
---@alias TeamID integer
---@references engine.Teams

---The ID of an ally team in the game.
---@alias AllyTeamID integer
---@references engine.AllyTeams

---A list of at least one ally team ID.
---@alias AllyTeamIDs AllyTeamID[]

-- Enums

---The direction a placed unit or feature faces. It is written as a compass letter, a compass word, or a number. The numbers start at south and go counterclockwise.
---@alias Facing integer|string

---The name of a difficulty, as defined in difficulties.json. Higher difficulty values are harder.
---@alias Difficulty string

---The kind of a message shown to the player, which decides how the message is presented.
---@alias MessageType string

-- Numbers

---A count or an amount that is zero or more.
---@alias Quantity number
---@bounds 0

---A whole number greater than zero.
---@alias PositiveInteger integer
---@bounds 1

---A proportion between zero and one, inclusive.
---@alias Fraction number
---@bounds 0 1

--- Commands

---A command that units can receive: a command ID from CMD or GameCMD, or the name of a unit definition, which stands for the order to build that unit. CMD.ANY matches every command, and CMD.BUILD matches every build order.
---@alias Command integer|string
---@panel

local types = {

	-- Table Validators:
	Table = "Table",
	Position = "Position",
	Positions = "Positions",
	AllyTeamIDs = "AllyTeamIDs",
	Orders = "Orders",
	Area = "Area",
	Direction = "Direction",
	UnitLoadout = "UnitLoadout",
	FeatureLoadout = "FeatureLoadout",
	ResourceIncomeSources = "ResourceIncomeSources",
	SensorTypes = "SensorTypes",

	-- String Validators:
	String = "String",
	StageID = "StageID",
	ObjectiveID = "ObjectiveID",
	CountdownID = "CountdownID",
	TriggerID = "TriggerID",
	UnitName = "UnitName",
	FeatureName = "FeatureName",
	UnitDefName = "UnitDefName",
	FeatureDefName = "FeatureDefName",
	WeaponDefName = "WeaponDefName",
	Facing = "Facing",
	SoundFile = "SoundFile",
	Difficulty = "Difficulty",

	-- Number Validators:
	Number = "Number",
	Quantity = "Quantity",
	PositiveInteger = "PositiveInteger",
	Fraction = "Fraction",
	TeamID = "TeamID",
	AllyTeamID = "AllyTeamID",
	MessageType = "MessageType",

	-- Boolean Validators:
	Boolean = "Boolean",

	-- Function Validators:
	Function = "Function",

	-- Number-or-String Validators:
	Command = "Command",

}

-- Difficulties are read by the client, so must be available in JSON
local difficultiesJSON = VFS.LoadFile("luarules/mission_api/difficulties.json")
local difficulties = Json.decode(difficultiesJSON)

local enums = {
	[types.Facing] = {
		[0] = true,
		[1] = true,
		[2] = true,
		[3] = true,
		n = true,
		s = true,
		e = true,
		w = true,
		north = true,
		south = true,
		east = true,
		west = true,
	},

	[types.Difficulty] = difficulties,

	[types.MessageType] = {
		Briefing = 1,
		Message = 2,
		Objective = 3,
		Notification = 4,
		Dialogue = 5,
	},
}

local enumSets = {
	[types.ResourceIncomeSources] = { "extractor", "production", "reclaim", "transfer" },
	[types.SensorTypes] = { "vision", "radar", "seismic" },
}

for enumSetName, enumSetValues in pairs(enumSets) do
	local valueSet = {}
	for _, value in ipairs(enumSetValues) do
		valueSet[value] = true
	end
	enums[enumSetName] = valueSet
end

return {
	Types = types,
	Enums = enums,
	EnumSets = enumSets,
}
