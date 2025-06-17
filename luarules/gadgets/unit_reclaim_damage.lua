local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Reclaim Degrades Features',
        desc      = '',
        author    = '',
        version   = 'v0',
        date      = '',
        license   = 'GNU GPL, v2 or later',
        layer     = 999999,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local math_clamp = math.clamp

local spDestroyFeature = Spring.DestroyFeature
local spGetFeatureHealth = Spring.GetFeatureHealth
local spSetFeatureHealth = Spring.SetFeatureHealth

-- NB: Features have very different health when compared to units.
-- They can have strange health:build costs or even fractional HP.
local healthMaxFractionalLimit = 10

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
    local health, healthMax = spGetFeatureHealth(featureID)
    local healthAfter = math_clamp(health / healthMax + part, 0, 1)

    if part < 0 and (healthAfter == 0 or (healthMax > healthMaxFractionalLimit and healthMax * healthAfter < 1)) then
        spDestroyFeature(featureID)
    elseif healthAfter < 1 then
        spSetFeatureHealth(featureID, healthMax * healthAfter)
        return part < 0
    end

    return true
end
