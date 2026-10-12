----------------------------------------------------------------
--- Mission API catalog consistency check -----------------------

-- Compares mission_api.json against the definition files loaded offline and exits non-zero
-- when they disagree. Run from the repository root:
--   lua tools/mission_api/check_catalog.lua --catalog <mission_api.json> --doc <doc.json> --root <repo>

local USAGE = "usage: check_catalog.lua --catalog <mission_api.json> --doc <doc.json> --root <repo root>"

local ACTIONS_PATTERN = "^luarules/mission_api/actions/[^/]+/[^/]+%.lua$"
local TRIGGERS_PATTERN = "^luarules/mission_api/triggers/[^/]+%.lua$"

local here = (arg and arg[0] and arg[0]:match("^(.*)[/\\]")) or "."
local util = dofile(here .. "/catalog_util.lua") ---@type table
local loadDefinitions = dofile(here .. "/load_definitions.lua") ---@type fun(root: string, json: table, files: string[], compare: function): table

local problems = {}

local function report(format, ...)
	problems[#problems + 1] = string.format(format, ...)
end

----------------------------------------------------------------
--- Comparisons -------------------------------------------------

local function sortedCopy(list)
	local copy = {}
	for index, item in ipairs(list or {}) do
		copy[index] = item
	end
	table.sort(copy)
	return copy
end

local function sameList(a, b)
	if #a ~= #b then
		return false
	end
	for index = 1, #a do
		if a[index] ~= b[index] then
			return false
		end
	end
	return true
end

local function compareParameters(label, definition, entry, types)
	local rows = definition.parameters
	local parameters = entry.parameters or {}
	local count = math.max(#rows, #parameters)
	for index = 1, count do
		local row, parameter = rows[index], parameters[index]
		if not row then
			report("%s: annotated field %d (%s) has no parameter row", label, index, parameter.name)
		elseif not parameter then
			report("%s: parameter %d (%s) is not annotated", label, index, row.name)
		else
			if row.name ~= parameter.name then
				report(
					"%s: parameter %d is %s in the definition and %s in the annotation",
					label,
					index,
					row.name,
					parameter.name
				)
			end
			if row.required ~= parameter.required then
				report(
					"%s.%s: required is %s in the definition and %s in the annotation",
					label,
					row.name,
					tostring(row.required),
					tostring(parameter.required)
				)
			end
			if row.type ~= parameter.type then
				report(
					"%s.%s: type is %s in the definition and %s in the annotation",
					label,
					row.name,
					tostring(row.type),
					tostring(parameter.type)
				)
			end
			if not types[parameter.type] then
				report("%s.%s: the annotated type %s is not a catalog type", label, row.name, tostring(parameter.type))
			end
		end
	end

	if not sameList(sortedCopy(definition.requiresOneOf), sortedCopy(entry.requiresOneOf)) then
		report(
			"%s: requiresOneOf is {%s} in the definition and {%s} in the annotation",
			label,
			table.concat(sortedCopy(definition.requiresOneOf), ", "),
			table.concat(sortedCopy(entry.requiresOneOf), ", ")
		)
	end

	local names = {}
	for _, parameter in ipairs(parameters) do
		names[parameter.name] = true
	end
	for _, name in ipairs(entry.declares or {}) do
		if not names[name] then
			report("%s: @declares names an unknown parameter %s", label, name)
		end
	end
	for _, name in ipairs(entry.requiresOneOf or {}) do
		if not names[name] then
			report("%s: @requiresOneOf names an unknown parameter %s", label, name)
		end
	end
end

local function compareSection(section, definitions, entries, types)
	for _, name in ipairs(util.sortedKeys(definitions)) do
		local entry = entries[name]
		if not entry then
			report("%s %s (%s) has no annotated class", section, name, definitions[name].file)
		else
			compareParameters(section .. " " .. name, definitions[name], entry, types)
			if entry.category and entry.category ~= definitions[name].category then
				report(
					"%s %s: category is %s in the tree and %s in the catalog",
					section,
					name,
					definitions[name].category,
					entry.category
				)
			end
		end
	end
	for _, name in ipairs(util.sortedKeys(entries)) do
		if not definitions[name] then
			report("%s %s is annotated but has no definition", section, name)
		end
	end
end

local function compareEnum(name, expected, entry)
	local actual = {}
	for index, row in ipairs(entry.values or {}) do
		actual[index] = row.value
	end
	if #actual ~= #expected then
		report("type %s: %d enum values are exported and %d are defined", name, #actual, #expected)
		return
	end
	for index = 1, #expected do
		if actual[index] ~= expected[index] then
			report(
				"type %s: enum value %d is %s in the catalog and %s in the definition",
				name,
				index,
				tostring(actual[index]),
				tostring(expected[index])
			)
		end
	end
end

local function compareTypes(definitions, types)
	for _, name in ipairs(util.sortedKeys(definitions.ParameterTypes.Types)) do
		if not types[name] then
			report("type %s has no annotation in parameter_types.lua", name)
		end
	end
	for name, values in pairs(definitions.EnumValues) do
		if types[name] then
			if types[name].kind ~= "enum" then
				report(
					"type %s is an enum in the definitions but kind %s in the catalog",
					name,
					tostring(types[name].kind)
				)
			else
				compareEnum(name, values, types[name])
			end
		end
	end
end

local function checkClassNames(doc, root, definitions)
	for _, entry in ipairs(doc.types or {}) do
		local loc = entry.loc and entry.loc[1]
		local file = loc and util.relativePath(loc.file or "", root)
		if entry.type == "class" and file then
			if file:match(ACTIONS_PATTERN) then
				local typeName = entry.name:match("^(.+)Action$")
				if not typeName or not definitions.Actions[typeName] then
					report("class %s in %s does not name an action definition", entry.name, file)
				end
			elseif file:match(TRIGGERS_PATTERN) then
				local typeName = entry.name:match("^(.+)Trigger$")
				if not typeName or not definitions.Triggers[typeName] then
					report("class %s in %s does not name a trigger definition", entry.name, file)
				end
			end
		end
	end
end

----------------------------------------------------------------
--- Main ----------------------------------------------------------

local options = util.parseArgs(arg, USAGE)
util.requireArgs(options, { "catalog", "doc", "root" }, USAGE)

local root = util.normalizePath(options.root):gsub("/+$", "")
local json = util.loadJsonModule(root)
local doc = json.decode(util.readFile(options.doc))
local catalog = json.decode(util.readFile(options.catalog))

local files = {}
for _, module in ipairs(doc.modules or {}) do
	local relative = util.relativePath(module.file or "", root)
	if relative then
		files[#files + 1] = relative
	end
end
table.sort(files)

local definitions = loadDefinitions(root, json, files, util.compareValues)
local types = catalog.types or {}

compareSection("action", definitions.Actions, catalog.actions or {}, types)
compareSection("trigger", definitions.Triggers, catalog.triggers or {}, types)
compareTypes(definitions, types)
checkClassNames(doc, root, definitions)

if #problems > 0 then
	table.sort(problems)
	io.stderr:write(string.format("%d problem(s) between %s and the definitions:\n", #problems, options.catalog))
	for _, problem in ipairs(problems) do
		io.stderr:write("  ", problem, "\n")
	end
	os.exit(1)
end
print(string.format("%s matches the definitions", options.catalog))
