return {
	armlroy = {
		acceleration = 1.81*1.25/60,
		activatewhenbuilt = true,
		brakerate = 1.81*1.25/1200,
		buildangle = 16384,
		buildcostenergy = 14200,
		buildcostmetal = 1300,
		buildpic = "ARMLROY.DDS",
		buildtime = 24000,
		canmove = true,
		category = "ALL NOTLAND MOBILE WEAPON NOTSUB SHIP NOTAIR NOTHOVER SURFACE CAPITALSHIP",
		collisionvolumeoffsets = "0 -13 -3",
		collisionvolumescales = "43 43 96",
		collisionvolumetype = "CylZ",
		corpse = "DEAD",
		description = "Laser Destroyer (Good vs Corvettes and Light Boats)",
		energymake = 2,
		energyuse = 2,
		explodeas = "mediumExplosionGeneric",
		floater = true,
		footprintx = 3,
		footprintz = 6,
		icontype = "sea",
		idleautoheal = 5,
		idletime = 1800,
		maxdamage = 4000,
		maxvelocity = 1.81*1.25,
		minwaterdepth = 12,
		movementclass = "BOATDESTROYER3X6",
		pushResistant = true,
		name = "Poker",
		nochasecategory = "VTOL",
		objectname = "ARMLROY",
		seismicsignature = 0,
		selfdestructas = "mediumExplosionGeneric",
		sightdistance = 0.8 *1200,
		turninplaceanglelimit = 10,
		turninplacespeedlimit = 1.87374,
		turnrate = 80,
		waterline = 4.5,
		customparams = {
			
		},
		featuredefs = {
			dead = {
				blocking = false,
				category = "corpses",
				collisionvolumeoffsets = "0.164245605469 8.02001953204e-06 -0.56591796875",
				collisionvolumescales = "38.5542297363 46.44581604 100.6425476074",
				collisionvolumetype = "Box",
				damage = 1545,
				description = "Poker Wreckage",
				energy = 0,
				featuredead = "HEAP",
				footprintx = 3,
				footprintz = 6,
				height = 4,
				hitdensity = 100,
				metal = 650,
				object = "ARMROY_DEAD",
				reclaimable = true,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
			heap = {
				blocking = false,
				category = "heaps",
				damage = 2016,
				description = "Poker Heap",
				energy = 0,
				footprintx = 5,
				footprintz = 5,
				height = 4,
				hitdensity = 100,
				metal = 325,
				object = "5X5B",
				reclaimable = true,
				resurrectable = 0,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
		},
		sfxtypes = { 
 			pieceExplosionGenerators = { 
				"deathceg2",
				"deathceg3",
				"deathceg4",
			},
			explosiongenerators = {
				[1] = "custom:barrelshot-small",
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
				[1] = "sharmmov",
			},
			select = {
				[1] = "sharmsel",
			},
		},
		weapondefs = {
		hlaser = {
				areaofeffect = 14,
				avoidfeature = false,
				beamtime = 0.15,
				corethickness = 0.2,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				energypershot = 75,
				explosiongenerator = "custom:laserhit-medium-green",
				firestarter = 90,
				impactonly = 1,
				impulseboost = 0,
				impulsefactor = 0,
				laserflaresize = 10,
				name = "HighEnergyLaser",
				noselfdamage = true,
				range = 0.8 * 400,
				reloadtime = 2,
				rgbcolor = "0 1 0",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundhitwetvolume = 0.5,
				soundstart = "Lasrmas2",
				soundtrigger = 1,
				targetmoveerror = 0.2,
				thickness = 1.5,
				tolerance = 10000,
				turret = true,
				weapontype = "BeamLaser",
				weaponvelocity = 2250,
				damage = {
					bombers = 18,
					commanders = 350,
					default = 200,
					fighters = 18,
					subs = 2,
					vtol = 18,
					scouts = 1000,
					corvettes = 500,
					destroyers = 10,
					cruisers = 10,
					carriers = 10,
					flagships = 10,
					battleships = 10,
				},
			},
		beamlaser = {
				areaofeffect = 8,
				avoidfeature = false,
				beamtime = 3,
				corethickness = 0.500,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				energypershot = 6,
				explosiongenerator = "custom:laserhit-small-blue",
				firestarter = 30,
				impactonly = 1,
				impulseboost = 0,
				impulsefactor = 0,
				laserflaresize = 12,
				name = "BeamLaser",
				noselfdamage = true,
				range = 0.8 * 400,
				reloadtime = 7,
				rgbcolor = "0 0 1",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundhitwetvolume = 0.5,
				soundstart = "beamershot",
				soundtrigger = 1,
				targetmoveerror = 0.05,
				thickness = 4.8,
				tolerance = 10000,
				turret = true,
				weapontype = "BeamLaser",
				weaponvelocity = 1000,
				damage = {
					bombers = 1,
					commanders = 640,
					default = 640,
					fighters = 1,
					subs = 1,
					vtol = 1,
					scouts = 32000,
					corvettes = 16000,
					destroyers = 320,
					cruisers = 320,
					carriers = 320,
					flagships = 320,
					battleships = 320,
				},
			},
		
		decklaser = {
				areaofeffect = 8,
				avoidfeature = false,
				beamtime = 0.01,
				beamttl = 20,
				beamdecay = 0.8,
				corethickness = 0.1,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				duration = 0.02,
				energypershot = 3,
				explosiongenerator = "custom:laserhit-small-green",
				firestarter = 50,
				impactonly = 1,
				impulseboost = 0,
				impulsefactor = 0,
				laserflaresize = 5,
				name = "Laser",
				noselfdamage = true,
				range = 0.8 * 240,
				reloadtime = 2,
				rgbcolor = "0 1 1",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundhitwetvolume = 0.5,
				soundstart = "lasrfir1",
				soundtrigger = 1,
				targetmoveerror = 0.2,
				thickness = 1,
				tolerance = 10000,
				turret = true,
				weapontype = "BeamLaser",
				weaponvelocity = 750,
				damage = {
					bombers = 1,
					default = 100,
					fighters = 1,
					subs = 1,
					vtol = 1,
					scouts = 500,
					corvettes = 250,
					destroyers = 5,
					cruisers = 5,
					carriers = 5,
					flagships = 5,
					battleships = 5,
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "VTOL SUBMARINE CAPITALSHIP",
				def = "BEAMLASER",
				maindir = "0 0 1",
				maxangledif = 90,
				onlytargetcategory = "SURFACE",
			},
			[2] = {
				badtargetcategory = "VTOL SUBMARINE CAPITALSHIP",
				def = "HLASER",
				maindir = "0 0 1",
				maxangledif = 270,
				onlytargetcategory = "SURFACE",
			},
			[3] = {
				badtargetcategory = "VTOL SUBMARINE CAPITALSHIP",
				def = "HLASER",
				onlytargetcategory = "SURFACE",
			},
			[4] = {
				badtargetcategory = "VTOLT SUBMARINE CAPITALSHIP",
				def = "DECKLASER",
				maindir = "1 0 1",
				maxangledif = 200,
				onlytargetcategory = "SURFACE",
			},
			[5] = {
				badtargetcategory = "VTOL SUBMARINE CAPITALSHIP",
				def = "DECKLASER",
				maindir = "1 0 -1",
				maxangledif = 200,
				onlytargetcategory = "SURFACE",
			},
			[6] = {
				badtargetcategory = "VTOL SUBMARINE CAPITALSHIP",
				def = "DECKLASER",
				maindir = "-1 0 1",
				maxangledif = 200,
				onlytargetcategory = "SURFACE",
			},
			[7] = {
				badtargetcategory = "VTOL SUBMARINE CAPITALSHIP",
				def = "DECKLASER",
				maindir = "-1 0 -1",
				maxangledif = 200,
				onlytargetcategory = "SURFACE",
			},
		},
	},
}
