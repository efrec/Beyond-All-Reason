
<!--

The rml layout is replacing this previous drawing fn that builds a text buffer
and draws a couple of simple rounded rectangles behind the calculated text area:

local function drawPopover(unitDefID, unitID, expanded)
	local unitDef = getUnitDefSummary(unitDefID)
	local unit = unitID and getUnitCompliment(unitID, unitDef)

	local myTeamID = Spring.GetMyTeamID()
	local isAlliedUnit = unit and Spring.AreTeamsAllied(myTeamID, unit.unitTeam)
	local showExperience = isAlliedUnit and unit.experience > 0

	-- Construction and resource costs

	if isAlliedUnit and unit.isBeingBuilt then
		pushText("prog", ("%d%%"):format(100 * unit.buildProgress))
		pushText("metal", ("%d / %d (%s%d%s, %d%s)"):format(
			unit.metalSpent, unitDef.metalCost,
			yellow, unit.metalUnspent, white,
			unit.metalETA, i18n.s))
		pushText("energy", ("%d / %d (%s%d%s, %d%s)"):format(
			unit.energySpent, unitDef.energyCost,
			yellow, unit.energyUnspent, white,
			unit.energyETA, i18n.s))
	else
		pushText("cost", ("%s%d%s | %s%d%s | %s%d"):format(
			metalColor, unitDef.metalCost, white,
			energyColor, unitDef.energyCost, white,
			buildColor, unitDef.buildTime
		))
	end

	-- Generic unit information

	if unitDef.speed then
		pushText("move", ("%.1f | %.1f | %.0f (%s)"):format(
			unit.speed or unitDef.speed,
			unit.acceleration or unitDef.acceleration,
			unit.turnRate or unitDef.turnRate,
			i18n.speedaccelturn
		))
	end

	if unitDef.buildSpeed then
		pushText("build", yellow .. unitDef.buildSpeed)
	end

	cy = cy - lineHeight

	-- Sensors and jamming

	if unitDef.radiusSight and unitDef.radiusSightAir then
		if unitDef.radiusSightAir > unitDef.radiusSight then
			pushText("los", ("%d ((" .. i18n.airlos .. "): %d)"):format(unitDef.radiusSight, unitDef.radiusSightAir))
		else
			pushText("los", unitDef.radiusSight)
		end
	end

	if unitDef.radiusRadar then pushText("radar", "\255\77\255\77" .. unitDef.radiusRadar) end
	if unitDef.radiusSonar then pushText("sonar", "\255\128\128\255" .. unitDef.radiusSonar) end
	if unitDef.radiusJammingRadar then pushText("jammer", "\255\255\77\77" .. unitDef.radiusJammingRadar) end
	if unitDef.radiusJammingSonar then pushText("sonarjam", "\255\255\77\77" .. unitDef.radiusJammingSonar) end
	if unitDef.radiusSeismicSense then pushText("seis", "\255\255\26\255" .. unitDef.radiusSeismicSense) end
	if unitDef.stealth then pushText("other1", i18n.stealth) end

	cy = cy - lineHeight

	-- Armor and resistance

	if unitDef.healthMax then
		pushText("armor", i18n.class .. " " .. unitDef.armorTypeName)
		if showExperience then
			pushText("exp", ("+%d%%" .. i18n.health):format(
				100 * (unit.healthMax / unitDef.healthMax - 1)
			))
		end
		local healthMax = unit.healthMax or unitDef.healthMax
		if unitDef.armorMultiplier then
			local armorMult = unit.armorMultiplier or unitDef.armorMultiplier
			pushText("open", ("%s = %d"):format(i18n.maxhp, healthMax))
			pushText("closed", ("+%d%% (%s: %d)"):format(100 / armorMult - 100, i18n.maxhp, healthMax / armorMult))
		else
			pushText("maxhp", healthMax)
		end
		if unitDef.paralyzeMultiplier then
			pushText("emp", blue .. (unitDef.paralyzeMultiplier == 0 and
				i18n.immune or
				floor(100 - unitDef.paralyzeMultiplier * 100)
			))
		end
		cy = cy - lineHeight
	end

	-- Transportability

	if unitDef.transportable then
		pushText("transportable", blue .. i18n
			[unitDef.transportableLight and transportable_light or transportable_heavy], 2)
	end

	-- Abilities

	if unitDef.abilityText then
		pushText("abilities", unitDef.abilityText)
	end

	-- Weapons
	-- TODO: "secondary damage" as a +amount in.. orange? possibly?

	if unitDef.weaponSummary then
		for i = 1, #unitDef.weaponSummary do
			local weapon = unitDef.weaponSummary[i]
			local bonus = unit and unit.weapons[i]
			local isDisintegrator = weapon.name:find("disintegrator")
			local isOnDeath = weapon.name == i18n.deathexplosion or weapon.name == i18n.selfdestruct
			if weapon.count == 1 then
				pushText("weap", weapon.name)
			else
				pushText("weap", ("%s%dx%s %s"):format(yellow, weapon.count, white, weapon.name))
			end
			if showExperience and not isOnDeath then
				pushText("exp", ("+%d%% %s, +%d%% %s, +%d%% %s, +%d%% %s"):format(
					i18n.accuracy, bonus.accuracy and bonus.accuracy / weapon.accuracy - 1 or 0,
					i18n.aim, bonus.moveError and bonus.moveError / weapon.moveError - 1 or 0,
					i18n.firerate, bonus.reload and bonus.reload / weapon.reload - 1 or 0,
					i18n.range, bonus.range and bonus.range / weapon.range - 1 or 0
				))
			end
			if isDisintegrator then
				pushText("info",
					("%.2f%s %s, %d %s"):format(bonus.reload or weapon.reload, i18n.s, i18n.reload,
						bonus.range or weapon.range, i18n.range))
				pushText("dmg", i18n.infinite)
			else
				local infoText = {}
				if isOnDeath then
					infoText[#infoText + 1] = ("%d %s, %d%% %s"):format(
						weapon.areaOfEffect, i18n.aoe,
						weapon.edgeEffectiveness, i18n.edge
					)
				elseif weapon.areaOfEffect then
					infoText[#infoText + 1] = ("%.2f%s %s, %d %s, %d %s (%d%% %s)"):format(
						bonus.reload or weapon.reload, i18n.s, i18n.reload,
						bonus.range or weapon.range, i18n.range,
						weapon.areaOfEffect, i18n.aoe,
						weapon.edgeEffectiveness, i18n.edge
					)
				else
					infoText[#infoText + 1] = ("%.2f%s %s, %d %s"):format(
						bonus.reload or weapon.reload, i18n.s, i18n.reload,
						bonus.range or weapon.range, i18n.range
					)
				end
				if weapon.paralyzeDamageTime then
					infoText[#infoText + 1] = ("%d%s %s"):format(weapon.paralyzeDamageTime, i18n.s, i18n.paranlyze)
				end
				if weapon.impulseFactorNet then
					infoText[#infoText + 1] = ("%d%% %s"):format(weapon.impulseFactorNet * 100, i18n.impulse)
				end
				if weapon.craterFactorNet then
					infoText[#infoText + 1] = ("%d%% %s"):format(weapon.craterFactorNet * 100, i18n.crater)
				end
				pushText("info", infoText:concat(", "))
				if isOnDeath then
					pushText("dmg", ("%s = %s%d"):format(i18n.burst, yellow, weapon.displayDamage))
				elseif weapon.count == 1 then
					pushText("dmg", ("%s = %s%d%s; %s = %s%d"):format(
						i18n.dps, yellow, weapon.displayDPS, white,
						i18n.burst, yellow, weapon.displayDamage
					))
				else
					pushText("dmg", ("%s = %s%d%s; %s = %s%d (%s)"):format(
						i18n.dps, yellow, weapon.displayDPS, white,
						i18n.burst, yellow, weapon.displayDamage, i18n.each
					))
				end
			end
			pushText("modifiers", weapon.damageModifiers:concat("; "))
			if weapon.metalCost or weapon.energyCost then

			end
			cy = cy - lineHeight
		end

		-- Damage summary

		pushText("totaldmg", ("%s = %s%d%s; %s = %s%d%s."):format(
			i18n.dps, yellow, unit.displayDPS or unitDef.displayDPS, white,
			i18n.burst, yellow, unit.displayDamage or unitDef.displayDamage, white,
			2
		))
	end

	-- Color and position corrections

	checkDrawingPositions()
	drawTitleArea()
	drawDataArea()
	drawText()
end -->