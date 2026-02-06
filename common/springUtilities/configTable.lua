-- springUtilities/configTable.lua ---------------------------------------------
--                                                                            --
-- Intended for use with Lua data files that may contain user-generated data. --
--                                                                            --
-- This does not provide security or protection for tables beyond very simple --
-- key-access patterns to enforce lowercasing. Do _not_ use this as security. --
--                                                                            --
--------------------------------------------------------------------------------

-- Track tables that have been set to auto-lowercase their keys.
-- The "k" mode allows collection of unreferenced keys (tables).
local autoLowerTbls = setmetatable({}, { __mode = "k" })

---Creates a new table, casing any string keys found in an input
---table and its subtables to lowercase, and copying any others.
---
---When the table has the `autoLowerKeys` metatable, though, the
---table is returned, and its subtables checked for lowercasing.
---@param T table
---@return table t
local function getLowerKeys(T)
	local t = autoLowerTbls[T] and T or {}

	if t ~= T then
		for key, value in pairs(T) do
			if type(key) == "string" then
				key = key:lower()
			end
			if type(value) == "table" then
				value = getLowerKeys(value)
			end
			t[key] = value
		end
	else
		for key, value in pairs(t) do
			if type(value) == "table" then
				t[key] = getLowerKeys(value)
			end
		end
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

setAutoLowerKeys = function(tbl)
	if not autoLowerTbls[tbl] then
		tbl = setmetatable(tbl, autoLowerKeys)
		autoLowerTbls[tbl] = true
	end

	for _, value in pairs(tbl) do
		if type(value) == "table" then
			setAutoLowerKeys(value)
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
