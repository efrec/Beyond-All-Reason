local definitions = {}

local clusterTrail = {
	flame = {
		class      = [[CBitmapMuzzleFlame]],
		count      = 1,
		air        = true,
		ground     = true,
		underwater = true,
		water      = true,
		properties = {
			colormap     = [[0.35 0.45 0.45 0.015
                             0.5 0.5 0.5 0.015
                             0.7 0.7 0.7 0.015
                             0 0 0 0.015]],
			dir          = [[dir]],
			frontoffset  = 0,
			fronttexture = [[glow]],
			length       = -10,
			sidetexture  = [[shot-trail]],
			size         = 2,
			sizegrowth   = -0.2,
			ttl          = 2,
			useairlos    = true,
			castShadow   = true,
		},
	},
	sparks = {
		class      = [[CSimpleParticleSystem]],
		count      = 1,
		air        = true,
		ground     = true,
		water      = true,
		underwater = true,
		properties = {
			airdrag             = 0.67,
			colormap            = [[0.9 0.95 0.97 0.017
                                    0.6 0.65 0.7 0.017
                                    0 0 0 0]],
			directional         = false,
			emitrot             = 25,
			emitrotspread       = 30,
			emitvector          = [[0, 1, 0]],
			gravity             = [[0, -0.15, 0]],
			numparticles        = 1,
			particlelife        = 2,
			particlelifespread  = 0,
			particlesize        = 7,
			particlesizespread  = 0,
			particlespeed       = 0,
			particlespeedspread = 0,
			pos                 = [[0, 0, 0]],
			sizegrowth          = -1.9,
			sizemod             = 1,
			texture             = [[bubbletexture]], -- what?
			useairlos           = true,
		},
	},
}

local fragmentTrail = {
	flame = {
		class      = [[CBitmapMuzzleFlame]],
		count      = 1,
		air        = true,
		ground     = true,
		underwater = true,
		water      = true,
		properties = {
			colormap     = [[0.6 0.6 1 0.04
                             0.65 0.65 1 0.02
                             0.3 0.4 0.8 0.01
                             0 0 0 0.01]],
			dir          = [[dir]],
			frontoffset  = 0,
			fronttexture = [[glow]],
			length       = -10,
			sidetexture  = [[shot-trail]],
			size         = 8,
			sizegrowth   = -0.18,
			ttl          = 3,
			useairlos    = true,
			castShadow   = true,
		},
	},
	sparks = {
		class      = [[CSimpleParticleSystem]],
		count      = 1,
		air        = true,
		ground     = true,
		water      = true,
		underwater = true,
		properties = {
			airdrag             = 0.67,
			colormap            = [[0.9 0.95 0.97 0.017
                                    0.6 0.65 0.9 0.011
                                    0 0 0 0]],
			directional         = false,
			emitrot             = 125,
			emitrotspread       = 30,
			emitvector          = [[0 -1 0]],
			gravity             = [[0, -0.15, 0]],
			numparticles        = [[0.55 r0.7]],
			particlelife        = 4,
			particlelifespread  = 5,
			particlesize        = 7,
			particlesizespread  = 14,
			particlespeed       = 1.5,
			particlespeedspread = 2.0,
			pos                 = [[0, 0, 0]],
			rotParams           = [[-20 r40, -5 r10, -180 r360]],
			sizegrowth          = 1.7,
			sizemod             = 0.9,
			texture             = [[gunshotxl]],
			useairlos           = true,
		},
	},
	dustparticles = {
		air        = true,
		class      = [[CSimpleParticleSystem]],
		count      = 1,
		ground     = true,
		underwater = true,
		water      = true,
		properties = {
			airdrag             = 0.15,
			colormap            = [[0.4 0.66 0.7 0.2
									1 0.74 0.48 0.1
									0.75 0.45 0.25 0.01
									0 0 0 0.01]],
			directional         = false,
			emitrot             = -180,
			emitrotspread       = 15,
			emitvector          = [[1 1 1]],
			gravity             = [[0, -0.011, 0]],
			numparticles        = [[0.5 r0.7]],
			particlelife        = 7,
			particlelifespread  = 9,
			particlesize        = 10,
			particlesizespread  = 25,
			particlespeed       = 0.03,
			particlespeedspread = 0.5,
			rotParams           = [[-10 r20, -10 r20, -180 r360]],
			pos                 = [[0, 0, 0]],
			sizegrowth          = 0.3,
			sizemod             = 1.0,
			texture             = [[randomdots]],
		},
	},
}

-- test: fraggy trail
definitions.fragment_trail = fragmentTrail

return definitions
