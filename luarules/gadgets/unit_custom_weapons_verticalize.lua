local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Semiballistic cruise and verticalize",
		desc    = "Trajectory alchemy for projectiles that must not hit terrain",
		author  = "efrec",
		license = "GNU GPL, v2 or later",
		layer   = -10000, -- before other gadgets can process projectiles -- todo: check specifics
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- [1] Cruise altitude is set by the launcher and uptime -----------------------
--                                                                            --
--                             (+ extra height)                               --
-- cruise altitude min x------------------------------x                       --
--                    /                                \                      --
--                   /                                  \                     --
--  end uptime pos  x                                    x   verticalized     --
--                  |                                    |                    --
--                  |                                    |                    --
-- launch position  x                                    |                    --
--                                                       |                    --
--                                                       x   target position  --
--                                                                            --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- [2] Cruise altitude is set by the target position ---------------------------
--                                                                            --
--                             (+ extra height)                               --
--                     x------------------------------x  cruise altitude min  --
--                    /                                \                      --
--                   /                                  \                     --
-- ascend position  x                                    x   verticalized     --
--                  |                                    |                    --
--                  |                                    |                    --
--  end uptime pos  x                                    x   target position  --
--                  |                                                         --
--                  |                                                         --
-- launch position  x                                                         --
--                                                                            --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local cruiseHeightFloor       = 50    -- note: barely above ground
local cruiseHeightCeiling     = 10000 -- note: soaring off-screen

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileTarget   = Spring.SetProjectileTarget
local spSetProjectileVelocity = Spring.SetProjectileVelocity

local gravityPerFrame         = -Game.gravity / (Game.gameSpeed ^ 2)

local targetedGround          = string.byte('g')
local targetedUnit            = string.byte('u')

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weapons                 = {}

local ascending               = {}
local cruising                = {}
local verticalizing           = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function parseCustomParams(weaponDef)
	local success = true

	local cruiseHeightMin, cruiseExtraHeight, uptimeMin, uptimeMax

	-- StarburstLauncher weapons have an early timeout that we have to handle
	-- and a different set of weapondef properties from missiles (e.g. uptime).
	local isStarburstWeapon = weaponDef.type == "StarburstLauncher"

	if weaponDef.customParams.cruise_altitude_min then
		if weaponDef.customParams.cruise_altitude_min == "auto" then
			cruiseHeightMin = "auto" -- determined from uptime
		else
			cruiseHeightMin = tonumber(weaponDef.customParams.cruise_altitude_min)
		end
	end

	if weaponDef.customParams.cruise_extra_height then
		cruiseExtraHeight = tonumber(weaponDef.customParams.cruise_extra_height)
	elseif weaponDef.trajectoryHeight > 0 then
		cruiseExtraHeight = weaponDef.trajectoryHeight -- does not work correctly
		local message = weaponDef.name .. " should not have a trajectoryHeight value"
		Spring.Log(gadget:GetInfo().name, LOG.NOTICE, message)
	else
		cruiseExtraHeight = 1.0 -- so a fallback value is okay for now
	end

	if weaponDef.customParams.uptime_min then
		uptimeMin = tonumber(weaponDef.customParams.uptime_min)
	elseif weaponDef.customParams.uptime then
		uptimeMin = tonumber(weaponDef.customParams.uptime)
	end

	if weaponDef.customParams.uptime_max then
		uptimeMax = tonumber(weaponDef.customParams.uptime_max)
	elseif weaponDef.customParams.uptime then
		uptimeMax = tonumber(weaponDef.customParams.uptime)
	end

	-- We should yell more often about bad customparams when we can:

	if not cruiseHeightMin then
		local message = weaponDef.name .. " needs a cruise_altitude_min value"
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

	if not cruiseExtraHeight then
		local message = weaponDef.name .. " has a bad cruise_extra_height value"
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

	if not uptimeMin then
		local message = weaponDef.name .. " needs a uptime_min (or uptime) value"
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

	if not uptimeMax then
		local message = weaponDef.name .. " needs a uptime_max (or uptime) value"
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

	-- This gadget uses the engine's motion controls. Derive the extents of that motion:

	local acceleration = weaponDef.weaponAcceleration
	local speedMin = weaponDef.startvelocity
	local speedMax = weaponDef.projectilespeed
	local turnRate = weaponDef.turnRate

	if turnRate == 0 then
		local message = weaponDef.name .. " cannot define a curve without a turnRate"
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

	local uptimeMinFrames = uptimeMin * Game.gameSpeed
	local uptimeMaxFrames = uptimeMax * Game.gameSpeed

	local accelerationFrames = 0
	if acceleration and acceleration ~= 0 then
		accelerationFrames = math_min((speedMax - speedMin) / acceleration, uptimeMinFrames)
	end

	local turnSpeedMin = speedMin + accelerationFrames * acceleration
	local turnHeightMin = turnSpeedMin * (uptimeMinFrames - accelerationFrames * 0.5)
	local turnRadiusMax = speedMax / turnRate / math_pi

	if cruiseHeightMin == "auto" then
		cruiseHeightMin = turnHeightMin + turnRadiusMax
	end

	cruiseHeightMin = math_clamp(cruiseHeightMin, cruiseHeightFloor, cruiseHeightCeiling)
	cruiseExtraHeight = math_clamp(cruiseExtraHeight, (isStarburstWeapon and 1 or 0), 4)

	local rangeMinimum = 2 * (turnSpeedMin / turnRate / math_pi) -- maybe overcompensates for slow accel?

	---@class VerticalMissileWeapon
	local weapon = {
		acceleration      = acceleration,
		speedMax          = speedMax,
		speedMin          = speedMin,
		turnRate          = turnRate,

		heightIntoTurn    = turnHeightMin,
		rangeMinimum      = rangeMinimum,
		uptimeMaxFrames   = uptimeMaxFrames,
		uptimeMinFrames   = uptimeMinFrames,
		respawning        = isStarburstWeapon,

		cruiseHeight      = cruiseHeightMin,
		cruiseExtraHeight = cruiseExtraHeight,
		turnRadius        = turnRadiusMax,
	}

	if isStarburstWeapon then
		-- Get the ProjectileParams properties for SpawnProjectile.
		if weaponDef.myGravity and weaponDef.myGravity ~= 0 then
			weapon.gravity = weaponDef.myGravity
		end

		if weaponDef.model then
			weapon.model = weaponDef.model
		end

		if weaponDef.cegTag then
			weapon.cegtag = weaponDef.cegTag
		end
	end

	if success then
		return weapon
	end
end

-- todo: achieve the target curve using only SetProjectileTarget and engine move controls
-- todo: do this by extending the tangent line of the curve to the target axis
-- todo: and, from the first point onward, changing only the height above target

local getUptime, respawnWithUptime -- lexical scope fix, see below

local function newProjectile(projectileID, weaponDefID)
end

getUptime = function(projectile, height)
end

respawnWithUptime = function(projectileID, projectile, uptime)
end

local function ascend(projectileID, projectile)
end

local function cruise(projectileID, projectile)
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID = 0, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponDefID]

		-- Working with missiles and starbursts together is an awkward challenge.
		-- StarburstProjectile uses a strict timeout on its `turnToTarget` value.
		if weaponDef.customParams.cruise_and_verticalize and (
				weaponDef.type == "MissileLauncher" or
				(weaponDef.type == "TorpedoLauncher" and weaponDef.subMissile) or
				weaponDef.type == "StarburstLauncher"
			)
		then
			local weapon = parseCustomParams(weaponDef)

			if weapon then
				weapons[weaponDefID] = weapon
				Script.SetWatchProjectile(weaponDefID, true)
			end
		end
	end

	if not next(weapons) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No weapons found.")
		gadgetHandler:RemoveGadget(self)
		return
	end

	-- todo: obviously do not delete everyone's projectiles in production
	local deleteAll = { -1e9, -1e9, 1e9, 1e9, false, false }
	for _, projectileID in ipairs(Spring.GetProjectilesInRectangle(unpack(deleteAll))) do
		Spring.DeleteProjectile(projectileID)
	end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	if weapons[weaponDefID] then
		newProjectile(projectileID, weaponDefID)
	end
end

function gadget:ProjectileDestroyed(projectileID, ownerID, weaponDefID)
	ascending[projectileID] = nil
	cruising[projectileID] = nil
end

function gadget:GameFrame(frame)
	for projectileID, projectile in pairs(ascending) do
		ascend(projectileID, projectile)
	end

	for projectileID, projectile in pairs(cruising) do
		cruise(projectileID, projectile)
	end
end
