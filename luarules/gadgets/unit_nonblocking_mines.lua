local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = 'Nonblocking mines',
		desc = 'For 92.+ mines need to be manually unblocked. But other units cannot be built on them.',
		author = 'Beherith',
		date = 'Jan 2013',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local footprintSize = Game.squareSize * Game.footprintScale
local isMine = Game.UnitInfo.Cache.mine
local footprints = Game.UnitInfo.Cache.footprintSize
local mines = {}

local spSetUnitBlocking = Spring.SetUnitBlocking

function gadget:UnitCreated(uID, uDefID, uTeam)
	if isMine[uDefID] then
		local x, _, z = Spring.GetUnitPosition(uID)
		mines[uID] = { x, z }
		spSetUnitBlocking(uID, false, false)
	end
end

function gadget:UnitDestroyed(uID, uDefID, uTeam)
	if isMine[uDefID] and mines[uID] then
		mines[uID] = nil
		spSetUnitBlocking(uID, false, false)
	end
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
	if x and y and z then
		local footprint = footprints[unitDefID]
		-- todo: this does not check facing
		local offsetX = (footprint[1] + footprintSize) * 0.5 -- add +1 to scale for the mine's size
		local offsetZ = (footprint[2] + footprintSize) * 0.5
		for mine, pos in pairs(mines) do
			if math.abs(x - pos[1]) < offsetX and math.abs(z - pos[2]) < offsetZ then
				return false
			end
		end
	end
	return true
end
