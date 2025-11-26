-- luarules/Utilities/springOverrides.lua --------------------------------------
-- Spring function overrides for LuaRules, loaded along with luarules/Utilities.

local base = Spring.Base or {}
Spring.Base = base

if Spring.TraceScreenRay then
	local sp_TraceScreenRay = Spring.TraceScreenRay

	---@diagnostic disable return-type-mismatch -- FIXME: docs are wrong

	---Get information about a ray traced from screen to world position.
	--
	-- This method is an override of the engine-provided TraceScreenRay,
	-- and can peek selection volumes hidden by `cmd_no_self_selection`.
	---@param screenX number position on x axis in mouse coordinates (origin on left border of view)
	---@param screenY number position on y axis in mouse coordinates (origin on top border of view)
	---@param onlyCoords boolean? (default: `false`) `result` includes only coordinates (NB: accepts a `heightOffset` with 3 args)
	---@param useMinimap boolean? (default: `false`) if position arguments are contained by minimap, use the minimap corresponding world position
	---@param includeSky boolean? (default: `false`)
	---@param ignoreWater boolean? (default: `false`)
	---@param heightOffset number? (default: `0`)
	---@return ("unit"|"feature"|"ground"|"sky")? description of traced object or position
	---@return (integer|xyz)? result unitID or featureID (integer), or position triple (xyz)
	local function traceScreenRay(screenX, screenY, onlyCoords, useMinimap, includeSky, ignoreWater, heightOffset)
		-- note: arg3 actually might be the heightOffset, which is a "number" type
		if useMinimap or onlyCoords == true then
			return sp_TraceScreenRay(
				screenX,
				screenY,
				onlyCoords, -- ignores units (but maybe is heightOffset)
				useMinimap, -- ignores unit volumes (queries by midpoint)
				includeSky,
				ignoreWater,
				heightOffset
			)
		end

		-- Peek any hidden selection volumes so we get a true ray trace.
		Script.LuaUI.RestoreSelectionVolume()
		local description, result = sp_TraceScreenRay(screenX, screenY, onlyCoords, useMinimap, includeSky, ignoreWater, heightOffset)
		Script.LuaUI.RemoveSelectionVolume()
		return description, result
	end

	---@diagnostic enable return-type-mismatch -- FIXME: docs are wrong

	base.TraceScreenRay = sp_TraceScreenRay
	Spring.TraceScreenRay = traceScreenRay
end
