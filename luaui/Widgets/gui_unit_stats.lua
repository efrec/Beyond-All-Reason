function widget:GetInfo()
	return {
		name      = "Unit Stats",
		desc      = "Shows detailed unit stats",
		author    = "Niobium + Doo",
		date      = "Jan 11, 2009",
		version   = 1.7,
		license   = "GNU GPL, v2 or later",
		layer     = -999990,
		enabled   = true,
	}
end

----v1.7 by Doo changes
-- Reverted "Added beamtime to oRld value to properly count dps of BeamLaser weapons" because reload starts at the beginning of the beamtime
-- Reduced the "minimal" reloadTime to properly calculate dps for low reloadtime weapons
-- Hid range from gui for explosion (death/selfd) as it is irrelevant.

----v1.6 by Doo changes
-- Fixed crashing when hovering some enemy units

----v1.5 by Doo changes
-- Fixed some issues with the add of BeamTime values
-- Added a 1/30 factor to stockpiling weapons (seems like the lua wDef.stockpileTime is in frames while the weaponDefs uses seconds) Probably the 1/30 value in older versions wasnt a "min reloadtime" but the 1/30 factor for stockpile weapons with a typo

----v1.4 by Doo changes
-- Added beamtime to oRld value to properly count dps of BeamLaser weapons

---- v1.3 changes
-- Fix for 87.0
-- Added display of experience effect (when experience >25%)

---- v1.2 changes
-- Fixed drains for burst weapons (Removed 0.125 minimum)
-- Show remaining costs for units under construction

---- v1.1 changes
-- Added extra text to help explain numbers
-- Added grouping of duplicate weapons
-- Added sonar radius
-- Fixed radar/jammer detection
-- Fixed stockpiling unit drains
-- Fixed turnrate/acceleration scale
-- Fixed very low reload times

------------------------------------------------------------------------------------
-- Configuration
------------------------------------------------------------------------------------

local customFontSize = 14
local useSelection = true

local white = '\255\255\255\255'
local grey = '\255\190\190\190'
local green = '\255\1\255\1'
local yellow = '\255\255\255\1'
local orange = '\255\255\128\1'
local blue = '\255\128\128\255'

local metalColor = '\255\196\196\255' -- Light blue
local energyColor = '\255\255\255\128' -- Light yellow
local buildColor = '\255\128\255\128' -- Light green

------------------------------------------------------------------------------------
-- Includes
------------------------------------------------------------------------------------

local damageStats = (VFS.FileExists("LuaUI/Config/BAR_damageStats.lua")) and VFS.Include("LuaUI/Config/BAR_damageStats.lua")

include("keysym.h.lua")

------------------------------------------------------------------------------------
-- Speedups
------------------------------------------------------------------------------------

local max = math.max
local floor = math.floor
local ceil = math.ceil
local format = string.format
local char = string.char

local glColor = gl.Color

local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamColor = Spring.GetTeamColor
local spIsUserWriting = Spring.IsUserWriting
local spGetModKeyState = Spring.GetModKeyState
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spGetUnitWeaponState = Spring.GetUnitWeaponState

local armorTypes = Game.armorTypes
local gameName = Game.gameName
local simSpeed = Game.gameSpeed

local uDefs = UnitDefs
local wDefs = WeaponDefs

------------------------------------------------------------------------------------
-- Globals
------------------------------------------------------------------------------------

local texts = {}

local fontFile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local font = WG['fonts'] and WG['fonts'].getFont(fontFile)
local fontSize = customFontSize or 14

local spec = Spring.GetSpectatingState()
local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousName = '?????'
local anonymousTeamColor = {
	Spring.GetConfigInt("anonymousColorR", 255)/255,
	Spring.GetConfigInt("anonymousColorG", 0)/255,
	Spring.GetConfigInt("anonymousColorB", 0)/255
}

local cX, cY, cYstart
local vsx, vsy = gl.GetViewSizes()
local widgetScale = 1
local xOffset = (32 + (fontSize*0.9))*widgetScale
local yOffset = -((32 - (fontSize*0.9))*widgetScale)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local RectRound, UiElement, UiUnit, bgpadding, elementCorner

local maxWidth = 0
local textBuffer = {}
local textBufferCount = 0

local showStats = false
local showUnitID

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

local weaponDefDisplayData = {}
do
	local trivial = 1
	local infinite = 9e8

	local default = armorTypes.default
	local baseTypes = {
		[armorTypes.default] = true, -- these keys can nil tbh
		[armorTypes.mines]   = true,
		[armorTypes.vtol]    = true,
	}

	local ignoredTypes = {
		[armorTypes.shields]        = true,
		[armorTypes.indestructable] = true, -- misspelled op
	}

	local function sortModifiers(a, b)
		if a == texts.infinite then
			a = 100
		end
		if b == texts.infinite then
			b = 100
		end
		if a == 100 then
			return true
		elseif b == 100 then
			return false
		else
			return a > b
		end
	end

	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.type ~= "Shield" and weaponDef.damages and not weaponDef.customParams.bogus then
			local damages = table.copy(weaponDef.damages)

			-- Aggregate any extra damage sources together.
			local custom = weaponDef.customParams
			if custom.spark_basedamage then
				local sparkDamage = custom.spark_basedamage * custom.spark_forkdamage * custom.spark_maxunits
				for armorType = 0, #armorTypes do
					damages[armorType] = damages[armorType] + sparkDamage
				end
			end
			if custom.speceffect == "split" and WeaponDefNames[custom.def] then
				local splitCount = custom.number or 1
				local splitDamages = WeaponDefNames[custom.def].damages
				for armorType = 0, #armorTypes do
					damages[armorType] = damages[armorType] + splitDamages[armorType] * splitCount
				end
			end
			if custom.cluster and WeaponDefNames[custom.def] then
				local clusterCount = math.sqrt(max(0, custom.number or 5)) -- they do not all hit, misleading to show all in stats
				local clusterDamages = WeaponDefNames[custom.def].damages
				for armorType = 0, #armorTypes do
					damages[armorType] = damages[armorType] + clusterDamages[armorType] * clusterCount
				end
			end

			local baseType = default
			local baseDamage = damages[baseType]
			for armorType in pairs(baseTypes) do
				if armorType and damages[baseType] < damages[armorType] then
					baseType = armorType
					baseDamage = damages[armorType]
				end
			end

			local weaponDisplayData = {
				defaultBurst  = 0,
				defaultDPS    = 0,
				defaultReload = 1,
				useExperience = false,
			}
			weaponDefDisplayData[weaponDefID] = weaponDisplayData

			if baseDamage > trivial then
				weaponDisplayData.useExperience = true

				local salvoSize = weaponDef.salvoSize * weaponDef.projectiles
				local salvoTime = max(1e-9, (weaponDef.stockpile and weaponDef.stockpileTime / simSpeed) or weaponDef.reload)

				weaponDisplayData.defaultBurst = baseDamage * salvoSize
				weaponDisplayData.defaultDPS = baseDamage * salvoSize / salvoTime
				weaponDisplayData.defaultReload = salvoTime

				local baseModifier = 100
				if baseDamage >= infinite then
					baseModifier = texts.infinite
				end

				local modifierGroups = {}
				for armorType = 0, #armorTypes do
					if not ignoredTypes[armorType] then
						local damage = damages[armorType]
						local modifier
						if damage <= trivial then
							modifier = 0
						elseif damage >= infinite then
							modifier = texts.infinite
						else
							modifier = math.round(damage / baseDamage * 100)
						end
						local group = modifierGroups[modifier]
						if not group then
							group = {}
							modifierGroups[modifier] = group
						end
						group[#group+1] = armorTypes[armorType]
					end
				end

				if table.count(modifierGroups) > 1 or baseType ~= default then
					if baseType == default then
						modifierGroups[baseModifier] =  { armorTypes[default] }
					end

					local modifiers = {}
					for modifier in pairs(modifierGroups) do
						modifiers[#modifiers+1] = modifier
					end
					table.sort(modifiers, sortModifiers)
	
					local modifierTexts = {}
					for index = 1, #modifiers do
						local modifier = modifiers[index]
						local armorText = table.concat(modifierGroups[modifier], ", ")
						if type(modifier) == "number" then
							modifier = modifier.."%"
						end
						modifierTexts[#modifierTexts+1] = armorText.." = "..yellow..modifier
					end

					weaponDisplayData.modifiers = table.concat(modifierTexts, white.."; ")
				end
			end
		end
	end
end

------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------

local function DrawText(t1, t2)
	textBufferCount = textBufferCount + 1
	textBuffer[textBufferCount] = {t1,t2,cX+(bgpadding*8),cY}
	cY = cY - fontSize
	maxWidth = max(maxWidth, (font:GetTextWidth(t1)*fontSize) + (bgpadding*10), (font:GetTextWidth(t2)*fontSize)+(fontSize*6.5) + (bgpadding*10))
end

local function DrawTextBuffer()
	local num = #textBuffer
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
	for i=1, num do
		font:Print(textBuffer[i][1], textBuffer[i][3], textBuffer[i][4], fontSize, "o")
		font:Print(textBuffer[i][2], textBuffer[i][3] + (fontSize*6.5), textBuffer[i][4], fontSize, "o")
	end
	font:End()
end

local function GetTeamColorCode(teamID)
	if not teamID then return "\255\255\255\255" end

	local R, G, B = spGetTeamColor(teamID)

	if not R then return "\255\255\255\255" end

	R = floor(R * 255)
	G = floor(G * 255)
	B = floor(B * 255)

	if (R < 11) then R = 11	end -- Note: char(10) terminates string
	if (G < 11) then G = 11	end
	if (B < 11) then B = 11	end

	return "\255" .. char(R) .. char(G) .. char(B)
end

local function GetTeamName(teamID)
	if not teamID then return 'Error:NoTeamID' end

	local _, teamLeader = spGetTeamInfo(teamID,false)
	if not teamLeader then return 'Error:NoLeader' end

	local leaderName = spGetPlayerInfo(teamLeader,false)
    if Spring.GetGameRulesParam('ainame_'..teamID) then
        leaderName = Spring.GetGameRulesParam('ainame_'..teamID)
    end

	if not spec and anonymousMode ~= 'disabled' then
		return anonymousName
	end

	return leaderName or 'Error:NoName'
end

local guishaderEnabled = false	-- not a config var
function RemoveGuishader()
	if guishaderEnabled and WG['guishader'] then
		WG['guishader'].DeleteScreenDlist('unit_stats_title')
		WG['guishader'].DeleteScreenDlist('unit_stats_data')
		guishaderEnabled = false
	end
end

------------------------------------------------------------------------------------
-- Code
------------------------------------------------------------------------------------

local function enableStats()
	showStats = true
end

local function disableStats()
	showStats = false
end

function widget:Initialize()
	texts = Spring.I18N('ui.unitstats')

	widget:ViewResize(vsx,vsy)

	WG['unitstats'] = {}
	WG['unitstats'].showUnit = function(unitID)
		showUnitID = unitID
		showStats = true
	end

	widgetHandler:AddAction("unit_stats", enableStats, nil, "p")
	widgetHandler:AddAction("unit_stats", disableStats, nil, "r")

	if damageStats and damageStats[gameName] and damageStats[gameName].team then
		local rate = 0
		for k, v in pairs (damageStats[gameName].team) do
			if not v == damageStats[gameName].team.games and v.cost and v.killed_cost then
				local compRate = v.killed_cost/v.cost
				if compRate > rate then
					highestUnitDef = k
					rate = compRate
				end
			end
		end
		local scndRate = 0
		for k, v in pairs (damageStats[gameName].team) do
			if not v == damageStats[gameName].team.games and v.cost and v.killed_cost then
				local compRate = v.killed_cost/v.cost
				if compRate > scndRate and k ~= highestUnitDef then
					scndhighestUnitDef = k
					scndRate = compRate
				end
			end
		end
		local thirdRate = 0
		for k, v in pairs (damageStats[gameName].team) do
			if not v == damageStats[gameName].team.games and v.cost and v.killed_cost then
				local compRate = v.killed_cost/v.cost
				if compRate > thirdRate and k ~= highestUnitDef and k ~= scndhighestUnitDef then
					thirdRate = compRate
				end
			end
		end
	end
end

function widget:Shutdown()
	WG['unitstats'] = nil
	RemoveGuishader()
end

function widget:PlayerChanged()
	spec = Spring.GetSpectatingState()
end

function init()
	vsx, vsy = gl.GetViewSizes()
	widgetScale = (1+((vsy-850)/900)) * (0.95+(ui_scale-1)/2.5)
	fontSize = customFontSize * widgetScale

	xOffset = (32 + bgpadding)*widgetScale
	yOffset = -((32 + bgpadding)*widgetScale)
end

local uiSec = 0
function widget:Update(dt)
	uiSec = uiSec + dt
	if uiSec > 0.5 then
		uiSec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
			ui_scale = Spring.GetConfigFloat("ui_scale",1)
			widget:ViewResize(vsx,vsy)
		end
	end
end

function widget:ViewResize(n_vsx,n_vsy)
	vsx,vsy = Spring.GetViewGeometry()
	widgetScale = (1+((vsy-850)/1800)) * (0.95+(ui_scale-1)/2.5)

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiUnit = WG.FlowUI.Draw.Unit

	font = WG['fonts'].getFont(fontFile)

	init()
end

local selectedUnits = Spring.GetSelectedUnits()
if useSelection then
	function widget:SelectionChanged(sel)
		selectedUnits = sel
	end
end


local function drawStats(unitDefID, unitID, mx, my)
	if not mx then
		mx, my = spGetMouseState()
	end
	
	cX = mx + xOffset
	cY = my + yOffset
	cYstart = cY

	cY = cY - (bgpadding/2)

	local titleFontSize = fontSize*1.07
	local cornersize = ceil(bgpadding*0.2)
	cY = cY - 2 * titleFontSize
	textBuffer = {}
	textBufferCount = 0

	local myTeamID = Spring.GetMyTeamID()
	local unitDef = uDefs[unitDefID]

	local isBeingBuilt, buildProgress, unitExperience, unitTeamID
	local maxHP, losRadius, airLosRadius, radarRadius, sonarRadius, jammingRadius, sonarJammingRadius, seismicRadius, armoredMultiple
	if unitID then
		isBeingBuilt, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
		unitExperience = spGetUnitExperience(unitID)
		unitTeamID = spGetUnitTeam(unitID)

		maxHP = select(2,Spring.GetUnitHealth(unitID))
		losRadius = spGetUnitSensorRadius(unitID, 'los') or 0
		airLosRadius = spGetUnitSensorRadius(unitID, 'airLos') or 0
		radarRadius = spGetUnitSensorRadius(unitID, 'radar') or 0
		sonarRadius = spGetUnitSensorRadius(unitID, 'sonar') or 0
		jammingRadius = spGetUnitSensorRadius(unitID, 'radarJammer') or 0
		sonarJammingRadius = spGetUnitSensorRadius(unitID, 'sonarJammer') or 0
		seismicRadius = spGetUnitSensorRadius(unitID, 'seismic') or 0
		armoredMultiple = select(2,Spring.GetUnitArmored(unitID))
	else
		maxHP              = unitDef.health
		losRadius          = unitDef.sightDistance
		airLosRadius       = unitDef.airSightDistance
		radarRadius        = unitDef.radarDistance
		sonarRadius        = unitDef.sonarDistance
		jammingRadius      = unitDef.radarDistanceJam
		sonarJammingRadius = unitDef.sonarDistanceJam
		seismicRadius      = unitDef.seismicDistance
		armoredMultiple    = unitDef.armoredMultiple
	end
	local mass          = unitDef.mass and unitDef.mass or 0
	local paralyzeMult  = tonumber(unitDef.customParams.paralyzemultiplier or 1)
	local size          = unitDef.xsize and unitDef.xsize / 2 or 0
	local transportable = not unitDef.cantBeTransported

	maxWidth = 0

	------------------------------------------------------------------------------------
	-- Units under construction
	------------------------------------------------------------------------------------

	if isBeingBuilt then
		local mCur, mStor, mPull, mInc, mExp, mShare, mSent, mRec = spGetTeamResources(myTeamID, 'metal')
		local eCur, eStor, ePull, eInc, eExp, eShare, eSent, eRec = spGetTeamResources(myTeamID, 'energy')

		local mTotal = unitDef.metalCost
		local eTotal = unitDef.energyCost
		local buildRem = 1 - buildProgress
		local mRem = mTotal * buildRem
		local eRem = eTotal * buildRem
		local mEta = (mRem - mCur) / (mInc + mRec)
		local eEta = (eRem - eCur) / (eInc + eRec)

		DrawText(texts.prog..":", format("%d%%", 100 * buildProgress))
		DrawText(texts.metal..":", format("%d / %d (" .. yellow .. "%d" .. white .. ", %ds)", mTotal * buildProgress, mTotal, mRem, mEta))
		DrawText(texts.energy..":", format("%d / %d (" .. yellow .. "%d" .. white .. ", %ds)", eTotal * buildProgress, eTotal, eRem, eEta))

		cY = cY - fontSize
	end

	------------------------------------------------------------------------------------
	-- Generic information, cost, move, class
	------------------------------------------------------------------------------------

	DrawText(texts.cost..":",
		format(
			metalColor .. '%d' .. white .. ' / ' ..
			energyColor .. '%d' .. white .. ' / ' ..
			buildColor .. '%d', unitDef.metalCost, unitDef.energyCost, unitDef.buildTime
		)
	)

	if not (unitDef.isBuilding or unitDef.isFactory) then
		if not unitID or not Spring.GetUnitMoveTypeData(unitID) then
			DrawText(texts.move..":", format("%.1f / %.1f / %.0f ("..texts.speedaccelturn..")", unitDef.speed, 900 * unitDef.maxAcc, simSpeed * unitDef.turnRate * (180 / 32767)))
		else
			local mData = Spring.GetUnitMoveTypeData(unitID)
			local mSpeed = mData.maxSpeed or unitDef.speed
			local mAccel = mData.accRate or unitDef.maxAcc
			local mTurnRate = mData.baseTurnRate or unitDef.turnRate
			DrawText(texts.move..":", format("%.1f / %.1f / %.0f ("..texts.speedaccelturn..")", mSpeed, 900 * mAccel, simSpeed * mTurnRate * (180 / 32767)))
		end
	end

	if unitDef.buildSpeed > 0 then
		DrawText(texts.build..':', yellow .. unitDef.buildSpeed)
	end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- Sensors and Jamming
	------------------------------------------------------------------------------------

	DrawText(texts.los..':', losRadius .. (airLosRadius > losRadius and format(' ('..texts.airlos..': %d)', airLosRadius) or ''))

	if radarRadius   > 0 then DrawText(texts.radar..':', '\255\77\255\77' .. radarRadius) end
	if sonarRadius   > 0 then DrawText(texts.sonar..':', '\255\128\128\255' .. sonarRadius) end
	if jammingRadius > 0 then DrawText(texts.jammer..':'  , '\255\255\77\77' .. jammingRadius) end
	if sonarJammingRadius > 0 then DrawText(texts.sonarjam..':', '\255\255\77\77' .. sonarJammingRadius) end
	if seismicRadius > 0 then DrawText(texts.seis..':' , '\255\255\26\255' .. seismicRadius) end

	if unitDef.stealth then DrawText(texts.other1..":", texts.stealth) end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- Armor
	------------------------------------------------------------------------------------

	DrawText(texts.armor..":", texts.class .. (Game.armorTypes[unitDef.armorType or 0] or '???'))

	if unitID and unitExperience ~= 0 then
		if maxHP then
			DrawText(texts.exp..":", format("+%d%% "..texts.health, (maxHP/unitDef.health-1)*100))
		end
	end

	if paralyzeMult < 1 then
		if paralyzeMult == 0 then
			DrawText(texts.emp..':', blue .. texts.immune)
		else
			local resist = floor(100 - (paralyzeMult * 100))
			DrawText(texts.emp..':', blue .. resist .. "% " .. white .. texts.resist)
		end
	end

	if maxHP then
		DrawText(texts.open..":", format(texts.maxhp..": %d", maxHP) )
		if armoredMultiple and armoredMultiple ~= 1 then
			DrawText(texts.closed..":", format(" +%d%%, "..texts.maxhp..": %d", (1/armoredMultiple-1) *100,maxHP/armoredMultiple))
		end
	end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- Transportable
	------------------------------------------------------------------------------------

	if transportable and mass > 0 and size > 0 then
		if mass < 751 and size < 4 then -- 3 is t1 transport max size
			DrawText(texts.transportable..':', blue .. texts.transportable_light)
		elseif mass < 100000 and size < 5 then
			DrawText(texts.transportable..':', yellow .. texts.transportable_heavy)
		end
	end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- SPECIAL ABILITIES
	------------------------------------------------------------------------------------

	---- Build Related
	local specabs = ''
	specabs = specabs..((unitDef.canBuild and texts.build..", ") or "")
	specabs = specabs..((unitDef.canAssist and texts.assist..", ") or "")
	specabs = specabs..((unitDef.canRepair and texts.repair..", ") or "")
	specabs = specabs..((unitDef.canReclaim and texts.reclaim..", ") or "")
	specabs = specabs..((unitDef.canResurrect and texts.resurrect..", ") or "")
	specabs = specabs..((unitDef.canCapture and texts.capture..", ") or "")
	---- Radar/Sonar states
	specabs = specabs..((unitDef.canCloak and texts.cloak..", ") or "")
	specabs = specabs..((unitDef.stealth and texts.stealth..",  ") or "")
	---- Attack Related
	specabs = specabs..((unitDef.canAttackWater and texts.waterweapon..", ") or "")
	specabs = specabs..((unitDef.canManualFire and texts.manuelfire..", ") or "")
	specabs = specabs..((unitDef.canStockpile and texts.stockpile..", ") or "")
	specabs = specabs..((unitDef.canParalyze  and texts.paralyzer..", ") or "")
	specabs = specabs..((unitDef.canKamikaze  and texts.kamikaze..", ") or "")

	if (string.len(specabs) > 11) then -- ?
		DrawText(texts.abilities..":", string.sub(specabs, 1, string.len(specabs)-2))
		cY = cY - fontSize
	end

	------------------------------------------------------------------------------------
	-- Weapons
	------------------------------------------------------------------------------------

	local weaponCounts = {}
	local weaponNumbers = {}
	local weaponsUnique = {}
	for i = 1, #unitDef.weapons do
		local wDefID = unitDef.weapons[i].weaponDef
		local wCount = weaponCounts[wDefID]
		if wCount then
			weaponCounts[wDefID] = wCount + 1
		else
			local index = #weaponsUnique + 1
			weaponCounts[wDefID] = 1
			weaponNumbers[index] = i
			weaponsUnique[index] = wDefID
		end
	end

	local selfDWeaponID = WeaponDefNames[unitDef.selfDExplosion].id
	local deathWeaponID = WeaponDefNames[unitDef.deathExplosion].id
	local selfDWeaponIndex
	local deathWeaponIndex
	if select(4, spGetModKeyState()) then
		weaponCounts[selfDWeaponID] = 1
		weaponCounts[deathWeaponID] = 1
		deathWeaponIndex = #weaponsUnique+1
		weaponsUnique[deathWeaponIndex] = deathWeaponID
		selfDWeaponIndex = #weaponsUnique+1
		weaponsUnique[selfDWeaponIndex] = selfDWeaponID
	end

	local totalDPS = 0
	local totalBurst = 0
	for i = 1, #weaponsUnique do
		local weaponNumber = weaponNumbers[i]
		local weaponDefID = weaponsUnique[i]
		local weaponDef = wDefs[weaponDefID]
		local weaponCount = weaponCounts[weaponDefID]
		local weaponName = weaponDef.description or weaponDef.name

		local range = weaponDef.range

		if range > 0 then			
			local isDisintegrator = string.find(weaponDef.name, "disintegrator")
			local isDeathExplosion = i == deathWeaponIndex
			local isSelfDExplosion = i == selfDWeaponIndex

			if weaponCount > 1 then
				DrawText(texts.weap..":", format(yellow .. "%dx" .. white .. " %s", weaponCount, weaponName))
			else
				local displayName = weaponName
				if isDeathExplosion then
					displayName = texts.selfdestruct
				elseif isSelfDExplosion then
					displayName = texts.deathexplosion
				end
				DrawText(texts.weap..":", displayName)
			end

			local burst = weaponDef.salvoSize * weaponDef.projectiles
			local accuracy = weaponDef.accuracy
			local moveError = weaponDef.targetMoveError

			local weaponData = weaponDefDisplayData[weaponDefID]
			local reload = weaponData.defaultReload
			local experience = not (isDeathExplosion or isSelfDExplosion) and unitExperience or 0

			local reloadAlt = reload -- todo: what is this doing
			if i == deathWeaponIndex then
				weaponName = texts.deathexplosion
				reload = 1
				reloadAlt = 1
			elseif i == selfDWeaponIndex then
				weaponName = texts.selfdestruct
				reload = 1
				reloadAlt = unitDef.selfDestructCountdown
			end

			if experience > 0 then
				local reloadState = spGetUnitWeaponState(unitID, weaponNumber, "reloadTimeXP") or
				                    spGetUnitWeaponState(unitID, weaponNumber, "reloadTime")

				local accuracyBonus  = accuracy ~= 0   and (spGetUnitWeaponState(unitID, weaponNumber, "accuracy") / accuracy - 1)          or 0
				local moveErrorBonus = moveError ~= 0  and (spGetUnitWeaponState(unitID, weaponNumber, "targetMoveError") / moveError - 1)  or 0
				local reloadBonus    = reload ~= 0     and (reloadState / reload - 1)                                                       or 0
				local rangeBonus     = range ~= 0      and (spGetUnitWeaponState(unitID, weaponNumber, "range") / range - 1)                or 0

				DrawText(texts.exp..":", format("+%d%% "..texts.accuracy..", +%d%% "..texts.aim..", +%d%% "..texts.firerate..", +%d%% "..texts.range, accuracyBonus*100, moveErrorBonus*100, reloadBonus*100, rangeBonus*100 ))

				range = reload * (1 + rangeBonus)
				reload = reload * (1 + reloadBonus)
				accuracy = accuracy * (1 + accuracyBonus)
				moveError = moveError * (1 + moveErrorBonus)
			end

			do
				local info
				if isDisintegrator then
					info = format("%.2f", reload).."s "..texts.reload..", "..format("%d "..texts.range, range)
				else
					if isDeathExplosion or isSelfDExplosion then
						info = format("%d "..texts.aoe..", %d%% "..texts.edge, weaponDef.damageAreaOfEffect, 100 * weaponDef.edgeEffectiveness)
					else
						info = format("%.2f", reload)..texts.s.." "..texts.reload..", "..format("%d "..texts.range..", %d "..texts.aoe..", %d%% "..texts.edge, range, weaponDef.damageAreaOfEffect, 100 * weaponDef.edgeEffectiveness)
					end
	
					if weaponDef.damages.paralyzeDamageTime > 0 then
						info = format("%s, %ds "..texts.paralyze, info, weaponDef.damages.paralyzeDamageTime)
					end
					if weaponDef.damages.impulseFactor > 0.123 then
						info = format("%s, %d "..texts.impulse, info, weaponDef.damages.impulseFactor*100)
					end
					if weaponDef.damages.craterBoost > 0 then
						info = format("%s, %d "..texts.crater, info, weaponDef.damages.craterBoost*100)
					end
				end
				DrawText(texts.info..":", info)

				if isDisintegrator then
					DrawText(texts.dmg..": ", texts.infinite)
				else
					local damage
					if isDeathExplosion or isSelfDExplosion then
						damage = texts.burst.." = "..(format(yellow .. "%d", weaponData.defaultBurst))..white.."."
					else
						local damageBurst = weaponData.defaultBurst * weaponCount
						local damageRate = weaponData.defaultDPS * weaponCount
						if experience ~= 0 then
							damageRate = damageBurst / reload
						end
						totalDPS = totalDPS + damageRate
						totalBurst = totalBurst + damageBurst

						damage = texts.dps.." = "..(format(yellow .. "%d", damageRate))..white.."; "..texts.burst.." = "..(format(yellow .. "%d", damageBurst))..white.."."
						if weaponCount > 1 then
							damage = damage..white.." ("..texts.each..")"
						end
					end
					DrawText(texts.dmg..":", damage)

					if weaponData.modifiers then
						DrawText(texts.modifiers..":", weaponData.modifiers..'.')
					end
				end
			end

			if weaponDef.metalCost > 0 or weaponDef.energyCost > 0 then
				-- Stockpiling weapons are weird
				-- They take the correct amount of resources overall
				-- They take the correct amount of time
				-- They drain ((simSpeed+2)/simSpeed) times more resources than they should (And the listed drain is real, having lower income than listed drain WILL stall you)
				local drainAdjust = weaponDef.stockpile and (simSpeed+2)/simSpeed or 1

				DrawText(texts.cost..':',
					format(
						metalColor .. '%d' .. white .. ', ' ..
						energyColor .. '%d' .. white .. ' = ' ..
						metalColor .. '-%d' .. white .. ', ' ..
						energyColor .. '-%d' .. white .. ' '..texts.persecond,
						weaponDef.metalCost,
						weaponDef.energyCost,
						drainAdjust * weaponDef.metalCost / reloadAlt,
						drainAdjust * weaponDef.energyCost / reloadAlt
					)
				)
			end

			cY = cY - fontSize
		end
	end

	if totalDPS > 0 then
		DrawText(texts.totaldmg..':', texts.dps.." = "..(format(yellow .. "%d", totalDPS))..white..'; '..texts.burst.." = "..(format(yellow .. "%d", totalBurst))..white..".")
		cY = cY - fontSize
	end

	-- background
	if WG['buildmenu'] and WG['buildmenu'].hoverID ~= nil then
		glColor(0.11,0.11,0.11,0.9)
	else
		glColor(0,0,0,0.66)
	end

	-- correct position when it goes below screen
	if cY < 0 then
		cYstart = cYstart - cY
		local num = #textBuffer
		for i=1, num do
			textBuffer[i][4] = textBuffer[i][4] - (cY/2)
			textBuffer[i][4] = textBuffer[i][4] - (cY/2)
		end
		cY = 0
	end
	-- correct position when it goes off screen
	if cX + maxWidth+bgpadding+bgpadding > vsx then
		local cXnew = vsx-maxWidth-bgpadding-bgpadding
		local num = #textBuffer
		for i=1, num do
			textBuffer[i][3] = textBuffer[i][3] - ((cX-cXnew)/2)
			textBuffer[i][3] = textBuffer[i][3] - ((cX-cXnew)/2)
		end
		cX = cXnew
	end

	local effectivenessRate = ''
	if damageStats and damageStats[gameName] and damageStats[gameName]["team"] and damageStats[gameName]["team"][unitDef.name] and damageStats[gameName]["team"][unitDef.name].cost and damageStats[gameName]["team"][unitDef.name].killed_cost then
		effectivenessRate = "   "..damageStats[gameName]["team"][unitDef.name].killed_cost / damageStats[gameName]["team"][unitDef.name].cost
	end

	-- title
	local text = "\255\190\255\190" .. UnitDefs[unitDefID].translatedHumanName
	if unitID then
		text = text .. "   " ..  grey ..  unitDef.name .. "   #" .. unitID .. "   ".. GetTeamColorCode(unitTeamID or myTeamID) .. GetTeamName(unitTeamID or myTeamID) .. grey .. effectivenessRate
	end
	local backgroundRect = {floor(cX-bgpadding), ceil(cYstart-bgpadding), floor(cX+(font:GetTextWidth(text)*titleFontSize)+(titleFontSize*3.5)), floor(cYstart+(titleFontSize*1.8)+bgpadding)}
	UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], 1,1,1,0, 1,1,0,1, max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
	if WG['guishader'] then
		guishaderEnabled = true
		WG['guishader'].InsertScreenDlist( gl.CreateList( function()
			RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], elementCorner, 1,1,1,0)
		end), 'unit_stats_title')
	end

	-- icon
	if unitID then
		local iconPadding = max(1, floor(bgpadding*0.8))
		glColor(1,1,1,1)
		UiUnit(
			backgroundRect[1]+bgpadding+iconPadding, backgroundRect[2]+iconPadding, backgroundRect[1]+(backgroundRect[4]-backgroundRect[2])-iconPadding, backgroundRect[4]-bgpadding-iconPadding,
			nil,
			1,1,1,1,
			0.13,
			nil, nil,
			'#'..unitDefID
		)
	end

	-- title text
	glColor(1,1,1,1)
	font:Begin()
	font:Print(text, backgroundRect[1]+((backgroundRect[4]-backgroundRect[2])*1.3), backgroundRect[2]+titleFontSize*0.7, titleFontSize, "o")
	font:End()

	-- stats
	UiElement(floor(cX-bgpadding), ceil(cY+(fontSize/3)+(bgpadding*0.3)), ceil(cX+maxWidth+bgpadding), ceil(cYstart-bgpadding), 0,1,1,1, 1,1,1,1, max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))

	if WG['guishader'] then
		guishaderEnabled = true
		WG['guishader'].InsertScreenDlist( gl.CreateList( function()
			RectRound(floor(cX-bgpadding), ceil(cY+(fontSize/3)+(bgpadding*0.3)), ceil(cX+maxWidth+bgpadding), floor(cYstart-bgpadding), elementCorner, 0,1,1,1)
		end), 'unit_stats_data')
	end
	DrawTextBuffer()
end

function widget:DrawScreen()
	if WG['topbar'] and WG['topbar'].showingQuit() then
		return
	end

	if WG['chat'] and WG['chat'].isInputActive then
		if WG['chat'].isInputActive() then
			showStats = false
		end
	end
	if (not showStats and not showUnitID) or spIsUserWriting() then
		RemoveGuishader()
		return
	end

	local unitDefID, unitID, mx, my
	do
		local _, targetDefID = Spring.GetActiveCommand()
		local targetDef = targetDefID and targetDefID < 0 and UnitDefs[-targetDefID]
		if targetDef then
			unitDefID = -targetDefID
		else
			unitDefID = WG['buildmenu'] and WG['buildmenu'].hoverID
			if not unitDefID then
				local selectedID = selectedUnits[1]
				if showUnitID and Spring.ValidUnitID(showUnitID) then
					unitID = showUnitID
					showUnitID = nil -- ?
				elseif useSelection and selectedID and Spring.ValidUnitID(selectedID) then
					unitID = selectedUnits[1]
				else
					mx, my = spGetMouseState()
					local entityType, entityID = spTraceScreenRay(mx, my)
					if entityType == "unit" then
						unitID = entityID
					end
				end
				if unitID then
					unitDefID = spGetUnitDefID(unitID)
				end
			end
		end
		if not unitDefID then
			RemoveGuishader()
			return
		end
	end
	drawStats(unitDefID, unitID, mx, my)
end
