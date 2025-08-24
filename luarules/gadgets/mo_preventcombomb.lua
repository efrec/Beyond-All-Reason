local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "preventcombomb",
		desc      = "Commanders survive commander blast",
		author    = "TheFatController",
		date      = "Aug 31, 2009",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local GetTeamInfo = Spring.GetTeamInfo
local GetUnitHealth = Spring.GetUnitHealth
local GetGameFrame = Spring.GetGameFrame
local DestroyUnit = Spring.DestroyUnit
local UnitTeam = Spring.GetUnitTeam
local math_random = math.random

local immuneDGunList = {}
local immuneEnvironment = {}
local environmentWeapon = {
	[Game.envDamageTypes.Debris] = true,
	[Game.envDamageTypes.GroundCollision] = true,
	[Game.envDamageTypes.ObjectCollision] = true,
	[Game.envDamageTypes.Fire] = true,
	[Game.envDamageTypes.Water] = true,
}

local isCommander = Game.UnitInfo.Cache.isCommanderUnit
local isDGun = {}
local isSelfD = {}
for udefID, def in pairs(UnitDefs) do
	if isCommander[udefID] and WeaponDefNames[ def.name..'_disintegrator' ] then
		isDGun[ WeaponDefNames[ def.name..'_disintegrator' ].id ] = true
		isSelfD[WeaponDefNames[ def.selfDExplosion         ].id ] = true
	end
end

local function CommCount(unitTeam)
	local teamsInAllyID = {}
	local allyteamlist = Spring.GetAllyTeamList()
	for ct, allyTeamID in pairs(allyteamlist) do
		teamsInAllyID[allyTeamID] = Spring.GetTeamList(allyTeamID) -- [1] = teamID,
	end
	-- Spring.Echo(teamsInAllyID[currentAllyTeamID])
	local count = 0
	for _, teamID in pairs(teamsInAllyID[select(6,GetTeamInfo(unitTeam,false))]) do -- [_] = teamID,
		for unitDefID,_ in pairs(isCommander) do
			count = count + Spring.GetTeamUnitDefCount(teamID, unitDefID)
		end
	end
	-- Spring.Echo(currentAllyTeamID..","..count)
	return count
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not isCommander[unitDefID] then
		return
	end

	--falling & debris damage
	if weaponID and immuneEnvironment[unitID] and environmentWeapon[weaponID] then
		return 0, 0
	end

	local combombDamage
	if isSelfD[weaponID] then
		local hp = GetUnitHealth(unitID) or 0
		combombDamage = hp-200-math_random(1,10)
		combombDamage = math.clamp(combombDamage, 0, math.min(hp * 0.33, damage))
	end

	if isDGun[weaponID] then
		if immuneDGunList[unitID] then
			return 0, 0
		elseif isCommander[attackerDefID] and CommCount(UnitTeam(unitID)) <= 1 and attackerID and CommCount(UnitTeam(attackerID)) <= 1 then
			-- make unitID immune to DGun, kill attackerID
			immuneDGunList[unitID] = GetGameFrame() + 45
			DestroyUnit(attackerID,false,false,unitID)
			return combombDamage, 0
		end
	elseif isSelfD[weaponID] and CommCount(UnitTeam(unitID)) <= 1 and attackerID and CommCount(UnitTeam(attackerID)) <= 1 then
		if unitID ~= attackerID then
			-- make unitID immune to DGun
			immuneDGunList[unitID] = GetGameFrame() + 45
			immuneEnvironment[unitID] = GetGameFrame() + 250
			return combombDamage, 0
		else
			--com blast hurts the attackerID
			return damage
		end
	end
	return damage
end

function gadget:GameFrame(currentFrame)
	for unitID,expirationTime in pairs(immuneDGunList) do
		if currentFrame > expirationTime then
			immuneDGunList[unitID] = nil
		end
	end
	for unitID,expirationTime in pairs(immuneEnvironment) do
		if currentFrame > expirationTime then
			immuneEnvironment[unitID] = nil
		end
	end
end
