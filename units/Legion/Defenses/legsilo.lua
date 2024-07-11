-- The loose goal is to have a nuclear MIRV that's comparable to a single, bigger nuke.
-- IRL spreading the damage out is much more effective than hitting a concentrated target.
-- In BAR, though, that's debatable. Surviving a nuclear strike isn't even a big deal.

local soloAreaDiameter = 1920
local mirvAreaDiameter = soloAreaDiameter / 2

local soloDamage = 11500
local mirvDamage = soloDamage / 1.2

local soloEdgeEffectiveness = 0.45
local mirvEdgeEffectiveness = soloEdgeEffectiveness

local mirvCount = 6
local mirvHasMiddle = true

-- Calc a dispersion radius so that explosions overlap at a given (total) percent effectiveness.
-- This lets you compare multiple small explosions with a single larger explosion for balance.
-- Note, though, that this overlap test occurs at the nearest halfway point between explosions.
-- So, in general, there are areas in-between nukes where the effectiveness can be much lower.

local damageAtOverlap = 2500 -- imo seems to be a good damage baseline
local boundingRadius = 50 -- of a unit that _might_ survive a nuke (solely bc others don't matter)
local overlapEffectiveness = damageAtOverlap / mirvDamage

local function calcDispersionRadius(count, area, edge, rateAtOverlap, middle)
	local areaRadius = area / 2
	local distanceAtOverlap = areaRadius * (2 - rateAtOverlap/2) / (2 - rateAtOverlap * edge) + boundingRadius
	local angleChord = 2 * math.pi / count

	local dispersionRadius
	if not middle then
		-- We get an exact solution
		local chordLength = 2 * distanceAtOverlap
		-- Given c = 2 r sin(θ / 2):
		dispersionRadius = chordLength / (2 * math.sin(angleChord / 2))
	else
		-- We get a weighted average
		-- between dispersionRadius and chordLength
		local countChords = count - 1
		local countRadial = count
		-- with: distanceAtOverlap = (dispersionRadius * countRadial + chordLength * countChords) / (countChords + countRadial)
		--  and: chordLength = 2 * dispersionRadius * sin(θ / 2)
		dispersionRadius = distanceAtOverlap * (countChords + countRadial) / (2 * countChords * math.sin(angleChord / 2) + countRadial)
	end
	return dispersionRadius
end
local dispersionRadius = calcDispersionRadius(mirvCount, mirvAreaDiameter, mirvEdgeEffectiveness, overlapEffectiveness, mirvHasMiddle)

Spring.Echo(string.format(
	'MIRV test for %s:\n' ..
	'    diameter solo       : %.0f\n' ..
	'    diameter mirv, net  : %.0f\n' ..
	'    diameter mirv, each : %.0f\n' ..
	'    dispersion radius   : %.0f',
	"legsilo_mirv", soloAreaDiameter, 2*dispersionRadius+mirvAreaDiameter, mirvAreaDiameter, dispersionRadius
))

return {
	legsilo = {
		maxacc = 0,
		maxdec = 0,
		buildangle = 8192,
		energycost = 82000,
		metalcost = 7700,
		buildpic = "LEGSILO.DDS",
		buildtime = 181000,
		category = "ALL NOTLAND WEAPON NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE EMPABLE",
		collisionvolumeoffsets = "0 18 -2",
		collisionvolumescales = "90 38 84",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		explodeas = "nukeBuilding",
		footprintx = 7,
		footprintz = 7,
		idleautoheal = 5,
		idletime = 1800,
		health = 6200,
		maxslope = 10,
		maxwaterdepth = 0,
		objectname = "Units/LEGSILO.s3o",
		radardistance = 50,
		script = "Units/LEGSILO.cob",
		seismicsignature = 0,
		selfdestructas = "nukeBuildingSelfd",
		sightdistance = 455,
		yardmap = "ooooooooooooooooooooooooooooooooooooooooooooooooo",
		customparams = {
			usebuildinggrounddecal = true,
			buildinggrounddecaltype = "decals/legsilo_aoplane.dds",
			buildinggrounddecalsizey = 10,
			buildinggrounddecalsizex = 10,
			buildinggrounddecaldecayspeed = 30,
			unitgroup = 'nuke',
			model_author = "Tharsy",
			normaltex = "unittextures/leg_normal.dds",
			-- onoffable = true,
			-- onoffname = "mirv",
			removewait = true,
			subfolder = "corbuildings/landdefenceoffence",
			techlevel = 2,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "0.0 -0.0182740600586 2.87522888184",
				collisionvolumescales = "75.0 23.7250518799 77.7504577637",
				collisionvolumetype = "Box",
				damage = 3336,
				featuredead = "HEAP",
				footprintx = 3,
				footprintz = 3,
				height = 20,
				metal = 4672,
				object = "Units/legsilo_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "55.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = 1668,
				footprintx = 3,
				footprintz = 3,
				height = 4,
				metal = 1869,
				object = "Units/cor3X3A.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			pieceexplosiongenerators = {
				[1] = "deathceg2",
				[2] = "deathceg3",
				[3] = "deathceg4",
			},
		},
		sounds = {
			canceldestruct = "cancel2",
			underattack = "warning1",
			cant = {
				[1] = "cantdo4",
			},
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			ok = {
				[1] = "servroc1",
			},
			select = {
				[1] = "servroc1",
			},
		},
		weapondefs = {
			legicbm = {
				areaofeffect = soloAreaDiameter,
				avoidfeature = false,
				avoidfriendly = false,
				cegtag = "NUKETRAIL",
				collideenemy = false,
				collidefeature = false,
				collidefriendly = false,
				commandfire = true,
				craterareaofeffect = soloAreaDiameter,
				craterboost = 2.4,
				cratermult = 1.2,
				edgeeffectiveness = soloEdgeEffectiveness,
				energypershot = 187500,
				explosiongenerator = "custom:newnukecor",
				firestarter = 100,
				flighttime = 400,
				impulseboost = 0.5,
				impulsefactor = 0.5,
				metalpershot = 1500,
				model = "legicbm.s3o",
				name = "Intercontinental Thermonuclear Ballistic Missile",
				range = 72000,
				reloadtime = 30,
				smoketrail = true,
				smokePeriod = 10,
				smoketime = 130,
				smokesize = 28,
				smokecolor = 0.85,
				smokeTrailCastShadow = true,
				soundhit = "nukecor",
				soundhitwet = "nukewater",
				soundstart = "nukelaunch",
				soundhitwetvolume = 56,
				soundstartvolume = 20,
				stockpile = true,
				stockpiletime = 180,
				texture1 = "null",
				texture2 = "railguntrail",
				texture3 = "null",
				targetable = 1,
				tolerance = 4000,
				turnrate = 5500,
				weaponacceleration = 100,
				weapontimer = 5.75,
				weapontype = "StarburstLauncher",
				weaponvelocity = 1600,
				customparams = {
					place_target_on_ground = "true",
					speceffect = "disperse",
					when = "ypos<altitude",
					disperse_altitude = 900,
					disperse_ceg = "genericshellexplosion-medium",
					disperse_def = "legsilo_mirv",
					disperse_middleDef = mirvHasMiddle and "legsilo_mirv" or nil, --
					disperse_momentum = 0.75,
					disperse_number = mirvCount,
					disperse_radius = dispersionRadius,
				},
				damage = {
					commanders = 2500,
					default = soloDamage,
				},
			},
			mirv = {
				areaofeffect = mirvAreaDiameter,
				burnblow = true,
				cegtag = "missiletrailmedium",
				collideenemy = false,
				collidefeature = false,
				collidefriendly = false,
				craterareaofeffect = mirvAreaDiameter,
				craterboost = 2.4,
				cratermult = 1.2,
				edgeeffectiveness = mirvEdgeEffectiveness,
				explosiongenerator = "custom:newnuke",
				firestarter = 100,
				flighttime = 10,
				impulseboost = 0.5,
				impulsefactor = 0.5,
				model = "cormissile.s3o",
				name = "Nuclear MIRV Warhead",
				range = 720,
				smoketrail = true,
				smokePeriod = 4,
				smoketime = 80,
				smokesize = 20,
				smokecolor = 0.75,
				smokeTrailCastShadow = true,
				soundhit = "nukearm",
				soundhitwet = "nukewater",
				soundstart = "packolau",
				soundhitwetvolume = 33,
				soundtrigger = true,
				startvelocity = 100,
				texture1 = "null",
				texture2 = "railguntrail",
				tolerance = 4000,
				-- tracks = true,
				-- turnrate = 3500,
				weaponacceleration = 500,
				weapontimer = 2,
				weapontype = "MissileLauncher",
				weaponvelocity = 1350,
				damage = {
					commanders = 2500 * mirvDamage / soloDamage,
					default = mirvDamage,
				},
			},
			nuclear_launch = {
				areaofeffect = 0,
				avoidfeature = false,
				avoidfriendly = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0,
				impulseboost = 0,
				impulsefactor = 0,
				metalpershot = 0,
				name = "Nuclear Launch",
				range = 0,
				reloadtime = 30,
				soundhit = "nukelaunchalarm",
				soundhitvolume = 50,
				tolerance = 10000,
				turnrate = 10000,
				weaponacceleration = 101,
				weapontimer = 0.1,
				weapontype = "Cannon",
				weaponvelocity = 100,
				damage = {
					default = 0,
				},
			},
		},
		weapons = {
			[1] = {
				def = "LEGICBM",
				onlytargetcategory = "NOTSUB",
			},
			[2] = {
				def = "NUCLEAR_LAUNCH",
				onlytargetcategory = "NOTSUB",
			},
		},
	},
}
