--------------------------------------------------------------------------------
--- luarules/configs/collisionvolumes.lua --------------------------------------

-- Contents:
-- - Custom collision volume definitions, mostly hand-curated.
-- - Extra types for collision volumes as configuration and as function args.
-- - Model scales and types for converting unit models to default volume types.
-- - Related unit values: mostly midpoint and aimpoint derivations.

local MIN_PIECE_DIM = 16 -- Model piece collision volumes need one dim >= this.
local MIN_PIECE_VOL = 16 * 5 * 5 -- Model piece colvols need a net volume >= this.

--[[  from Spring Wiki and source code, info about CollisionVolumeData

Spring.GetUnitCollisionVolumeData ( number unitID ) ->
	number scaleX, number scaleY, number scaleZ, number offsetX, number offsetY, number offsetZ,
	number volumeType, number testType, number primaryAxis, boolean disabled

Spring.SetUnitCollisionVolumeData ( number unitID, number scaleX, number scaleY, number scaleZ,
					number offsetX, number offsetY, number offsetX,
					number vType, number tType, number Axis ) -> nil

Spring.SetUnitPieceCollisionVolumeData ( number unitID, number pieceIndex, boolean enabled, number scaleX, number scaleY, number scaleZ,
					number offsetX, number offsetY, number offsetZ, number vType, number Axis) -> nil
	per piece collision volumes always use COLVOL_TEST_CONT as tType
	above syntax is for 0.83, for 0.82 compatibility repeat enabled 3 more times

   sample collision volume with detailed descriptions
	unitCollisionVolume["arm_advanced_radar_tower"] = {
		on=            -- Unit is active/open/poped-up
		   {60,80,60,  -- Volume X scale, Volume Y scale, Volume Z scale,
		    0,15,0,    -- Volume X offset, Volume Y offset, Volume Z offset,
		    0,1,0[,    -- vType, tType, axis [,  -- Optional
			0,0,0]}    -- Aimpoint X offset, Aimpoint Y offset, Aimpoint Z offset]},
		off={32,48,32,0,-10,0,0,1,0},
	}                  -- Aimpoint offsets are relative to unit's base position (aka unit coordiante space)
	pieceCollisionVolume["arm_big_bertha"] = {
		["0"]={true,       -- [pieceIndexNumber]={enabled,
			   48,74,48,   --            Volume X scale, Volume Y scale, Volume Z scale,
		       0,0,0,      --            Volume X offset, Volume Y offset, Volume Z offset,
			   1,1},       --            vType, axis},
		....               -- All undefined pieces will be treated as disabled for collision detection
	}
	dynamicPieceCollisionVolume["cor_viper"] = {	--same as with pieceCollisionVolume only uses "on" and "off" tables
	
	Warning 
	Ensure that buildings/units do not have a unitdeff hitbox defined
	It will break certain units being able to damage the relevant building/unit
	this is possibly a bug but not sure

		on = {
			["0"]={true,51,12,53,0,4,0,2,0},
			["5"]={true,25,66,25,0,-14,0,1,1},
			offsets={0,35,0}   -- Aimpoint X offset, Aimpoint Y offset, Aimpoint Z offset
		},                     -- offsets entry is optional
		off = {
			["0"]={true,51,12,53,0,4,0,2,0},
			offsets={0,8,0}
		}
	}

	Q: How am I supposed to guess the piece index number?
	A: Open the model in UpSpring and locate your piece. Count all pieces above it in the piece tree.
	   Piece index number is equal to number of pieces above it in tree. Root piece has index 0.
	   Or start counting from tree top till your piece starting from 0. Count lines in Upspring
	   not along the tree hierarchy.
	Q: I defined all per piece volumes in here but unit still uses only one collision volume!
	A: Edit unit's definition file and add:
		usePieceCollisionVolumes=1;    (FBI)
		usePieceCollisionVolumes=true, (LUA)
	Q: The unit always has on/off volume and it never changes
	A: You need to edit the unit script and set ARMORED status to on or off depending on the
	   unit's on/off status, unarmored for on and armored for off
]]--

--------------------------------------------------------------------------------
-- Engine types ----------------------------------------------------------------

---@type table<VolumeShapeName, VolumeShapeIndex>
local COLVOL_SHAPE = {
	---@alias VolumeShapeName
	---|"DISABLED" -1 -- Do not use. Disables hit detection on the unit.
	---|"ELLIPSOID" 0
	---|"CYLINDER" 1
	---|"BOX" 2
	---|"SPHERE" 3
	---|"FOOTPRINT" 4 -- Default. Intersection of footprint and sphere. Makes a box.
	---@alias VolumeShapeIndex
	---|-1 DISABLED -- Do not use. Disables hit detection on the unit.
	---|0 ELLIPSOID
	---|1 CYLINDER
	---|2 BOX
	---|3 SPHERE
	---|4 FOOTPRINT -- Default. Intersection of footprint and sphere. Makes a box.
	DISABLED  = -1, -- Do not use. Disables hit detection on the unit.
	ELLIPSOID = 0,
	CYLINDER  = 1,
	BOX       = 2,
	SPHERE    = 3,
	FOOTPRINT = 4, -- Default. Intersection of footprint and sphere. Makes a box.
}

---@alias VolumeHitTestType 0|1
local COLVOL_TEST_DISC = 0 ---@type VolumeHitTestType discrete
local COLVOL_TEST_CONT = 1 ---@type VolumeHitTestType continuous

---@alias VolumeAxisIndex 0|1|2
local COLVOL_AXIS_VALUES = { X = 0, Y = 1, Z = 2 } ---@type table<"X"|"Y"|"Z", VolumeAxisIndex>
local COLVOL_AXIS_DEFAULT = COLVOL_AXIS_VALUES.Z

---See `LuaUtils::ParseColVolData`.
---@class UnitCollisionVolumeData
---@field [1] number scaleX
---@field [2] number scaleY
---@field [3] number scaleZ
---@field [4] number offsetX
---@field [5] number offsetY
---@field [6] number offsetZ
---@field [7] VolumeShapeIndex volumeType (default := `4`, FOOTPRINT)
---@field [8] VolumeHitTestType useContinuousHitTest (default := `1`, CONT)
---@field [9] VolumeAxisIndex primaryAxis (default := `2`, Z)
---@field radius number?
---@field height number?

---See `SetSolidObjectPieceCollisionVolumeData`.
---@class PieceCollisionVolumeData
---@field [1] number scaleX (default := `1`)
---@field [2] number scaleY
---@field [3] number scaleZ
---@field [4] number offsetX (default := `0`)
---@field [5] number offsetY
---@field [6] number offsetZ
---@field [7] VolumeShapeIndex volumeType (default := `3`, SPHERE) (no FOOTPRINT)
---@field [8] VolumeAxisIndex primaryAxis (default := `2`, Z)

--------------------------------------------------------------------------------
-- Collision volume definitions ------------------------------------------------

---Summary type for all unitDef collision volume configuration types. Unwieldy.
---@alias UnitColVolConfig ColVolUnitDef|ColVolUnitOnOff|ColVolPieceMap|ColVolPieceMapOnOff

---@alias ColVolUnitDef UnitCollisionVolumeData

---@class ColVolUnitOnOff
---@field on UnitCollisionVolumeData
---@field off UnitCollisionVolumeData

---@class ColVolPieceMap
---@field [string|integer] PieceCollisionVolumeData Numeric string keys "0"..."65535"
---@field offsets? float3 unit-space aimpoint offsets
---@field count? integer

---@class ColVolPieceMapOnOff
---@field on ColVolPieceMap
---@field off ColVolPieceMap

local staticUnitCollisionVolume = {} ---@type table<string|integer, ColVolUnitDef> static unit collision volume definitions
local dynamicUnitCollisionVolume = {} ---@type table<string|integer, ColVolUnitOnOff> dynamic unit collision volume definitions
local staticPieceCollisionVolume = {} ---@type table<string|integer, ColVolPieceMap> static per piece collision volume definitions
local dynamicPieceCollisionVolume = {} ---@type table<string|integer, ColVolPieceMapOnOff> dynamic per piece collision volume definitions

--------------------------------------------------------------------------------
-- Custom volumes --------------------------------------------------------------

-- number of times this table had to be touched since 2022 ~45
-- increase this number eachtime this table gets touched

dynamicPieceCollisionVolume['cormaw'] = {
    on={
        ['0']={32,70,32,0,5,0,1,1,1},
        ['offsets']={0,27,0},
    },
    off={
        ['0']={32,22,32,0,10,0,1,1,1},
        ['offsets']={0,0,0},
    }
}
dynamicPieceCollisionVolume['armclaw'] = {
    on={
        ['0']={32,85,32,0,5,0,1,1,1},
        ['offsets']={0,30,0},
    },
    off={
        ['0']={32,22,32,0,10,0,1,1,1},
        ['offsets']={0,0,0},
    }
}
dynamicPieceCollisionVolume['legdtr'] = {
    on={
        ['0']={32,90,32,0,5,0,1,1,1},
        ['offsets']={0,45,0},
    },
    off={
        ['0']={32,22,32,0,11,0,1,1,1},
        ['offsets']={0,0,0},
    }
}
dynamicPieceCollisionVolume['armannit3'] = {
    on={
        ['1']={96,140,96,0,5,0,2,1,0},
    },
    off={
        ['0']={96,80,96,0,10,0,2,1,0},
    }
}
dynamicPieceCollisionVolume['cordoomt3'] = {
    on={
        ['1']={112,180,112,0,5,0,1,1,0},
    },
    off={
        ['0']={96,80,96,0,10,0,2,1,0},
    }
}

dynamicUnitCollisionVolume['armanni'] = {
	on={54,81,54,0,-2,0,2,1,0},
	off={54,56,54,0,-15,0,2,1,0},
}
dynamicUnitCollisionVolume['armlab'] = {
	on={95,28,95,0,2,0,2,1,0},
	off={95,22,95,0,-1,0,1,1,1},
}
dynamicUnitCollisionVolume['armpb'] = {
	on={32,88,32,0,-8,0,1,1,1},
	off={40,40,40,0,-8,0,3,1,1},
}
dynamicUnitCollisionVolume['armplat'] = {
	on={96,66,96,0,33,0,1,1,1},
	off={96,44,96,0,0,0,1,1,1},
}
dynamicUnitCollisionVolume['armsolar'] = {
	on={73,76,73,0,-18,1,0,1,0},
	off={50,76,50,0,-18,1,0,1,0},
}
dynamicUnitCollisionVolume['armvp'] = {
	on={96,34,96,0,0,0,2,1,0},
	off={96,34,96,0,0,0,2,1,0},
}
dynamicUnitCollisionVolume['cordoom'] = {
	on={63,112,63,0,0,0,1,1,1},
	off={45,87,45,0,-12,0,2,1,0},
}

dynamicUnitCollisionVolume['corplat'] = {
	on={96,60,96,0,28,0,1,1,1},
	off={96,42,96,0,-20,0,1,1,1},
}
dynamicUnitCollisionVolume['legsolar'] = {

	on={70,70,70,0,-12,1,0,1,0},

	off={40,76,40,0,-10,1,0,1,0},

}


staticPieceCollisionVolume['corhrk'] = {
	['2']={35,40,30,0,-8,0,2,1},

}
staticPieceCollisionVolume['legpede'] = {
	['0']={26,28,90,0,5,-23,2,1},
	['32']={26,28,86,0,0,7,2,1},
}
staticPieceCollisionVolume['legrail'] = {
	['2']={31,20,38,-0.5,-4,-4,2,1},
	['5']={10,10,36,0,0,9,1,2},
}
staticPieceCollisionVolume['legsrail'] = {
	['0']={55,24,55,0,12,0,1,1},
	['7']={12,12,60,0,3,9,1,2},
}
staticPieceCollisionVolume['legerailtank'] = {
	['0']={65,20,75, 0,-4,0, 2,1}, 
	['4']={31,21,36, 0,0,0, 2,1},
	--['10']={50,50,50,0,0,0,2,1},
}
staticPieceCollisionVolume['leginf'] = {
	['1']={38,49,88, 0,22.8,14.3, 2,1},
	['0']={35,37,88, 0,21,11, 2,1},
}
---pieceCollisionVolume['legsrailt4'] = {
---	['0']={121,53,121,0,26,0,2,2},
---	['7']={26,26,132,0,7,20,2,4},
---}
staticPieceCollisionVolume['armrad'] = {
	['1']={22,58,22,0,0,0,1,1},
	['3']={60,13,13,11,0,0,1,0},
}
staticPieceCollisionVolume['armamb'] = {
	['3']={22,22,22,0,0,-10,1,1},
	['0']={60,30,15,0,0,0,1,1,0},
}
staticPieceCollisionVolume['cortoast'] = {
	['3']={22,22,22,0,10,0,1,1},
	['0']={60,30,15,0,0,0,1,1,0},
}
staticPieceCollisionVolume['armbrtha'] = {
	['1']={32,84,32,0,-20,0,1,1},
	['3']={13,0,75,0,0,20,1,2},
}
staticPieceCollisionVolume['corint'] = {
	['1']={72,84,72,0,28,0,1,1},
	['3']={13,13,34,0,1,28,1,2},
}
staticPieceCollisionVolume['armvulc'] = {
	['0']={98,140,98,0,40,0,1,1},
	['5']={55,55,174,0,18,0,1,2},
}
staticPieceCollisionVolume['corgator'] = {
	['0']={23,14,33,0,0,0,2,1},
	['3']={15,5,25,0,0,2,2,1},
}
staticPieceCollisionVolume['corsala'] = {
	['0']={34,20,34,0,3.5,0,2,1},
	['1']={13.5,6.2,17,0,1.875,1.5,2,1},
}
staticPieceCollisionVolume['cortermite'] = {
	['3']={22,10,22,0,2,0,1,1},
	['1']={48,25,48,0,0,0,1,1,0},
}


staticPieceCollisionVolume['correap'] = {
	['1']={35,20,46,0,1,0,2,1},
	['9']={19,14,20,0,2,0,2,1},
}
staticPieceCollisionVolume['corlevlr'] = {
	['0']={31,17,31,0,3.5,0,2,1},
	['1']={16,10,15,0,1.875,1.5,2,1},
}
staticPieceCollisionVolume['corraid'] = {
	['0']={33,18,39,0,3.5,0,2,1},
	['4']={16,7,15,0,0,1,2,1},
}
staticPieceCollisionVolume['cormist'] = {
	['0']={34,18,43,0,3.5,0,2,1},
	['1']={20,28,24,0,0,1.5,2,1},
}
staticPieceCollisionVolume['corgarp'] = {
	['0']={30,21,42,0,0,6,2,1},
	['6']={16,7,15,0,-2,1.5,2,1},
}
staticPieceCollisionVolume['armstump'] = {
	['0']={34,18,40,0,-5,0,2,1},
	['18']={17,16,16,1,0,0,2,1},
}
staticPieceCollisionVolume['armsam'] = {
	['0']={26,26,43,0,0,-2,2,1},
	['8']={16,16,20,0,0,0,2,1},
}
staticPieceCollisionVolume['armpincer'] = {
	['0']={31,13,31,0,5,0,2,1},
	['1']={16,12,20,0,0,0,2,1},
}
staticPieceCollisionVolume['armjanus'] = {
	['0']={26,12,35,0,0,0,2,1},
	['1']={20,10,20,0,0,0,2,1},
}
staticPieceCollisionVolume['armanac'] = {
	['0']={40,19,40,0,4,0,1,1},
	['3']={16,10,16,0,5,0,2,1},
}
staticPieceCollisionVolume['corah'] = {
	['0']={28,16,35,0,5,0,2,1},
	['2']={10,20,10,0,0,0,2,1},
}
staticPieceCollisionVolume['corhal'] = {
	['0']={42,12,42,0,0,0,2,1},
	['1']={14,10,14,0,0,0,2,1},
}
staticPieceCollisionVolume['corsnap'] = {
	['0']={32,16,38,0,4,0,2,1},
	['3']={12,10,12,0,0,0,2,1},
}
staticPieceCollisionVolume['corsumo'] = {
	['0']={42,32,45,0,0,0,2,1},
	['2']={22,10,22,0,0,0,1,1},
}
staticPieceCollisionVolume['armfboy'] = {
	['0']={34,40,42,0,-5,0,2,1},
	['8']={16,16,16,0,0,0,2,1},
}
staticPieceCollisionVolume['armfido'] = {
	['1']={26,32,34,0,-10,10,2,1},
	['15']={12,30,12,0,0,0,2,1},
}
staticPieceCollisionVolume['corgol'] = {
	['0']={48,44,56,0,0,0,2,1},
	['3']={24,24,24,0,0,0,2,1},
}
staticPieceCollisionVolume['cortrem'] = {
	['0']={40,32,44,0,0,0,2,1},
	['1']={24,64,24,0,0,0,2,1},
}
staticPieceCollisionVolume['seal'] = {
	['0']={28,25,34,0,0,0,2,1},
	['1']={12,16,12,0,0,0,2,1},
}
staticPieceCollisionVolume['corban'] = {
	['0']={44,32,44,0,0,0,2,1},
	['3']={24,16,24,0,8,0,2,1},
}
staticPieceCollisionVolume['cormart'] = {
	['0']={30,28,34,0,0,0,2,1},
	['5']={12,25,12,0,2,0,2,1},
}
staticPieceCollisionVolume['armmart'] = {
	['0']={44,24,50,0,0,0,2,1},
	['1']={16,32,16,0,0,0,2,1},
}
staticPieceCollisionVolume['armbull'] = {
	['0']={44,23,52,0,5,0,2,1},
	['4']={24,18,24,0,0,0,2,1},
}
staticPieceCollisionVolume['armlatnk'] = {
	['0']={30,26,34,0,0,0,2,1},
	['5']={16,16,16,0,0,0,2,1},
}
staticPieceCollisionVolume['armmanni'] = {
	['0']={48,34,38,0,10,0,2,1},
	['1']={24,52,24,0,0,0,2,1},
}
staticPieceCollisionVolume['armthor'] = {
	['0']={80,25,80,0,10,0,2,1},
	['15']={55,25,40,0,0,0,2,1},
}
staticPieceCollisionVolume['legfloat'] = {
	['0']={40,18,50,0,-1.5,0,2,1},
	['8']={18,9,30,0,1,-5,2,1},
}
staticPieceCollisionVolume['legnavyfrigate'] = {
	['0']={30,18,52,-1,-4,1,2,1},
	['3']={11,13,20,0,5,0,2,1},
}
staticPieceCollisionVolume['legcar'] = {
	['0']={34,16,46,0,-2.5,1,2,1},
	['4']={14,12,20,0,-2,-6,2,1},
}

staticPieceCollisionVolume['legmed'] = {
	['0']={48,31,69,0,0,0,2,1},
	['1']={7,35,15,0,40,-5,2,1},
}

staticPieceCollisionVolume['legehovertank'] = {
	['0']={63,32,63,0,-15,0,1,1},
	['20']={25,12,37,0,0,-6,2,1},
}

staticPieceCollisionVolume['corsiegebreaker'] = {
	['0']={36,18,64,0,4,8,2,2},
	['1']={19,12,24,0,-2.5,-2.5,2,1},
}

staticPieceCollisionVolume['armshockwave'] = {
    ['2']={22,22,22,0,10,0,1,1},
    ['0']={60,65,60,0,20,0,1,1,0},
}
staticPieceCollisionVolume['legmohoconct'] = {
	['0']={70,30,70,0,-3,0,1,1},
	['1']={21,16,30,0,-3,-1,2,1},
}


dynamicPieceCollisionVolume['corvipe'] = {
	on = {
		['0']={38,26,38,0,0,0,2,0},
		['5']={25,45,25,0,25,0,1,1}, -- changed to [1] so the cylinder collision is attached to the turret and not a door 
		['offsets']={0,23,0},
	},
	off = {
		['0']={38,26,38,0,0,0,2,0},
		['offsets']={0, 8, 0}, --['offsets']={0,10,0}, TODO: revert back when issue fixed: https://springrts.com/mantis/view.php?id=5144
	}
}

--------------------------------------------------------------------------------
-- Processing ------------------------------------------------------------------

---Maps units to their collision volume data, organized by colvol types.
---@class CollisionVolumeConfigs
---@field [1] table<string|integer, ColVolUnitDef> unitStaticColliders
---@field [2] table<string|integer, ColVolUnitOnOff> unitDynamicColliders
---@field [3] table<string|integer, ColVolPieceMap> pieceStaticColliders
---@field [4] table<string|integer, ColVolPieceMapOnOff> pieceDynamicColliders
local colVolConfigs = {
	staticUnitCollisionVolume,
	dynamicUnitCollisionVolume,
	staticPieceCollisionVolume,
	dynamicPieceCollisionVolume,
}

local function getVolumeVolume(colvol)
	local scaleX, scaleY, scaleZ, vType = colvol[1], colvol[2], colvol[3], colvol[7]
	local v = scaleX * scaleY * scaleZ
	if vType == 0 or vType == 3 or vType == 4 then
		return v * math.pi / 6
	elseif vType == 1 then
		return v * math.pi / 4
	else
		return v
	end
end

local function isPieceColVolTooSmall(colvol)
	return MIN_PIECE_DIM > math.max(colvol[1], colvol[2], colvol[3])
		or MIN_PIECE_VOL > getVolumeVolume(colvol)
end

---@type PieceCollisionVolumeData
local pieceColVolDisabled = { 1, 1, 1, 0, 0, 0, COLVOL_SHAPE.SPHERE, COLVOL_TEST_CONT, false }

local function setupPieceColVol(unitName, colvol)
	local pieceList = Spring.GetModelPieceList(UnitDefNames[unitName] and UnitDefNames[unitName].modelname)
	if pieceList then
		for index = 1, #pieceList do
			colvol[index] = pieceColVolDisabled -- fill for sequential array
		end
	end
	for key, value in pairs(colvol) do
		if type(key) == "string" and type(value) == "table" then
			if tonumber(key) and not isPieceColVolTooSmall(value) then
				value[9] = true -- enable piece volume
				colvol[tonumber(key) + 1] = value -- shift to Lua index
				colvol[key] = nil
			end
		end
	end
	colvol.count = #colvol
end

for unitName, colvol in pairs(staticPieceCollisionVolume) do
	setupPieceColVol(unitName, colvol)
end
for unitName, colvol in pairs(dynamicPieceCollisionVolume) do
	setupPieceColVol(unitName, colvol.on)
	setupPieceColVol(unitName, colvol.off)
end

for unitName in pairs(UnitDefNames) do
	if not table.any(colVolConfigs, function(config) return config[unitName] ~= nil end) then
		for _, config in ipairs(colVolConfigs) do
			for name, colvol in pairs(config) do
				if unitName:find(name) then
					config[unitName] = colvol
					break
				end
			end
		end
	end
end

---@type table<string|integer, 1|2|3|4>
local unitColVolTypeIndex = table.new(#UnitDefs, #UnitDefs)

for unitName in pairs(UnitDefNames) do
	local index = 1
	for i = 1, 4 do
		if colVolConfigs[i][unitName] then
			index = i
			break
		end
	end
	unitColVolTypeIndex[unitName] = index
end

--------------------------------------------------------------------------------
-- Model conversions -----------------------------------------------------------

-- The remaining collision volumes are based on the unit's actual model, which
-- the engine converts into collision volumes and which we must further modify.

---Automated corrections to colvols converted by the engine from 3D models.
local MODEL_TO_VOLUME = {
	UNIT = {
		["3DO"] = {
			SCALE               = 0.68,
			SMALL_RADIUS        = 47,
			SMALL_SCALE         = 0.73,
			VTOL_SCALE_XZ       = 0.53,
			VTOL_SCALE_Y        = 0.17,
			VTOL_HEIGHT_MIN     = 13,
			VTOL_TRANSPORT_SIZE = 16,
			VTOL_VOLUME_TYPE    = COLVOL_SHAPE.CYLINDER, -- why?
			VTOL_VOLUME_AXIS    = COLVOL_AXIS_VALUES.Z,
		},
		["S3O"] = {
			VTOL_SCALE_XZ    = 1.15,
			VTOL_SCALE_Y     = 0.33,
			VTOL_HEIGHT_MIN  = 13,
			VTOL_VOLUME_TYPE = COLVOL_SHAPE.SPHERE, -- why anything?
			VTOL_VOLUME_AXIS = COLVOL_AXIS_VALUES.X,
		},
	},
	FEATURE = {
		["3DO"] = {
			RADIUS_SCALE       = 0.68,
			HEIGHT_SCALE       = 0.60,
			SMALL_RADIUS       = 47,
			SMALL_RADIUS_SCALE = 0.75,
			SMALL_HEIGHT_SCALE = 0.67,
			HEIGHT_TO_OFFSET   = -0.1323529,
		},
		["S3O"] = {
			HEIGHT_SCALE       = 0.75,
			HEIGHT_TO_OFFSET   = -0.09,
			VOLUME_TYPE        = COLVOL_SHAPE.CYLINDER,
			VOLUME_AXIS        = 1,
		},
	},
	PIECE = { ["3DO"] = {}, ["S3O"] = {} },
}

---@type float3 The x-axis goes "right" in world space, "left" in object space.
local OBJECT_TO_WORLD_SPACE = { -1, 1, 1 }

local vTypeIsSphere = {
	[COLVOL_SHAPE.ELLIPSOID] = true, [COLVOL_SHAPE.SPHERE] = true, [COLVOL_SHAPE.FOOTPRINT] = true,
}

local function isSphere(array)
	return (array[1] == array[2] and array[1] == array[3]) and vTypeIsSphere[array[7]]
end

local function waterDepth(unitDef)
	return unitDef.moveDef and unitDef.moveDef.depth or unitDef.maxWaterDepth
end

local function rescaleUnitFromS3O(colvol, model, unitDef)
	if isSphere(colvol) and unitDef.canFly then
		local scaleXZ = model.VTOL_SCALE_XZ
		colvol[1] = colvol[1] * scaleXZ
		colvol[2] = math.max(colvol[2] * model.VTOL_SCALE_Y, model.VTOL_HEIGHT_MIN)
		colvol[3] = colvol[3] * scaleXZ
		colvol[7] = model.VTOL_VOLUME_TYPE
		colvol[9] = model.VTOL_VOLUME_AXIS
		colvol.radius = (colvol[1] + colvol[2] + colvol[3] + math.max(colvol[1] + colvol[2] + colvol[3])) / 4
		colvol.height = colvol[2]
	end
end

local function rescaleUnitFrom3DO(colvol, model, unitDef)
	local unitCanFly = unitDef.canFly
	local unitRadius = unitDef.radius

	local scaleXZ, scaleY
	if unitCanFly then
		scaleXZ, scaleY = model.VTOL_SCALE_XZ, model.VTOL_SCALE_Y
	elseif unitRadius <= model.SMALL_RADIUS then
		scaleXZ, scaleY = model.SMALL_SCALE, model.SMALL_SCALE
	else
		scaleXZ, scaleY = model.SCALE, model.SCALE
	end

	if isSphere(colvol) then
		colvol[1] = colvol[1] * scaleXZ
		colvol[2] = colvol[2] * scaleY
		colvol[3] = colvol[3] * scaleXZ
		if unitCanFly then
			colvol[2] = math.max(colvol[2], model.VTOL_HEIGHT_MIN)
			colvol[7] = model.VTOL_VOLUME_TYPE
			colvol[9] = model.VTOL_VOLUME_AXIS
		end
	end

	if unitCanFly and unitDef.transportCapacity >= 1 then
		colvol.radius = model.VTOL_TRANSPORT_SIZE
		colvol.height = model.VTOL_TRANSPORT_SIZE
	elseif unitDef.modCategories.underwater and unitRadius * scaleXZ > waterDepth(unitDef) then
		colvol.radius = waterDepth(unitDef) - 1
		colvol.height = unitDef.height * scaleY
	else
		colvol.radius = unitRadius * scaleXZ
		colvol.height = unitDef.height * scaleY
	end
end

MODEL_TO_VOLUME.UNIT["S3O"].modelToVolume = rescaleUnitFromS3O
MODEL_TO_VOLUME.UNIT["3DO"].modelToVolume = rescaleUnitFrom3DO

-- We can't get 100% of colvol data without a unit instance. -- TODO: This is wasteful vs. UnitCreated.
local allUnits = {} -- ! The worst case is a 32k array.
local function getUnitWithDefID(unitDefID)
	local frame = Spring.GetGameFrame()
	local units = allUnits[frame]
	if not units then
		units = Spring.GetAllUnits()
		allUnits = { [frame] = units } -- ! Which we keep indefinitely.
	end
	for _, unitID in ipairs(units) do
		if Spring.GetUnitDefID(unitID) == unitDefID then
			return unitID
		end
	end
end

local function hasCylinderAxis(colvol)
	if colvol[7] == COLVOL_SHAPE.CYLINDER and (colvol[1] ~= colvol[2] or colvol[1] ~= colvol[3]) then
		colvol[9] = (colvol[1] == colvol[2] and COLVOL_AXIS_VALUES.Z) or (colvol[1] == colvol[3] and COLVOL_AXIS_VALUES.Y)
		return colvol[9] ~= nil
	end
end

local function getModelUnitCollisionVolume(unitDef)
	local collisionVolume = unitDef.collisionVolume

	local defaultCoVoType =
		collisionVolume.defaultToPieceTree and COLVOL_SHAPE.SPHERE
		or collisionVolume.defaultToFootprint and COLVOL_SHAPE.BOX
		or collisionVolume.defaulttoSphere and COLVOL_SHAPE.SPHERE
		or COLVOL_SHAPE.SPHERE

	---@type UnitCollisionVolumeData
	local colvol = {
		collisionVolume.scaleX, collisionVolume.scaleY, collisionVolume.scaleZ,
		collisionVolume.offsetX, collisionVolume.offsetY, collisionVolume.offsetZ,
		COLVOL_SHAPE[collisionVolume.type:upper()] or defaultCoVoType,
		COLVOL_TEST_CONT,
		nil, -- todo: Add the primary axis to LuaUtils::PushColVolTable.
	}

	local modelUnit = unitDef.modelType and MODEL_TO_VOLUME.UNIT[unitDef.modelType:upper()]
	local scaleUnit = modelUnit and modelUnit.modelToVolume

	if colvol[7] ~= COLVOL_SHAPE.CYLINDER then
		colvol[9] = COLVOL_AXIS_DEFAULT -- shape does not require orientation
		if scaleUnit then scaleUnit(colvol, modelUnit, unitDef) end
	elseif not hasCylinderAxis(colvol) then
		local unitDef, unitDefID, modelUnit, scaleUnit = unitDef, unitDef.id, modelUnit, scaleUnit
		local pAxisIndex = 9
		local pAxisDefault = (unitDef.canFly and COLVOL_AXIS_VALUES.Z) or (unitDef.upright and COLVOL_AXIS_VALUES.Y) or COLVOL_AXIS_VALUES.X

		colvol = setmetatable(colvol, {
			__index = function(self, key)
				if key == pAxisIndex then
					local unitID = getUnitWithDefID(unitDefID)
					if not unitID then
						return
					end
					setmetatable(self, nil) -- only do this once
					local pAxis = select(pAxisIndex, Spring.GetUnitCollisionVolumeData(unitID))
					self[pAxisIndex] = pAxis or pAxisDefault -- handles failure case on first unit to spawn in
					-- if scaleUnit then
					-- 	scaleUnit(self, modelUnit, unitDef)
					-- end
					return self[pAxisIndex]
				end
			end,
		})
	end

	return colvol
end

local getMaxIndex = function(acc, value, key) return (not value or acc >= key) and acc or key end -- for what, fault tolerance? idk

local function getPieceColVols(unitID, pieceList, colvol)
	local count = table.reduce(pieceList, getMaxIndex, 0)
	local used = {}
	local GetVolumeData = Spring.GetUnitPieceCollisionVolumeData
	for i = 1, count do
		local sx, sy, sz, ox, oy, oz, vType, hType, pAxis, ignore = GetVolumeData(unitID, i)
		if ignore then
			colvol[i] = pieceColVolDisabled
		else
			colvol[i] = { sx, sy, sz, ox, oy, oz, vType, pAxis, true }
			used[#used + 1] = i
		end
	end
	while #used > 1 do
		local i = table.remove(used)
		local v = colvol[i]
		if
			MIN_PIECE_DIM > math.max(v[1], v[2], v[3]) or
			MIN_PIECE_VOL > getVolumeVolume(v)
		then
			colvol[i] = pieceColVolDisabled
		end
	end
	colvol.count = count
end

local function getModelPieceCollisionVolumes(unitDef)
	local unitDefID = unitDef.id
	return setmetatable({}, {
		__index = function(self, key)
			local unitID = getUnitWithDefID(unitDefID)
			if not unitID then
				return
			end
			local pieceList = Spring.GetUnitPieceList(unitID)
			if not pieceList then
				return
			end
			setmetatable(self, nil) -- only do this once
			getPieceColVols(unitID, pieceList, self)
			return self[key]
		end
	})
end

for unitName, unitDef in pairs(UnitDefNames) do
	if unitColVolTypeIndex[unitName] == 1 then
		if unitDef.collisionVolume and unitDef.collisionVolume.defaultToPieceTree then
			staticPieceCollisionVolume[unitName] = getModelPieceCollisionVolumes(unitDef)
			unitColVolTypeIndex[unitName] = 3
		else
			staticUnitCollisionVolume[unitName] = getModelUnitCollisionVolume(unitDef)
		end
	end
end

--------------------------------------------------------------------------------
-- Mid and aim position offsets ------------------------------------------------

local function setConfigMidAndAimOffsets(colvol, unitHeight)
	for k, v in pairs(colvol) do
		if k == "offsets" then
			colvol[k] = { 0.0, unitHeight * 0.5, 0.0, v[1], v[2], v[3], true }
		elseif k == "on" or k == "off" then
			setConfigMidAndAimOffsets(v, unitHeight)
		end
	end
end

for _, config in ipairs(colVolConfigs) do
	for unitName, colvol in pairs(config) do
		setConfigMidAndAimOffsets(colvol, colvol.height or (UnitDefNames[unitName] and UnitDefNames[unitName].height) or 0)
	end
end

--------------------------------------------------------------------------------
-- Export module ---------------------------------------------------------------

-- All config tables can be acccessed using either the unit's name or unitDefID.
for unitDefID = 1, #UnitDefs do
	local unitDef = UnitDefs[unitDefID]
	local unitName = unitDef.name

	local configTable = colVolConfigs[unitColVolTypeIndex[unitName]]
	configTable[unitDefID] = configTable and configTable[unitName]
	unitColVolTypeIndex[unitDefID] = unitColVolTypeIndex[unitName] or false
end

return {
	ColVolConfigs      = colVolConfigs,
	UnitDefColVolIndex = unitColVolTypeIndex,
	PieceColVolDisable = pieceColVolDisabled,
	ModelToVolumeScale = MODEL_TO_VOLUME,
	ObjectToWorldSpace = OBJECT_TO_WORLD_SPACE,
	COLVOL = {
		AXIS_DEFAULT = COLVOL_AXIS_DEFAULT,
		AXIS_VALUES  = COLVOL_AXIS_VALUES,
		TEST_CONT    = COLVOL_TEST_CONT,
		TEST_DISC    = COLVOL_TEST_DISC,
		SHAPE        = COLVOL_SHAPE,
	},
}
