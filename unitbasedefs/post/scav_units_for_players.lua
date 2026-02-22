local armadaAdvancedLand = {
	"armapt3", -- T3 Aircraft Gantry
	"armminivulc", -- Mini Ragnarok
	"armbotrail", -- Pawn Launcher
	"armannit3", -- Epic Pulsar
	"armafust3", -- Epic Fusion Reactor
	"armmmkrt3", -- Epic Energy Converter
}
--
local cortexAdvancedLand = {
	"corapt3", -- T3 Aircraft Gantry
	"corminibuzz", -- Mini Calamity
	"corhllllt", -- Quad Guard - Quad Light Laser Turret
	"cordoomt3", -- Epic Bulwark
	"corafust3", -- Epic Fusion Reactor
	"cormmkrt3", -- Epic Energy Converter
}
--
local legionAdvancedLand = {
	"legapt3", -- T3 Aircraft Gantry
	"legministarfall", -- Mini Starfall
	"legafust3", -- Epic Fusion Reactor
	"legadveconvt3", -- Epic Energy Converter
}

local buildOptionLists = {
	armaca = armadaAdvancedLand,
	armack = armadaAdvancedLand,
	armacv = armadaAdvancedLand,
	armasy = {
		"armdronecarry", -- Nexus - Drone Carrier
		"armptt2", -- Epic Skater
		"armdecadet3", -- Epic Dolphin
		"armpshipt3", -- Epic Ellysaw
		"armserpt3", -- Epic Serpent
		"armtrident", -- Trident - Depth Charge Drone Carrier
	},
	armshltx = {
		"armrattet4", -- Ratte - Very Heavy Tank
		"armsptkt4", -- Epic Recluse
		"armpwt4", -- Epic Pawn
		"armvadert4", -- Epic Tumbleweed - Nuclear Rolling Bomb
		"armdronecarryland", -- Nexus Terra - Drone Carrier
	},
	armshltxuw = {
		"armrattet4", -- Ratte - Very Heavy Tank
		"armsptkt4", -- Epic Recluse
		"armpwt4", -- Epic Pawn
		"armvadert4", -- Epic Tumbleweed - Nuclear Rolling Bomb
	},
	--
	corlab = { "corkark" }, -- Archaic Karkinos
	coraca = cortexAdvancedLand,
	corack = cortexAdvancedLand,
	coracv = cortexAdvancedLand,
	coravp = {
		"corgatreap", -- Laser Tiger
		"corftiger", -- Heat Tiger
	},
	coraap = {
		"corcrw", -- Archaic Dragon
	},
	corasy = {
		"cordronecarry", -- Dispenser - Drone Carrier
		"corslrpc", -- Leviathan - LRPC Ship
		"corsentinel", -- Sentinel - Depth Charge Drone Carrier
	},
	corgant = {
		"corkarganetht4", -- Epic Karganeth
		"corgolt4", -- Epic Tzar
		"corakt4", -- Epic Grunt
		"corthermite", -- Thermite/Epic Termite
		"cormandot4", -- Epic Commando
	},
	corgantuw = {
		"corkarganetht4", -- Epic Karganeth
		"corgolt4", -- Epic Tzar
		"corakt4", -- Epic Grunt
		"cormandot4", -- Epic Commando
	},
	--
	legaca = legionAdvancedLand,
	legack = legionAdvancedLand,
	legacv = legionAdvancedLand,
	leggant = {
		"legsrailt4", -- Epic Arquebus
		"leggobt3", -- Epic Goblin
		"legpede", -- Mukade - Heavy Multi Weapon Centipede
		"legeheatraymech_old", -- Old Sol Invictus - Quad Heatray Mech
	}
}

return {
	buildOptionLists = buildOptionLists,
}