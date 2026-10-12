----------------------------------------------------------------
--- Shared helpers for the Mission API catalog tools -----------

-- Plain Lua 5.1. The game's Lua is float32, so integers are only trusted below 2^24.

local INTEGER_LIMIT = 2 ^ 24

local ARRAY_MT = {}
local RAW_MT = {}

----------------------------------------------------------------
--- Arguments and files -----------------------------------------

local function parseArgs(argv, usage)
	local options = {}
	local index = 1
	while index <= #argv do
		local name = argv[index]:match("^%-%-(.+)$")
		if not name then
			io.stderr:write(usage, "\n")
			os.exit(2)
		end
		options[name] = argv[index + 1]
		index = index + 2
	end
	return options
end

local function requireArgs(options, names, usage)
	for _, name in ipairs(names) do
		if options[name] == nil then
			io.stderr:write("missing --", name, "\n", usage, "\n")
			os.exit(2)
		end
	end
end

local function readFile(path)
	local file, message = io.open(path, "rb")
	if not file then
		error("cannot read " .. path .. ": " .. tostring(message), 0)
	end
	local text = file:read("*a")
	file:close()
	return text
end

local function writeFile(path, text)
	local file, message = io.open(path, "wb")
	if not file then
		error("cannot write " .. path .. ": " .. tostring(message), 0)
	end
	file:write(text)
	file:close()
end

local function scriptDirectory()
	return (arg and arg[0] and arg[0]:match("^(.*)[/\\]")) or "."
end

local function joinPath(root, relative)
	if root == "" or root:sub(-1) == "/" then
		return root .. relative
	end
	return root .. "/" .. relative
end

local function normalizePath(path)
	return (path:gsub("\\", "/"))
end

local function relativePath(path, root)
	path = normalizePath(path)
	root = normalizePath(root):gsub("/+$", "")
	if path:sub(1, #root):lower() == root:lower() and path:sub(#root + 1, #root + 1) == "/" then
		return path:sub(#root + 2)
	end
	return nil
end

----------------------------------------------------------------
--- JSON ----------------------------------------------------------

local function loadJsonModule(root)
	local chunk, message = loadfile(joinPath(root, "common/luaUtilities/json.lua"))
	if not chunk then
		error("cannot load the repository JSON module: " .. tostring(message), 0)
	end
	return chunk() --[[@as table]]
end

local function array(items)
	return setmetatable(items or {}, ARRAY_MT)
end

local function isArray(value)
	return getmetatable(value) == ARRAY_MT
end

-- A number written in the source is emitted as written, so the two interpreters agree.
local function rawNumber(text)
	if not text:match("^%-?%d+$") and not text:match("^%-?%d+%.%d+$") then
		error("not a number literal: " .. text, 0)
	end
	return setmetatable({ text = text }, RAW_MT)
end

local function sortedKeys(object)
	local keys = {}
	for key in pairs(object) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local ESCAPES = {
	["\\"] = "\\\\",
	['"'] = '\\"',
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function encodeString(text)
	return '"'
		.. text:gsub('[%c"\\]', function(char)
			return ESCAPES[char] or string.format("\\u%04x", char:byte())
		end)
		.. '"'
end

local function encodeNumber(number)
	if number ~= number or number == math.huge or number == -math.huge then
		error("cannot encode " .. tostring(number), 0)
	end
	if number == math.floor(number) and math.abs(number) < INTEGER_LIMIT then
		return string.format("%d", number)
	end
	local text = string.format("%.7g", number)
	if text:find("%.") and not text:find("e") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return text
end

local function encodeValue(value, indent, out)
	local kind = type(value)
	if kind == "string" then
		out[#out + 1] = encodeString(value)
	elseif kind == "number" then
		out[#out + 1] = encodeNumber(value)
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif kind == "table" and getmetatable(value) == RAW_MT then
		out[#out + 1] = value.text
	elseif kind == "table" and isArray(value) then
		if #value == 0 then
			out[#out + 1] = "[]"
			return
		end
		local inner = indent .. "  "
		out[#out + 1] = "[\n"
		for index, item in ipairs(value) do
			out[#out + 1] = inner
			encodeValue(item, inner, out)
			out[#out + 1] = index < #value and ",\n" or "\n"
		end
		out[#out + 1] = indent .. "]"
	elseif kind == "table" then
		local keys = sortedKeys(value)
		if #keys == 0 then
			out[#out + 1] = "{}"
			return
		end
		local inner = indent .. "  "
		out[#out + 1] = "{\n"
		for index, key in ipairs(keys) do
			if type(key) ~= "string" then
				error("object keys must be strings, got " .. tostring(key), 0)
			end
			out[#out + 1] = inner .. encodeString(key) .. ": "
			encodeValue(value[key], inner, out)
			out[#out + 1] = index < #keys and ",\n" or "\n"
		end
		out[#out + 1] = indent .. "}"
	else
		error("cannot encode a " .. kind, 0)
	end
end

local function encodeSortedJson(value)
	local out = {}
	encodeValue(value, "", out)
	out[#out + 1] = "\n"
	return table.concat(out)
end

----------------------------------------------------------------
--- Text ----------------------------------------------------------

local function trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function splitWords(text)
	local words = {}
	for word in text:gmatch("%S+") do
		words[#words + 1] = word
	end
	return words
end

-- Numbers sort before strings, and each group ascends.
local function compareValues(a, b)
	local aNumber, bNumber = type(a) == "number", type(b) == "number"
	if aNumber ~= bNumber then
		return aNumber
	end
	return a < b
end

----------------------------------------------------------------
--- Exports -------------------------------------------------------

return {
	parseArgs = parseArgs,
	requireArgs = requireArgs,
	readFile = readFile,
	writeFile = writeFile,
	scriptDirectory = scriptDirectory,
	joinPath = joinPath,
	normalizePath = normalizePath,
	relativePath = relativePath,
	loadJsonModule = loadJsonModule,
	array = array,
	isArray = isArray,
	rawNumber = rawNumber,
	sortedKeys = sortedKeys,
	encodeSortedJson = encodeSortedJson,
	formatNumber = encodeNumber,
	trim = trim,
	splitWords = splitWords,
	compareValues = compareValues,
}
