--- unitTaskClaims.lua ---------------------------------------------------------
--- Arbitrates between automation tasks of multiple clients, e.g. auto-repairs,
--- so that the two tasks don't both try to command one unit. Claims are local,
--- never seen by other clients, so are separated from sharedTeam.lua.
--------------------------------------------------------------------------------

if not Spring then
	return
end

local spGetGameFrame = Spring.GetGameFrame

local claimOfUnit = {} ---@type table<UnitID, { tag: string, expiry: integer }?>

-- Module functions ------------------------------------------------------------

---@param unitID UnitID
---@param tag string The automation claiming the unit, e.g. "autorepair".
---@param ttl integer Task duration in frames. There is no default value.
---@return boolean claimed `false` when another automation holds a claim.
local function claim(unitID, tag, ttl)
	local held = claimOfUnit[unitID]
	local frame = spGetGameFrame()

	if held and held.tag ~= tag and frame < held.expiry then
		return false
	end

	claimOfUnit[unitID] = { tag = tag, expiry = frame + ttl }
	return true
end

---@param unitID UnitID
---@param tag string Matching the automation ending its claim.
local function release(unitID, tag)
	local held = claimOfUnit[unitID]
	if held and held.tag == tag then
		claimOfUnit[unitID] = nil
	end
end

---@param unitID UnitID
---@return string? tag `nil` when the unit is free or the claim has expired.
local function getHolder(unitID)
	local held = claimOfUnit[unitID]
	if held and spGetGameFrame() < held.expiry then
		return held.tag
	end
	return nil
end

---@param unitID UnitID
local function forget(unitID)
	claimOfUnit[unitID] = nil
end

-- Export ----------------------------------------------------------------------

return {
	Claim = claim,
	Release = release,
	GetHolder = getHolder,
	Forget = forget,
}
