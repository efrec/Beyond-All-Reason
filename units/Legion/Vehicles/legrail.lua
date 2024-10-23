return {
	legrail = {
		maxacc = 0.0236,
		airsightdistance = 900,
		maxdec = 0.08,
		energycost = 4000,
		metalcost = 260,
		buildpic = "LEGRAIL.DDS",
		buildtime = 4000,
		canmove = true,
		collisionvolumeoffsets = "0 7 4",
		collisionvolumescales = "37 39 40",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		explodeas = "mediumexplosiongeneric",
		footprintx = 3,
		footprintz = 3,
		idleautoheal = 5,
		idletime = 1800,
		leavetracks = true,
		health = 1100,
		maxslope = 16,
		speed = 43.5,
		maxwaterdepth = 12,
		movementclass = "TANK3",
		name = "Railgun",
		objectname = "Units/LEGRAIL.s3o",
		script = "Units/LEGRAIL.cob",
		seismicsignature = 0,
		selfdestructas = "mediumExplosionGenericSelfd",
		sightdistance = 525,
		trackoffset = -7,
		trackstrength = 5,
		tracktype = "armbull_tracks",
		trackwidth = 32,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 1.056,
		turnrate = 250,
		usepiececollisionvolumes = 1,
		customparams = {
			unitgroup = 'weaponaa',
			model_author = "Tharsis",
			normaltex = "unittextures/leg_normal.dds",
			subfolder = "ArmVehicles",
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "1.01370239258 -1.0546875e-05 -0.0623321533203",
				collisionvolumescales = "34.0520019531 26.7133789063 42.7676696777",
				collisionvolumetype = "Box",
				damage = 639,
				featuredead = "HEAP",
				footprintx = 3,
				footprintz = 3,
				height = 20,
				metal = 180,
				object = "Units/legrail_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "55.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = 320,
				footprintx = 3,
				footprintz = 3,
				height = 4,
				metal = 80,
				object = "Units/arm3X3D.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:rocketflare",
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
				[1] = "veht1aaok",
			},
			select = {
				[1] = "veht1aasel",
			},
		},
		weapondefs = {
			railgun = {
				areaofeffect = 16,
				avoidfeature = false,
				burnblow = true,
				cegtag = "railgun",
				collisionsize = 0.7,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				duration = 0.12,
				edgeeffectiveness = 0.85,
				explosiongenerator = "custom:plasmahit-sparkonly",
				firestarter = 0,
				hardstop = true,
				impulseboost = 0.4,
				impulsefactor = 1,
				intensity = 0.8,
				name = "Railgun",
				noexplode = true,
				noselfdamage = true,
				ownerExpAccWeight = 4.0,
				proximitypriority = 1,
				range = 650,
				reloadtime = 8,
				rgbcolor = "0.34 0.64 0.94",
				soundhit = "mavgun3",
				soundhitwet = "splshbig",
				soundstart = "lancefire",
				soundstartvolume = 13,
				thickness = 2,
				tolerance = 6000,
				turret = true,
				weapontype = "LaserCannon",
				weaponvelocity = 3240,
				customparams = {
					overpenetrate = true,
				},
				damage = {
					commanders = 100,
					default = 200,
					vtol = 400,
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "NOTAIR",
				def = "RAILGUN",
				maindir = "0 0.5 1",
				maxangledif = 210,
				onlytargetcategory = "NOTSUB",
			},
		},
	},
}
