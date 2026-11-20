local Game = import('/lua/ui/game/gamemain.lua')
local identifier = 'ClaretUI.Notifications'
local hqLayers = {
    land = { suffix = '01', frame = 'land' },
    air = { suffix = '02', frame = 'air' },
    naval = { suffix = '03', frame = 'sea' },
}
local hqFactions = { [0] = 'ueb', [1] = 'uab', [2] = 'urb', [3] = 'xsb' }
local icons = '/mods/ClaretUI/textures/notifications/'

local function NukeIcon(unit)
    if unit:IsInCategory('STRUCTURE') then return icons .. 'nuke-silo.png' end
    if unit:IsInCategory('NAVAL') and unit:IsInCategory('SUBMERSIBLE') then return icons .. 'nuke-sub.png' end
    return nil
end

local function HQIcon(army, tech, layer)
    local armies = GetArmiesTable()
    local data = armies and armies.armiesTable and armies.armiesTable[army]
    local faction = data and hqFactions[data.faction]
    if not faction then return nil end
    local UI = import('/lua/ui/uiutil.lua')
    local dir = '/icons/units/'
    local icon = UI.UIFile(dir .. faction .. '0' .. tech .. layer.suffix .. '_icon.dds', true)
    if not icon or not DiskGetFileInfo(icon) then return nil end
    return icon, UI.UIFile(dir .. layer.frame .. '_up.dds')
end

local function Owned(unit, army)
    return unit and not unit:IsDead() and unit:GetArmy() == army
end

function Start(self, scope, isReplay, options)
    local army = Game.OriginalFocusArmy
    if isReplay or type(army) ~= 'number' or army < 1 then return end

    local display = import('/mods/ClaretUI/modules/NotificationDisplay.lua').Create(scope, options)
    local watched, pending = {}, {}
    local builders = {}
    local sampling = false
    local nextSample = 0

    local function OnEnhancements(messages)
        if GetFocusArmy() ~= army then return end
        for _, message in ipairs(messages) do
            if message.army == army and message.trigger == 'completed' and type(message.source) == 'string' then
                if message.category == 'tech' and options.notificationsHQ:Get() then
                    local layer, tech = string.match(message.source, '^research(%a+)tech([23])$')
                    local hq = layer and hqLayers[layer]
                    if hq then
                        local icon, frame = HQIcon(army, tech, hq)
                        display:Show('hq', 'hq_' .. layer, tech, icon, frame)
                    end
                elseif message.id and options.notificationsACU:Get() and not string.find(message.source, 'Remove', 1, true) then
                    local unit = GetUnitById(message.id)
                    if Owned(unit, army) and unit:IsInCategory('COMMAND') then
                        local bp = unit:GetBlueprint()
                        local enhancement = bp and bp.Enhancements and bp.Enhancements[message.source]
                        if enhancement then
                            local icon
                            if bp.BlueprintId and enhancement.Icon then
                                local construction = import('/lua/ui/game/construction.lua')
                                local texture = construction.GetEnhancementTextures(bp.BlueprintId, enhancement.Icon)
                                if texture and DiskGetFileInfo(texture) then icon = texture end
                            end
                            display:Show('acu', nil, {
                                id = message.source,
                                unitId = bp.BlueprintId,
                                name = enhancement.Name or message.source,
                            }, icon)
                        end
                    end
                end
            end
        end
    end

    local function Discover(unit)
        if Owned(unit, army) and unit:IsInCategory('NUKE') then
            local id = unit:GetEntityId()
            if not watched[id] then watched[id] = { unit = unit } end
        end
    end

    local function OnSelection(selection)
        builders = {}
        if GetFocusArmy() ~= army then return end
        for _, unit in ipairs(selection or {}) do
            if Owned(unit, army) then
                Discover(unit)
                if unit:IsInCategory('ENGINEER') or unit:IsInCategory('FACTORY') or unit:IsInCategory('COMMAND') then
                    table.insert(builders, unit)
                end
            end
        end
    end

    local function SelectionChanged(info)
        OnSelection(info.newSelection)
    end

    local function OnUnitData(data)
        if GetFocusArmy() ~= army then return end
        for key, value in pairs(data) do
            local id = tonumber(key)
            if id and value and not watched[id] and not pending[id] then pending[id] = 3 end
        end
    end

    local function Sample()
        if GetFocusArmy() ~= army then return end
        local now = GetSystemTimeSeconds()
        if now < nextSample then return end
        nextSample = now + 0.5
        for id, attempts in pairs(pending) do
            local unit = GetUnitById(id)
            if unit then
                Discover(unit)
                pending[id] = nil
            else
                pending[id] = attempts > 1 and attempts - 1 or nil
            end
        end
        for _, builder in ipairs(builders) do
            if Owned(builder, army) then Discover(builder:GetFocus()) end
        end
        for id, state in pairs(watched) do
            local unit = state.unit
            if not Owned(unit, army) then
                watched[id] = nil
            else
                local missiles = unit:GetMissileInfo()
                local count = missiles and missiles.nukeSiloStorageCount
                if type(count) == 'number' and count >= 0 then
                    local previous = state.count
                    state.count = count
                    if previous and count > previous then
                        display:Show('nuke', nil, nil, NukeIcon(unit))
                    end
                else
                    state.count = nil
                end
            end
        end
    end

    local function StopSampling()
        if not sampling then return end
        sampling = false
        Game.RemoveBeatFunction(Sample)
        Game.ObserveSelection:AddObserver(nil, identifier)
        RemoveOnSyncHashedCallback('UnitData', identifier)
        watched, pending, builders = {}, {}, {}
    end

    local function UpdateSampling()
        if not options.notificationsNuke:Get() or GetFocusArmy() ~= army then
            StopSampling()
            return
        end
        if sampling then return end
        sampling = true
        nextSample = 0
        OnUnitData(UnitData)
        OnSelection(GetSelectedUnits())
        AddOnSyncHashedCallback(OnUnitData, 'UnitData', identifier)
        Game.ObserveSelection:AddObserver(SelectionChanged, identifier)
        Game.AddBeatFunction(Sample, true)
    end

    scope:Defer(StopSampling)
    scope:Bind(options.notificationsNuke.OnChanged, UpdateSampling)
    scope:Defer(function()
        RemoveOnSyncHashedCallback('EnhanceMessage', identifier)
        RemoveOnSyncHashedCallback('FocusArmyChanged', identifier)
    end)
    AddOnSyncHashedCallback(OnEnhancements, 'EnhanceMessage', identifier)
    AddOnSyncHashedCallback(function()
        display:Clear()
        StopSampling()
        UpdateSampling()
    end, 'FocusArmyChanged', identifier)
    UpdateSampling()
end
