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

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
    local health, healthMax = Spring.GetFeatureHealth(featureID)
    local healthPart = health / healthMax

    if part < 0 then
        if -part < healthPart then
            Spring.SetFeatureHealth(featureID, healthMax * (healthPart + part))
        else
            Spring.DestroyFeature(featureID)
        end
    elseif part > 0 and healthPart < 1 then
        Spring.SetFeatureHealth(featureID, healthMax * math.min(1, healthPart + part))
        return false
    end

    return true
end
