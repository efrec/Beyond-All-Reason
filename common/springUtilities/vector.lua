--------------------------------------------------------------- [[ vector.lua ]]
-- A vector + math module for fast vector programs that avoid table allocations.

--------------------------------------------------------------------------------
-- Definitions and etc ---------------------------------------------------------

-- All vectors are presupposed to be in Cartesian coordinates (e.g. x, y, and z)
-- and are generalized tables, meaning that they do not make use of metamethods,
-- might contain other fields like `vector.isDirty`, and so on.

-- These functions work with a few "subtypes" of vector that cannot be mixed:
-- *  standard vector3 = { x, y, z }
-- * augmented vector3 = { x, y, z, magnitude }
-- *  weighted vector3 = { dx, dy, dz, magnitude } (used the least)

-- The magnitudes above also have two types, which are also not interchangeable:
-- * 3D magnitude = sqrt(x^2 + y^2 + x^2)
-- * 2D magnitude = sqrt(x^2 + z^2)

--------------------------------------------------------------------------------
-- Working with RecoilEngine ---------------------------------------------------

-- RecoilEngine tends to return multi-values, not tables, which you must assign:
-- * position = { GetUnitPosition(unitID) }
-- * position = pack(GetUnitPosition(unitID))

-- When you can, you should update existing vectors, rather than replacing them:
-- * position[1], position[2], position[3] = GetUnitPosition(unitID)
-- * repack(position, GetUnitPosition(unitID))

-- When RecoilEngine does return a table, of course you can assign it directly:
-- * position = GetUnitPositionTable(unitID)

-- Unless you need to maintain references to the original, in which case:
-- * copyInto(position, GetUnitPositionTable(unitID))
-- * refill(position, GetUnitPositionTable(unitID))

-- Finally, since Recoil uses X-Z as its ground plane and Y as its up direction,
-- most vector functions have a 2D version that uses the XZ plane only, like so:
-- * repackXZ(positionXZ, GetUnitPosition(unitID))
-- * refillXZ(positionXZ, GetUnitPositionTable(unitID))

--------------------------------------------------------------------------------
-- Performance notes -----------------------------------------------------------

-- This module strictly returns multivalues rather than use intermediate tables.
-- Whenever you need them in a table, create one as above; e.g., `{ random() }`;
-- and, if that ignites your pantalones, `function f() return { random() } end`.

-- More ideally, you should include reusable tables, possibly with helper code:

-- > local repack3
-- > do
-- >     local vector3 = { 0, 0, 0 } -- gated access is not guaranteed
-- >     repack3 = function(x, y, z)
-- >         local vector3 = vector3
-- >         vector3[1], vector3[2], vector3[3] = x, y, z
-- >         return vector3
-- >     end
-- > end

-- There is not much more to do to improve on performance without stepping into
-- specific cases. There is room to improve, but this blood price has been paid.

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local math_abs             = math.abs
local math_clamp           = math.clamp
local math_min             = math.min
local math_max             = math.max
local math_random          = math.random
local math_sqrt            = math.sqrt
local math_cos             = math.cos
local math_sin             = math.sin
local math_acos            = math.acos
local math_asin            = math.asin
local math_atan2           = math.atan2
local math_pi              = math.pi

-- Boundary and acceptability constants
local ARC_EPSILON          = 1e-6
local ARC_NORMAL_EPSILON   = 1 - 1e-6
local ARC_OPPOSITE_EPSILON = -1 + 1e-6

local RAD_EPSILON          = 1e-8
local RAD_NORMAL_EPSILON   = math_pi * 0.5 - 1e-8
local RAD_OPPOSITE_EPSILON = math_pi - 1e-8

local XYZ_EPSILON          = 1e-3
local XYZ_PATH_EPSILON     = 1

-- Vector space conventions
local dirUp                = { 0, 1, 0, 1 }
local dirDown              = { 0, -1, 0, 1 }
local dirLeft              = { -1, 0, 0, 1 }
local dirRight             = { 1, 0, 0, 1 }
local dirForward           = { 0, 0, 1, 1 }
local dirBackward          = { 0, 0, -1, 1 }

-- Reusable tables for zero-allocation module
local float3               = { 0, 0, 0 }
local float3a              = { 0, 0, 0, 0 }

-- For use when readability matters (which is never, apparently)
local indexX               = 1
local indexY               = 2
local indexZ               = 3
local indexA               = 4

-- Fixes for lexical scope
local cross, magnitude, magnitudeXZ

--------------------------------------------------------------------------------
-- Table construction ----------------------------------------------------------

-- * These are the module's only functions allowed to return the `table` type: *

---Create a new copy of a vector. If the original is augmented, then the copy is.
---@param vector table
---@return table
local function copy(vector)
	return { vector[1], vector[2], vector[3], vector[4] }
end

---@param x number
---@param y number
---@param z number
---@return table vector3
local function vector3(x, y, z)
	return { x, y, z }
end

---@param x number
---@param y number
---@param z number
---@param a number augment term
---@return table vector3a
local function vector3a(x, y, z, a)
	return { x, y, z, a }
end

---@param x any
---@param z any
---@return table
local function vectorXZ(x, z)
	return { x, 0, z }
end

---@param x any
---@param z any
---@return table
local function vectorXZa(x, z, augment)
	return { x, 0, z, augment or math_sqrt(x * x + z * z) }
end

---Get the epsilon values used to determine numerical stability and accuracy.
---@return table settings
local function getTolerances()
	return {
		ARC_EPSILON          = ARC_EPSILON,
		ARC_NORMAL_EPSILON   = ARC_NORMAL_EPSILON,
		ARC_OPPOSITE_EPSILON = ARC_OPPOSITE_EPSILON,

		RAD_EPSILON          = RAD_EPSILON,
		RAD_NORMAL_EPSILON   = RAD_NORMAL_EPSILON,
		RAD_OPPOSITE_EPSILON = RAD_OPPOSITE_EPSILON,

		XYZ_EPSILON          = XYZ_EPSILON,
		XYZ_PATH_EPSILON     = XYZ_PATH_EPSILON,
	}
end

--------------------------------------------------------------------------------
-- Table reuse -----------------------------------------------------------------

---Fill an existing vector with all the values in another vector.
---
---Modifies `vector1` and overrides the augment.
---@param vector1 table
---@param vector2 table
local function copyFrom(vector1, vector2)
	vector1[1] = vector2[1]
	vector1[2] = vector2[2]
	vector1[3] = vector2[3]
	vector1[4] = vector2[4]
end

local function zeroes(vector)
	vector[1], vector[2], vector[3] = 0, 0, 0
	if vector[4] then vector[4] = 0 end
end

---Fill an existing vector with the values in another vector.
---The magnitude is recalculated only if it was already set in vector1.
---
---Modifies `vector1` and updates its augment, if present.
---@param vector1 table
---@param vector2 table
local function refill(vector1, vector2)
	vector1[1] = vector2[1]
	vector1[2] = vector2[2]
	vector1[3] = vector2[3]
	if vector1[4] then
		vector1[4] = vector2[4] or magnitude(vector1)
	end
end

---Fill an existing vector with the values in another vector.
---The magnitude is recalculated only if it was already set in vector1.
---
---Modifies `vector1` and updates its augment, if present.
---@param vector1 table
---@param vector2 table
local function refillXZ(vector1, vector2)
	vector1[1] = vector2[1]
	vector1[3] = vector2[3]
	if vector1[4] then
		vector1[4] = vector2[4] or magnitudeXZ(vector1)
	end
end

---Fill a vector with the values from a list of multi-values, similar to `pack(...)`.
---Even if a 4th argument is passed, the augment is updated only if it was set already.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param arg1 number
---@param arg2 number
---@param arg3 number
---@param arg4 number? augment
local function repack(vector, arg1, arg2, arg3, arg4)
	vector[1] = arg1
	vector[2] = arg2
	vector[3] = arg3
	if vector[4] then
		vector[4] = arg4 or magnitude(vector)
	end
end

---Fill a vector with the values from a list of multi-values, similar to `pack`.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param arg1 number
---@param arg2 number
---@param arg3 number?
local function repackXZ(vector, arg1, arg2)
	vector[1] = arg1
	vector[3] = arg2
end

---Fill a vector with the values from a list of multi-values, similar to `pack`.
---Even if a 3rd argument is passed, the augment is updated only if it was set already.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param arg1 number
---@param arg2 number
---@param arg3 number?
local function repackXZa(vector, arg1, arg2, arg3)
	vector[1] = arg1
	vector[3] = arg2
	if vector[4] then
		vector[4] = arg3 or magnitudeXZ(vector)
	end
end

--------------------------------------------------------------------------------
-- General properties ----------------------------------------------------------

---@param vector table
---@return number
magnitude = function(vector)
	local v1 = vector[1]
	local v2 = vector[2]
	local v3 = vector[3]
	return math_sqrt(v1 * v1 + v2 * v2 + v3 * v3)
end

---@param vector table
---@return number
magnitudeXZ = function(vector)
	local v1 = vector[1]
	local v3 = vector[3]
	return math_sqrt(v1 * v1 + v3 * v3)
end

---Note: You may want to write your own "getOrSetMagnitude" function in some cases.
---@param vector table
---@return number magnitude either from the augment (so may be invalid) or recomputed
local function getMagnitude(vector)
	return vector[4] or magnitude(vector)
end

---Note: You may want to write your own "getOrSetMagnitudeXZ" function in some cases.
---@param vector table
---@return number magnitude either from the augment (so may be invalid) or recomputed
local function getMagnitudeXZ(vector)
	return vector[4] or magnitudeXZ(vector)
end

---@param vector table
---@return boolean result whether the vector is a valid unit vector
local function isUnitary(vector)
	return getMagnitude(vector) == 1
end

---@param vector table
---@return boolean result whether the vector is a valid unit vector (2D)
local function isUnitaryXZ(vector)
	return getMagnitudeXZ(vector) == 1
end

---@param vector table
---@return boolean result whether the vector is a valid weighted vector
local function isWeighted(vector)
	return vector[4] and magnitude(vector) == 1
end

---@param vector table
---@return boolean result whether the vector is a valid weighted vector (2D)
local function isWeightedXZ(vector)
	return vector[4] and magnitudeXZ(vector) == 1
end

---@param vector table
---@return boolean
local function isZero(vector)
	return vector[1] == 0 and vector[2] == 0 and vector[3] == 0
end

---@param vector table
---@return boolean
local function isZeroXZ(vector)
	return vector[1] == 0 and vector[3] == 0
end

--------------------------------------------------------------------------------
-- General in-place transformations --------------------------------------------

---Modifies `vector1`.
---@param vector1 table
---@param vector2 table
local function add(vector1, vector2)
	vector1[1] = vector1[1] + vector2[1]
	vector1[2] = vector1[2] + vector2[2]
	vector1[3] = vector1[3] + vector2[3]
end

---Modifies `vector1`.
---@param vector1 table
---@param vector2 table
local function addXZ(vector1, vector2)
	vector1[1] = vector1[1] + vector2[1]
	vector1[3] = vector1[3] + vector2[3]
end

---Modifies `vector`.
---@param vector table
---@param value number
local function addNumber(vector, value)
	vector[1] = vector[1] + value
	vector[2] = vector[2] + value
	vector[3] = vector[3] + value
end

---Modifies `vector`.
---@param vector table
---@param value number
local function addNumberXZ(vector, value)
	vector[1] = vector[1] + value
	vector[3] = vector[3] + value
end

---Modifies `vector1`.
---@param vector1 table
---@param vector2 table
local function subtract(vector1, vector2)
	vector1[1] = vector1[1] - vector2[1]
	vector1[2] = vector1[2] - vector2[2]
	vector1[3] = vector1[3] - vector2[3]
end

---Modifies `vector1`.
---@param vector1 table
---@param vector2 table
local function subtractXZ(vector1, vector2)
	vector1[1] = vector1[1] - vector2[1]
	vector1[3] = vector1[3] - vector2[3]
end

---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param value number
local function multiply(vector, value)
	vector[1] = vector[1] * value
	vector[2] = vector[2] * value
	vector[3] = vector[3] * value
	if vector[4] then
		vector[4] = vector[4] * value
	end
end

---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param value number
local function multiplyXZ(vector, value)
	vector[1] = vector[1] * value
	vector[3] = vector[3] * value
	if vector[4] then
		vector[4] = vector[4] * value
	end
end

---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param value number
local function divide(vector, value)
	vector[1] = vector[1] / value
	vector[2] = vector[2] / value
	vector[3] = vector[3] / value
	if vector[4] then
		vector[4] = vector[4] / value
	end
end

---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param value number
local function divideXZ(vector, value)
	vector[1] = vector[1] / value
	vector[3] = vector[3] / value
	if vector[4] then
		vector[4] = vector[4] / value
	end
end

---Rescale a vector to length 1. Does not set the augment term.
---
---Modifies `vector`.
---@param vector table
local function normalize(vector)
	local scale = getMagnitude(vector)
	vector[1] = vector[1] / scale
	vector[2] = vector[2] / scale
	vector[3] = vector[3] / scale
end

---Rescale a vector to length 1. Does not set the augment term.
---
---Modifies `vector`.
---@param vector table
local function normalizeXZ(vector)
	local scale = getMagnitudeXZ(vector)
	vector[1] = vector[1] / scale
	vector[3] = vector[3] / scale
end

---Rescale a vector to a value, or set its augment term if no value is given.
---
---Modifies `vector`.
---@param vector table
---@param value number
local function setMagnitude(vector, value)
	if not value then
		value = magnitude(vector)
	else
		local scale = value / magnitude(vector)
		vector[1] = vector[1] * scale
		vector[2] = vector[2] * scale
		vector[3] = vector[3] * scale
	end
	vector[4] = value
end

---Rescale a vector to a value, or set its augment term if no value is given.
---
---Modifies `vector`.
---@param vector table
---@param value number
local function setMagnitudeXZ(vector, value)
	if not value then
		value = magnitudeXZ(vector)
	else
		local scale = value / magnitudeXZ(vector)
		vector[1] = vector[1] * scale
		vector[3] = vector[3] * scale
	end
	vector[4] = value
end

---Set the weight term of a vector, or augment and normalize it if no weight is given.
---
---Modifies `vector`.
---@param vector table
local function setWeight(vector, value)
	if value then
		normalize(vector)
	else
		value = magnitude(vector)
		vector[1] = vector[1] / value
		vector[2] = vector[2] / value
		vector[3] = vector[3] / value
	end
	vector[4] = value
end

---Set the weight term of a vector, or augment and normalize it if no weight is given.
---
---Modifies `vector`.
---@param vector table
local function setWeightXZ(vector, value)
	if value then
		normalize(vector)
	else
		value = magnitudeXZ(vector)
		vector[1] = vector[1] / value
		vector[3] = vector[3] / value
	end
	vector[4] = value
end

---Normalize an augmented vector to length 1.
---
---Modifies `vector`.
---@param vector table
local function toUnitary(vector)
	local scale = vector[4]
	vector[1] = vector[1] / scale
	vector[2] = vector[2] / scale
	vector[3] = vector[3] / scale
	vector[4] = 1
end

---Denormalize a weighted vector into an augmented vector.
---
---Modifies `vector`.
---@param vector table
local function toUnweighted(vector)
	local scale = vector[4]
	vector[1] = vector[1] * scale
	vector[2] = vector[2] * scale
	vector[3] = vector[3] * scale
	vector[4] = scale
end

---Normalize a standard or augmented vector into a weighted vector.
---
---Modifies `vector`.
---@param vector table
local function toWeighted(vector)
	local scale = getMagnitude(vector)
	vector[1] = vector[1] / scale
	vector[2] = vector[2] / scale
	vector[3] = vector[3] / scale
	vector[4] = scale
end

---Modifies `vector1` and updates its augment, if present.
---@param vector1 table
---@param vector2 table
---@param factor number interpolation factor, from 0 to 1
local function mix(vector1, vector2, factor)
	if factor > 0 then
		if factor < 1 then
			vector1[1] = vector1[1] * (1 - factor) + vector2[1] * factor
			vector1[2] = vector1[2] * (1 - factor) + vector2[2] * factor
			vector1[3] = vector1[3] * (1 - factor) + vector2[3] * factor
			if vector1[4] then
				if vector2[4] then
					vector1[4] = vector1[4] * (1 - factor) + vector2[4] * factor
				else
					vector1[4] = magnitude(vector1)
				end
			end
		else
			refill(vector1, vector2)
		end
	end
end

---Modifies `vector1` and updates its augment, if present.
---@param vector1 table
---@param vector2 table
---@param factor number interpolation factor, from 0 to 1
local function mixXZ(vector1, vector2, factor)
	if factor > 0 then
		if factor < 1 then
			vector1[1] = vector1[1] * (1 - factor) + vector2[1] * factor
			vector1[3] = vector1[3] * (1 - factor) + vector2[3] * factor
			if vector1[4] then
				if vector2[4] then
					vector1[4] = vector1[4] * (1 - factor) + vector2[4] * factor
				else
					vector1[4] = magnitude(vector1)
				end
			end
		else
			refillXZ(vector1, vector2)
		end
	end
end

---Module internal. Helper function for the mixMagnitude's.
---@param vector1 table
---@param vector2 table
local function _copy_magnitude(vector1, vector2)
	setMagnitude(vector1, getMagnitude(vector2))
end

---Module internal. Helper function for the mixMagnitude's.
---@param vector1 table
---@param vector2 table
local function _copy_magnitude_xz(vector1, vector2)
	setMagnitudeXZ(vector1, getMagnitudeXZ(vector2))
end

---Modifies `vector1` and updates its augment, if present.
---@param vector1 table
---@param vector2 table
---@param factor number interpolation factor, from 0 to 1
local function mixMagnitude(vector1, vector2, factor)
	if factor > 0 then
		if factor < 1 then
			local scale = (1 - factor) + factor * getMagnitude(vector2) / getMagnitude(vector1)
			vector1[1] = vector1[1] * scale
			vector1[2] = vector1[2] * scale
			vector1[3] = vector1[3] * scale
			if vector1[4] then
				vector1[4] = vector1[4] * scale
			end
		else
			_copy_magnitude(vector1, vector2)
		end
	end
end

---Modifies `vector1` and updates its augment, if present.
---@param vector1 table
---@param vector2 table
---@param factor number interpolation factor, from 0 to 1
local function mixMagnitudeXZ(vector1, vector2, factor)
	if factor > 0 then
		if factor < 1 then
			local scale = (1 - factor) + factor * getMagnitudeXZ(vector2) / getMagnitudeXZ(vector1)
			vector1[1] = vector1[1] * scale
			vector1[3] = vector1[3] * scale
			if vector1[4] then
				vector1[4] = vector1[4] * scale
			end
		else
			_copy_magnitude_xz(vector1, vector2)
		end
	end
end

---Modifies `vector1`.
---@param vector1 table
---@param vector2 table
local function rotateTo(vector1, vector2)
	local scale = getMagnitude(vector1) / getMagnitude(vector2)
	vector1[1] = vector2[1] * scale
	vector1[2] = vector2[2] * scale
	vector1[3] = vector2[3] * scale
end

---Modifies `vector1`.
---@param vector1 table
---@param vector2 table
local function rotateToXZ(vector1, vector2)
	local scale = getMagnitudeXZ(vector1) / getMagnitudeXZ(vector2)
	vector1[1] = vector2[1] * scale
	vector1[3] = vector2[3] * scale
end

---Spherical linear interpolation between two vectors with numerical safety checks.
---
---Modifies `vector1`.
---@param vector1 table
---@param vector2 table
---@param factor number [0, 1]
---@return integer? misalignment `nil`: none, `-1`: opposite vectors, `1`: parallel vectors
local function slerp(vector1, vector2, factor)
	if factor > ARC_EPSILON then
		if factor < ARC_NORMAL_EPSILON then
			local v11, v12, v13 = vector1[1], vector1[2], vector1[3]
			local v21, v22, v23 = vector2[1], vector2[2], vector2[3]
			local m1 = getMagnitude(vector1)
			local m2 = getMagnitude(vector2)

			local cos_angle = (v11 * v21 + v12 * v22 + v13 * v23) / (m1 * m2)

			if math_abs(cos_angle) < ARC_NORMAL_EPSILON then
				local angle = math_acos(cos_angle)
				local weight1 = math_sin((1 - factor) * angle) / m1
				local weight2 = math_sin(factor * angle) / m2
				local scale = m1 / math_sin(angle)

				vector1[1] = (v11 * weight1 + v21 * weight2) * scale
				vector1[2] = (v12 * weight1 + v22 * weight2) * scale
				vector1[3] = (v13 * weight1 + v23 * weight2) * scale
			else
				return cos_angle < 0 and -1 or 1
			end
		else
			rotateTo(vector1, vector2)
		end
	end
end

---Fails when `vector1` and `vector2` have opposite direction. Not good, only fast.
---
---Modifies `vector1`.
---@param vector1 table
---@param vector2 table
---@param factor number interpolation factor, from 0 to 1
local function mixRotation(vector1, vector2, factor)
	if factor > 0 then
		if factor < 1 then
			local m1 = getMagnitude(vector1)
			local m2 = getMagnitude(vector2)
			-- Preserves scale of `vector1`. Redundant for unit vectors.
			local scale = m1 / (m1 * (1 - factor) + m2 * m1 / m2 * factor)
			vector1[1] = (vector1[1] * (1 - factor) + vector2[1] * m1 / m2 * factor) * scale
			vector1[2] = (vector1[2] * (1 - factor) + vector2[2] * m1 / m2 * factor) * scale
			vector1[3] = (vector1[3] * (1 - factor) + vector2[3] * m1 / m2 * factor) * scale
		else
			rotateTo(vector1, vector2)
		end
	end
end

---Fails when `vector1` and `vector2` have opposite direction. Not good, only fast.
---
---Modifies `vector1`.
---@param vector1 table
---@param vector2 table
---@param factor number interpolation factor, from 0 to 1
local function mixRotationXZ(vector1, vector2, factor, rescale)
	if factor > 0 then
		if factor < 1 then
			local m1 = getMagnitudeXZ(vector1)
			local m2 = getMagnitudeXZ(vector2)
			-- Preserves scale of `vector1`. Redundant for unit vectors.
			local scale = m1 / (m1 * (1 - factor) + m2 * m1 / m2 * factor)
			vector1[1] = (vector1[1] * (1 - factor) + vector2[1] * m1 / m2 * factor) * scale
			vector1[3] = (vector1[3] * (1 - factor) + vector2[3] * m1 / m2 * factor) * scale
		else
			rotateToXZ(vector1, vector2)
		end
	end
end

--------------------------------------------------------------------------------
-- General scalar and vector products ------------------------------------------

---@param vector1 table
---@param vector2 table
---@return number product
local function dot(vector1, vector2)
	return vector1[1] * vector2[1] + vector1[2] * vector2[2] + vector1[3] * vector2[3]
end

---@param vector1 table
---@param vector2 table
---@return number product
local function dotXZ(vector1, vector2)
	return vector1[1] * vector2[1] + vector1[3] * vector2[3]
end

---@param vector1 table
---@param vector2 table
---@return number product
local function dotUnit(vector1, vector2)
	local product = vector1[1] * vector2[1] + vector1[2] * vector2[2] + vector1[3] * vector2[3]
	-- resolve numerical instability in float:
	return (product > 1 and 1) or (product < -1 and -1) or product
end

---@param vector1 table
---@param vector2 table
---@return number product
local function dotUnitXZ(vector1, vector2)
	local product = vector1[1] * vector2[1] + vector1[3] * vector2[3]
	-- resolve numerical instability in float:
	return (product > 1 and 1) or (product < -1 and -1) or product
end

---@param vector1 table
---@param vector2 table
---@return number productX
---@return number productY
---@return number productZ
cross = function(vector1, vector2)
	local v11 = vector1[1]
	local v12 = vector1[2]
	local v13 = vector1[3]
	local v21 = vector2[1]
	local v22 = vector2[2]
	local v23 = vector2[3]
	return
		-v22 * v13 + v12 * v23,
		-v11 * v23 + v21 * v13,
		-v21 * v12 + v11 * v22
end

---@param vector1 table
---@param vector2 table
---@return number productY only the y value is needed given that x = 0 and z = 0 always
local function crossXZ(vector1, vector2)
	return -vector1[1] * vector2[3] + vector2[1] * vector1[3]
end

---@param vector1 table
---@param vector2 table
---@return number productX used like a measure of colinearity, linear dependence, or covariation
---@return number productY
---@return number productZ
local function hadamard(vector1, vector2)
	return
		vector1[1] * vector2[1],
		vector1[2] * vector2[2],
		vector1[3] * vector2[3]
end

---@param vector1 table
---@param vector2 table
---@return number productX used like a measure of colinearity, linear dependence, or covariation
---@return number productZ
local function hadamardXZ(vector1, vector2)
	return
		vector1[1] * vector2[1],
		vector1[3] * vector2[3]
end

--------------------------------------------------------------------------------
-- General scalar measures -----------------------------------------------------

---@param point1 table
---@param point2 table
---@return number
local function distance(point1, point2)
	local d1 = point1[1] - point2[1]
	local d2 = point1[2] - point2[2]
	local d3 = point1[3] - point2[3]
	return math_sqrt(d1 * d1 + d2 * d2 + d3 * d3)
end

---@param point1 table
---@param point2 table
---@return number
local function distanceXZ(point1, point2)
	local d1 = point1[1] - point2[1]
	local d3 = point1[3] - point2[3]
	return math_sqrt(d1 * d1 + d3 * d3)
end

---@param point1 table
---@param point2 table
---@return number
local function distanceSquared(point1, point2)
	local d1 = point1[1] - point2[1]
	local d2 = point1[2] - point2[2]
	local d3 = point1[3] - point2[3]
	return d1 * d1 + d2 * d2 + d3 * d3
end

---@param point1 table
---@param point2 table
---@return number
local function distanceSquaredXZ(point1, point2)
	local d1 = point1[1] - point2[1]
	local d3 = point1[3] - point2[3]
	return d1 * d1 + d3 * d3
end

---@param vector1 table
---@param vector2 table
---@return number radians
local function getAngleBetween(vector1, vector2)
	return math_acos(dot(vector1, vector2) / getMagnitude(vector1) / getMagnitude(vector2))
end

---@param vector1 table
---@param vector2 table
---@return number radians
local function getAngleBetweenXZ(vector1, vector2)
	return math_acos(dotXZ(vector1, vector2) / getMagnitudeXZ(vector1) / getMagnitudeXZ(vector2))
end

---The length of vector1 along the direction of vector2. Can be negative.
---@param vector1 table
---@param vector2 table
---@return number scalar from -||vector1|| to ||vector1||
local function projection(vector1, vector2)
	return dot(vector1, vector2) / getMagnitude(vector2)
end

---The length of vector1 along the direction of vector2. Can be negative.
---@param vector1 table
---@param vector2 table
---@return number scalar from -||vector1|| to ||vector1||
local function projectionXZ(vector1, vector2)
	return dotXZ(vector1, vector2) / getMagnitudeXZ(vector2)
end

---The length of vector1 perpendicular to the direction of vector2. Always non-negative.
---@param vector1 table
---@param vector2 table
---@return number scalar from -||vector1|| to ||vector1||
local function rejection(vector1, vector2)
	local m1 = getMagnitude(vector1)
	local m2 = projection(vector1, vector2)
	return math_sqrt(m1 * m1 - m2 * m2)
end

---The length of vector1 perpendicular to the direction of vector2. Always non-negative.
---@param vector1 table
---@param vector2 table
---@return number scalar from -||vector1|| to ||vector1||
local function rejectionXZ(vector1, vector2)
	local m1 = getMagnitudeXZ(vector1)
	local m2 = projectionXZ(vector1, vector2)
	return math_sqrt(m1 * m1 - m2 * m2)
end

--------------------------------------------------------------------------------
-- General vector measures -----------------------------------------------------

---Get the coordinate values of a codirectional unit vector.
---@param vector table
---@return number dx
---@return number dy
---@return number dz
---@return integer magnitude unitary
local function versor(vector)
	local scale = getMagnitude(vector)
	return vector[1] / scale, vector[2] / scale, vector[3] / scale, 1
end

---Get the coordinate values of a codirectional unit vector in XZ.
---@param vector table
---@return number dx
---@return number dz
---@return integer magnitude unitary
local function versorXZ(vector)
	local scale = getMagnitudeXZ(vector)
	return vector[1] / scale, vector[3] / scale, 1
end

---@param vector1 table
---@param vector2 table
local function displacement(vector1, vector2)
	return
		vector2[1] - vector1[1],
		vector2[2] - vector1[2],
		vector2[3] - vector1[3]
end

---@param vector1 table
---@param vector2 table
local function displacementXZ(vector1, vector2)
	return
		vector2[1] - vector1[1],
		vector2[3] - vector1[3]
end

--------------------------------------------------------------------------------
-- Normals and orthonormals ----------------------------------------------------

---Get two normalized basis vectors to pair with an existing vector.
---The basis is completely arbitrary but is conditioned for numerical stability.
---@param vector table
---@return integer ux arbitrary axis-aligned basis vector
---@return integer uy
---@return integer uz
---@return number vx from `vector`
---@return number vy
---@return number vz
---@return number wx = cross(u, v)
---@return number wy
---@return number wz
local function basisFrom(vector)
	local vx, vy, vz = vector[1], vector[2], vector[3]
	local ux, uy, uz -- arbitrarily chosen against values in `v`
	local wx, wy, wz -- cross(u, v)

	if vx <= vy and vx <= vz then
		ux, uy, uz = 1, 0, 0
		wx, wy, wz = 0, -vz, vy
	elseif vy <= vz then
		ux, uy, uz = 0, 1, 0
		wx, wy, wz = vz, 0, -vx
	else
		ux, uy, uz = 0, 0, 1
		wx, wy, wz = -vy, vx, 0
	end

	return
		ux, uy, uz,
		vx, vy, vz,
		wx, wy, wz
end

---Repack two normalized basis vectors, as determined from an input vector, and
---return the (non-normalized) input vector (without updating the vector).
---
---Modifies `basis1` and `basis2`, and returns the values from `vector`.
---@param vector table
---@param basis1 table
---@param basis2 table
---@return number vx
---@return number vy
---@return number vz
local function repackBasis(vector, basis1, basis2)
	local vx, vy, vz;
	-- basis is in <u, v, w>:
	basis1[1], basis1[2], basis1[3],
	vx, vy, vz,
	basis2[1], basis2[2], basis2[3] = basisFrom(vector)
	return vx, vy, vz
end

---@param vector1 table
---@param vector2 table
---@return boolean
local function areNormal(vector1, vector2)
	return dot(vector1, vector2) == 0
end

---@param vector1 table
---@param vector2 table
---@return boolean
local function areNormalXZ(vector1, vector2)
	return dotXZ(vector1, vector2) == 0
end

---@param vector1 table
---@param vector2 table
---@return boolean
local function areOrthonormal(vector1, vector2)
	return isUnitary(vector1) and isUnitary(vector2) and dot(vector1, vector2) == 0
end

---@param vector1 table
---@param vector2 table
---@return boolean
local function areOrthonormalXZ(vector1, vector2)
	return isUnitaryXZ(vector1) and isUnitaryXZ(vector2) and dotXZ(vector1, vector2) == 0
end

--------------------------------------------------------------------------------
-- Randomization ---------------------------------------------------------------

---@param vector table
---@param length number? default = 1
---@return number x
---@return number y
---@return number z
local function random(length)
	if not length then length = 1 end
	-- Marsaglia method:
	local m1, m2, m3
	repeat
		m1 = 2 * math_random() - 1
		m2 = 2 * math_random() - 1
		m3 = m1 * m1 + m2 * m2
	until (m3 < 1)
	local m4 = math_sqrt(1 - m3)
	return
		(2 * m1 * m4) * length,
		(2 * m2 * m4) * length,
		(1 - 2 * m3) * length
end

---@param vector table
---@param length number
---@return number x
---@return number z
local function randomXZ(length)
	if not length then length = 1 end
	local angle = math_random() * 2 * math_pi
	return
		math_cos(angle) * length,
		math_sin(angle) * length
end

---Get random components by deviating away from an existing vector's components.
---`factor` scales with magnitude.
---@param vector table
---@param factor number [0, 1] random deviation from original
---@return number x
---@return number y
---@return number z
local function randomFrom(vector, factor)
	factor = math_clamp(factor, 0, 1)
	local scale = factor * (2 * math_random() - 1) * getMagnitude(vector)
	local rx, ry, rz = random()
	return
		vector[1] + rx * scale,
		vector[2] + ry * scale,
		vector[3] + rz * scale
end

---Get random components by deviating away from an existing vector's components.
---`factor` scales with magnitude.
---@param vector table
---@param factor number [0, 1] random deviation from original
---@return number x
---@return number z
local function randomFromXZ(vector, factor)
	factor = math_clamp(factor, 0, 1)
	local scale = factor * (2 * math_random() - 1) * getMagnitudeXZ(vector)
	local rx, rz = randomXZ()
	return
		vector[1] + rx * scale,
		vector[3] + rz * scale
end

---Get random components by deviating away from an existing vector's components.
---`factor` scales with magnitude.
---@param vector table
---@param factorX number
---@param factorY number
---@param factorZ number
---@return number x
---@return number y
---@return number z
local function randomFrom3D(vector, factorX, factorY, factorZ)
	local scale = getMagnitude(vector)
	local rx, ry, rz = random()
	return
		vector[1] + rx * factorX * scale,
		vector[2] + ry * factorY * scale,
		vector[3] + rz * factorZ * scale
end

---Get random components by deviating away from an existing vector's components.
---`factor` scales with magnitude.
---@param vector table
---@param factorX number
---@param factorY number
---@param factorZ number
---@return number x
---@return number z
local function randomFrom2D(vector, factorX, factorZ)
	local scale = getMagnitude(vector)
	local rx, rz = randomXZ()
	return
		vector[1] + rx * factorX * scale,
		vector[3] + rz * factorZ * scale
end

---Select a random radius between two concentric circles (or shells) uniformly.
---@param inner number
---@param outer number
---@return number radius between `inner` and `outer`
local function _random_annulus(inner, outer)
	local innerSquared = inner * inner
	return math_sqrt(innerSquared + (outer * outer - innerSquared) * math_random())
end

---Get random components from scattering and scaling an existing vector's components.
---`lengthFactor` scales with magnitude.
---@param vector table
---@param angleMax number (0, pi] which is the half-angle
---@param lengthFactor number [-1, 1] <0: shrink factor, >0 symmetric grow/shrink factor
---@return number x
---@return number y
---@return number z
---@return number a magnitude
local function randomFromConic(vector, angleMax, lengthFactor)
	local ux, uy, uz, vx, vy, vz, wx, wy, wz = basisFrom(vector)
	local length = getMagnitude(vector)

	vx, vy, vz = vx / length, vy / length, vz / length

	local r1 = math_random()
	local cos_theta = (1 - r1) + r1 * math_cos(angleMax)
	local sin_theta = math_sqrt(1 - cos_theta * cos_theta)
	local phi = math_random() * 2 * math_pi

	local rx = sin_theta * math_cos(phi)
	local ry = cos_theta -- aligned with `v`
	local rz = sin_theta * math_sin(phi)

	if lengthFactor ~= 0 then
		local scaleMin, scaleMax
		if lengthFactor > 0 then
			-- Grow/shrink symmetrically
			scaleMin = 1 - lengthFactor * 0.5
			scaleMax = 1 + lengthFactor * 0.5
		else
			-- Shrink only
			scaleMin = 1 + lengthFactor
			scaleMax = 1
		end
		length = length * _random_annulus(math_max(0, scaleMin), scaleMax)
	end

	return
		(vx * ry + ux * rx + wx * rz) * length,
		(vy * ry + uy * rx + wy * rz) * length,
		(vz * ry + uz * rx + wz * rz) * length,
		length
end

---Get random components from scattering and scaling an existing vector's components.
---`lengthFactor` scales with magnitude.
---@param vector table
---@param angleMax number (0, pi] which is the half-angle
---@param lengthFactor number [-1, 1] <0: shrink factor, >0 symmetric grow/shrink factor
---@return number x
---@return number z
---@return number a -- magnitude
local function randomFromConicXZ(vector, angleMax, lengthFactor)
	local angle = angleMax * (2 * math_random() - 1)
	local cos_angle = math_cos(angle)
	local sin_angle = math_sin(angle)

	local length = getMagnitude(vector)
	local scale = 1

	if lengthFactor ~= 0 then
		local scaleMin, scaleMax
		if lengthFactor > 0 then
			-- Grow/shrink symmetrically
			scaleMin = 1 - lengthFactor * 0.5
			scaleMax = 1 + lengthFactor * 0.5
		else
			-- Shrink only
			scaleMin = 1 + lengthFactor
			scaleMax = 1
		end
		scale = _random_annulus(math_max(0, scaleMin), scaleMax)
	end

	return
		(vector[1] * cos_angle - vector[3] * sin_angle) * scale,
		(vector[1] * sin_angle + vector[3] * cos_angle) * scale,
		length * scale
end

---Add scatter/jitter/etc. to an existing vector.
---`factor` scales with magnitude.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param factor number
local function randomize(vector, factor)
	if factor > 0 then
		local scale = factor * getMagnitude(vector)
		vector[1] = vector[1] + (2 * math_random() - 1) * scale
		vector[2] = vector[2] + (2 * math_random() - 1) * scale
		vector[3] = vector[3] + (2 * math_random() - 1) * scale
		if vector[4] then
			vector[4] = magnitude(vector)
		end
	end
end

---Add scatter/jitter/etc. to an existing vector.
---`factor` scales with magnitude.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param factor number
local function randomizeXZ(vector, factor)
	if factor > 0 then
		local scale = factor * getMagnitude(vector)
		vector[1] = vector[1] + (2 * math_random() - 1) * scale
		vector[3] = vector[3] + (2 * math_random() - 1) * scale
		if vector[4] then
			vector[4] = magnitudeXZ(vector)
		end
	end
end

---Add scatter/jitter/etc. to an existing vector.
---`factor{XYZ}` scales with magnitude.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param factor number
local function randomize3D(vector, factorX, factorY, factorZ)
	-- still don't trust you crazy kids to check your bounds:
	if factorX > 0 or factorY > 0 or factorZ > 0 then
		if factorX < 0 then factorX = 0 end
		if factorY < 0 then factorY = 0 end
		if factorZ < 0 then factorZ = 0 end
		local scale = getMagnitude(vector)
		vector[1] = vector[1] + (2 * math_random() - 1) * factorX * scale
		vector[2] = vector[2] + (2 * math_random() - 1) * factorY * scale
		vector[3] = vector[3] + (2 * math_random() - 1) * factorZ * scale
		if vector[4] then
			vector[4] = magnitude(vector)
		end
	end
end

---Add scatter/jitter/etc. to an existing vector.
---`factor{XZ}` scales with magnitude.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param factor number
local function randomize2D(vector, factorX, factorZ)
	if factorX > 0 or factorZ > 0 then
		if factorX < 0 then factorX = 0 end
		if factorZ < 0 then factorZ = 0 end
		local scale = getMagnitude(vector)
		vector[1] = vector[1] + (2 * math_random() - 1) * factorX * scale
		vector[3] = vector[3] + (2 * math_random() - 1) * factorZ * scale
		if vector[4] then
			vector[4] = magnitudeXZ(vector)
		end
	end
end

---Add scattering and scaling to an existing vector's components.
---`lengthFactor` scales with magnitude.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param angleMax number (0, pi] which is the half-angle
---@param lengthFactor number [-1, 1] <0: shrink factor, >0 symmetric grow/shrink factor
local function randomizeConic(vector, angleMax, lengthFactor)
	vector[1], vector[2], vector[3], vector[4] = randomFromConic(vector, angleMax, lengthFactor or 0)
end

---Add scattering and scaling to an existing vector's components.
---`lengthFactor` scales with magnitude.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param angleMax number (0, pi] which is the half-angle
---@param lengthFactor number [-1, 1] <0: shrink factor, >0 symmetric grow/shrink factor
local function randomizeConicXZ(vector, angleMax, lengthFactor)
	-- If you are only randomizing xz, but have a valid y,
	-- then this result will give you the wrong magnitude:
	vector[1], vector[3], vector[4] = randomFromConicXZ(vector, angleMax, lengthFactor or 0)
end

--------------------------------------------------------------------------------
-- Constraints -----------------------------------------------------------------

---@param vector table
---@param xMin number
---@param xMax number
---@param yMin number
---@param yMax number
---@param zMin number
---@param zMax number
---@return boolean
local function isInBox(vector, xMin, xMax, yMin, yMax, zMin, zMax)
	local x, y, z = vector[1], vector[2], vector[3]
	return x >= xMin and x <= xMax
		and z >= zMin and z <= zMax
		and y >= yMin and y <= yMax -- y bounds are less likely to be constraining
end

---Test if a vector points within a cone opening downward from `peak`.
---@param vector table
---@param peak table
---@param angle number using the half-angle
---@return boolean
local function isInConeDown(vector, peak, angle)
	local v1, v2, v3 = vector[1], vector[2], vector[3]
	local p1, p2, p3 = peak[1], peak[2], peak[3]
	if v2 > p2 then
		return false
	elseif v2 == p2 then
		return v1 == p1 and v3 == p3
	else
		local peakToVector = float3
		peakToVector[1] = p1 - v1
		peakToVector[2] = p2 - v2
		peakToVector[3] = p3 - v3
		return dot(peakToVector, dirDown) / magnitude(peakToVector) <= math_cos(angle)
	end
end

---Test if a vector points within a cone opening upward from `peak`.
---@param vector table
---@param peak table
---@param angle number using the half-angle
---@return boolean
local function isInConeUp(vector, peak, angle)
	local v1, v2, v3 = vector[1], vector[2], vector[3]
	local p1, p2, p3 = peak[1], peak[2], peak[3]
	if v2 < p2 then
		return false
	elseif v2 == p2 then
		return v1 == p1 and v3 == p3
	else
		local peakToVector = float3
		peakToVector[1] = p1 - v1
		peakToVector[2] = p2 - v2
		peakToVector[3] = p3 - v3
		return dot(peakToVector, dirUp) / magnitude(peakToVector) <= math_cos(angle)
	end
end

---Test if a vector points within a radius around a vertical axis set by `origin`.
---@param vector table
---@param origin table
---@param radius number
---@return boolean
local function isInCylinder(vector, origin, radius)
	local v1, v3 = vector[1], vector[3]
	local o1, o3 = origin[1], origin[3]
	return radius * radius >= (v1 - o1) * (v1 - o1) + (v3 - o3) * (v3 - o3)
end

---Test if a vector points within a radius around `origin`.
---@param vector table
---@param origin table
---@param radius number
---@return boolean
local function isInSphere(vector, origin, radius)
	local v1, v2, v3 = vector[1], vector[2], vector[3]
	local o1, o2, o3 = origin[1], origin[2], origin[3]
	return radius * radius >= (v1 - o1) * (v1 - o1) + (v2 - o2) * (v2 - o2) + (v3 - o3) * (v3 - o3)
end

---Constrain a vector to a set of absolute coordinates.
---
---Modifies `vector`.
---@param vector table
---@param xMin number
---@param xMax number
---@param yMin number
---@param yMax number
---@param zMin number
---@param zMax number
local function limitBox(vector, xMin, xMax, yMin, yMax, zMin, zMax)
	vector[1] = math_clamp(vector[1], xMin, xMax)
	vector[2] = math_clamp(vector[2], yMin, yMax)
	vector[3] = math_clamp(vector[3], zMin, zMax)
end

---Constrain a vector to a conic envelope opening downward from `peak`.
---
---Modifies `vector`.
---@param vector table
---@param peak table
---@param angle number [0, pi] using the half-angle
local function limitConeDown(vector, peak, angle)
	local v1, v2, v3 = vector[1], vector[2], vector[3]
	local p1, p2, p3 = peak[1], peak[2], peak[3]
	if v2 >= p2 then
		vector[1] = p1
		vector[2] = math_min(p2, v2 - math_sin(angle) * (v2 - p2))
		vector[3] = p3
	else
		local peakToVector = float3
		peakToVector[1] = v1 - p1
		peakToVector[2] = v2 - p2
		peakToVector[3] = v3 - p3
		local cos_angle = math_cos(angle)
		if dot(peakToVector, dirDown) / magnitude(peakToVector) <= cos_angle then
			local sin_angle = math_sin(angle)
			-- u: v to cone axis, through nearest point on cone surface
			local u_xz = math_sqrt((v1 - p1) * (v1 - p1) + (v3 - p3) * (v3 - p3))
			local u = u_xz / cos_angle
			local u_y = u * sin_angle
			-- w: peak to intersection of cone axis and u
			local w = (p2 - v2) + u * sin_angle
			-- a: xz-length of u inside of cone
			-- b: y-length of u inside of cone
			-- c: length of u inside of cone
			local c = w * sin_angle
			local a = c * sin_angle
			local b = c * cos_angle
			local angleXZ = math_atan2(p1 - v1, p3 - v3)
			vector[1] = p1 + a * math_cos(angleXZ)
			vector[2] = p2 - w - b
			vector[3] = p3 + a * math_sin(angleXZ)
		end
	end
end

---Constrain a vector to a conic envelope opening upward from `peak`.
---
---Modifies `vector`.
---@param vector table
local function limitConeUp(vector, peak, angle)
	local v1, v2, v3 = vector[1], vector[2], vector[3]
	local p1, p2, p3 = peak[1], peak[2], peak[3]
	if v2 <= p2 then
		vector[1] = p1
		vector[2] = math_max(p2, v2 + math_sin(angle) * (p2 - v2))
		vector[3] = p3
	else
		local peakToVector = float3
		peakToVector[1] = p1 - v1
		peakToVector[2] = p2 - v2
		peakToVector[3] = p3 - v3
		local cos_angle = math_cos(angle)
		if dot(peakToVector, dirUp) / magnitude(peakToVector) <= cos_angle then
			local sin_angle = math_sin(angle)
			-- u: v to cone axis, through nearest point on cone surface
			local u_xz = math_sqrt((v1 - p1) * (v1 - p1) + (v3 - p3) * (v3 - p3))
			local u = u_xz / cos_angle
			local u_y = u * sin_angle
			-- w: peak to intersection of cone axis and u
			local w = (v2 - p2) + u * sin_angle
			-- a: xz-length of u inside of cone
			-- b: y-length of u inside of cone
			-- c: length of u inside of cone
			local c = w * sin_angle
			local a = c * sin_angle
			local b = c * cos_angle
			local angleXZ = math_atan2(p1 - v1, p3 - v3)
			vector[1] = p1 + a * math_cos(angleXZ)
			vector[2] = p2 + w - b
			vector[3] = p3 + a * math_sin(angleXZ)
		end
	end
end

---Constrain a vector to a radius around a given vertical axis, set by a point.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
local function limitCylinder(vector, originXZ, radius)
	local v1, v3 = vector[1], vector[3]
	local o1, o3 = originXZ[1], originXZ[3]
	local r = (v1 - o1) * (v1 - o1) + (v3 - o3) * (v3 - o3)
	if r > radius * radius then
		r = math_sqrt(r) / radius
		vector[1] = v1 - (v1 - o1) / r
		vector[3] = v3 - (v3 - o3) / r
		if vector[4] then
			vector[4] = vector[4] / r
		end
	end
end

---Constrain a vector to a radius around a given point.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
local function limitSphere(vector, origin, radius)
	local v1, v2, v3 = vector[1], vector[2], vector[3]
	local o1, o2, o3 = origin[1], origin[2], origin[3]
	local r = (v1 - o1) * (v1 - o1) + (v2 - o2) * (v2 - o2) + (v3 - o3) * (v3 - o3)
	if r > radius * radius then
		r = math_sqrt(r) / radius
		vector[1] = v1 - (v1 - o1) / r
		vector[2] = v2 - (v2 - o2) / r
		vector[3] = v3 - (v3 - o3) / r
		if vector[4] then
			vector[4] = vector[4] / r
		end
	end
end

---Reduce a vector proportionally against a mask vector with an intensity.
---
---- Between perpendicular and opposite, reduction scales from `factor` to `1`.
---- Otherwise, no reduction occurs.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param vectorMask table must be a unitary vector
---@param factor number reduction intensity, [0 to 1], where 1+ is a binary mask
local function mask(vector, vectorMask, factor)
	if factor > 0 then
		local angle = dot(vector, vectorMask)
		-- We only care about perpendicular or obtuse angles:
		if angle <= 0 then
			if factor >= 1 then
				vector[1], vector[2], vector[3] = 0, 0, 0
				if vector[4] then vector[4] = 0 end
			else
				local m = getMagnitude(vector)
				local scale = 1 - (angle / m * (1 - factor) + factor)
				vector[1] = vector[1] * scale
				vector[2] = vector[2] * scale
				vector[3] = vector[3] * scale
				if vector[4] then
					vector[4] = m * scale
				end
			end
		end
	end
end

---Reduce a vector proportionally against a mask vector with an intensity.
---
---- Between perpendicular and opposite, reduction scales from `factor` to `1`.
---- Otherwise, no reduction occurs.
---
---Modifies `vector` and updates its augment, if present.
---@param vector table
---@param vectorMask table must be a unitary vector
---@param factor number reduction intensity, [0 to 1], where 1+ is a binary mask
local function maskXZ(vector, vectorMask, factor)
	if factor > 0 then
		local angle = dotXZ(vector, vectorMask)
		-- We only care about perpendicular or obtuse angles:
		if angle <= 0 then
			if factor >= 1 then
				vector[1], vector[3] = 0, 0
				if vector[4] then vector[4] = 0 end
			else
				local m = getMagnitude(vector)
				local scale = 1 - (angle / m * (1 - factor) + factor)
				vector[1] = vector[1] * scale
				vector[3] = vector[3] * scale
				if vector[4] then
					vector[4] = m * scale
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- General kinematics ----------------------------------------------------------

-- A vector module shouldn't get into these kinds of specifics, but in our case
-- we can build toward a specific target (that has specific, quirky kinematics).

-- These functions are tailored toward RecoilEngine so include more assumptions.
-- For example, these assume that `velocity` contains its augment term (speed),
-- and angular speeds are constant rates, rather than building up acceleration.

---Modifies `position` and `velocity`.
---@param position table
---@param velocity table
---@param acceleration number
---@param speedMax number
local function updateSpeedAndPosition(position, velocity, acceleration, speedMax)
	local speed = velocity[4] or magnitude(velocity)
	local speedNew = speed + acceleration
	local ratio = speedNew < speedMax and speedNew / speed or 1
	velocity[1] = velocity[1] * ratio
	velocity[2] = velocity[2] * ratio
	velocity[3] = velocity[3] * ratio
	position[1] = position[1] + velocity[1]
	position[2] = position[2] + velocity[2]
	position[3] = position[3] + velocity[3]
end

---tbh, this is just `vector.add`.
---
---Modifies `position`.
---@param position table
---@param velocity table
local function updatePosition(position, velocity)
	position[1] = position[1] + velocity[1]
	position[2] = position[2] + velocity[2]
	position[3] = position[3] + velocity[3]
end

---Modifies `velocity`.
---@param velocity table
---@param acceleration number
---@param speedMax number
local function accelerate(velocity, acceleration, speedMax)
	local speed = velocity[4]
	local speedNew = speed + acceleration
	local ratio = speedNew < speedMax and speedNew / speed or 1
	velocity[1] = velocity[1] * ratio
	velocity[2] = velocity[2] * ratio
	velocity[3] = velocity[3] * ratio
end

---Modifies `velocity`.
---@param velocity table
---@param deceleration number
---@param speedMin number
local function decelerate(velocity, deceleration, speedMin)
	local speed = velocity[4]
	local speedNew = speed - deceleration
	local ratio = (speedNew > speedMin and speedNew or speedMin) / speed
	velocity[1] = velocity[1] * ratio
	velocity[2] = velocity[2] * ratio
	velocity[3] = velocity[3] * ratio
end

---Modifies `velocity`.
---@param velocity table
---@param angle number
local function turnDown(velocity, angle)
	local speed = velocity[4]
	local pitch = math_asin(velocity[2] / speed)
	if pitch - angle <= -RAD_NORMAL_EPSILON then
		velocity[1], velocity[3] = 0, 0
		velocity[2] = -speed
	else
		pitch = pitch - angle
		local cos_pitch = math_cos(pitch)
		velocity[1] = velocity[1] * cos_pitch
		velocity[2] = speed * math_sin(pitch)
		velocity[3] = velocity[3] * cos_pitch
	end
end

---Modifies `velocity`.
---@param velocity table
---@param angle number
local function turnUp(velocity, angle)
	local speed = velocity[4]
	local pitch = math_asin(velocity[2] / speed)
	if pitch + angle >= RAD_NORMAL_EPSILON then
		velocity[1], velocity[3] = 0, 0
		velocity[2] = speed
	else
		pitch = pitch + angle
		local cos_pitch = math_cos(pitch)
		velocity[1] = velocity[1] * cos_pitch
		velocity[2] = speed * math_sin(pitch)
		velocity[3] = velocity[3] * cos_pitch
	end
end

---Does not use the actual left-orientation of an object, solely considering trajectory.
---Thus, gradually moves toward horizontal if not already moving at level.
---Fails when `velocity` is vertical because "left" and "right" are relative terms.
---
---Modifies `velocity`.
---@param velocity table
---@param angle number
local function turnLeft(velocity, angle)
	local heading = math_atan2(velocity[1], velocity[3])
	local speedUp = velocity[2]
	local speed = velocity[4]
	if speedUp == 0 or math_abs(speedUp / speed) < ARC_EPSILON then
		heading = heading + angle
		local cos_heading = math_cos(heading)
		local sin_heading = math_sin(heading)
		velocity[1] = speed * cos_heading
		velocity[2] = 0
		velocity[3] = speed * sin_heading
	else
		-- Remove up to half of the `angle` from the pitch, instead.
		-- This is not really a good, intended use case.
		local pitch = math_asin(speedUp / speed)
		local anglePitch = angle * 0.5 * pitch / math_pi
		pitch = pitch + (pitch > 0 and -anglePitch or anglePitch)
		local cos_pitch = math_cos(pitch)

		heading = heading + angle * math_cos(anglePitch)
		local cos_heading = math_cos(heading)
		local sin_heading = math_sin(heading)

		velocity[1] = speed * cos_heading * cos_pitch
		velocity[2] = speed * math_sin(pitch)
		velocity[3] = speed * sin_heading * cos_pitch
	end
end

---Does not use the actual right-orientation of an object, solely considering trajectory.
---Thus, gradually moves toward horizontal if not already moving at level.
---Fails when `velocity` is vertical because "left" and "right" are relative terms.
---
---Modifies `velocity`.
---@param velocity table
---@param angle number
local function turnRight(velocity, angle)
	local heading = math_atan2(velocity[1], velocity[3])
	local speedUp = velocity[2]
	local speed = velocity[4]
	if speedUp == 0 or math_abs(speedUp / speed) < ARC_EPSILON then
		heading = heading - angle
		local cos_heading = math_cos(heading)
		local sin_heading = math_sin(heading)
		velocity[1] = speed * cos_heading
		velocity[2] = 0
		velocity[3] = speed * sin_heading
	else
		-- Remove up to half of the `angle` from the pitch, instead.
		-- This is not really a good, intended use case.
		local pitch = math_asin(speedUp / speed)
		local anglePitch = angle * 0.5 * pitch / math_pi
		pitch = pitch + (pitch > 0 and -anglePitch or anglePitch)
		local cos_pitch = math_cos(pitch)

		heading = heading - angle * math_cos(anglePitch)
		local cos_heading = math_cos(heading)
		local sin_heading = math_sin(heading)

		velocity[1] = speed * cos_heading * cos_pitch
		velocity[2] = speed * math_sin(pitch)
		velocity[3] = speed * sin_heading * cos_pitch
	end
end

---Basic movement under gravity. Does not allow terminal speeds above the base speed.
---
---Modifies `position` and `velocity`, and lazy-evaluates speed.
---@param position table
---@param velocity table
---@param speedMax number
---@param gravity number
local function updateBallistics(position, velocity, speedMax, gravity)
	velocity[2] = velocity[2] - gravity
	local speed = velocity[4]

	if speed + gravity > speedMax then
		speed = magnitude(velocity)
		if speed > speedMax then
			local ratio = speed / speedMax
			velocity[1] = velocity[1] * ratio
			velocity[2] = velocity[2] * ratio
			velocity[3] = velocity[3] * ratio
			velocity[4] = speedMax
		else
			velocity[4] = speed
		end
	else
		velocity[4] = nil
	end

	position[1] = position[1] + velocity[1]
	position[2] = position[2] + velocity[2]
	position[3] = position[3] + velocity[3]
end

---Simple controlled movement that ignores gravity. Does not pursue moving targets efficiently.
---You can start with low initial pursuit guidance (chaseFactor = 2) to prevent overcorrection.
---
---Modifies `position` and `velocity`.
---@param position table
---@param target table
---@param velocity table
---@param speedMax number
---@param accelerationMax number
---@param turnAngleMax number
---@param chaseFactor number [0, 2] where 0: full turn to target, 1: constant turn to target, 2: excessively lazy
---@return boolean updated
local function updateGuidance(position, velocity, target, speedMax, accelerationMax, turnAngleMax, chaseFactor)
	local displacement = float3a
	displacement[1] = target[1] - position[1]
	displacement[2] = target[2] - position[2]
	displacement[3] = target[3] - position[3]
	local distance = magnitude(displacement)
	displacement[4] = distance

	if distance > XYZ_PATH_EPSILON then
		local angleBetween = getAngleBetween(velocity, displacement)
		local cos_angle = math_cos(angleBetween)

		local forwardness = 1 - cos_angle * cos_angle
		local acceleration = accelerationMax * forwardness

		if angleBetween > RAD_EPSILON then
			-- Such that `slerp` will turn by exactly `turnAngleMax`:
			local angleFactor = turnAngleMax / angleBetween

			-- With more time and distance, we can be lazier, allowing guidance to follow a "chase cone"
			-- instead of tracking directly onto its target. This helps slightly to follow moving targets.
			local distanceFactor = velocity[4] * cos_angle / distance
			chaseFactor = chaseFactor * forwardness
			angleFactor = angleFactor * (1 - chaseFactor * distanceFactor / (distanceFactor + angleFactor))

			slerp(velocity, displacement, angleFactor)
		end

		updateSpeedAndPosition(position, velocity, acceleration, speedMax)

		return true
	else
		return false
	end
end

---Simple controlled movement under gravity. Does not pursue moving targets efficiently.
---
---Modifies `position` and `velocity`.
---@param position table
---@param target table
---@param velocity number
---@param speedMax number
---@param acceleration number
---@param turnAngle number
---@param gravity number
---@return number? accelerationX `number` desired constant acceleration | `nil` if unresolved
---@return number? accelerationY
---@return number? accelerationZ
local function updateSemiballistics(position, target, velocity, speedMax, acceleration, turnAngle, gravity)
	local velocityX = velocity[1]
	local velocityY = velocity[2]
	local velocityZ = velocity[3]
	local speed = velocity[4]

	local positionX = position[1]
	local positionY = position[2]
	local positionZ = position[3]

	local turnAccel = turnAngle * speed

	local tti
	do
		local a = 0.5 * gravity
		-- local b = speed
		local c = positionY - target[2]
		local discriminant = speed * speed - 4 * a * c
		if discriminant >= 0 then
			discriminant = math_sqrt(discriminant)
			local t1 = (-speed + discriminant) / (2 * a)
			local t2 = (-speed - discriminant) / (2 * a)
			if t1 >= 0 and t2 >= 0 then
				tti = math_min(t1, t2)
			elseif t1 >= 0 then
				tti = t1
			elseif t2 >= 0 then
				tti = t2
			end
			if not tti or tti < 1 then
				return
			end
		end
	end

	-- todo: This compensates for `speedMax` in the calcs above, but not in the below:

	-- The ideal guidance is taken to be constant acceleration towards the target:
	local accelX = (target[1] - positionX - velocityX * tti) * 2 / (tti * tti)
	local accelY = (target[2] - positionY - velocityY * tti) * 2 / (tti * tti)
	local accelZ = (target[3] - positionZ - velocityZ * tti) * 2 / (tti * tti)

	-- Aiming should have compensated for gravity already:
	accelY = accelY + gravity

	local accelWanted = math_sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)

	local forward = accelX * velocityX + accelY * velocityY + accelZ * velocityZ
	local angular = math_sqrt(accelWanted * accelWanted - forward * forward)

	if forward <= acceleration and angular <= turnAccel or
		-- Turn rate is just free acceleration, if you're willing to cheat, which we are, so:
		forward <= acceleration + turnAccel * 0.5 and angular <= turnAccel - (forward - acceleration)
	then
		velocityX = velocityX + accelX
		velocityY = velocityY + accelY - gravity
		velocityZ = velocityZ + accelZ

		velocity[1] = velocityX
		velocity[2] = velocityY
		velocity[3] = velocityZ
		velocity[4] = math_sqrt(velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ)

		position[1] = positionX + velocityX
		position[2] = positionY + velocityY
		position[3] = positionZ + velocityZ

		return accelX, accelY, accelZ
	end
end

--------------------------------------------------------------------------------
-- Export ----------------------------------------------------------------------

return {
	copy                   = copy,
	vector3                = vector3,
	vector3a               = vector3a,
	vectorXZ               = vectorXZ,
	vectorXZa              = vectorXZa,
	getTolerances          = getTolerances,

	copyFrom               = copyFrom,
	zeroes                 = zeroes,
	refill                 = refill,
	refillXZ               = refillXZ,
	repack                 = repack,
	repackXZ               = repackXZ,
	repackXZa              = repackXZa,

	magnitude              = magnitude,
	magnitudeXZ            = magnitudeXZ,
	getMagnitude           = getMagnitude,
	getMagnitudeXZ         = getMagnitudeXZ,
	isUnitary              = isUnitary,
	isUnitaryXZ            = isUnitaryXZ,
	isWeighted             = isWeighted,
	isWeightedXZ           = isWeightedXZ,
	isZero                 = isZero,
	isZeroXZ               = isZeroXZ,

	add                    = add,
	addXZ                  = addXZ,
	addNumber              = addNumber,
	addNumberXZ            = addNumberXZ,
	subtract               = subtract,
	subtractXZ             = subtractXZ,
	multiply               = multiply,
	multiplyXZ             = multiplyXZ,
	divide                 = divide,
	divideXZ               = divideXZ,
	normalize              = normalize,
	normalizeXZ            = normalizeXZ,
	setMagnitude           = setMagnitude,
	setMagnitudeXZ         = setMagnitudeXZ,
	setWeight              = setWeight,
	setWeightXZ            = setWeightXZ,
	toUnitary              = toUnitary,
	toUnweighted           = toUnweighted,
	mix                    = mix,
	mixXZ                  = mixXZ,
	mixMagnitude           = mixMagnitude,
	mixMagnitudeXZ         = mixMagnitudeXZ,
	rotateTo               = rotateTo,
	rotateToXZ             = rotateToXZ,
	slerp                  = slerp,
	mixRotation            = mixRotation,
	mixRotationXZ          = mixRotationXZ,

	dot                    = dot,
	dotXZ                  = dotXZ,
	dotUnit                = dotUnit,
	dotUnitXZ              = dotUnitXZ,
	cross                  = cross,
	crossXZ                = crossXZ,
	hadamard               = hadamard,
	hadamardXZ             = hadamardXZ,

	distance               = distance,
	distanceXZ             = distanceXZ,
	distanceSquared        = distanceSquared,
	distanceSquaredXZ      = distanceSquaredXZ,
	getAngleBetween        = getAngleBetween,
	getAngleBetweenXZ      = getAngleBetweenXZ,
	projection             = projection,
	projectionXZ           = projectionXZ,
	rejection              = rejection,
	rejectionXZ            = rejectionXZ,

	versor                 = versor,
	versorXZ               = versorXZ,
	displacement           = displacement,
	displacementXZ         = displacementXZ,

	basisFrom              = basisFrom,
	repackBasis            = repackBasis,
	areNormal              = areNormal,
	areNormalXZ            = areNormalXZ,
	areOrthonormal         = areOrthonormal,
	areOrthonormalXZ       = areOrthonormalXZ,

	random                 = random,
	randomXZ               = randomXZ,
	randomFrom             = randomFrom,
	randomFromXZ           = randomFromXZ,
	randomFrom3D           = randomFrom3D,
	randomFrom2D           = randomFrom2D,
	randomFromConic        = randomFromConic,
	randomFromConicXZ      = randomFromConicXZ,
	randomize              = randomize,
	randomizeXZ            = randomizeXZ,
	randomize3D            = randomize3D,
	randomize2D            = randomize2D,
	randomizeConic         = randomizeConic,
	randomizeConicXZ       = randomizeConicXZ,

	isInBox                = isInBox,
	isInConeDown           = isInConeDown,
	isInConeUp             = isInConeUp,
	isInCylinder           = isInCylinder,
	isInSphere             = isInSphere,
	limitBox               = limitBox,
	limitConeDown          = limitConeDown,
	limitConeUp            = limitConeUp,
	limitCylinder          = limitCylinder,
	limitSphere            = limitSphere,
	mask                   = mask,
	maskXZ                 = maskXZ,

	updateSpeedAndPosition = updateSpeedAndPosition,
	updatePosition         = updatePosition,
	accelerate             = accelerate,
	decelerate             = decelerate,
	turnUp                 = turnUp,
	turnDown               = turnDown,
	turnLeft               = turnLeft,
	turnRight              = turnRight,
	updateBallistics       = updateBallistics,
	updateGuidance         = updateGuidance,
	updateSemiballistics   = updateSemiballistics,
}

--------------------------------------------------------------------------------
-- Footnotes -------------------------------------------------------------------

-- You need to keep track of normalization, denormalization, and augmentation
-- while writing code. Your reviewer also needs to be able to do this. Add
-- comments when normalization is not needed and when it is guaranteed, etc.

-- This module contains a number of functions that _do not_ check for div-zero.
-- These are elementary operations (or their prototypes) that will always, 100%
-- of the time, exist inside of other functions while serving specific purposes.
-- You need to be able to verify for yourself when to check boundary conditions.
-- The set of tolerances values, if needed, is available from `getTolerances`.

-- There are also subtle pitfalls that require more explanation:

-- - Very few functions force the augment (`vector[4]`) term to update, which
--   can lead to magnitudes becoming incorrect or stale following mutations.
-- - The `slerp` rotation interpolation does not attempt to handle cases where
--   the two vectors are exactly opposite (though, it indicates this result).
-- - The functions `turnLeft` and `turnRight` are basic prototypical movements
--   that you'd likely adapt for your own use case. Still, they do not check
--   at all for vectors aligned with the Up/Down axis, so might emit `NaN`s.

-- Once you start getting into use-case code, more results are provided when
-- a vector mutates or fails to mutate so you can handle this logically:

-- - The `updateBallistics` function is unique (so far) for un-setting its
--   augmented term rather than reevaluating it and for doing so silently.
-- - The `updateGuidance` function may avoid updating position and velocity
--   when its guidance strategy cannot be met. It indicates this result.
-- - The `updateSemiballistics` function has an empty return on any failure
--   and returns an acceleration plan for future frames on a success.
