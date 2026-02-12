local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Inherit Creation Units XP",
		desc = "Allows units with added UnitDefs to gain a defined fraction of the XP earned by their creations.",
		author = "SethDGamre and Xehrath",
		date = "May 2024",
		license = "Public domain",
		layer = 0,
		enabled = true
	}
end

-- synced only
if not gadgetHandler:IsSyncedCode() then return false end

--**********unit customparams to add to unitdef***********
-- inheritxpratemultiplier = 1, 	-- defined in unitdef customparams of the parent unit. It's a number by which XP gained by children is multiplied and passed to the parent after power difference calculations
-- childreninheritxp = "TURRET MOBILEBUILT DRONE BOTCANNON", --  determines what kinds of units linked to parent inherit XP
-- parentsinheritxp = "TURRET MOBILEBUILT DRONE BOTCANNON", -- determines what kinds of units linked to the parent will give the parent XP

local spGetUnitExperience = Spring.GetUnitExperience
local spSetUnitExperience = Spring.SetUnitExperience
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID

local inheritChildrenXP = {} -- stores the value of XP rate to be derived from unitdef
local inheritCreationXP = {} -- multiplier of XP to inherit to newly created units, indexed by unitID
local childrenInheritXP = {} -- stores the string that represents the types of units that will inherit the parent's XP when created
local parentsInheritXP = {} -- stores the string that represents the types of units the parent will gain xp from
local unitNeverGainsXP = {}
local childrenWithParents = {} --stores the parent/child relationships format. Each entry stores key of unitID with an array of {unitID, builderID, xpInheritance}
local mobileUnits = {}
local turretUnits = {}
local unitPowerDefs = {}

for id, def in pairs(UnitDefs) do
	if def.customParams.inheritxpratemultiplier then
		inheritChildrenXP[id] = def.customParams.inheritxpratemultiplier or 1
	end
	if def.customParams.inheritcreationxpmultiplier then
		inheritCreationXP[id] = def.customParams.inheritcreationxpmultiplier or 1
	end
	parentsInheritXP[id] = def.customParams.parentsinheritxp or ""
	childrenInheritXP[id] = def.customParams.childreninheritxp or ""
	unitNeverGainsXP[id] = def.customParams.no_xp_gain and true or false
	mobileUnits[id] = (def.speed or 0) > 0
	if def.speed == 0 and def.weapons and def.weapons[1] then
		for i = 1, #def.weapons do
			local wDef = WeaponDefs[def.weapons[i].weaponDef]
			if wDef.type ~= "Shield" then
				turretUnits[id] = true
				break
			end
		end
	end
	unitPowerDefs[id] = def.power
end

if table.count(inheritChildrenXP) == 0 then
	gadgetHandler:RemoveGadget()
	return
end

local oldChildXPValues = {}
local experienceGained = {} -- aggregated partial XP gains, applied in batches
local experienceGainedFull = {} -- aggregated full XP gains

local function calculatePowerDiffXP(childID, parentID) -- this function calculates the right proportion of XP to inherit from child as though they were attacking the target themself.
	local childDefID = spGetUnitDefID(childID)
	local parentDefID = spGetUnitDefID(parentID)
	if not childDefID or not parentDefID then
		return 0
	end
	local childPower = unitPowerDefs[childDefID] or 1
	local parentPower = unitPowerDefs[parentDefID] or 1
	local parentToChildScale = inheritChildrenXP[parentDefID] or 1
	return (childPower / parentPower) * parentToChildScale
end

local function setUnitCreationXP(unitID)
	local carrierUnitID = spGetUnitRulesParam(unitID, "carrier_host_unit_id")
	local parentUnitID = spGetUnitRulesParam(unitID, "parent_unit_id")

	local parentID = carrierUnitID or parentUnitID
	local parentDefID = spGetUnitDefID(parentID)
	if not parentID or not parentDefID then
		return
	end

	local childToParent
	if carrierUnitID then
		if parentsInheritXP[parentDefID]:find("DRONE") then
			childToParent = {
				unitid = unitID,
				parentunitid = carrierUnitID,
				parentxpmultiplier = calculatePowerDiffXP(unitID, carrierUnitID),
				childtype = "DRONE",
			}
			childrenWithParents[unitID] = childToParent
		end
	end
	if parentUnitID then
		if parentsInheritXP[parentDefID]:find("BOTCANNON") then
			childToParent = {
				unitid = unitID,
				parentunitid = parentUnitID,
				parentxpmultiplier = calculatePowerDiffXP(unitID, parentUnitID),
				childtype = "BOTCANNON",
			}
			childrenWithParents[unitID] = childToParent
		end
	end
	if not childToParent then
		-- MOBILEBUILT and TURRET rules work differently, see UnitCreated:
		childToParent = childrenWithParents[unitID]
		if not childToParent then
			return
		end
	end

	parentID = childToParent.parentunitid

	if parentID and Spring.GetUnitIsDead(parentID) == false then
		parentDefID = spGetUnitDefID(parentID)
		if (childrenInheritXP[parentDefID] or ""):find(childToParent.childtype or "") then
			local parentXP = spGetUnitExperience(parentID)
			local initMult = inheritCreationXP[parentDefID] or 1
			local childInitXP = parentXP * initMult
			spSetUnitExperience(unitID, childInitXP)
			oldChildXPValues[unitID] = childInitXP
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if  builderID and mobileUnits[unitDefID] and parentsInheritXP[spGetUnitDefID(builderID)]:find("MOBILEBUILT") then -- only mobile combat units will pass xp
		childrenWithParents[unitID] = {
			unitid = unitID,
			parentunitid = builderID,
			parentxpmultiplier = calculatePowerDiffXP(unitID, builderID),
			childtype = "MOBILEBUILT",
		}
	end
	if  builderID and turretUnits[unitDefID] and parentsInheritXP[spGetUnitDefID(builderID)]:find("TURRET") then -- only immobile combat units will pass xp
		childrenWithParents[unitID] = {
			unitid = unitID,
			parentunitid = builderID,
			parentxpmultiplier = calculatePowerDiffXP(unitID, builderID),
			childtype = "TURRET",
		}
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	setUnitCreationXP(unitID)
end

function gadget:GameFrame(frame)
	if frame%30 == 0 then
		for unitID, data in pairs(childrenWithParents) do
			local parentID = data.parentunitid
			local newXP = spGetUnitExperience(unitID) or 0
			local oldXP = oldChildXPValues[unitID] or 0
			local addXP = experienceGained[unitID] or 0
			if Spring.GetUnitIsDead(parentID) == false and oldXP < newXP + addXP then
				local parentXP = spGetUnitExperience(parentID) or 0
				local multiplier = data.parentxpmultiplier or 1
				local gainedXP = parentXP + multiplier * (newXP + addXP - oldXP)
				oldChildXPValues[unitID] = newXP + addXP
				spSetUnitExperience(parentID, gainedXP)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local evoID = Spring.GetUnitRulesParam(unitID, "unit_evolved")
	if evoID then
		for id, data in pairs(childrenWithParents) do
			if data.parentunitid == unitID then
				data.parentunitid = evoID
				data.parentxpmultiplier = calculatePowerDiffXP(id, evoID)
			end
		end
	end
	childrenWithParents[unitID] = nil
end

local inUnitExperience = false

function gadget:UnitExperience(unitID, unitDefID, unitTeam, newXP, oldXP)
    if not unitNeverGainsXP[unitDefID] or inUnitExperience then
        return
    end

    inUnitExperience = true

	local gainedXP = newXP - oldXP

	-- We cannot subtract XP with SetUnitExperience, so we negate the gains.
	if gainedXP > 0 then
		Spring.AddUnitExperience(unitID, -gainedXP)
	end

	-- Keep incremental XP gains and apply them in the batch update.
	experienceGained[unitID] = (experienceGained[unitID] or 0) + gainedXP
	experienceGainedFull[unitID] = math.max(0, (experienceGainedFull[unitID] or 0) + gainedXP)

    inUnitExperience = false
end

function gadget:Initialize()
	-- Units that negate their XP gains still share XP to their parent (if any).
	-- We track the negated XP gains, as well, to allow custom game XP behaviors.
	GG.UnitGainedXP = experienceGainedFull
end

function gadget:Shutdown()
	GG.UnitGainedXP = nil
end
