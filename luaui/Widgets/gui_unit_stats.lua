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

local spGetActiveCommand = Spring.GetActiveCommand
local spGetModKeyState = Spring.GetModKeyState
local spGetMouseState = Spring.GetMouseState
local spGetMyTeamID = Spring.GetMyTeamID
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamColor = Spring.GetTeamColor
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamResources = Spring.GetTeamResources

local spGetUnitArmored = Spring.GetUnitArmored
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitWeaponState = Spring.GetUnitWeaponState

local spIsUserWriting = Spring.IsUserWriting
local spTraceScreenRay = Spring.TraceScreenRay
local spValidUnitID = Spring.ValidUnitID

local armorTypes = Game.armorTypes
local gameName = Game.gameName
local simSpeed = Game.gameSpeed

local UnitDefs = UnitDefs
local WeaponDefs = WeaponDefs

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

local vsx, vsy = gl.GetViewSizes()
local widgetScale = 1
local xOffset = (32 + (fontSize*0.9))*widgetScale
local yOffset = -((32 - (fontSize*0.9))*widgetScale)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local ui_opacity = max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7))

local RectRound, UiElement, UiUnit, bgpadding, elementCorner

local textBuffer = {}
local cX, cY, cYstart
local maxWidth = 0

local titleRectX1Old = 0
local titleRectX2Old = 0
local titleRectY1Old = 0
local titleRectY2Old = 0
local statsRectX1Old = 0
local statsRectX2Old = 0
local statsRectY1Old = 0
local statsRectY2Old = 0

local showStats = false
local showUnitID

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

local unitAbilitiesMap
local weaponDefDisplayData
local prefixes, formats

------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------

local function DrawText(t1, t2)
	textBuffer[#textBuffer+1] = { t1, t2, cX+(bgpadding*8), cY }
	cY = cY - fontSize
	maxWidth = max(maxWidth, (font:GetTextWidth(t1)*fontSize) + (bgpadding*10), (font:GetTextWidth(t2)*fontSize)+(fontSize*6.5) + (bgpadding*10))
end

local function DrawTextBuffer()
	local font = font
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
	for i = 1, #textBuffer do
		local buffer = textBuffer[i]
		font:Print(buffer[1], buffer[3], buffer[4], fontSize, "o")
		font:Print(buffer[2], buffer[3] + (fontSize*6.5), buffer[4], fontSize, "o")
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

local guishaderIsActive = false
function RemoveGuishader()
	if guishaderIsActive and WG['guishader'] then
		WG['guishader'].DeleteScreenDlist('unit_stats_title')
		WG['guishader'].DeleteScreenDlist('unit_stats_data')
		guishaderIsActive = false
	end
end

local function unitStatsDataClosure()
	RectRound(statsRectX1Old, statsRectY1Old, statsRectX2Old, statsRectY2Old, elementCorner, 0,1,1,1)
end

local function unitStatsTitleClosure()
	RectRound(titleRectX1Old, titleRectY1Old, titleRectX2Old, titleRectY2Old, elementCorner, 1,1,1,0)
end

local function drawStats(unitDefID, unitID, mx, my, hovering)
	if not WG['guishader'] then
		return
	end

	textBuffer = {}
	maxWidth = 0

	cX = mx + xOffset
	cY = my + yOffset
	cYstart = cY

	local titleFontSize = fontSize*1.07
	local cornersize = ceil(bgpadding*0.2)
	cY = cY - 2 * titleFontSize - (bgpadding/2)

	local myTeamID = spGetMyTeamID()
	local unitDef = UnitDefs[unitDefID]

	local isBeingBuilt, buildProgress, unitExperience, unitTeamID
	local maxHP, losRadius, airLosRadius, radarRadius, sonarRadius, jammingRadius, sonarJammingRadius, seismicRadius, armoredMultiple
	if unitID then
		isBeingBuilt, buildProgress = spGetUnitIsBeingBuilt(unitID)
		unitExperience = spGetUnitExperience(unitID)
		unitTeamID = spGetUnitTeam(unitID)
		maxHP              = select(2, spGetUnitHealth(unitID))
		armoredMultiple    = select(2, spGetUnitArmored(unitID))
		losRadius          = spGetUnitSensorRadius(unitID, "los") or 0
		airLosRadius       = spGetUnitSensorRadius(unitID, "airLos") or 0
		radarRadius        = spGetUnitSensorRadius(unitID, "radar") or 0
		sonarRadius        = spGetUnitSensorRadius(unitID, "sonar") or 0
		jammingRadius      = spGetUnitSensorRadius(unitID, "radarJammer") or 0
		sonarJammingRadius = spGetUnitSensorRadius(unitID, "sonarJammer") or 0
		seismicRadius      = spGetUnitSensorRadius(unitID, "seismic") or 0
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

		DrawText(prefixes.prog, format("%d%%", 100 * buildProgress))
		DrawText(prefixes.metal, format(formats.prog, mTotal * buildProgress, mTotal, mRem, mEta))
		DrawText(prefixes.energy, format(formats.prog, eTotal * buildProgress, eTotal, eRem, eEta))

		cY = cY - fontSize
	end

	------------------------------------------------------------------------------------
	-- Generic information, cost, move, class
	------------------------------------------------------------------------------------

	DrawText(prefixes.cost, format(formats.cost, unitDef.metalCost, unitDef.energyCost, unitDef.buildTime))

	if not (unitDef.isBuilding or unitDef.isFactory) then
		local moveData = unitID and Spring.GetUnitMoveTypeData(unitID) or unitDef
		local speed = moveData.maxSpeed or unitDef.speed
		local accel = (moveData.accRate or unitDef.maxAcc or 0) * (simSpeed * simSpeed)
		local turn = (moveData.baseTurnRate or unitDef.turnRate or 0) * (simSpeed * (180 / 32767))
		DrawText(prefixes.move, format(formats.move, speed, accel, turn))
	end

	if unitDef.buildSpeed > 0 then
		DrawText(prefixes.build, yellow..unitDef.buildSpeed)
	end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- Sensors and Jamming
	------------------------------------------------------------------------------------

	DrawText(prefixes.los, losRadius..(airLosRadius > losRadius and format(formats.airLos, airLosRadius) or ''))

	if radarRadius        > 0 then DrawText(prefixes.radar,    '\255\77\255\77'..radarRadius) end
	if sonarRadius        > 0 then DrawText(prefixes.sonar,    blue..sonarRadius) end
	if jammingRadius      > 0 then DrawText(prefixes.jammer,   '\255\255\77\77'..jammingRadius) end
	if sonarJammingRadius > 0 then DrawText(prefixes.sonarjam, '\255\255\77\77'..sonarJammingRadius) end
	if seismicRadius      > 0 then DrawText(prefixes.seis ,    '\255\255\26\255'..seismicRadius) end

	if unitDef.stealth then DrawText(prefixes.other1, texts.stealth) end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- Armor
	------------------------------------------------------------------------------------

	DrawText(prefixes.armor, texts.class.." "..(unitDef.armorType and armorTypes[unitDef.armorType] or '???'))

	if unitID and unitExperience ~= 0 and maxHP then
		DrawText(prefixes.exp, format(formats.health, (maxHP/unitDef.health-1)*100))
	end

	if paralyzeMult < 1 then
		local resist = (paralyzeMult == 0 and texts.immune) or (floor(100-(paralyzeMult*100))..formats.resist)
		DrawText(prefixes.emp, blue..resist)
	end

	if maxHP then
		if armoredMultiple and armoredMultiple ~= 1 then
			DrawText(prefixes.open, format(formats.maxhp, maxHP))
			DrawText(prefixes.closed, format(formats.closed, (1/armoredMultiple-1)*100, maxHP/armoredMultiple))
		else
			DrawText(prefixes.maxhp, format(formats.maxhp, maxHP))
		end
	end

	cY = cY - fontSize

	------------------------------------------------------------------------------------
	-- Transportable
	------------------------------------------------------------------------------------

	if transportable and mass > 0 and size > 0 then
		if mass < 751 and size < 4 then -- 3 is t1 transport max size
			DrawText(prefixes.transportable, formats.transportable_light)
			cY = cY - fontSize
		elseif mass < 100000 and size < 5 then
			DrawText(prefixes.transportable, formats.transportable_heavy)
			cY = cY - fontSize
		end
	end

	------------------------------------------------------------------------------------
	-- Special Abilities
	------------------------------------------------------------------------------------

	local abilities = {}
	local unitAbilitiesMap = unitAbilitiesMap
	for index, propertyName in ipairs(unitAbilitiesMap) do
		if unitDef[propertyName] then
			abilities[#abilities+1] = unitAbilitiesMap[propertyName]
		end
	end
	if #abilities > 0 then
		local abilityText = table.concat(abilities, ", ")
		DrawText(prefixes.abilities, abilityText)
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
		if weaponDefDisplayData[wDefID] then
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
	end

	local selfDWeaponID = WeaponDefNames[unitDef.selfDExplosion].id
	local deathWeaponID = WeaponDefNames[unitDef.deathExplosion].id
	local selfDWeaponIndex, deathWeaponIndex, isExplosiveUnit
	if select(4, spGetModKeyState()) then
		weaponCounts[selfDWeaponID] = 1
		weaponCounts[deathWeaponID] = 1
		deathWeaponIndex = #weaponsUnique+1
		weaponsUnique[deathWeaponIndex] = deathWeaponID
		selfDWeaponIndex = #weaponsUnique+1
		weaponsUnique[selfDWeaponIndex] = selfDWeaponID
		isExplosiveUnit = unitDef.customParams.unitgroup == "explo"
	end

	local totalDPS = 0
	local totalBurst = 0
	for i = 1, #weaponsUnique do
		local weaponDefID = weaponsUnique[i]
		local weaponDef = WeaponDefs[weaponDefID]
		local weaponCount = weaponCounts[weaponDefID]
		local weaponName = weaponDef.description or weaponDef.name

		local range = weaponDef.range

		if range > 0 then
			local isDisintegrator = weaponDef.type == "DGun" and string.find(weaponDef.name, "disintegrator")
			local isDeathExplosion = i == deathWeaponIndex
			local isSelfDExplosion = i == selfDWeaponIndex

			if weaponCount > 1 then
				DrawText(prefixes.weap, format(formats.weap, weaponCount, weaponName))
			else
				local displayName = weaponName
				if isDeathExplosion then
					displayName = texts.selfdestruct
				elseif isSelfDExplosion then
					displayName = texts.deathexplosion
				end
				DrawText(prefixes.weap, displayName)
			end

			local burst = weaponDef.salvoSize * weaponDef.projectiles
			local accuracy = weaponDef.accuracy
			local moveError = weaponDef.targetMoveError

			local weaponData = weaponDefDisplayData[weaponDefID]
			local reload = weaponData.defaultReload
			local experience = (not isDeathExplosion and not isSelfDExplosion) and unitExperience or 0

			if isDeathExplosion then
				weaponName = texts.deathexplosion
				reload = 1
			elseif isSelfDExplosion then
				weaponName = texts.selfdestruct
				reload = 1
			end

			if experience > 0 then
				local weaponNumber = weaponNumbers[i]
				local reloadState = spGetUnitWeaponState(unitID, weaponNumber, "reloadTimeXP") or
				                    spGetUnitWeaponState(unitID, weaponNumber, "reloadTime")

				local accuracyBonus  = accuracy ~= 0   and (spGetUnitWeaponState(unitID, weaponNumber, "accuracy") / accuracy - 1)          or 0
				local moveErrorBonus = moveError ~= 0  and (spGetUnitWeaponState(unitID, weaponNumber, "targetMoveError") / moveError - 1)  or 0
				local rangeBonus     = range ~= 0      and (spGetUnitWeaponState(unitID, weaponNumber, "range") / range - 1)                or 0
				local reloadBonus    = reload ~= 0     and (reloadState / reload - 1)                                                       or 0
				DrawText(prefixes.exp, format(formats.exp, accuracyBonus*100, moveErrorBonus*100, reloadBonus*100, rangeBonus*100))

				range = reload * (1 + rangeBonus)
				reload = reload * (1 + reloadBonus)
				accuracy = accuracy * (1 + accuracyBonus)
				moveError = moveError * (1 + moveErrorBonus)
			end

			local info
			if isDisintegrator then
				info = format("%.2f", reload).."s "..texts.reload..", "..format("%d "..texts.range, range)
			else
				if isDeathExplosion or isSelfDExplosion then
					info = format(formats.deathexplosion, weaponDef.damageAreaOfEffect, 100 * weaponDef.edgeEffectiveness)
				else
					info = format(formats.weapons, reload, range, weaponDef.damageAreaOfEffect, 100 * weaponDef.edgeEffectiveness)
				end

				if weaponDef.damages.paralyzeDamageTime > 0 then
					info = format(formats.paralyzeDamageTime, info, weaponDef.damages.paralyzeDamageTime)
				end
				if weaponDef.damages.impulseFactor > 0.123 then
					info = format(formats.impulseFactor, info, weaponDef.damages.impulseFactor*100)
				end
				if weaponDef.damages.craterBoost > 0 then
					info = format(formats.craterBoost, info, weaponDef.damages.craterBoost*100)
				end
			end
			DrawText(prefixes.info, info)

			if isDisintegrator then
				DrawText(texts.dmg..": ", texts.infinite)
			else
				local damage
				if isDeathExplosion or isSelfDExplosion then
					local damageBurst = weaponData.defaultBurst
					if isExplosiveUnit then
						totalBurst = totalBurst + damageBurst
					end
					damage = format(formats.burst, damageBurst)
				else
					local damageBurst = weaponData.defaultBurst * weaponCount
					local damageRate
					if experience == 0 then
						damageRate = weaponData.defaultDPS * weaponCount
					else
						damageRate = damageBurst / reload
					end
					totalDPS = totalDPS + damageRate
					totalBurst = totalBurst + damageBurst
					damage = format(formats.dps, damageRate, damageBurst)
				end
				DrawText(prefixes.dmg, damage)

				local modifiers = weaponData.modifiers
				if modifiers then
					DrawText(prefixes.modifiers, modifiers..'.')
				end
			end

			if weaponDef.metalCost > 0 or weaponDef.energyCost > 0 then
				-- Stockpiling weapons are weird
				-- They take the correct amount of resources overall
				-- They take the correct amount of time
				-- They drain ((simSpeed+2)/simSpeed) times more resources than they should (And the listed drain is real, having lower income than listed drain WILL stall you)
				local drainAdjust = weaponDef.stockpile and (simSpeed+2)/simSpeed or 1

				DrawText(prefixes.cost,
					format(
						formats.persecond,
						weaponDef.metalCost, weaponDef.energyCost, drainAdjust * weaponDef.metalCost / reload, drainAdjust * weaponDef.energyCost / reload
					)
				)
			end

			cY = cY - fontSize
		end
	end

	local damageTotals
	if totalDPS > 0 then
		damageTotals = format(formats.dps, totalDPS, totalBurst)
	elseif totalBurst > 0 then
		damageTotals = format(formats.burst, totalBurst)
	end
	if damageTotals then
		DrawText(prefixes.totaldmg, damageTotals)
		cY = cY - fontSize
	end

	-- background
	if hovering then
		glColor(0.11,0.11,0.11,0.9)
	else
		glColor(0,0,0,0.66)
	end

	-- correct position when it goes below screen
	if cY < 0 then
		cYstart = cYstart - cY
		local correction = cY / -2
		cY = 0
		for i = 1, #textBuffer do
			local buffer = textBuffer[i]
			buffer[4] = buffer[4] + correction
			buffer[4] = buffer[4] + correction
		end
	end

	-- correct position when it goes off screen
	if cX + maxWidth + bgpadding * 2 > vsx then
		local cXnew = vsx - maxWidth - bgpadding * 2
		local correction = (cX - cXnew) / -2
		for i = 1, #textBuffer do
			local buffer = textBuffer[i]
			buffer[3] = buffer[3] + correction
			buffer[3] = buffer[3] + correction
		end
		cX = cXnew
	end

	-- title
	local title = '\255\190\255\190'..UnitDefs[unitDefID].translatedHumanName
	if unitID then
		title = title.."   "..grey..unitDef.name.."   #"..unitID.."   "..GetTeamColorCode(unitTeamID or myTeamID)..GetTeamName(unitTeamID or myTeamID)
	end
	if damageStats and damageStats[gameName] then
		local unitDefStats = damageStats[gameName][unitDef.name]
		if unitDefStats and unitDefStats.killed_cost and unitDefStats.cost then
			title = title..grey.."   "..unitDefStats.killed_cost / unitDefStats.cost				
		end
	end
	local titleRectX1 = floor(cX-bgpadding)
	local titleRectX2 = floor(cX+(font:GetTextWidth(title)*titleFontSize)+(titleFontSize*3.5))
	local titleRectY1 = ceil(cYstart-bgpadding)
	local titleRectY2 = floor(cYstart+(titleFontSize*1.8)+bgpadding)

	-- stats
	local statsRectX1 = floor(cX-bgpadding)
	local statsRectY1 = ceil(cY+(fontSize/3)+(bgpadding*0.3))
	local statsRectX2 = ceil(cX+maxWidth+bgpadding)
	local statsRectY2 = floor(cYstart-bgpadding)

	titleRectX1Old = titleRectX1
	titleRectX2Old = titleRectX2
	titleRectY1Old = titleRectY1
	titleRectY2Old = titleRectY2
	statsRectX1Old = statsRectX1
	statsRectX2Old = statsRectX2
	statsRectY1Old = statsRectY1
	statsRectY2Old = statsRectY2

	-- It's taken until now to draw anything; we're doing too much for a DrawScreen call.

	UiElement(titleRectX1, titleRectY1, titleRectX2, titleRectY2, 1,1,1,0, 1,1,0,1, ui_opacity)
	WG['guishader'].InsertScreenDlist(gl.CreateList(unitStatsTitleClosure), 'unit_stats_title')

	if unitID then
		local iconPadding = max(1, floor(bgpadding * 0.8))
		glColor(1,1,1,1)
		UiUnit(
			titleRectX1 + bgpadding + iconPadding,
			titleRectY1 + iconPadding,
			titleRectX1 + (titleRectY2 - titleRectY1) - iconPadding,
			titleRectY2 - bgpadding - iconPadding,
			nil,
			1, 1, 1, 1, 0.13,
			nil, nil,
			'#'..unitDefID
		)
	end

	glColor(1,1,1,1)
	font:Begin()
	font:Print(title, titleRectX1+((titleRectY2-titleRectY1)*1.3), titleRectY1+titleFontSize*0.7, titleFontSize, "o")
	font:End()

	UiElement(statsRectX1, statsRectY1, statsRectX2, statsRectY2, 0,1,1,1, 1,1,1,1, ui_opacity)
	WG['guishader'].InsertScreenDlist(gl.CreateList(unitStatsDataClosure), 'unit_stats_data')

	if (not guishaderIsActive) then
		guishaderIsActive = true
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
	widget:LanguageChanged()
	widget:ViewResize(vsx,vsy)

	WG['unitstats'] = {}
	WG['unitstats'].showUnit = function(unitID)
		showUnitID = unitID
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

function widget:LanguageChanged()
	texts = Spring.I18N('ui.unitstats')

	prefixes = {
		abilities     = texts.abilities..":",
		armor         = texts.armor..":",
		build         = texts.build..":",
		closed        = texts.closed..":",
		cost          = texts.cost..':',
		dmg           = texts.dmg..": ",
		emp           = texts.emp..':',
		energy        = texts.energy..":",
		exp           = texts.exp..":",
		info          = texts.info..":",
		jammer        = texts.jammer..':',
		los           = texts.los..":",
		maxhp         = texts.maxhp..":",
		metal         = texts.metal..":",
		modifiers     = texts.modifiers..":",
		move          = texts.move..":",
		open          = texts.open..":",
		other1        = texts.other1..":",
		prog          = texts.prog..":",
		radar         = texts.radar..':',
		seis          = texts.seis..':',
		sonar         = texts.sonar..':',
		sonarjam      = texts.sonarjam..':',
		totaldmg      = texts.totaldmg..':',
		transportable = texts.transportable..':',
		weap          = texts.weap..":",
	}

	formats = {
		prog                = "%d / %d ("..yellow.."%d"..white..", %ds)",
		cost                = metalColor..'%d'..white..' / '..energyColor..'%d'..white..' / '..buildColor..'%d',

		airLos              = ' ('..texts.airlos..': %d)',

		health              = "+%d%% "..texts.health,
		maxhp               = texts.maxhp..": %d",
		closed              = " +%d%%, "..texts.maxhp..": %d",
		resist              = "%"..white.." "..texts.resist,

		move                = "%.1f / %.1f / %.0f ("..texts.speedaccelturn..")",
		transportable_light = blue..texts.transportable_light,
		transportable_heavy = yellow..texts.transportable_heavy,

		weap                = yellow.."%dx"..white.." %s",
		exp                 = "+%d%% "..texts.accuracy..", +%d%% "..texts.aim..", +%d%% "..texts.firerate..", +%d%% "..texts.range,
		deathexplosion      = "%d "..texts.aoe..", %d%% "..texts.edge,
		weapons             = "%.2f"..texts.s.." "..texts.reload..", %d "..texts.range..", %d "..texts.aoe..", %d%% "..texts.edge,
		paralyzeDamageTime  = "%s, %ds "..texts.paralyze,
		impulseFactor       = "%s, %d "..texts.impulse,
		craterBoost         = "%s, %d "..texts.crater,
		burst               = texts.burst.." = "..yellow.."%d"..white..".",
		dps                 = texts.dps.." = "..yellow.."%d"..white.."; "..texts.burst.." = "..yellow.."%d"..white..".",
		persecond           = metalColor..'%d'..white..', '..energyColor..'%d'..white..' = '..metalColor..'-%d'..white..', '..energyColor..'-%d'..white..' '..texts.persecond,
	}

	unitAbilitiesMap = {
		"canBuild",
		"canAssist",
		"canRepair",
		"canReclaim",
		"canResurrect",
		"canCapture",
		"canCloak",
		"stealth",
		"canAttackWater",
		"canManualFire",
		"canStockpile",
		"canParalyze",
		"canKamikaze",
		canBuild       = texts.build,
		canAssist      = texts.assist,
		canRepair      = texts.repair,
		canReclaim     = texts.reclaim,
		canResurrect   = texts.resurrect,
		canCapture     = texts.capture,
		canCloak       = texts.cloak,
		stealth        = texts.stealth,
		canAttackWater = texts.waterweapon,
		canManualFire  = texts.manuelfire,
		canStockpile   = texts.stockpile,
		canParalyze    = texts.paralyzer,
		canKamikaze    = texts.kamikaze,
	}
	for index, name in ipairs(unitAbilitiesMap) do
		if not unitAbilitiesMap[name] then
			Spring.Log(widget:GetInfo().name, LOG.ERROR, "Did not find a translation for ability name = "..name)
			table.remove(unitAbilitiesMap, index)
		end
	end

	weaponDefDisplayData = {}

	local trivial = 1
	local infinite = 9e8
	local default = armorTypes.default or armorTypes.standard or 0 -- armor types can, but shouldn't, be nil
	local baseTypes = {
		[armorTypes.default or -1] = true,
		[armorTypes.mines or -1]   = true,
		[armorTypes.vtol or -1]    = true,
	}
	local ignoredTypes = {
		[armorTypes.shields or -1]        = true,
		[armorTypes.indestructable or -1] = true,
	}

	local function sortModifiers(a, b)
		if a == 100 then
			return true
		elseif b == 100 then
			return false
		end
		if a == texts.infinite then
			a = infinite
		end
		if b == texts.infinite then
			b = infinite
		end
		return a > b
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
			if custom.def then -- shared customparam
				if custom.speceffect == "split" and WeaponDefNames[custom.def] then
					local splitCount = tonumber(custom.number or 1)
					local splitDamages = WeaponDefNames[custom.def].damages
					for armorType = 0, #armorTypes do
						damages[armorType] = damages[armorType] + splitDamages[armorType] * splitCount
					end
				elseif custom.cluster and WeaponDefNames[custom.def] then
					local clusterCount = math.sqrt(max(0, tonumber(custom.number or 5))) -- they do not all hit, misleading to show all in stats
					local clusterDamages = WeaponDefNames[custom.def].damages
					for armorType = 0, #armorTypes do
						damages[armorType] = damages[armorType] + clusterDamages[armorType] * clusterCount
					end
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
				defaultBurst  = 1,
				defaultDPS    = 1,
				defaultReload = 1,
				useExperience = false,
			}
			weaponDefDisplayData[weaponDefID] = weaponDisplayData

			if baseDamage > trivial then
				weaponDisplayData.useExperience = true

				local salvoSize = weaponDef.salvoSize * weaponDef.projectiles
				local salvoTime = max(1e-9, weaponDef.reload, ((weaponDef.stockpileTime or 0) / simSpeed))

				weaponDisplayData.defaultBurst = baseDamage * salvoSize
				weaponDisplayData.defaultDPS = baseDamage * salvoSize / salvoTime
				weaponDisplayData.defaultReload = salvoTime

				local baseModifier = 100
				if baseDamage >= infinite then
					baseModifier = texts.infinite
				end

				local modifierGroups = {}
				local defaultModifier = 100
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
						if armorType == default then
							defaultModifier = modifier
						end
						local group = modifierGroups[modifier]
						if not group then
							group = {}
							modifierGroups[modifier] = group
						end
						group[#group+1] = armorTypes[armorType]
					end
				end
				modifierGroups[defaultModifier] = { armorTypes[default] }

				if table.count(modifierGroups) > 1 or baseType ~= default then
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

function widget:PlayerChanged()
	spec = Spring.GetSpectatingState()
end

local updateSeconds = 0

function widget:Update(dt)
	updateSeconds = updateSeconds + dt
	if updateSeconds > 1 then
		updateSeconds = 0
		local ui_scale_update = Spring.GetConfigFloat("ui_scale", 1)
		if ui_scale ~= ui_scale_update then
			ui_scale = ui_scale_update
			widget:ViewResize(vsx,vsy)
		end
		ui_opacity = max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7))
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

	vsx, vsy = gl.GetViewSizes()
	widgetScale = (1+((vsy-850)/900)) * (0.95+(ui_scale-1)/2.5)
	fontSize = customFontSize * widgetScale

	xOffset = (32 + bgpadding)*widgetScale
	yOffset = -((32 + bgpadding)*widgetScale)
end

local selectedUnits = Spring.GetSelectedUnits()
if useSelection then
	function widget:SelectionChanged(sel)
		selectedUnits = sel
	end
end

function widget:DrawScreen()
	local topbar = WG.topbar
	if topbar and topbar.showingQuit() then
		return
	end

	if showStats then
		local chat = WG.chat
		if (chat and chat.isInputActive()) or spIsUserWriting() then
			showStats = false
			RemoveGuishader()
			return
		end
	else
		RemoveGuishader()
		return
	end

	local unitDefID, unitID, mx, my, hovering
	local targetDefID = (select(2, spGetActiveCommand()) or 0) * -1
	local targetDef = targetDefID and targetDefID > 0 and UnitDefs[targetDefID]
	if targetDef then
		unitDefID = targetDefID
	else
		unitDefID = WG['buildmenu'] and WG['buildmenu'].hoverID
		if unitDefID then
			hovering = true
		else
			local selectedID = selectedUnits[1]
			if showUnitID and spValidUnitID(showUnitID) then
				unitID = showUnitID
				showUnitID = nil
			elseif useSelection and selectedID and spValidUnitID(selectedID) then
				unitID = selectedID
			else
				mx, my = spGetMouseState()
				local entityType, entityID = spTraceScreenRay(mx, my)
				if entityType == "unit" then
					unitID = entityID
				end
			end
			if unitID then
				unitDefID = spGetUnitDefID(unitID)
				if not unitDefID then
				end
			end
		end
	end
	if not unitDefID then
		RemoveGuishader()
		return
	end

	if not mx then
		mx, my = spGetMouseState()
	end

	drawStats(unitDefID, unitID, mx, my, hovering)
	DrawTextBuffer()
end
