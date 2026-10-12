----------------------------------------------------------------
--- Mission API catalog exporter --------------------------------

-- Normalizes the emmylua_doc_cli JSON export of luarules/mission_api into mission_api.json.
-- Run from the repository root:
--   lua tools/mission_api/export_catalog.lua --doc <doc.json> --root <repo> --out <mission_api.json> [--game-version <text>]

local USAGE =
	"usage: export_catalog.lua --doc <doc.json> --root <repo root> --out <mission_api.json> [--game-version <text>]"

local FORMAT_VERSION = 1

local PARAMETER_TYPES_FILE = "luarules/mission_api/parameter_types.lua"
local MISSION_FORMAT_FILE = "luarules/mission_api/mission_format.lua"
local ACTIONS_PATTERN = "^luarules/mission_api/actions/([^/]+)/[^/]+%.lua$"
local TRIGGERS_PATTERN = "^luarules/mission_api/triggers/[^/]+%.lua$"

---@type table<string, string?>
local SCALAR_JSON_TYPES = {
	string = "string",
	integer = "integer",
	number = "number",
	boolean = "boolean",
	table = "object",
	["function"] = "function",
}

local here = (arg and arg[0] and arg[0]:match("^(.*)[/\\]")) or "."
local util = dofile(here .. "/catalog_util.lua") ---@type table
local loadDefinitions = dofile(here .. "/load_definitions.lua") ---@type fun(root: string, json: table, files: string[], compare: function): table

----------------------------------------------------------------
--- Reading the doc export ----------------------------------------

local function text(value)
	return util.trim(value or "")
end

local function locationOf(entry, root)
	local loc = entry.loc
	if type(loc) == "table" and loc[1] then
		loc = loc[1]
	end
	if type(loc) ~= "table" or not loc.file then
		return nil, 0
	end
	return util.relativePath(loc.file, root), loc.line or 0
end

local root ---@type string
local sourceLines = {}
local aliasNames = {}

local function sourceLine(file, line)
	if not file or not line or line < 1 then
		return nil
	end
	local lines = sourceLines[file]
	if not lines then
		lines = {}
		for item in (util.readFile(util.joinPath(root, file)) .. "\n"):gmatch("(.-)\r?\n") do
			lines[#lines + 1] = item
		end
		sourceLines[file] = lines
	end
	return lines[line]
end

-- doc_cli prints union members in no fixed order, so unions are compared and emitted sorted.
local function normalizeUnion(typ)
	local inner = typ:match("^%((.*)%)$")
	if not inner then
		return typ
	end
	local members = {}
	for member in inner:gmatch("[^|]+") do
		members[#members + 1] = util.trim(member)
	end
	table.sort(members)
	return "(" .. table.concat(members, "|") .. ")"
end

-- doc_cli inlines a union alias into the field type, and cuts the union short past six members, so
-- the type name is read back from the annotation when the field names a type by a bare identifier.
local function fieldType(member)
	local typ = member.typ or ""
	local optional = typ:sub(-1) == "?"
	if optional then
		typ = typ:sub(1, -2)
	end
	typ = normalizeUnion(typ)
	local file, line = locationOf(member, root)
	local source = sourceLine(file, line)
	if source then
		local name, mark, token = source:match("^%s*%-%-%-%s*@field%s+([%w_]+)(%??)%s+([%w_]+)%s*$")
		if not name then
			name, mark, token = source:match("^%s*%-%-%-%s*@field%s+([%w_]+)(%??)%s+([%w_]+)%s")
		end
		if name == member.name then
			return token, mark ~= "?"
		end
	end
	return aliasNames[typ] or typ, not optional
end

local function fieldsOf(entry)
	local fields = {}
	for _, member in ipairs(entry.members or {}) do
		if member.type == "field" then
			local typ, required = fieldType(member)
			fields[#fields + 1] = {
				name = member.name,
				type = typ,
				required = required,
				description = text(member.description),
				line = member.loc and member.loc.line or 0,
			}
		end
	end
	table.sort(fields, function(a, b)
		if a.line ~= b.line then
			return a.line < b.line
		end
		return a.name < b.name
	end)
	for _, field in ipairs(fields) do
		field.line = nil
	end
	return fields
end

local function tagsOf(entry)
	local tags = {}
	for _, tag in ipairs(entry.tag_content or {}) do
		tags[#tags + 1] = { name = tag.tag_name, content = text(tag.content) }
	end
	return tags
end

local function addCommon(output, entry)
	if entry.deprecated then
		output.deprecated = true
		local reason = text(entry.deprecation_reason)
		if reason ~= "" then
			output.deprecationReason = reason
		end
	end
	for _, tag in ipairs(tagsOf(entry)) do
		if tag.name == "see" and tag.content ~= "" then
			output.see = output.see or util.array()
			output.see[#output.see + 1] = tag.content
		end
	end
end

----------------------------------------------------------------
--- Actions and triggers ------------------------------------------

local function definitionEntry(entry)
	local parameters = util.array()
	local byName = {}
	for _, field in ipairs(fieldsOf(entry)) do
		parameters[#parameters + 1] = field
		byName[field.name] = field
	end

	local output = {
		description = text(entry.description),
		parameters = parameters,
		requiresOneOf = util.array(),
		declares = util.array(),
	}
	addCommon(output, entry)

	for _, tag in ipairs(tagsOf(entry)) do
		if tag.name == "default" then
			local name, value = tag.content:match("^(%S+)%s*(.*)$")
			if not name then
				error(entry.name .. ": @default needs a parameter name", 0)
			end
			if not byName[name] then
				error(entry.name .. ": @default names an unknown parameter " .. name, 0)
			end
			byName[name].default = value
		elseif tag.name == "requiresOneOf" then
			for _, name in ipairs(util.splitWords(tag.content)) do
				output.requiresOneOf[#output.requiresOneOf + 1] = name
			end
		elseif tag.name == "declares" then
			if tag.content == "" then
				error(entry.name .. ": @declares needs a parameter name", 0)
			end
			output.declares[#output.declares + 1] = tag.content
		elseif tag.name == "unavailable" then
			output.available = false
			output.unavailableReason = tag.content
		end
	end
	return output
end

----------------------------------------------------------------
--- Parameter types -----------------------------------------------

local function unionMembers(typ)
	local inner = typ:match("^%((.*)%)$") or typ
	local members = {}
	for member in inner:gmatch("[^|]+") do
		members[#members + 1] = util.trim(member)
	end
	return members
end

local function literalValue(member)
	local quoted = member:match('^"(.*)"$') or member:match("^'(.*)'$")
	if quoted then
		return quoted
	end
	if member:match("^%-?%d+$") or member:match("^%-?%d+%.%d+$") then
		return tonumber(member), member
	end
	return nil
end

local function enumValueRows(values)
	local rows = util.array()
	for _, value in ipairs(values) do
		local row = { value = value, label = tostring(value) }
		if type(value) == "number" and value ~= math.floor(value) then
			row.value = util.rawNumber(tostring(value))
		end
		rows[#rows + 1] = row
	end
	return rows
end

---@return table?
local function literalEnumRows(members)
	local values, literals = {}, {}
	for _, member in ipairs(members) do
		local value, literal = literalValue(member)
		if value == nil then
			return nil
		end
		values[#values + 1] = value
		literals[value] = literal
	end
	table.sort(values, util.compareValues)
	local rows = util.array()
	for _, value in ipairs(values) do
		local row = { value = value, label = tostring(value) }
		if type(value) == "number" and value ~= math.floor(value) then
			row.value = util.rawNumber(literals[value])
		end
		rows[#rows + 1] = row
	end
	return rows
end

local function aliasKind(output, typ, knownTypes, name)
	local itemType = typ:match("^([%w_]+)%[%]$")
	if itemType then
		if not SCALAR_JSON_TYPES[itemType] and not knownTypes[itemType] then
			error(name .. ": cannot classify the list item type " .. itemType, 0)
		end
		output.kind = "list"
		output.itemType = SCALAR_JSON_TYPES[itemType] or itemType
		return
	end

	local members = unionMembers(typ)
	local rows = literalEnumRows(members)
	if rows then
		output.kind = "enum"
		output.values = rows
		return
	end

	local scalars, references = {}, {}
	for _, member in ipairs(members) do
		if SCALAR_JSON_TYPES[member] then
			scalars[#scalars + 1] = SCALAR_JSON_TYPES[member]
		elseif knownTypes[member] then
			references[#references + 1] = member
		else
			error(name .. ": cannot classify the alias member " .. member .. " in " .. typ, 0)
		end
	end
	if #scalars == #members then
		table.sort(scalars)
		output.kind = "scalar"
		output.jsonType = #scalars == 1 and scalars[1] or util.array(scalars)
	elseif #references == #members then
		table.sort(references)
		output.kind = "union"
		output.oneOf = util.array(references)
	else
		error(name .. ": an alias mixes scalars and types in " .. typ, 0)
	end
end

local function typeEntry(entry, knownTypes, enumValues)
	local output = { description = text(entry.description) } ---@type table<string, any>
	addCommon(output, entry)

	if entry.type == "class" then
		output.kind = "record"
		output.fields = util.array(fieldsOf(entry))
	elseif entry.type == "alias" then
		aliasKind(output, entry.typ or "", knownTypes, entry.name)
	elseif entry.type == "enum" then
		output.kind = "enum"
	else
		error(entry.name .. ": unsupported type kind " .. tostring(entry.type), 0)
	end

	if enumValues[entry.name] then
		output.kind = "enum"
		output.values = enumValueRows(enumValues[entry.name])
		output.fields, output.oneOf = nil, nil
		if output.itemType then
			output.multiple = true
			output.jsonType, output.itemType = output.itemType, nil
		end
	elseif output.kind == "enum" and not output.values then
		error(entry.name .. ": no values are defined for the enum", 0)
	end

	for _, tag in ipairs(tagsOf(entry)) do
		if tag.name == "bounds" then
			local words = util.splitWords(tag.content)
			if #words == 0 or #words > 2 then
				error(entry.name .. ": @bounds takes one or two numbers", 0)
			end
			output.bounds = { min = util.rawNumber(words[1]) }
			if words[2] then
				output.bounds.max = util.rawNumber(words[2])
			end
		elseif tag.name == "references" then
			if not tag.content:match("^mission%.%w+$") and not tag.content:match("^engine%.%w+$") then
				error(entry.name .. ": @references must name mission.<domain> or engine.<Table>", 0)
			end
			output.kind = "reference"
			output.references = tag.content
		elseif tag.name == "pick" then
			if tag.content ~= "point" and tag.content ~= "points" and tag.content ~= "area" then
				error(entry.name .. ": @pick must be point, points, or area", 0)
			end
			output.pick = tag.content
		elseif tag.name == "panel" then
			output.panel = true
		end
	end
	return output
end

local function missionEntry(entry)
	local output = {
		description = text(entry.description),
		fields = util.array(fieldsOf(entry)),
	}
	addCommon(output, entry)
	return output
end

----------------------------------------------------------------
--- Main ----------------------------------------------------------

local options = util.parseArgs(arg, USAGE)
util.requireArgs(options, { "doc", "root", "out" }, USAGE)

root = util.normalizePath(options.root):gsub("/+$", "")
local json = util.loadJsonModule(root)
local doc = json.decode(util.readFile(options.doc))

local files = {}
for _, module in ipairs(doc.modules or {}) do
	local relative = util.relativePath(module.file or "", root)
	if relative then
		files[#files + 1] = relative
	end
end
table.sort(files)

local definitions = loadDefinitions(root, json, files, util.compareValues)

local catalog = {
	formatVersion = FORMAT_VERSION,
	gameVersion = options["game-version"] or "unknown",
	types = {},
	actions = {},
	triggers = {},
	mission = {},
}

local knownTypes = {}
local typeEntries = {}
for _, entry in ipairs(doc.types or {}) do
	local file = locationOf(entry, root)
	if file == PARAMETER_TYPES_FILE then
		knownTypes[entry.name] = true
		typeEntries[#typeEntries + 1] = entry
	end
end
table.sort(typeEntries, function(a, b)
	return a.name < b.name
end)
-- Only a union of named types is mapped back to its alias; a scalar union on a field stays as written.
for _, entry in ipairs(typeEntries) do
	if entry.type == "alias" and entry.typ and entry.typ:match("^%(.*%)$") then
		local union = normalizeUnion(entry.typ)
		local named = true
		for _, member in ipairs(unionMembers(union)) do
			named = named and knownTypes[member] == true
		end
		if named then
			aliasNames[union] = aliasNames[union] == nil and entry.name or false
		end
	end
end

for _, entry in ipairs(typeEntries) do
	if catalog.types[entry.name] then
		error("type annotated twice: " .. entry.name, 0)
	end
	catalog.types[entry.name] = typeEntry(entry, knownTypes, definitions.EnumValues)
end

for _, entry in ipairs(doc.types or {}) do
	local file = locationOf(entry, root)
	if entry.type == "class" and file then
		local category = file:match(ACTIONS_PATTERN)
		local typeName
		if category and entry.name:match("Action$") then
			typeName = entry.name:sub(1, -7)
			if catalog.actions[typeName] then
				error("action annotated twice: " .. typeName, 0)
			end
			local output = definitionEntry(entry)
			output.category = category
			catalog.actions[typeName] = output
		elseif file:match(TRIGGERS_PATTERN) and entry.name:match("Trigger$") then
			typeName = entry.name:sub(1, -8)
			if catalog.triggers[typeName] then
				error("trigger annotated twice: " .. typeName, 0)
			end
			catalog.triggers[typeName] = definitionEntry(entry)
		elseif file == MISSION_FORMAT_FILE then
			catalog.mission[entry.name] = missionEntry(entry)
		end
	end
end

util.writeFile(options.out, util.encodeSortedJson(catalog))

local counts = { types = 0, actions = 0, triggers = 0, mission = 0 }
for section in pairs(counts) do
	for _ in pairs(catalog[section]) do
		counts[section] = counts[section] + 1
	end
end
print(
	string.format(
		"wrote %s: %d types, %d actions, %d triggers, %d mission classes",
		options.out,
		counts.types,
		counts.actions,
		counts.triggers,
		counts.mission
	)
)
