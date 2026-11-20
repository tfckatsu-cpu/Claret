-- Ring descriptors are cached independently of cursor position and display filters.
local params = import('/lua/ui/game/rangeoverlayparams.lua').RangeOverlayParams
local getEnhancements = import('/lua/enhancementcommon.lua').GetEnhancements
local rangeTypes = {
    UWRC_DirectFire = 'AllMilitary',
    UWRC_IndirectFire = 'IndirectFire',
    UWRC_AntiAir = 'AntiAir',
    UWRC_AntiNavy = 'AntiNavy',
    UWRC_Countermeasure = 'Defense',
}
local rangeWeapons = {
    ual0001 = { RightDisruptor = true, ChronoDampener = true },
    uel0001 = { RightZephyr = true },
    url0001 = { RightRipper = true, MLG = true },
    xsl0001 = { ChronotronCannon = true },
    ual0301 = { RightReactonCannon = true },
    uel0301 = { RightHeavyPlasmaCannon = true },
    url0301 = { RightDisintegrator = true },
    xsl0301 = { LightChronatronCannon = true },
}
local empty = {}
local overcharge = { OverCharge = true, AutoOverCharge = true }
local styles = {}
for _, kind in ipairs({
    'AllMilitary', 'IndirectFire', 'AntiAir', 'AntiNavy', 'Defense',
    'Radar', 'Sonar', 'Omni', 'CounterIntel', 'Miscellaneous',
}) do
    local style = params[kind]
    styles[kind] = { color = 'ff' .. string.sub(style.NormalColor, 3), thickness = style.Outer[1] / style.Type }
end

local function Add(rings, kind, radius)
    if type(radius) ~= 'number' or radius <= 0 then return end
    local style = styles[kind]
    table.insert(rings, { kind = kind, radius = radius, color = style.color, thickness = style.thickness })
end

local function Describe(blueprint, installed)
    local rings = {}
    local enhancements = blueprint.Enhancements or empty
    local preset = blueprint.EnhancementPresetAssigned or empty
    local weaponLabels = rangeWeapons[preset.BaseBlueprintId or blueprint.BlueprintId]
    local unlocked = {}
    local weaponRange, radar, omni
    for _, name in pairs(installed or preset.Enhancements or empty) do
        local enhancement = enhancements[name]
        if enhancement then
            unlocked[name] = true
            if enhancement.NewMaxRadius then weaponRange = math.max(weaponRange or 0, enhancement.NewMaxRadius) end
            if enhancement.NewRadarRadius then radar = math.max(radar or 0, enhancement.NewRadarRadius) end
            if enhancement.NewOmniRadius then omni = math.max(omni or 0, enhancement.NewOmniRadius) end
        end
    end
    for _, weapon in ipairs(blueprint.Weapon or empty) do
        local kind = rangeTypes[weapon.RangeCategory]
        if kind and (not weapon.EnabledByEnhancement or unlocked[weapon.EnabledByEnhancement]) then
            local radius = weapon.MaxRadius
            if weaponRange and weaponLabels and (weaponLabels[weapon.Label] or overcharge[weapon.Label]) then
                radius = weaponRange
            end
            Add(rings, kind, radius)
        end
    end
    local intel = blueprint.Intel or empty
    Add(rings, 'Radar', radar or intel.RadarRadius)
    Add(rings, 'Sonar', intel.SonarRadius)
    Add(rings, 'Omni', omni or intel.OmniRadius)
    Add(rings, 'CounterIntel', math.max(
        intel.CloakFieldRadius or 0, intel.RadarStealthFieldRadius or 0, intel.SonarStealthFieldRadius or 0))
    return rings
end

function CreateCache()
    local byBlueprint = {}
    local byUnit = setmetatable({}, { __mode = 'k' })
    local cache = {}

    function cache:Get(blueprint, unit)
        if not blueprint then return empty end
        local installed = unit and blueprint.Enhancements and getEnhancements(unit:GetEntityId())
        if installed then
            local cached = byUnit[unit]
            if not cached or cached.blueprint ~= blueprint or cached.installed ~= installed then
                cached = { blueprint = blueprint, installed = installed, rings = Describe(blueprint, installed) }
                byUnit[unit] = cached
            end
            return cached.rings
        end
        local rings = byBlueprint[blueprint]
        if not rings then
            rings = Describe(blueprint)
            byBlueprint[blueprint] = rings
        end
        return rings
    end

    return cache
end

function Style(kind)
    return styles[kind]
end
