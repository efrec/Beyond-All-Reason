return {
	raptor_land_swarmer_acids_t2_v1 = {
		maxacc = 0.1725,
		maxdec = 0.345,
		energycost = 53,
		metalcost = 25,
		builder = false,
		buildpic = "raptors/raptoracidswarmer.DDS",
		buildtime = 900,
		canattack = true,
		canguard = true,
		canmove = true,
		canpatrol = true,
		canstop = "1",
		capturable = false,
		category = "BOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE RAPTOR EMPABLE",
		collisionvolumeoffsets = "0 -3 -3",
		collisionvolumescales = "18 40 40",
		collisionvolumetype = "box",
		defaultmissiontype = "Standby",
		explodeas = "BUG_DEATH_ACID",
		floater = false,
		footprintx = 1.5,
		footprintz = 1.5,
		leavetracks = true,
		maneuverleashlength = 640,
		mass = 30,
		health = 1110,
		maxslope = 18,
		speed = 81.0,
		maxwaterdepth = 0,
		movementclass = "RAPTORSMALLHOVER",
		noautofire = false,
		nochasecategory = "VTOL SPACE",
		objectname = "Raptors/raptoracidswarmer.s3o",
		script = "Raptors/raptor1.cob",
		seismicsignature = 0,
		selfdestructas = "BUG_DEATH_ACID",
		side = "THUNDERBIRDS",
		sightdistance = 300,
		smoothanim = true,
		trackoffset = 0,
		trackstrength = 3,
		trackstretch = 1,
		tracktype = "RaptorTrack",
		trackwidth = 18,
		turninplace = true,
		turninplaceanglelimit = 90,
		turnrate = 1840,
		unitname = "raptore1",
		upright = false,
		waterline = 16,
		workertime = 0,
		customparams = {
			subfolder = "other/raptors",
			model_author = "KDR_11k, Beherith",
			normalmaps = "yes",
			normaltex = "unittextures/chicken_s_normals.png",
			paralyzemultiplier = 0,
			timed_area_ceg = "acid-area-75",
			timed_area_damageCeg = "acid-damage-gen",
			timed_area_time = 10,
			timed_area_damage = 40,
			timed_area_range = 75,
			timed_area_resistance = "_RAPTORACID_",
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
				accuracy = 1024,
				areaofeffect = 75,
				collidefriendly = 0,
				collidefeature = 0,
				avoidfeature = 0,
				avoidfriendly = 0,
				burst = 2,
				burstrate = 0.3,
				cegtag = "blob_trail_green",
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.63,
				explosiongenerator = "custom:acid-explosion-small",
				impulseboost = 0,
				impulsefactor = 0.4,
				intensity = 0.7,
				interceptedbyshieldtype = 1,
				name = "GOOLAUNCHER",
				noselfdamage = true,
				range = 300,
				reloadtime = 5,
				rgbcolor = "0.8 0.99 0.11",
				nogap = false,
				size = 7,
				sizedecay = 0.05,
				alphaDecay = 0.15,
				stages = 7,
				soundhit = "bloodsplash3",
				soundstart = "alien_bombrel",
				sprayangle = 128,
				tolerance = 5000,
				turret = true,
				weapontimer = 0.2,
				weaponvelocity = 520,
				customparams = {
					timed_area_ceg = "acid-area-75",
					timed_area_damageCeg = "acid-damage-gen",
					timed_area_time = 10,
					timed_area_damage = 40,
					timed_area_range = 75,
					timed_area_resistance = "_RAPTORACID_",
				},
				damage = {
					default = 1, --damage done in unit_area_timed_damage.lua
					shields = 80,
				},
			},
		},
		weapons = {
			[1] = {
				def = "acidspit",
				maindir = "0 0 1",
				maxangledif = 180,
				onlytargetcategory = "NOTAIR",
			},
		},
	},
}
