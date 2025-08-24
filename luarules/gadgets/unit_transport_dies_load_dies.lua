--in BAR "commando" unit always survives being shot down during transport
--when a com dies in mid air the damage done is controlled by unit_combomb_full_damage

--several other ways to code this do not work because:
--when UnitDestroyed() is called, Spring.GetUnitIsTransporting is already empty -> meh
--checking newDamage>health in UnitDamaged() does not work because UnitDamaged() does not trigger on selfdestruct -> meh
--with releaseHeld, on death of a transport UnitUnload is called before UnitDestroyed
--when UnitUnloaded is called due to transport death, Spring.GetUnitIsDead (transportID) is still false
--when trans is self d'ed, on the frame it dies it has both Spring.GetUnitHealth(ID)>0 and Spring.UnitSelfDTime(ID)=0
--when trans is crashing it isn't dead
--SO: we wait one frame after UnitUnload and then check if the trans is dead/alive/crashing

--DestroyUnit(ID, true, true) will trigger self d explosion, won't leave a wreck but won't cause an explosion either
--DestroyUnit(ID, true, false) won't leave a wreck but won't cause the self d explosion either
--AddUnitDamage (ID, math.huge) makes a normal death explo but leaves wreck. Calling this for the transportee on the same frame as the trans dies results in a crash.


local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "transport_dies_load_dies",
		desc      = "kills units in transports when transports dies (except commandos, lootboxes, scavengerbeacons and hats)",
		author    = "knorke, bluestone, icexuick, beherith",
		date      = "Dec 2012",
		license   = "GNU GPL, v2 or later, horses",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local deathExplosion = Game.UnitInfo.Cache.deathExplosionWeapon
local doNotDestroy = {}
do
	local isDecorationUnit = Game.UnitInfo.Cache.isDecorationUnit -- hats
	local isParatrooperUnit = Game.UnitInfo.Cache.isParatrooperUnit -- commandos
	for udid, ud in pairs(UnitDefs) do
		if isParatrooperUnit[udid] or isDecorationUnit[udid] then
			doNotDestroy[udid] = true
		end
	end
end

local toKill = {} -- [frame][unitID]
local fromtrans = {}

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if not doNotDestroy[unitDefID] then
		--don't destroy units with effigies. Spring.SetUnitPosition cannot move a unit mid-fall.
		if Spring.GetUnitRulesParam(unitID, "unit_effigy") then
			return
		end
		local currentFrame = Spring.GetGameFrame()
		if not toKill[currentFrame+1] then
			toKill[currentFrame+1] = {}
		end
		toKill[currentFrame+1][unitID] = true
		if not fromtrans[currentFrame+1] then
			fromtrans[currentFrame+1] = {}
		end
		fromtrans[currentFrame+1][unitID] = transportID
		--Spring.Echo("added killing request for " .. unitID .. " on frame " .. currentFrame+1 .. " from transport " .. transportID )
	else
		--commandos are given a move order to the location of the ground below where the transport died; remove it
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	end
end

function gadget:GameFrame(frame)
	if toKill[frame] then --kill units as requested from above
		for uID in pairs (toKill[frame]) do
			local tID = fromtrans[frame][uID]
			--check that trans is dead/crashing and unit is still alive
			if (Spring.GetUnitIsDead(tID) or Spring.GetUnitMoveTypeData(tID).aircraftState == "crashing") and Spring.GetUnitIsDead(uID) == false then
				local explode = deathExplosion[Spring.GetUnitDefID(uID)]
				if explode then
					Spring.SetUnitWeaponDamages(uID, "selfDestruct", explode)
					Spring.SetUnitWeaponDamages(uID, "selfDestruct", explode.damages)
				end
				Spring.DestroyUnit(uID, true, false)
			end
		end
		toKill[frame] = nil
		fromtrans[frame] = nil
	end
end
