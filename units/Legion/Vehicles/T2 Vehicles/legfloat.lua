return {
	legfloat = {
		maxacc = 0.034,
		maxdec = 0.068,
		buildcostenergy = 14000,
		buildcostmetal = 700,
		buildpic = "LEGFLOAT.DDS",
		buildtime = 16000,
		canmove = true,
		collisionvolumeoffsets = "0 0 0",
		collisionvolumescales = "40 20 50",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		description = "Floating Tank",
		explodeas = "mediumExplosionGeneric",
		footprintx = 3,
		footprintz = 3,
		idleautoheal = 5,
		usepiececollisionvolumes = 1,
		idletime = 1800,
		leavetracks = true,
		maxdamage = 3500,
		maxslope = 10,
		speed = 60,
		maxwaterdepth = 12,
		movementclass = "HOVER3",
		floater = false,
		name = "Triton",
		nochasecategory = "VTOL",
		objectname = "Units/LEGFLOAT.s3o",
		script = "Units/LEGFLOAT.cob",
		seismicsignature = 0,
		selfdestructas = "mediumExplosionGenericSelfd",
		sightdistance = 400,
		trackoffset = 6,
		trackstrength = 5,
		tracktype = "armacv_tracks",
		trackwidth = 36,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 1.8,
		turnrate = 350,
		waterline = 7.5,
		customparams = {
			model_author = "EnderRobo",
			normaltex = "unittextures/leg_normal.dds",
			subfolder = "legvehicles/T2",
			techlevel = 2,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "0 0 -0.5",
				collisionvolumescales = "40 27 60",
				collisionvolumetype = "Box",
				damage = 1800,
				description = "Triton Wreckage",
				featuredead = "HEAP",
				footprintx = 2,
				footprintz = 2,
				height = 20,
				metal = 400,
				object = "Units/legfloat_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "35.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = 1300,
				description = "Triton Heap",
				footprintx = 2,
				footprintz = 2,
				height = 4,
				metal = 160,
				object = "Units/cor2X2D.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:barrelshot-medium",
				[2] = "custom:waterwake-small",
				[3] = "custom:bowsplash-small",
				[4] = "custom:bowsplash-medium",
			},
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
				[1] = "tarmmove",
			},
			select = {
				[1] = "tarmsel",
			},
		},
		weapondefs = {
			legfloat_gauss = {
				areaofeffect = 8,
				avoidfeature = false,
				burnblow = true,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-small",
				impactonly = 1,
				impulseboost = (3/2) * 0.123,
				impulsefactor = (3/2) * 0.123,
				name = "Medium g2g gauss cannon",
				noselfdamage = true,
				range = 600,
				reloadtime = 2.5,
				separation = 1.8,
				nogap = false,
				sizeDecay = 0.06,
				stages = 14,
				alphaDecay = 0.08,
				soundhit = "xplomed2",
				soundhitwet = "splshbig",
				soundstart = "cannhvy1",
				targetmoveerror = 0.2,
				tolerance = 8000,
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 600,
				customparams = {
					overpen = true,
				},
				damage = {
					default = (2/3) * 250,
				},
			},
			legfloat_gauss_explosion = {
				areaofeffect = 36,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.2,
				explosiongenerator = "custom:genericshellexplosion-medium",
				impulseboost = (3/2) * 0.123,
				impulsefactor = (3/2) * 0.123,
				name = "Gauss impact explosion",
				noselfdamage = true,
				weapontype = "Cannon",
				damage = {
					default = (1/3) * 250,
				},
			},
			legfloat_gatling = {
				accuracy = 2,
				areaofeffect = 16,
				avoidfeature = false,
				burst = 10,
				burstrate = 0.075,
				burnblow = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				duration = 0.03,
				edgeeffectiveness = 0.85,
				explosiongenerator = "custom:plasmahit-sparkonly",
				fallOffRate = 0.2,
				firestarter = 0,
				impulseboost = 0.4,
				impulsefactor = 1.5,
				intensity = 0.8,
				name = "Light rotary cannon",
				noselfdamage = true,
				ownerExpAccWeight = 4.0,
				proximitypriority = 1,
				range = 450,
				reloadtime = 0.675,
				rgbcolor = "1 0.95 0.4",
				soundhit = "bimpact3",
				soundhitwet = "splshbig",
				soundstart = "minigun3",
				soundstartvolume = 3,
				sprayangle = 1200,
				thickness = 0.6,
				tolerance = 6000,
				turret = true,
				weapontype = "LaserCannon",
				weaponvelocity = 950,
				damage = {
					default = 6,
					vtol = 9,
					fighters = 9,
					bombers = 9,
				},
			},
		},
		weapons = {
			[1] = {
				def = "LEGFLOAT_GAUSS",
				onlytargetcategory = "SURFACE",
			},
			[2] = {
				def = "LEGFLOAT_GATLING",
				onlytargetcategory = "NOTSUB",
				badTargetCategory = "SURFACE NOTAIR",
			},
		},
	},
}
