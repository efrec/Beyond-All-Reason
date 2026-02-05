-- springFunctions/configTable.lua ---------------------------------------------
-- Intended for use with Lua data files that may contain user-generated data. --
--------------------------------------------------------------------------------

---Creates a new table, casing any string keys found in an input
---table and its subtables to lowercase, and copying any others.
---@param T table
---@return table t
local function getLowerKeys(T)
	local t = {}

	for key, value in pairs(T) do
		if type(key) == "string" then
			key = key:lower()
		end
		if type(value) == "table" then
			value = getLowerKeys(value)
		end
		t[key] = value
	end

	return t
end

local setAutoLowerKeys = function(tbl) return tbl end ---@param tbl table

---@type metatable
local autoLowerKeys = {
	__metatable = "ConfigTable",

	__index = function(tbl, key)
		if type(key) == "string" then
			return rawget(tbl, key:lower())
		end
	end,

	__newindex = function(tbl, key, value)
		if type(key) == "string" then
			key = key:lower()
		end
		if type(value) == "table" then
			value = getLowerKeys(value)
			value = setAutoLowerKeys(value)
		end
		rawset(tbl, key, value)
	end,
}

local autoLowerTbls = setmetatable({}, { __mode = "k" }) -- allow collection of tables-as-keys

setAutoLowerKeys = function(tbl)
	if not autoLowerTbls[tbl] then
		autoLowerTbls[tbl] = true

		tbl = setmetatable(tbl, autoLowerKeys)

		for _, value in pairs(tbl) do
			if type(value) == "table" then
				setAutoLowerKeys(value)
			end
		end
	end
	return tbl
end

---Recasts a `table` to a new, normalized data table containing no "matching" keys.
---
---Keys can have any casing, effectively, when recasting them to lowercase anyway.
---This can produce mixed sets of keys, without any clearly preferred, "real" key.
---
---This function checks for and resolves any overlapping keys in different casings.
---@param tbl table
---@return table
local function getConfigTableLower(tbl)
	return setAutoLowerKeys(getLowerKeys(tbl))
end

--------------------------------------------------------------------------------
-- Export module ---------------------------------------------------------------

return {
	ConfigTbl = getConfigTableLower,
	LowerKeys = getLowerKeys,
}
