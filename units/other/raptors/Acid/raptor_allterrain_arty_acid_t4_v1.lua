return {
	raptor_allterrain_arty_acid_t4_v1 = {
		maxacc = 0.115,
		maxdec = 0.414,
		energycost = 12320,
		metalcost = 396,
		builder = false,
		buildpic = "raptors/raptoracidartyxl.DDS",
		buildtime = 6750,
		canattack = true,
		canguard = true,
		canmove = true,
		canpatrol = true,
		canstop = "1",
		capturable = false,
		category = "BOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE RAPTOR EMPABLE",
		collisionvolumeoffsets = "0 1 0",
		collisionvolumescales = "60 34 80",
		collisionvolumetype = "box",
		defaultmissiontype = "Standby",
		explodeas = "LOBBER_MORPH",
		footprintx = 3,
		footprintz = 3,
		hidedamage = 1,
		idleautoheal = 20,
		idletime = 300,
		leavetracks = true,
		maneuverleashlength = "640",
		mass = 4000,
		health = 8000,
		maxslope = 18,
		speed = 84.0,
		maxwaterdepth = 0,
		movementclass = "RAPTORALLTERRAINBIGHOVER",
		noautofire = false,
		nochasecategory = "VTOL SPACE",
		objectname = "Raptors/raptor_artillery_meteor_v2_acid.s3o",
		script = "Raptors/raptor_artillery_v2.cob",
		seismicsignature = 0,
		selfdestructas = "LOBBER_MORPH",
		side = "THUNDERBIRDS",
		sightdistance = 1000,
		smoothanim = true,
		trackoffset = 6,
		trackstrength = 3,
		trackstretch = 1,
		tracktype = "RaptorTrack",
		trackwidth = 30,
		turninplace = true,
		turninplaceanglelimit = 90,
		turnrate = 1840,
		unitname = "raptor_allterrain_arty_acid_t4_v1",
		upright = false,
		workertime = 0,
		waterline = 10,
		customparams = {
			subfolder = "other/raptors",
			model_author = "KDR_11k, Beherith",
			normalmaps = "yes",
			normaltex = "unittextures/chicken_s_normals.png",
			timed_area_deathexplosion = {
				ceg = "acid-area-150",
				damageCeg = "acid-damage-gen",
				time = 10,
				damage = 100,
				range = 150,
				resistance = "_RAPTORACID_",
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:blood_spray",
				[2] = "custom:blood_explode",
				[3] = "custom:dirt",
			},
			pieceexplosiongenerators = {
				[1] = "blood_spray",
				[2] = "blood_spray",
				[3] = "blood_spray",
			},
		},
		weapondefs = {
			acidspit = {
				accuracy = 2048,
				areaofeffect = 150,
				collidefriendly = 0,
				collidefeature = 0,
				avoidfeature = 0,
				avoidfriendly = 0,
				burst = 4,
				burstrate = 0.001,
				cegtag = "blob_trail_green",
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.63,
				explosiongenerator = "custom:acid-explosion-xl",
				impulseboost = 0,
				impulsefactor = 0,
				intensity = 0.7,
				interceptedbyshieldtype = 1,
				name = "GOOLAUNCHER",
				noselfdamage = true,
				nogap = false,
				size = 9,
				sizedecay = 0.04,
				alphaDecay = 0.18,
				stages = 8,
				proximitypriority = -4,
				range = 2000,
				reloadtime = 20,
				rgbcolor = "0.8 0.99 0.11",
				soundhit = "bloodsplash3",
				soundstart = "alien_bombrel",
				sprayangle = 2048,
				tolerance = 5000,
				turret = true,
				weapontype = "Cannon",
				weapontimer = 0.2,
				weaponvelocity = 520,
				customparams = {
					timed_area_weapon = {
						ceg = "acid-area-150",
						damageCeg = "acid-damage-gen",
						time = 10,
						damage = 200,
						range = 150,
						resistance = "_RAPTORACID_",
					},
				},
				damage = {
					default = 1,
					shields = 320,
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "MOBILE",
				def = "acidspit",
				maindir = "0 0 1",
				maxangledif = 50,
				onlytargetcategory = "NOTAIR",
			},
		},
	},
}
