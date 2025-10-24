local function techsplit_balanceTweaks(name, unitDef)
	if name == "corthud" then
		unitDef.speed = 54
		unitDef.weapondefs.arm_ham.range = 300
		unitDef.weapondefs.arm_ham.predictboost = 0.8
		unitDef.weapondefs.arm_ham.damage = {
			default = 150,
			subs = 50,
			vtol = 15,
		}
		unitDef.weapondefs.arm_ham.reloadtime = 1.73
		unitDef.weapondefs.arm_ham.areaofeffect = 51
	elseif name == "armwar" then
		unitDef.speed = 60
		unitDef.weapondefs.armwar_laser.range = 280
	elseif name == "corstorm" then
		unitDef.speed = 45
		unitDef.weapondefs.cor_bot_rocket.range = 600
		unitDef.weapondefs.cor_bot_rocket.reloadtime = 4.8
		unitDef.weapondefs.cor_bot_rocket.damage.default = 198
		unitDef.weapondefs.cor_bot_rocket.accuracy = 150
		unitDef.health = 385
	elseif name == "armrock" then
		unitDef.speed = 50
		unitDef.weapondefs.arm_bot_rocket.range = 575
		unitDef.weapondefs.arm_bot_rocket.reloadtime = 4.6
		unitDef.weapondefs.arm_bot_rocket.damage.default = 190
		unitDef.health = 390
	elseif name == "armhlt" then
		unitDef.health = 4640
		unitDef.metalcost = 535
		unitDef.energycost = 5700
		unitDef.buildtime = 13700
		unitDef.weapondefs.arm_laserh1.range = 750
		unitDef.weapondefs.arm_laserh1.reloadtime = 2.9
		unitDef.weapondefs.arm_laserh1.damage = {
			commanders = 801,
			default = 534,
			vtol = 48,
		}
	elseif name == "armfhlt" then
		unitDef.health = 7600
		unitDef.metalcost = 570
		unitDef.energycost = 7520
		unitDef.buildtime = 11700
		unitDef.weapondefs.armfhlt_laser.range = 750
		unitDef.weapondefs.armfhlt_laser.reloadtime = 1.45
		unitDef.weapondefs.armfhlt_laser.damage = {
			commanders = 414,
			default = 290,
			vtol = 71,
		}
	elseif name == "corhlt" then
		unitDef.health = 4640
		unitDef.metalcost = 580
		unitDef.energycost = 5700
		unitDef.buildtime = 13800
		unitDef.weapondefs.cor_laserh1.range = 750
		unitDef.weapondefs.cor_laserh1.reloadtime = 1.8
		unitDef.weapondefs.cor_laserh1.damage = {
			commanders = 540,
			default = 360,
			vtol = 41,
		}
	elseif name == "corfhlt" then
		unitDef.health = 7340
		unitDef.metalcost = 580
		unitDef.energycost = 7520
		unitDef.buildtime = 13800
		unitDef.weapondefs.corfhlt_laser.range = 750
		unitDef.weapondefs.corfhlt_laser.reloadtime = 1.5
		unitDef.weapondefs.corfhlt_laser.damage = {
			commanders = 482,
			default = 319,
			vtol = 61,
		}
	elseif name == "armart" then
		unitDef.speed = 65
		unitDef.turnrate = 210
		unitDef.maxacc = 0.018
		unitDef.maxdec = 0.081
		unitDef.weapondefs.tawf113_weapon.accuracy = 150
		unitDef.weapondefs.tawf113_weapon.range = 830
		unitDef.weapondefs.tawf113_weapon.damage = {
			default = 182,
			subs = 61,
			vtol = 20,
		}
		unitDef.weapons[1].maxangledif = 30
	elseif name == "corwolv" then
		unitDef.speed = 62
		unitDef.turnrate = 250
		unitDef.maxacc = 0.015
		unitDef.maxdec = 0.0675
		unitDef.weapondefs.corwolv_gun.accuracy = 150
		unitDef.weapondefs.corwolv_gun.range = 850
		unitDef.weapondefs.corwolv_gun.damage = {
			default = 375,
			subs = 95,
			vtol = 38,
		}
		unitDef.weapons[1].maxangledif = 30
	elseif name == "armmart" then
		unitDef.metalcost = 400
		unitDef.energycost = 5500
		unitDef.buildtime = 7500
		unitDef.speed = 47
		unitDef.turnrate = 120
		unitDef.maxacc = 0.005
		unitDef.health = 750
		unitDef.weapondefs.arm_artillery.accuracy = 75
		unitDef.weapondefs.arm_artillery.areaofeffect = 60
		unitDef.weapondefs.arm_artillery.hightrajectory = 1
		unitDef.weapondefs.arm_artillery.range = 1140
		unitDef.weapondefs.arm_artillery.reloadtime = 3.05
		unitDef.weapondefs.arm_artillery.weaponvelocity = 500
		unitDef.weapondefs.arm_artillery.damage = {
			default = 488,
			subs = 122,
			vtol = 49,
		}
		unitDef.weapons[1].maxangledif = 30
	elseif name == "cormart" then
		unitDef.metalcost = 600
		unitDef.energycost = 6600
		unitDef.buildtime = 6500
		unitDef.speed = 45
		unitDef.turnrate = 100
		unitDef.maxacc = 0.005
		unitDef.weapondefs.cor_artillery = {
			accuracy = 75,
			areaofeffect = 75,
			avoidfeature = false,
			cegtag = "arty-heavy",
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 0.65,
			explosiongenerator = "custom:genericshellexplosion-large-bomb",
			gravityaffected = "true",
			mygravity = 0.1,
			hightrajectory = 1,
			impulsefactor = 0.123,
			name = "PlasmaCannon",
			noselfdamage = true,
			range = 1050,
			reloadtime = 5,
			soundhit = "xplomed4",
			soundhitwet = "splsmed",
			soundstart = "cannhvy2",
			turret = true,
			weapontype = "Cannon",
			weaponvelocity = 349.5354,
			damage = {
				default = 1200,
				subs = 400,
				vtol = 120,
			},
		}
		unitDef.weapons[1].maxangledif = 30
	elseif name == "armfido" then
		unitDef.speed = 74
		unitDef.weapondefs.bfido.range = 500
		unitDef.weapondefs.bfido.weaponvelocity = 400
	elseif name == "cormort" then
		unitDef.metalcost = 325
		unitDef.health = 800
		unitDef.speed = 51
		unitDef.weapondefs.cor_mort.range = 650
		unitDef.weapondefs.cor_mort.reloadtime = 3
		unitDef.weapondefs.cor_mort.areaofeffect = 64
		unitDef.weapondefs.cor_mort.damage = {
			default = 250,
			subs = 83,
			vtol = 25,
		}
	elseif name == "corhrk" then
		unitDef.turnrate = 600
		unitDef.weapondefs.corhrk_rocket.areaofeffect = 128
		unitDef.weapondefs.corhrk_rocket.weapontimer = 4
		unitDef.weapondefs.corhrk_rocket.flighttime = 22
		unitDef.weapondefs.corhrk_rocket.range = 900
		unitDef.weapondefs.corhrk_rocket.weaponvelocity = 600
		unitDef.weapondefs.corhrk_rocket.turnrate = 30000
		unitDef.weapondefs.corhrk_rocket.reloadtime = 8
		unitDef.weapondefs.corhrk_rocket.damage = {
			default = 1200,
			subs = 400,
			vtol = 120,
		}
		unitDef.weapons[1].maindir = "0 0 1"
		unitDef.weapons[1].maxangledif = 60
	elseif name == "armsptk" then
		unitDef.metalcost = 500
		unitDef.speed = 43
		unitDef.health = 450
		unitDef.turnrate = 600
		unitDef.weapondefs.adv_rocket.range = 775
		unitDef.weapondefs.adv_rocket.trajectoryheight = 1
		unitDef.weapondefs.adv_rocket.customparams.overrange_distance = 800
		unitDef.weapondefs.adv_rocket.weapontimer = 8
		unitDef.weapondefs.adv_rocket.flighttime = 4
		unitDef.weapons[1].maxangledif = 45
		unitDef.weapons[1].maindir = "0 0 1"
	elseif name == "corshiva" then
		unitDef.speed = 55
		unitDef.weapondefs.shiva_gun.range = 475
		unitDef.weapondefs.shiva_gun.areaofeffect = 180
		unitDef.weapondefs.shiva_gun.weaponvelocity = 372
		unitDef.weapondefs.shiva_rocket.areaofeffect = 96
		unitDef.weapondefs.shiva_rocket.range = 900
		unitDef.weapondefs.shiva_rocket.reloadtime = 14
		unitDef.weapondefs.shiva_rocket.damage.default = 1500
	elseif name == "armmar" then
		unitDef.health = 3920
		unitDef.weapondefs.armmech_cannon.areaofeffect = 48
		unitDef.weapondefs.armmech_cannon.range = 275
		unitDef.weapondefs.armmech_cannon.reloadtime = 1.25
		unitDef.weapondefs.armmech_cannon.damage = {
			default = 525,
			vtol = 134,
		}
	elseif name == "corban" then
		unitDef.speed = 69
		unitDef.turnrate = 500
		unitDef.weapondefs.banisher.areaofeffect = 180
		unitDef.weapondefs.banisher.range = 400
		unitDef.weapondefs.banisher.weaponvelocity = 864
	elseif name == "armcroc" then
		unitDef.health = 5250
		unitDef.turnrate = 270
		unitDef.weapondefs.arm_triton.reloadtime = 1.5
		unitDef.weapondefs.arm_triton.damage = {
			default = 250,
			subs = 111,
			vtol = 44
		}
		table.removeIf(unitDef.weapons, function(v) return v.def == "ARMCL_MISSILE" end)
	elseif name == "correap" then
		unitDef.speed = 76
		unitDef.turnrate = 250
		unitDef.weapondefs.cor_reap.areaofeffect = 92
		unitDef.weapondefs.cor_reap.damage = {
			default = 150,
			vtol = 48,
		}
		unitDef.weapondefs.cor_reap.range = 305
	elseif name == "armbull" then
		unitDef.health = 6000
		unitDef.metalcost = 1100
		unitDef.weapondefs.arm_bull.range = 400
		unitDef.weapondefs.arm_bull.damage = {
			default = 600,
			subs = 222,
			vtol = 67
		}
		unitDef.weapondefs.arm_bull.reloadtime = 2
		unitDef.weapondefs.arm_bull.areaofeffect = 96
	elseif name == "corsumo" then
		unitDef.weapondefs.corsumo_weapon.range = 750
		unitDef.weapondefs.corsumo_weapon.damage = {
			default = 700,
			vtol = 165,
		}
		unitDef.weapondefs.corsumo_weapon.reloadtime = 1
	elseif name == "corgol" then
		unitDef.speed = 37
		unitDef.weapondefs.cor_gol.damage = {
			default = 1600,
			subs = 356,
			vtol = 98,
		}
		unitDef.weapondefs.cor_gol.reloadtime = 4
		unitDef.weapondefs.cor_gol.range = 700
	elseif name == "armguard" then
		unitDef.health = 6000
		unitDef.metalcost = 800
		unitDef.energycost = 8000
		unitDef.buildtime = 16000
		unitDef.weapondefs.plasma.areaofeffect = 150
		unitDef.weapondefs.plasma.range = 1000
		unitDef.weapondefs.plasma.reloadtime = 2.3
		unitDef.weapondefs.plasma.weaponvelocity = 550
		unitDef.weapondefs.plasma.damage = {
			default = 140,
			subs = 70,
			vtol = 42,
		}
		unitDef.weapondefs.plasma_high.areaofeffect = 150
		unitDef.weapondefs.plasma_high.range = 1000
		unitDef.weapondefs.plasma_high.reloadtime = 2.3
		unitDef.weapondefs.plasma_high.weaponvelocity = 700
		unitDef.weapondefs.plasma_high.damage = {
			default = 140,
			subs = 70,
			vtol = 42,
		}
	elseif name == "corpun" then
		unitDef.health = 6400
		unitDef.metalcost = 870
		unitDef.energycost = 8700
		unitDef.buildtime = 16400
		unitDef.weapondefs.plasma.areaofeffect = 180
		unitDef.weapondefs.plasma.range = 1020
		unitDef.weapondefs.plasma.reloadtime = 2.3
		unitDef.weapondefs.plasma.weaponvelocity = 550
		unitDef.weapondefs.plasma.damage = {
			default = 163,
			lboats = 163,
			subs = 21,
			vtol = 22,
		}
		unitDef.weapondefs.plasma_high.areaofeffect = 180
		unitDef.weapondefs.plasma_high.range = 1020
		unitDef.weapondefs.plasma_high.reloadtime = 2.3
		unitDef.weapondefs.plasma_high.weaponvelocity = 700
		unitDef.weapondefs.plasma_high.damage = {
			default = 163,
			lboats = 163,
			subs = 21,
			vtol = 22,
		}
	elseif name == "armpb" then
		unitDef.health = 3360
		unitDef.weapondefs.armpb_weapon.range = 500
		unitDef.weapondefs.armpb_weapon.reloadtime = 1.2
	elseif name == "corvipe" then
		unitDef.health = 3600
		unitDef.weapondefs.vipersabot.areaofeffect = 96
		unitDef.weapondefs.vipersabot.edgeeffectiveness = 0.8
		unitDef.weapondefs.vipersabot.range = 480
		unitDef.weapondefs.vipersabot.reloadtime = 3
	elseif name == "legapopupdef" then
		unitDef.weapondefs.advanced_riot_cannon.range = 480
		unitDef.weapondefs.advanced_riot_cannon.reloadtime = 1.5
		unitDef.weapondefs.standard_minigun.range = 400
	elseif name == "legmg" then
		unitDef.weapondefs.armmg_weapon.range = 650
	end

	return unitDef
end

return {
	techsplit_balanceTweaks = techsplit_balanceTweaks,
}
