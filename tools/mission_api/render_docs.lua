----------------------------------------------------------------
--- Mission API Markdown renderer -------------------------------

-- Renders mission_api.json into GitHub-flavored Markdown pages. Run from the repository root:
--   lua tools/mission_api/render_docs.lua --catalog <mission_api.json> --out <doc directory> [--root <repo>]
-- The output directory and its actions/ subdirectory must exist.

local USAGE = "usage: render_docs.lua --catalog <mission_api.json> --out <doc directory> [--root <repo root>]"

local PICK_PHRASES = {
	point = "Picked on the map as a point.",
	points = "Picked on the map as a series of points.",
	area = "Picked on the map as an area.",
}

local here = (arg and arg[0] and arg[0]:match("^(.*)[/\\]")) or "."
local util = dofile(here .. "/catalog_util.lua") ---@type table

local catalog ---@type table<string, table<string, any>>

----------------------------------------------------------------
--- Markdown pieces -----------------------------------------------

local function anchor(name)
	return (name:lower():gsub("[^%w%- ]", ""):gsub(" ", "-"))
end

local function cell(text)
	return (util.trim(text or ""):gsub("\r?\n", " "):gsub("|", "\\|"))
end

local function code(text)
	return "`" .. text .. "`"
end

local function joinNames(names, conjunction)
	if #names == 1 then
		return names[1]
	end
	if #names == 2 then
		return names[1] .. " " .. conjunction .. " " .. names[2]
	end
	return table.concat(names, ", ", 1, #names - 1) .. ", " .. conjunction .. " " .. names[#names]
end

local function number(value)
	if type(value) == "number" then
		return util.formatNumber(value)
	end
	return tostring(value)
end

-- `prefix` is the relative path from the page being written to the repository doc root.
local function typeLink(name, prefix)
	if catalog.types[name] then
		return "[" .. name .. "](" .. prefix .. "types.md#" .. anchor(name) .. ")"
	end
	if catalog.mission[name] then
		return "[" .. name .. "](" .. prefix .. "mission.md#" .. anchor(name) .. ")"
	end
	return code(cell(name))
end

local function entryLink(name, prefix)
	local action = catalog.actions[name]
	if action then
		return "[" .. name .. "](" .. prefix .. "actions/" .. action.category .. ".md#" .. anchor(name) .. ")"
	end
	if catalog.triggers[name] then
		return "[" .. name .. "](" .. prefix .. "triggers.md#" .. anchor(name) .. ")"
	end
	return typeLink(name, prefix)
end

local function addNotes(lines, entry)
	if entry.deprecated then
		lines[#lines + 1] = "**Deprecated.**" .. (entry.deprecationReason and " " .. entry.deprecationReason or "")
		lines[#lines + 1] = ""
	end
	if entry.available == false then
		lines[#lines + 1] = "**Not available.**" .. (entry.unavailableReason and " " .. entry.unavailableReason or "")
		lines[#lines + 1] = ""
	end
end

local function addSeeAlso(lines, entry, prefix)
	if entry.see and #entry.see > 0 then
		local links = {}
		for index, name in ipairs(entry.see) do
			links[index] = entryLink(name, prefix)
		end
		lines[#lines + 1] = "See also: " .. table.concat(links, ", ") .. "."
		lines[#lines + 1] = ""
	end
end

local function addFieldTable(lines, fields, prefix, withDefault)
	if withDefault then
		lines[#lines + 1] = "| Name | Type | Required | Default | Description |"
		lines[#lines + 1] = "| --- | --- | --- | --- | --- |"
	else
		lines[#lines + 1] = "| Name | Type | Required | Description |"
		lines[#lines + 1] = "| --- | --- | --- | --- |"
	end
	for _, field in ipairs(fields) do
		local columns = {
			code(field.name),
			typeLink(field.type, prefix),
			field.required and "Yes" or "No",
		}
		if withDefault then
			columns[#columns + 1] = field.default and code(cell(field.default)) or ""
		end
		columns[#columns + 1] = cell(field.description)
		lines[#lines + 1] = "| " .. table.concat(columns, " | ") .. " |"
	end
	lines[#lines + 1] = ""
end

----------------------------------------------------------------
--- Pages ---------------------------------------------------------

local function addDefinition(lines, name, entry, noun, prefix)
	lines[#lines + 1] = "## " .. name
	lines[#lines + 1] = ""
	if entry.description ~= "" then
		lines[#lines + 1] = entry.description
		lines[#lines + 1] = ""
	end
	addNotes(lines, entry)
	if #entry.parameters == 0 then
		lines[#lines + 1] = "This " .. noun .. " takes no parameters."
		lines[#lines + 1] = ""
	else
		addFieldTable(lines, entry.parameters, prefix, true)
	end
	if #entry.requiresOneOf > 0 then
		local names = {}
		for index, parameter in ipairs(entry.requiresOneOf) do
			names[index] = code(parameter)
		end
		lines[#lines + 1] = "At least one of " .. joinNames(names, "and") .. " is required."
		lines[#lines + 1] = ""
	end
	for _, parameter in ipairs(entry.declares) do
		lines[#lines + 1] = "The value of "
			.. code(parameter)
			.. " declares a new name that other actions and triggers can refer to."
		lines[#lines + 1] = ""
	end
	addSeeAlso(lines, entry, prefix)
end

local function categoryPage(category, names)
	local lines = { "# Actions: " .. category, "" } ---@type string[]
	lines[#lines + 1] = "Back to the [Mission API index](../index.md)."
	lines[#lines + 1] = ""
	for _, name in ipairs(names) do
		addDefinition(lines, name, catalog.actions[name], "action", "../")
	end
	return lines
end

local function triggersPage()
	local lines = { "# Triggers", "" } ---@type string[]
	lines[#lines + 1] = "Back to the [Mission API index](index.md)."
	lines[#lines + 1] = ""
	for _, name in ipairs(util.sortedKeys(catalog.triggers)) do
		addDefinition(lines, name, catalog.triggers[name], "trigger", "")
	end
	return lines
end

local function addTypeDetails(lines, entry)
	if entry.kind == "record" then
		if #entry.fields == 0 then
			lines[#lines + 1] = "A table with no fixed fields."
			lines[#lines + 1] = ""
		else
			addFieldTable(lines, entry.fields, "", false)
		end
	elseif entry.kind == "union" then
		local links = {}
		for index, name in ipairs(entry.oneOf) do
			links[index] = typeLink(name, "")
		end
		lines[#lines + 1] = "One of " .. joinNames(links, "or") .. "."
		lines[#lines + 1] = ""
	elseif entry.kind == "enum" then
		local values = {}
		for index, row in ipairs(entry.values) do
			values[index] = code(number(row.value))
		end
		if entry.multiple then
			lines[#lines + 1] = "A list of any of " .. joinNames(values, "and") .. "."
		else
			lines[#lines + 1] = "One of " .. joinNames(values, "or") .. "."
		end
		lines[#lines + 1] = ""
	elseif entry.kind == "list" then
		lines[#lines + 1] = "A list of " .. typeLink(entry.itemType, "") .. " values."
		lines[#lines + 1] = ""
	else
		local jsonTypes = type(entry.jsonType) == "table" and entry.jsonType or { entry.jsonType }
		local names = {}
		for index, jsonType in ipairs(jsonTypes) do
			names[index] = code(jsonType)
		end
		if #names > 0 then
			lines[#lines + 1] = "A " .. joinNames(names, "or") .. " value."
			lines[#lines + 1] = ""
		end
	end
	if entry.references then
		lines[#lines + 1] = "Refers to " .. code(entry.references) .. "."
		lines[#lines + 1] = ""
	end
	if entry.bounds then
		if entry.bounds.max ~= nil then
			lines[#lines + 1] = "Between "
				.. code(number(entry.bounds.min))
				.. " and "
				.. code(number(entry.bounds.max))
				.. " inclusive."
		else
			lines[#lines + 1] = "At least " .. code(number(entry.bounds.min)) .. "."
		end
		lines[#lines + 1] = ""
	end
	if entry.pick then
		lines[#lines + 1] = PICK_PHRASES[entry.pick]
		lines[#lines + 1] = ""
	end
	if entry.panel then
		lines[#lines + 1] = "Edited in its own panel."
		lines[#lines + 1] = ""
	end
end

local function typesPage()
	local lines = { "# Parameter types", "" } ---@type string[]
	lines[#lines + 1] = "Back to the [Mission API index](index.md)."
	lines[#lines + 1] = ""
	for _, name in ipairs(util.sortedKeys(catalog.types)) do
		local entry = catalog.types[name]
		lines[#lines + 1] = "## " .. name
		lines[#lines + 1] = ""
		if entry.description ~= "" then
			lines[#lines + 1] = entry.description
			lines[#lines + 1] = ""
		end
		addNotes(lines, entry)
		addTypeDetails(lines, entry)
		addSeeAlso(lines, entry, "")
	end
	return lines
end

local function missionPage()
	local lines = { "# Mission file format", "" } ---@type string[]
	lines[#lines + 1] = "Back to the [Mission API index](index.md)."
	lines[#lines + 1] = ""
	local names = util.sortedKeys(catalog.mission)
	if #names == 0 then
		lines[#lines + 1] = "The mission file format is not annotated yet."
		lines[#lines + 1] = ""
	end
	for _, name in ipairs(names) do
		local entry = catalog.mission[name]
		lines[#lines + 1] = "## " .. name
		lines[#lines + 1] = ""
		if entry.description ~= "" then
			lines[#lines + 1] = entry.description
			lines[#lines + 1] = ""
		end
		addNotes(lines, entry)
		if #entry.fields == 0 then
			lines[#lines + 1] = "A table with no fixed fields."
			lines[#lines + 1] = ""
		else
			addFieldTable(lines, entry.fields, "", false)
		end
		addSeeAlso(lines, entry, "")
	end
	local difficulty = catalog.types.Difficulty
	if difficulty and difficulty.kind == "enum" then
		lines[#lines + 1] = "## Difficulties"
		lines[#lines + 1] = ""
		local values = {}
		for index, row in ipairs(difficulty.values) do
			values[index] = code(number(row.value))
		end
		lines[#lines + 1] = "The difficulties are "
			.. joinNames(values, "and")
			.. ", in that order. See [Difficulty](types.md#difficulty)."
		lines[#lines + 1] = ""
	end
	return lines
end

local function indexPage(categories)
	local lines = { "# Mission API", "" } ---@type string[]
	lines[#lines + 1] = "Generated from the annotations in `luarules/mission_api` by `tools/mission_api/build_docs.sh`."
	lines[#lines + 1] = ""
	lines[#lines + 1] = "- [Parameter types](types.md)"
	lines[#lines + 1] = "- [Mission file format](mission.md)"
	lines[#lines + 1] = "- [Triggers](triggers.md)"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "## Actions"
	lines[#lines + 1] = ""
	for _, category in ipairs(util.sortedKeys(categories)) do
		lines[#lines + 1] = "### [" .. category .. "](actions/" .. category .. ".md)"
		lines[#lines + 1] = ""
		for _, name in ipairs(categories[category]) do
			lines[#lines + 1] = "- " .. entryLink(name, "")
		end
		lines[#lines + 1] = ""
	end
	lines[#lines + 1] = "## Triggers"
	lines[#lines + 1] = ""
	for _, name in ipairs(util.sortedKeys(catalog.triggers)) do
		lines[#lines + 1] = "- " .. entryLink(name, "")
	end
	lines[#lines + 1] = ""
	return lines
end

----------------------------------------------------------------
--- Main ----------------------------------------------------------

local options = util.parseArgs(arg, USAGE)
util.requireArgs(options, { "catalog", "out" }, USAGE)

local json = util.loadJsonModule(options.root or ".")
catalog = json.decode(util.readFile(options.catalog))
catalog.types = catalog.types or {}
catalog.actions = catalog.actions or {}
catalog.triggers = catalog.triggers or {}
catalog.mission = catalog.mission or {}

local categories = {}
for _, name in ipairs(util.sortedKeys(catalog.actions)) do
	local category = catalog.actions[name].category
	categories[category] = categories[category] or {}
	table.insert(categories[category], name)
end

local out = util.normalizePath(options.out):gsub("/+$", "")
local written = 0

local function writePage(path, lines)
	while lines[#lines] == "" do
		lines[#lines] = nil
	end
	util.writeFile(util.joinPath(out, path), table.concat(lines, "\n") .. "\n")
	written = written + 1
end

writePage("index.md", indexPage(categories))
writePage("types.md", typesPage())
writePage("triggers.md", triggersPage())
writePage("mission.md", missionPage())
for _, category in ipairs(util.sortedKeys(categories)) do
	writePage("actions/" .. category .. ".md", categoryPage(category, categories[category]))
end

print(string.format("wrote %d pages under %s", written, out))
