-- Effects for Fire / Flames / Napalm
local definitions = {

["fire-incinerator"] = {
     usedefaultexplosions = false,
     burned_area = {
       air                = true,
       class              = [[CBitmapMuzzleFlame]],
       count              = 1,
       ground             = true,
       underwater         = 1,
       water              = true,
       properties = {
         colormap           = [[0 0 0 0.1   0.08 0.06 0.06 0.2   0.12 0.1 0.1 0.75      0.12 0.1 0.1 0.80   0.12 0.1 0.1 0.80    0.12 0.1 0.1 0.80    0.11 0.08 0.08 0.45   0.10 0.07 0.07 0.2   0.08 0.06 0.06 0.2   0 0 0 0.1]],
         dir                = [[0, 1, 0]],
         frontoffset        = 0,
         fronttexture       = [[bloodcentersplatshwhite]],
         length             = 5,
         sidetexture        = [[none]],
         size               = [[21 r11]],
         sizegrowth         = 0.1,
         ttl                = 83,
         pos                = [[0, 4, 0]],
         rotParams          = [[0, 0, -180 r360]],
         alwaysvisible      = true,
         drawOrder          = -2,
         --castShadow         = true,
       },
     },
    fireflamearea = {
             air                = true,
             class              = [[CExpGenSpawner]],
             count              = 1, --60
             ground             = true,
             water              = true,
             underwater         = true,
             properties = {
                 delay              = [[0 r50]],
                 explosiongenerator = [[custom:fire-flames-small]],
                 pos                = [[-18 r36, 0 r10, -18 r36]],
                 --alwaysvisible      = true,
            },
        },
    fireflameground = {
             air                = true,
             class              = [[CExpGenSpawner]],
             count              = 1, --60
             ground             = true,
             water              = true,
             underwater         = true,
             properties = {
                 delay              = [[0 r50]],
                 explosiongenerator = [[custom:fire-burnground-small]],
                 pos                = [[-15 r30, 0 r5, -15 r30]],
                 --alwaysvisible      = true,
            },
        },
    fireburngroundcircle = {
          air                = false,
          class              = [[CBitmapMuzzleFlame]],
          count              = 0,
          ground             = true,
          underwater         = true,
          water              = true,
          properties = {
            --colormap           = [[0 0 0 0   0.06 0.04 0.02 0.006   0.10 0.08 0.04 0.008   0.18 0.12 0.08 0.010   0.4 0.35 0.3 0.15  0.18 0.12 0.08 0.010   0.10 0.08 0.04 0.005    0.06 0.04 0.02 0.004    0 0 0 0.01]],
            colormap           = [[0 0 0 0.01   0.40 0.40 0.48 0.12   0.67 0.69 0.9 0.85   0.64 0.67 0.79 0.55   0.68 0.78 0.88 0.85   0.02 0.02 0.03 0.44   0.026 0.026 0.026 0.40   0.02 0.02 0.02 0.30   0.023 0.023 0.023 0.38   0 0 0 0.03   0 0 0 0.01]],
            dir                = [[0, 1, 0]],
            --gravity            = [[0.0, 0.1, 0.0]],
            frontoffset        = 0,
            fronttexture       = [[FireBall02-anim]],
            animParams         = [[8,8,80 r50]],
            length             = 0,
            sidetexture        = [[none]],
            size               = [[10 r5]],
            sizegrowth         = [[-0.5 r2.2]],
            ttl                = 135,
            pos                = [[0, 8, 0]],
            rotParams          = [[-2 r4, -2 r4, -180 r360]],
            drawOrder          = 0,
            castShadow         = true,
          },
        },
   },

["fire-area-75"] = {
     usedefaultexplosions = false,
    fireflamearea = {
             class              = [[CExpGenSpawner]],
             count              = 1, -- 10 --60
             air                = true,
             ground             = true,
             water              = true,
             underwater         = true,
             properties = {
                 delay              = [[0]],
                 explosiongenerator = [[custom:fire-flames]],
                 pos                = [[-18 r36, 0 r10, -18 r36]],
            },
        },
    fireflameground = {
             class              = [[CExpGenSpawner]],
             count              = 1, --60
             air                = true,
             ground             = true,
             water              = true,
             underwater         = true,
             properties = {
                 delay              = [[r12]],
                 explosiongenerator = [[custom:fire-burnground]],
                 pos                = [[-15 r30, 0 r5, -15 r30]],
            },
        },
   },

   ["fire-flames"] = {
     usedefaultexplosions = false,
        flame1 = {
          air                = true,
          class              = [[CSimpleParticleSystem]],
          count              = 1,
          ground             = true,
          properties = {
            airdrag            = 0.88,
            colormap           = [[0 0 0 0.01   0.95 0.95 1 0.4  0.65 0.65 0.68 0.2   0.1 0.1 0.1 0.18   0.08 0.07 0.06 0.12   0 0 0 0.01]],
            directional        = false,
            emitrot            = 40,
            emitrotspread      = 30,
            emitvector         = [[0.2, -0.4, 0.2]],
            gravity            = [[0, 0.03 r0.04, 0]],
            numparticles       = [[0.50 r0.70]],
            particlelife       = 80,
            particlelifespread = 75,
            particlesize       = 35,
            particlesizespread = 57,
            particlespeed      = 1,
            particlespeedspread = 1.3,
            animParams         = [[8,8,90 r50]],
            rotParams          = [[-3 r6, -3 r6, -180 r360]],
            pos                = [[-4 r8, -5 r15, -4 r8]],
            sizegrowth         = [[1.6 r0.6]],
            sizemod            = 0.98,
            texture            = [[FireBall02-anim]],
            drawOrder          = 1,
            --castShadow         = true,
          },
        },
        blacksmoke = {
                air                = true,
                class              = [[CSimpleParticleSystem]],
                count              = 1,
                ground             = true,
                water              = true,
                properties = {
                    airdrag            = 0.70,
                    --colormap           = [[0.01 0.01 0.01 0.01   0.02 0.02 0.01 0.2   0.15 0.14 0.12 0.68   0.13 0.12 0.10 0.75   0.11 0.10 0.09 0.85  0.09 0.08 0.08 0.7    0.075 0.07 0.07 0.6   0.05 0.05 0.05 0.4   0.01 0.01 0.01 0.01]],
                    colormap           = [[0.01 0.01 0.01 0.01   0.02 0.02 0.01 0.2   0.15 0.14 0.12 0.68   0.11 0.10 0.09 0.85    0.075 0.07 0.07 0.6   0.01 0.01 0.01 0.01]],
                    directional        = false,
                    emitrot            = 90,
                    emitrotspread      = 70,
                    emitvector         = [[0.3, 1, 0.3]],
                    gravity            = [[-0.03 r0.06, 0.24 r0.3, -0.03 r0.06]],
                    numparticles       = [[0.55 r0.55]],
                    particlelife       = 110,
                    particlelifespread = 60,
                    particlesize       = 45,
                    particlesizespread = 60,
                    particlespeed      = 3,
                    particlespeedspread = 2,
                    rotParams          = [[-15 r30, -2 r4, -180 r360]],
                    pos                = [[0.0, 30, 0.0]],
                    sizegrowth         = [[0.55 r0.55]],
                    sizemod            = 1,
                    texture            = [[smoke-ice-anim]],
                    animParams         = [[8,8,150 r80]],
                    useairlos          = true,
                    alwaysvisible      = true,
                    castShadow         = true,
                    drawOrder          = 1,
                    castShadow         = true,
                },
            },
    },
    
	["fire-flames-small"] = {
     usedefaultexplosions = false,
        flame1 = {
          air                = true,
          class              = [[CSimpleParticleSystem]],
          count              = 1,
          ground             = true,
          properties = {
            airdrag            = 0.88,
            colormap           = [[0 0 0 0.01   0.95 0.95 1 0.4  0.65 0.65 0.68 0.2   0.1 0.1 0.1 0.18   0.08 0.07 0.06 0.12   0 0 0 0.01]],
            directional        = false,
            emitrot            = 40,
            emitrotspread      = 30,
            emitvector         = [[0.2, -0.4, 0.2]],
            gravity            = [[0, 0.01 r0.04, 0]],
            numparticles       = [[0.50 r0.65]],
            particlelife       = 30,
            particlelifespread = 27,
            particlesize       = 11,
            particlesizespread = 35,
            particlespeed      = 1,
            particlespeedspread = 1.3,
            animParams         = [[8,8,120 r50]],
            rotParams          = [[-5 r10, -5 r10, -180 r360]],
            pos                = [[-3 r8, 0 r15, -3 r8]],
            sizegrowth         = [[1.2 r0.45]],
            sizemod            = 0.98,
            texture            = [[FireBall02-anim]],
            drawOrder          = 0,
            --castShadow         = true,
          },
        },
    },
	
	["fire-burnground-small"] = {
    usedefaultexplosions = false,
    -- flame = {
    --   air                = true,
    --   class              = [[CSimpleParticleSystem]],
    --   count              = 2,
    --   ground             = true,
    --   properties = {
    --     airdrag            = 0.98,
    --     colormap           = [[0.14 0.14 0.10 0.3   0.81 0.89 1 1   0.75 0.76 0.89 0.75   0.72 0.75 1 1    0.026 0.026 0.026 0.58   0.022 0.022 0.022 0.35   0.02 0.02 0.02 0.25   0.023 0.023 0.023 0.15   0 0 0 0.03   0 0 0 0.01]],
    --     directional        = true,
    --     emitrot            = 65,
    --     emitrotspread      = 65,
    --     emitvector         = [[0.28, 1, 0.28]],
    --     gravity            = [[-0.02 r0.05, 0.01 r0.07, -0.02 r0.05]],
    --     numparticles       = [[0.70 r0.65]],
    --     particlelife       = 80,
    --     particlelifespread = 65,
    --     particlesize       = 14,
    --     particlesizespread = 48,
    --     particlespeed      = 0.45,
    --     particlespeedspread = 0.4,
    --     rotParams          = [[-5 r10, 0, -180 r360]],
    --     animParams         = [[8,8,80 r50]],
    --     pos                = [[-3 r6, -5 r6, -3 r6]],
    --     sizegrowth         = [[1.22 r0.8]],
    --     sizemod            = 0.98,
    --     texture            = [[FireBall02-anim]],
    --     drawOrder          = 1,
    --   },
    -- },
    flamematt = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      ground             = true,
      properties = {
        airdrag            = 0.96,
        colormap           = [[0.4 0.25 0.1 0.75   1 0.66 0.45 0.95   0.9 0.8 0.66 1   0.85 0.52 0.28 1    0.80 0.47 0.24 0.98   0.75 0.41 0.20 0.97   0.72 0.38 0.18 0.96   0.6 0.30 0.12 0.9    0.18 0.10 0.05 0.55   0.023 0.022 0.022 0.2   0 0 0 0.01]],

        directional        = false,
        emitrot            = 65,
        emitrotspread      = 65,
        emitvector         = [[0.28, 1, 0.28]],
        gravity            = [[-0.03 r0.05, 0.03 r0.08, -0.03 r0.05]],
        numparticles       = [[0.68 r0.65]],
        particlelife       = 40,
        particlelifespread = 30,
        particlesize       = 20,
        particlesizespread = 50,
        particlespeed      = 0.20,
        particlespeedspread = 0.20,
        rotParams          = [[-5 r10, 0, -180 r360]],
        animParams         = [[16,6,80 r55]],
        pos                = [[-3 r6, -8 r6, -3 r6]],
        sizegrowth         = [[0.8 r0.5]],
        sizemod            = 0.98,
        texture            = [[BARFlame02]],
        drawOrder          = 1,
        castShadow         = true,
      },
    },
    sparks = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = true,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0 0 0 0.01   0 0 0 0.01  1 0.88 0.77 0.030   0.8 0.55 0.3 0.015   0 0 0 0]],
        directional        = true,
        emitrot            = 35,
        emitrotspread      = 22,
        emitvector         = [[0, 1, 0]],
        gravity            = [[-0.4 r0.8, -0.1 r0.3, -0.4 r0.8]],
        numparticles       = [[0.65 r0.75]],
        particlelife       = 6,
        particlelifespread = 6,
        particlesize       = -12,
        particlesizespread = -3,
        particlespeed      = 4,
        particlespeedspread = 3,
        pos                = [[-7 r14, 17 r15, -7 r14]],
        sizegrowth         = 0.04,
        sizemod            = 0.91,
        texture            = [[gunshotxl2]],
        useairlos          = false,
        drawOrder          = 2,
      },
    },
  },
  
    ["fire-burnground"] = {
    usedefaultexplosions = false,
    -- flame = {
    --   air                = true,
    --   class              = [[CSimpleParticleSystem]],
    --   count              = 2,
    --   ground             = true,
    --   properties = {
    --     airdrag            = 0.98,
    --     colormap           = [[0.14 0.14 0.10 0.3   0.81 0.89 1 1   0.75 0.76 0.89 0.75   0.72 0.75 1 1    0.026 0.026 0.026 0.58   0.022 0.022 0.022 0.35   0.02 0.02 0.02 0.25   0.023 0.023 0.023 0.15   0 0 0 0.03   0 0 0 0.01]],
    --     directional        = true,
    --     emitrot            = 65,
    --     emitrotspread      = 65,
    --     emitvector         = [[0.28, 1, 0.28]],
    --     gravity            = [[-0.02 r0.05, 0.01 r0.07, -0.02 r0.05]],
    --     numparticles       = [[0.70 r0.65]],
    --     particlelife       = 80,
    --     particlelifespread = 65,
    --     particlesize       = 14,
    --     particlesizespread = 48,
    --     particlespeed      = 0.45,
    --     particlespeedspread = 0.4,
    --     rotParams          = [[-5 r10, 0, -180 r360]],
    --     animParams         = [[8,8,80 r50]],
    --     pos                = [[-3 r6, -5 r6, -3 r6]],
    --     sizegrowth         = [[1.22 r0.8]],
    --     sizemod            = 0.98,
    --     texture            = [[FireBall02-anim]],
    --     drawOrder          = 1,
    --   },
    -- },
    flamematt = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      ground             = true,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0.25 0.22 0.18 0.75   0.75 0.77 0.71 1   0.72 0.51 0.39 1    0.67 0.47 0.34 0.99   0.63 0.41 0.27 0.98   0.58 0.37 0.29 0.97   0.48 0.31 0.22 0.91    0.11 0.11 0.12 0.50   0.016 0.011 0.07 0.45   0 0 0 0.01]],

        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0.32, 0.7, 0.32]],
        gravity            = [[-0.025 r0.05, 0.03 r0.11, -0.025 r0.05]],
        numparticles       = [[0.67 r0.69]],
        particlelife       = 50,
        particlelifespread = 60,
        particlesize       = 46,
        particlesizespread = 130,
        particlespeed      = 3.20,
        particlespeedspread = 5.20,
        rotParams          = [[-5 r10, -20 r40, -180 r360]],
        animParams         = [[16,6,88 r55]],
        pos                = [[-3 r6, -25 r12, -3 r6]],
        sizegrowth         = [[1.10 r1.05]],
        sizemod            = 0.98,
        texture            = [[BARFlame02]],
        drawOrder          = 2,
        castShadow         = true,
      },
    },
    flamedark = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.93,
        colormap           = [[0.26 0.29 0.21 0.1   0.36 0.27 0.29 0.90   0.34 0.43 0.40 0.88   0.33 0.29 0.20 0.85    0.33 0.27 0.18 0.83   0.29 0.22 0.14 0.80   0.29 0.20 0.13 0.75   0.22 0.16 0.11 0.55    0.05 0.06 0.09 0.35   0.021 0.022 0.023 0.2   0 0 0 0.01]],

        directional        = false,
        emitrot            = 85,
        emitrotspread      = 25,
        emitvector         = [[0.28, 0.9, 0.28]],
        gravity            = [[-0.02 r0.04, 0.015 r0.032, -0.02 r0.04]],
        numparticles       = [[0.32 r0.68]],
        particlelife       = 25,
        particlelifespread = 35,
        particlesize       = 72,
        particlesizespread = 100,
        particlespeed      = 0.10,
        particlespeedspread = 0.16,
        rotParams          = [[-5 r10, 0, -180 r360]],
        animParams         = [[16,6,80 r55]],
        pos                = [[0, 60 r25, 0]],
        sizegrowth         = [[1.3 r1.1]],
        sizemod            = 0.99,
        texture            = [[BARFlame02]],
        drawOrder          = 3,
        castShadow         = true,
      },
    },
    sparks = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = true,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0 0 0 0.01   0 0 0 0.01  1 0.88 0.77 0.030   0.8 0.55 0.3 0.015   0 0 0 0]],
        directional        = true,
        emitrot            = 35,
        emitrotspread      = 22,
        emitvector         = [[0, 1, 0]],
        gravity            = [[-0.4 r0.8, -0.1 r0.3, -0.4 r0.8]],
        numparticles       = [[0.50 r0.65]],
        particlelife       = 11,
        particlelifespread = 11,
        particlesize       = -24,
        particlesizespread = -8,
        particlespeed      = 9,
        particlespeedspread = 4,
        pos                = [[-7 r14, 17 r15, -7 r14]],
        sizegrowth         = 0.04,
        sizemod            = 0.91,
        texture            = [[gunshotxl2]],
        useairlos          = false,
        drawOrder          = 2,
      },
    },
  },
  
  --["fire-flames-backup"] = {
    --  usedefaultexplosions = false,
    --      extrafires = {
    --           air                = true,
    --           class              = [[CSimpleParticleSystem]],
    --           count              = 1,
    --           ground             = true,
    --           properties = {
    --             airdrag            = 0.95,
    --             colormap           = [[0 0 0 0.01   0.33 0.18 0.45 0.18   0.55 0.52 0.42 0.35   0.35 0.35 0.28 0.25  0.5 0.5 0.42 0.32   0.32 0.28 0.18 0.12    0.01 0 0 0.01]],
    --             directional        = false,
    --             emitrot            = 90,
    --             emitrotspread      = 1,
    --             emitvector         = [[dir]],
    --             gravity            = [[0, 0.06, 0]],
    --             numparticles       = [[0.23 r0.81]],
    --             particlelife       = 9,
    --             particlelifespread = 18,
    --             particlesize       = 11,
    --             particlesizespread = 15,
    --             particlespeed      = 0,
    --             particlespeedspread = 0,
    --             rotParams          = [[-90 r180, -50 r100, -180 r360]],
    --             pos                = [[-3 r6, 20, -3 r6]],
    --             sizegrowth         = [[1.3 r0.35]],
    --             sizemod            = 0.99,
    --             texture            = [[fire]],
    --             drawOrder          = 0,
    --           },
    --         },
    --     flame1 = {
    --       air                = true,
    --       class              = [[CSimpleParticleSystem]],
    --       count              = 1,
    --       ground             = true,
    --       properties = {
    --         airdrag            = 0.99,
    --         colormap           = [[0 0 0 0.01   0.95 0.95 1 0.4  0.65 0.65 0.68 0.2   0.1 0.1 0.1 0.18   0.08 0.07 0.06 0.12   0 0 0 0.01]],
    --         directional        = false,
    --         emitrot            = 70,
    --         emitrotspread      = 40,
    --         emitvector         = [[0.2, -0.4, 0.2]],
    --         gravity            = [[0, 0.23 r0.09, 0]],
    --         numparticles       = [[0.45 r0.62]],
    --         particlelife       = 14,
    --         particlelifespread = 18,
    --         particlesize       = 4.9,
    --         particlesizespread = 22,
    --         particlespeed      = -2,
    --         particlespeedspread = 0.9,
    --         rotParams          = [[-120 r240, -80 r160, -180 r360]],
    --         pos                = [[-3 r8, 25 r10, -3 r8]],
    --         sizegrowth         = [[1.6 r0.6]],
    --         sizemod            = 0.98,
    --         texture            = [[flame_alt2]],
    --         drawOrder          = 2,
    --       },
    --     },

    --     flame2 = {
    --       air                = true,
    --       class              = [[CSimpleParticleSystem]],
    --       count              = 1,
    --       ground             = true,
    --       properties = {
    --         airdrag            = 0.99,
    --         colormap           = [[0 0 0 0.01   0.95 0.95 1 0.25  0.65 0.65 0.68 0.15   0.1 0.1 0.1 0.16   0.08 0.07 0.06 0.11   0 0 0 0.01]],
    --         directional        = false,
    --         emitrot            = 70,
    --         emitrotspread      = 40,
    --         emitvector         = [[0.2, -0.4, 0.2]],
    --         gravity            = [[0, 0.23 r0.09, 0]],
    --         numparticles       = [[0.45 r0.62]],
    --         particlelife       = 14,
    --         particlelifespread = 18,
    --         particlesize       = 4.9,
    --         particlesizespread = 22,
    --         particlespeed      = -2,
    --         particlespeedspread = 0.9,
    --         rotParams          = [[-180 r360, -80 r160, -180 r360]],
    --         pos                = [[-3 r8, 25 r10, -3 r8]],
    --         sizegrowth         = [[1.6 r0.6]],
    --         sizemod            = 0.98,
    --         texture            = [[fire]],
    --         drawOrder          = 1,
    --       },
    --     },
    -- },
	
	--not finalized
	["fire-area-150"] = {
     usedefaultexplosions = false,
    fireflamearea = {
             air                = true,
             class              = [[CExpGenSpawner]],
             count              = 1, -- 25 --60
             ground             = true,
             water              = true,
             underwater         = true,
             properties = {
                 delay              = [[r12]],
                 explosiongenerator = [[custom:fire-flames]],
                 pos                = [[-66 r132, 0 r10, -66 r132]],
            },
        },
    fireflameground = {
             class              = [[CExpGenSpawner]],
             count              = 1, -- 24 --60
             air                = true,
             ground             = true,
             water              = true,
             underwater         = true,
             properties = {
                 delay              = [[r12]],
                 explosiongenerator = [[custom:fire-burnground]],
                 pos                = [[-60 r120, 0 r5, -60 r120]],
            },
        },
   },
}

return definitions
