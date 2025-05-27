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
