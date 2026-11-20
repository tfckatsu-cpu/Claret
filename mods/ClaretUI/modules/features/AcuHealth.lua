-- Claret UI: commander health panel.
--
-- Original implementation written for Claret. The behaviour follows the
-- documented ACUHealth panel (see .tools/specs/acu-hp.md); no third-party code
-- is used or copied.
--
-- FAF LuaPlus dialect: table.getn instead of the length operator, import
-- instead of require, no continue/goto, math.mod where needed.

local PREF_KEY = 'ClaretUI_AcuBox'
local LOG_PREFIX = '[ClaretUI][acu] '

-- Logical panel base size. There is deliberately no Theme token for the
-- overlay box: the slider scales this 200x30 logical rectangle.
local BASE_WIDTH = 200
local BASE_HEIGHT = 30
-- Shield strip height in logical units (the brief fixes it at 5 px).
local SHIELD_HEIGHT = 5

local DEATH_MESSAGE_TIME = 2
local BREAKUP_TIME = 0.72
local SHARD_TEXTURE = '/mods/ClaretUI/textures/acu/shard-'
-- Logical bounds of the seven matching masks and their launch trajectories.
-- The masks use the scrim fill and accent color along the fracture edges.
local DEATH_PIECES = {
    { x = 0,   y = 0,  width = 51, height = 18, drift = -58, lift = -48, drop = 65 },
    { x = 44,  y = 0,  width = 74, height = 18, drift = -13, lift = -69, drop = 67 },
    { x = 112, y = 0,  width = 88, height = 18, drift = 54,  lift = -46, drop = 56 },
    { x = 0,   y = 13, width = 35, height = 17, drift = -44, lift = 12,  drop = 58 },
    { x = 28,  y = 12, width = 66, height = 18, drift = -24, lift = -6,  drop = 86 },
    { x = 87,  y = 11, width = 81, height = 19, drift = 14,  lift = 16,  drop = 48 },
    { x = 159, y = 11, width = 41, height = 19, drift = 69,  lift = -3,  drop = 72 },
}

-- Refresh cadence: every 5th beat of the shared beat list (~10 beats/s).
local BEAT_INTERVAL = 5

-- HP fractions: colour steps and the alarm threshold.
local HIGH_FRACTION = 0.75
local LOW_FRACTION = 0.3
local ALARM_FRACTION = 0.15
local ALARM_CLEAR = 0.17
local CRITICAL_FRACTION = 0.05
local CRITICAL_CLEAR = 0.07
local ALARM_PERIOD = 0.8
local CRITICAL_PERIOD = 1.1
local SECOND_PULSE_TIME = 0.23

local DEFAULT_LOGICAL_X = 500
local DEFAULT_LOGICAL_Y = 170

-- The panel scale is independent of the shared UI scale.
local DEFAULT_SCALE = 100
local MIN_SCALE = 50
local MAX_SCALE = 200

-- Engine globals are not always visible through rawget(_G, name); read them by
-- their real names inside pcall, as the rest of Claret does.
-- LuaPlus module tables raise on missing fields, so every probe of a module
-- (or engine) field goes through pcall and falls back to nil.
local function Probe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

-- ReUI.ClaretCore.Localization is the public facade; the Core module is the
-- fallback when this file is loaded without Core's Main having run.
local function ResolveLocalization()
    local facade = Probe(function()
        local localization = ReUI.ClaretCore.Localization
        if type(localization) == 'table' and type(localization.Text) == 'function' then
            return localization
        end
        return nil
    end)
    if facade ~= nil then return facade end
    local module = Probe(function()
        return import('/mods/ClaretCore/modules/Localization.lua').Localization
    end)
    if type(module) == 'table' and type(module.Text) == 'function' then return module end
    return nil
end

-- Every user-visible string goes through localisation; the key itself is shown
-- only when the dictionary is missing, so no English text is baked in here.
local function MakeText(localization)
    return function(key, first)
        if localization ~= nil then
            local ok, value = pcall(localization.Text, key, first)
            if ok and type(value) == 'string' and value ~= '' then return value end
        end
        return key
    end
end

local function IsCommander(unit)
    return Probe(function() return unit:IsInCategory('COMMAND') end) == true
end

local function IsDead(unit)
    return Probe(function() return unit:IsDead() end)
end

-- Avatar membership can change independently of the commander's life state.
local searchFailureLogged = false
local function FindCommander(previous)
    local ok, avatars = pcall(function() return GetArmyAvatars() end)
    local dead = false
    if not ok or type(avatars) ~= 'table' then
        if not searchFailureLogged then
            LOG(LOG_PREFIX .. 'GetArmyAvatars failed or returned ' .. type(avatars) .. ': ' .. tostring(avatars))
            searchFailureLogged = true
        end
    else
        searchFailureLogged = false
        for _, unit in pairs(avatars) do
            if IsCommander(unit) then
                local unitDead = IsDead(unit)
                if unitDead == false then return unit, false end
                dead = dead or unitDead == true
            end
        end
    end
    return nil, dead or (previous ~= nil and IsDead(previous) == true)
end

local function ReadNumber(unit, method, fallback)
    local value = Probe(function() return unit[method](unit) end)
    if type(value) == 'number' and value == value then return value end
    return fallback
end

local function ReadShieldMaximum(unit)
    return Probe(function()
        local blueprint = unit:GetBlueprint()
        local shield = blueprint.Defense and blueprint.Defense.Shield
        local maximum = shield and shield.ShieldMaxHealth
        if type(maximum) == 'number' and maximum > 0 then return maximum end
        local enhancements = import('/lua/enhancementcommon.lua').GetEnhancements(unit:GetEntityId())
        if type(enhancements) ~= 'table' then return nil end
        for _, name in pairs(enhancements) do
            local enhancement = blueprint.Enhancements and blueprint.Enhancements[name]
            maximum = enhancement and enhancement.ShieldMaxHealth
            if type(maximum) == 'number' and maximum > 0 then return maximum end
        end
        return nil
    end)
end

local module = {}

---@param scope table Claret feature scope created by Lifecycle.Create
---@param isReplay boolean
function module:Start(scope, isReplay, options)
    if type(scope) ~= 'table' or type(scope.Own) ~= 'function' or type(scope.Defer) ~= 'function' then
        LOG(LOG_PREFIX .. 'start aborted: feature scope is unavailable')
        return
    end

    local okTheme, Theme = pcall(import, '/mods/ClaretCore/modules/Theme.lua')
    if not okTheme or type(Theme) ~= 'table' then
        LOG(LOG_PREFIX .. 'start aborted: ClaretCore theme is unavailable')
        return
    end
    local C = Probe(function() return Theme.Colors end)
    local metrics = Probe(function() return Theme.Metrics end)
    local fonts = Probe(function() return Theme.Fonts end)
    if type(C) ~= 'table' or type(metrics) ~= 'table' or type(fonts) ~= 'table' then
        LOG(LOG_PREFIX .. 'start aborted: ClaretCore theme is incomplete')
        return
    end

    local Layout = Probe(function() return ReUI.UI.FloorLayoutFor end)
    if Layout == nil then
        LOG(LOG_PREFIX .. 'start aborted: ReUI.UI layout helper is unavailable')
        return
    end

    local Bitmap = Probe(function()
        return import('/lua/maui/bitmap.lua').Bitmap
    end)
    -- Maui classes are callable tables (ClassUI + __call), not plain functions.
    if Bitmap == nil or (type(Bitmap) ~= 'function' and type(Bitmap) ~= 'table') then
        LOG(LOG_PREFIX .. 'start aborted: Bitmap is unavailable')
        return
    end

    local uiutil = Probe(function() return import('/lua/ui/uiutil.lua') end)
    local createText = type(uiutil) == 'table' and Probe(function() return uiutil.CreateText end) or nil
    if type(createText) ~= 'function' then
        LOG(LOG_PREFIX .. 'start aborted: UI text is unavailable')
        return
    end

    local borders = Probe(function() return import('/lua/ui/game/borders.lua') end)
    local getMapGroup = type(borders) == 'table' and Probe(function() return borders.GetMapGroup end) or nil
    local mapGroup = nil
    if type(getMapGroup) == 'function' then
        local okGroup, group = pcall(getMapGroup)
        if okGroup then mapGroup = group end
    end
    if mapGroup == nil then
        LOG(LOG_PREFIX .. 'start aborted: the map group is unavailable')
        return
    end

    local Prefs = Probe(function() return import('/lua/user/prefs.lua') end)
    if type(Prefs) ~= 'table' then Prefs = nil end

    local localization = ResolveLocalization()
    if localization == nil then LOG(LOG_PREFIX .. 'localisation is unavailable; keys will be shown') end
    local T = MakeText(localization)

    -- UI scale in screen pixels per logical unit. The shared layouter already
    -- uses it, so this only corrects text sizes and saved coordinates.
    local pixel = Probe(function() return Layout:ScaleNumber(1) end)
    if type(pixel) ~= 'number' or pixel <= 0 then
        pixel = 1
        LOG(LOG_PREFIX .. 'UI scale is unavailable; assuming 1.0')
    end

    -- Screen pixels to logical units. The layouter exposes ScaleNumber only, so
    -- the inverse is plain division by the same factor.
    local function Unscale(value)
        if type(pixel) ~= 'number' or pixel <= 0 then return value end
        return value / pixel
    end

    -- Theme has no shield token; the cool blue reads as shielding over the fill.
    local SHIELD_COLOR = C.keyCombo1

    local box = {
        scale = DEFAULT_SCALE,
        beats = 0,
        alarm = 0,
        lastHp = nil,
        x = DEFAULT_LOGICAL_X,
        y = DEFAULT_LOGICAL_Y,
        innerWidth = BASE_WIDTH,
        visible = true,
        beatObserved = false,
        loggedKind = nil,
        current = { kind = 'searching' },
    }

    local function ReadSaved()
        if Prefs == nil then return end
        local getValue = Probe(function() return Prefs.GetFromCurrentProfile end)
        if type(getValue) ~= 'function' then return end
        local ok, saved = pcall(getValue, PREF_KEY)
        if not ok then
            LOG(LOG_PREFIX .. 'saved layout could not be read')
            return
        end
        if saved == nil then return end
        if type(saved) ~= 'table' then
            LOG(LOG_PREFIX .. 'ignoring malformed saved layout')
            return
        end
        if type(saved.x) == 'number' and saved.x == saved.x
            and type(saved.y) == 'number' and saved.y == saved.y then
            box.x, box.y = saved.x, saved.y
        else
            LOG(LOG_PREFIX .. 'saved layout has no usable position')
        end
        box.legacySize = saved.size
    end

    -- Saved values are logical: screen pixels divided by the UI scale, so the
    -- box keeps its place when the interface scale changes.
    local function SaveBox()
        if Prefs == nil or box.panel == nil then return end
        local writeValue = Probe(function() return Prefs.SetToCurrentProfile end)
        if type(writeValue) ~= 'function' then return end
        local record = {
            x = Unscale(box.panel.Left() - mapGroup.Left()),
            y = Unscale(box.panel.Top() - mapGroup.Top()),
            size = box.legacySize,
        }
        local ok, err = pcall(writeValue, PREF_KEY, record)
        if not ok then
            LOG(LOG_PREFIX .. 'saved layout could not be written: ' .. tostring(err))
            return
        end
        local flush = Probe(function() return SavePreferences end)
        if type(flush) == 'function' then
            local flushed, flushError = pcall(flush)
            if not flushed then
                LOG(LOG_PREFIX .. 'preferences could not be flushed: ' .. tostring(flushError))
            end
        end
    end

    ReadSaved()

    local scaleOption = type(options) == 'table' and options.acuScale or nil
    local lockOption = type(options) == 'table' and options.acuLocked or nil
    local locked = lockOption ~= nil and lockOption:Get() == true
    if scaleOption ~= nil then
        local savedScale = Probe(function() return scaleOption:Get() end)
        if type(savedScale) == 'number' and savedScale >= MIN_SCALE and savedScale <= MAX_SCALE then
            box.scale = math.floor(savedScale / 5 + 0.5) * 5
        end
    end

    local panel = scope:Own(Bitmap(mapGroup))
    box.panel = panel
    module.panel = panel
    panel:SetSolidColor(C.scrim)
    if locked then panel:DisableHitTest() else panel:EnableHitTest() end
    -- Live depth: the map group can be raised together with the game UI.
    panel.Depth:Set(function() return mapGroup.Depth() + 10 end)

    local alarmBorder = Bitmap(panel)
    alarmBorder:SetSolidColor(C.danger)
    alarmBorder:DisableHitTest()
    alarmBorder.Depth:Set(function() return panel.Depth() + 1 end)
    Layout(alarmBorder):FillFixedBorder(panel, 0)
    alarmBorder:SetAlpha(0)
    alarmBorder:Hide()

    local track = Bitmap(panel)
    track:SetSolidColor(C.raised)
    track:DisableHitTest()
    track.Depth:Set(function() return alarmBorder.Depth() + 1 end)

    local fill = Bitmap(track)
    fill:SetSolidColor(C.health)
    fill:DisableHitTest()
    fill.Depth:Set(function() return track.Depth() + 1 end)

    local shield = Bitmap(track)
    shield:SetSolidColor(SHIELD_COLOR)
    shield:DisableHitTest()
    shield.Depth:Set(function() return fill.Depth() + 1 end)
    shield:Hide()

    local alarmCorners = {}
    for index = 1, 8 do
        local edge = Bitmap(panel)
        edge:SetSolidColor(C.danger)
        edge:DisableHitTest()
        edge.Depth:Set(function() return shield.Depth() + 1 end)
        edge:SetAlpha(0)
        edge:Hide()
        alarmCorners[index] = edge
    end

    local label = createText(panel, T('claretui.acu.searching'), metrics.caption, fonts.body)
    label:SetColor(C.text)
    label:DisableHitTest()
    label.Depth:Set(function() return shield.Depth() + 2 end)
    if Probe(function() return label.SetDropShadow end) ~= nil then
        local okShadow, shadowError = pcall(label.SetDropShadow, label, true)
        if not okShadow then LOG(LOG_PREFIX .. 'text shadow failed: ' .. tostring(shadowError)) end
    end

    local function ApplySize()
        local factor = box.scale / 100
        local inset = metrics.panelRadius / 2 * factor
        -- Text takes a logical point size, corrected by the box scale over the
        -- UI scale so it grows with the panel and not with the screen alone.
        local scale = pixel * factor
        local ratio = scale / pixel
        if Probe(function() return label.SetFont end) ~= nil then
            local okFont, fontError = pcall(label.SetFont, label, fonts.body, metrics.caption * ratio)
            if not okFont then LOG(LOG_PREFIX .. 'text size failed: ' .. tostring(fontError)) end
        end
        box.innerWidth = BASE_WIDTH * factor - inset * 2
        -- Logical sizes go through the layout helper; nothing sets raw pixels.
        Layout(panel):Width(BASE_WIDTH * factor):Height(BASE_HEIGHT * factor)
        Layout(track):FillFixedBorder(panel, inset)
        Layout(fill):AtLeftTopIn(track, 0, 0):FillVertically(track)
        Layout(shield):AtLeftTopIn(track, 0, 0):Height(SHIELD_HEIGHT * factor)
        local width, height = BASE_WIDTH * factor, BASE_HEIGHT * factor
        local length, thickness = 12 * factor, 3 * factor
        for index = 1, 4 do
            local right = math.mod(index, 2) == 0
            local bottom = index > 2
            local x = right and width - length or 0
            local y = bottom and height - thickness or 0
            Layout(alarmCorners[index]):AtLeftTopIn(panel, x, y):Width(length):Height(thickness)
            x = right and width - thickness or 0
            y = bottom and height - length or 0
            Layout(alarmCorners[index + 4]):AtLeftTopIn(panel, x, y):Width(thickness):Height(length)
        end
        Layout(label):AtCenterIn(panel)
    end

    local function ApplyPosition()
        -- box.x/y are logical; the helper multiplies them by the UI scale.
        Layout(panel):AtLeftTopIn(mapGroup, box.x, box.y)
    end

    local pieces
    local alarmPhase
    local pulseLevel = 0
    local function SetAlarmPulse(level)
        if level > 0 then
            if pulseLevel == level then return end
            pulseLevel = level
            alarmPhase = 0
            alarmBorder:SetAlpha(1)
            alarmBorder:Show()
            panel:SetNeedsFrameUpdate(true)
        else
            alarmBorder:SetAlpha(0)
            alarmBorder:Hide()
            if alarmPhase ~= nil then
                alarmPhase = nil
                fill:SetAlpha(1)
                panel:SetNeedsFrameUpdate(false)
            end
            pulseLevel = 0
        end
        for _, edge in ipairs(alarmCorners) do
            edge:SetAlpha(level == 2 and 1 or 0)
            if level == 2 then edge:Show() else edge:Hide() end
        end
    end

    local function StopBreakup()
        panel:SetNeedsFrameUpdate(false)
        if pieces ~= nil then
            for _, piece in ipairs(pieces) do piece:Destroy() end
            pieces = nil
        end
        label:SetAlpha(1)
        panel:SetSolidColor(C.scrim)
    end

    local function ResetDeath()
        if box.deathElapsed == nil then return end
        StopBreakup()
        box.deathElapsed = nil
        if locked then panel:DisableHitTest() else panel:EnableHitTest() end
        track:Show()
    end

    local function FinishDeath()
        box.deathElapsed = DEATH_MESSAGE_TIME + BREAKUP_TIME
        StopBreakup()
        panel:Hide()
    end

    local previousOnFrame = panel.OnFrame
    panel.OnFrame = function(self, delta)
        if previousOnFrame then previousOnFrame(self, delta) end
        if alarmPhase ~= nil then
            local period = pulseLevel == 2 and CRITICAL_PERIOD or ALARM_PERIOD
            alarmPhase = math.mod(alarmPhase + delta, period)
            local intensity
            if pulseLevel == 2 then
                local first = 1 - alarmPhase / 0.13
                local second = 1 - math.abs(alarmPhase - SECOND_PULSE_TIME) / 0.1
                intensity = math.max(0, first, second)
                for _, edge in ipairs(alarmCorners) do edge:SetAlpha(0.24 + 0.76 * intensity) end
            else
                intensity = (1 + math.cos(2 * math.pi * alarmPhase / period)) / 2
            end
            alarmBorder:SetAlpha(0.38 + 0.62 * intensity)
            fill:SetAlpha(0.72 + 0.28 * intensity)
            return
        end
        if box.deathElapsed == nil then return end
        box.deathElapsed = box.deathElapsed + delta
        local progress = (box.deathElapsed - DEATH_MESSAGE_TIME) / BREAKUP_TIME
        if progress < 0 then return end
        if progress >= 1 then
            FinishDeath()
            return
        end

        if pieces == nil then
            pieces = {}
            panel:SetSolidColor(C.transparent)
            for index in ipairs(DEATH_PIECES) do
                local piece = Bitmap(panel)
                piece:SetTexture(SHARD_TEXTURE .. index .. '.png')
                piece:DisableHitTest()
                piece.Depth:Set(function() return panel.Depth() + 1 end)
                pieces[index] = piece
            end
        end

        local factor = box.scale / 100
        local drift = progress * (2 - progress)
        local fall = progress * progress
        local opacity = math.min(1, (1 - progress) / 0.72)
        for index, shape in ipairs(DEATH_PIECES) do
            local piece = pieces[index]
            local x = shape.x + shape.drift * drift
            local y = shape.y + shape.lift * progress + shape.drop * fall
            Layout(piece):AtLeftTopIn(panel, x * factor, y * factor)
                :Width(shape.width * factor):Height(shape.height * factor)
            piece:SetAlpha(opacity)
        end
        label:SetAlpha(math.max(0, 1 - progress / 0.32))
    end
    scope:Defer(function()
        if not IsDestroyed(panel) then panel:SetNeedsFrameUpdate(false) end
    end)

    -- Reads the current state only; never changes selection or units.
    local function Render()
        if not box.visible then return end
        local current = box.current
        if current.kind == 'dead' then
            if box.deathElapsed == nil then
                box.deathElapsed = 0
                panel:Show()
                SetAlarmPulse(0)
                panel:DisableHitTest()
                track:Hide()
                fill:Hide()
                shield:Hide()
                panel:SetNeedsFrameUpdate(true)
            end
            if box.deathElapsed < DEATH_MESSAGE_TIME + BREAKUP_TIME then
                label:SetColor(C.text)
                label:SetFont(fonts.body, metrics.caption * box.scale / 100)
                label:SetText(T('claretui.acu.dead'))
                label:Show()
            end
            return
        end
        ResetDeath()
        panel:Show()
        SetAlarmPulse(current.kind == 'alive' and box.alarm or 0)
        if current.kind == 'alive' then
            local fraction = current.fraction
            local fillColor = C.danger
            if fraction > HIGH_FRACTION then fillColor = C.health
            elseif fraction > LOW_FRACTION then fillColor = C.warning end
            label:SetColor(C.text)
            local text = string.format('%d HP %+d%s', math.floor(current.hp), math.floor(current.regen), T('claretui.acu.per_second'))
            local hasShield = current.shieldMax or (current.shield and current.shield > 0)
            if hasShield then
                local shieldText = current.shield ~= nil and string.format('%d%%', math.floor(current.shield * 100 + 0.5)) or '?'
                text = text .. ' | ' .. shieldText .. ' ' .. T('claretui.acu.shield')
            end
            label:SetText(text)
            local textSize = metrics.caption * box.scale / 100
            if hasShield then textSize = textSize * 0.72 end
            label:SetFont(fonts.body, textSize)
            fill:Show()
            fill:SetSolidColor(fillColor)
            Layout(fill):Width(math.max(1, box.innerWidth * fraction))
            label:Show()
            if current.shield and current.shield > 0 then
                shield:Show()
                Layout(shield):Width(math.max(1, box.innerWidth * current.shield))
            else
                shield:Hide()
            end
        else
            label:Show()
            label:SetColor(C.muted)
            label:SetText(T('claretui.acu.searching'))
            fill:Hide()
            shield:Hide()
        end
    end

    local function ArmAlarm(fraction)
        local previous = box.alarm
        local level = 0
        if fraction > 0 then
            if fraction < CRITICAL_FRACTION or (previous == 2 and fraction < CRITICAL_CLEAR) then
                level = 2
            elseif fraction < ALARM_FRACTION or (previous > 0 and fraction < ALARM_CLEAR) then
                level = 1
            end
        end
        box.alarm = level
    end

    local function LogState(kind)
        if box.loggedKind ~= kind then
            box.loggedKind = kind
            LOG(LOG_PREFIX .. 'commander state=' .. kind)
        end
    end

    local function Refresh()
        local focus = Probe(function() return GetFocusArmy() end)
        local sameFocus = focus == box.focus
        if not sameFocus then
            ResetDeath()
            box.focus = focus
            box.commander = nil
            box.commanderId = nil
            box.lastHp = nil
        end

        local unit, dead = FindCommander(box.commander)
        local hp, maxHp
        if unit ~= nil then
            box.commander = unit
            local id = ReadNumber(unit, 'GetEntityId', unit)
            if id ~= box.commanderId then
                SetAlarmPulse(0)
                box.alarm = 0
                box.commanderId = id
                box.lastHp = nil
            end
            hp = ReadNumber(unit, 'GetHealth')
            maxHp = ReadNumber(unit, 'GetMaxHealth')
        end

        if hp == nil or maxHp == nil or maxHp <= 0 then
            box.lastHp = nil
            box.alarm = 0
            if unit == nil and sameFocus and box.current.kind == 'dead' then dead = true end
            if dead then box.commander = nil end
            if dead and sameFocus and box.current.kind == 'dead' then return end
            box.current = { kind = dead and 'dead' or 'searching' }
            LogState(box.current.kind)
            Render()
            return
        end
        LogState('alive')
        local regen = Probe(function() return unit:GetStat('HitpointsRegeneration', 0).Value end)
        if type(regen) ~= 'number' or regen ~= regen then regen = 0 end
        box.lastHp = hp
        local fraction = hp / maxHp
        if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
        local shieldRatio = ReadNumber(unit, 'GetShieldRatio')
        if shieldRatio and shieldRatio < 0 then shieldRatio = 0 elseif shieldRatio and shieldRatio > 1 then shieldRatio = 1 end
        local shieldMax = ReadShieldMaximum(unit)
        box.current = {
            kind = 'alive',
            hp = hp,
            regen = regen,
            fraction = fraction,
            shield = shieldRatio,
            shieldMax = shieldMax,
        }
        ArmAlarm(fraction)
        Render()
    end

    local function OnBeat()
        if not box.beatObserved then
            box.beatObserved = true
            LOG(LOG_PREFIX .. 'first game beat received')
        end
        if not box.visible then return end
        box.beats = box.beats + 1
        if box.beats < BEAT_INTERVAL then return end
        box.beats = 0
        local ok, err = pcall(Refresh)
        if not ok then LOG(LOG_PREFIX .. 'refresh failed: ' .. tostring(err)) end
    end

    local function ClampToScreen(left, top)
        local getFrame = Probe(function() return GetFrame end)
        if type(getFrame) ~= 'function' then return left, top end
        local ok, frame = pcall(getFrame, 0)
        if not ok or frame == nil then return left, top end
        local minLeft, minTop = frame.Left(), frame.Top()
        local maxLeft, maxTop = frame.Right() - panel.Width(), frame.Bottom() - panel.Height()
        if maxLeft < minLeft then maxLeft = minLeft end
        if maxTop < minTop then maxTop = minTop end
        if left < minLeft then left = minLeft elseif left > maxLeft then left = maxLeft end
        if top < minTop then top = minTop elseif top > maxTop then top = maxTop end
        return left, top
    end

    local function ApplyScale(sender, value)
        if type(value) ~= 'number' or value < MIN_SCALE or value > MAX_SCALE then return end
        box.scale = math.floor(value / 5 + 0.5) * 5
        ApplySize()
        local left, top = ClampToScreen(panel.Left(), panel.Top())
        panel.Left:Set(left)
        panel.Top:Set(top)
        box.x = Unscale(left - mapGroup.Left())
        box.y = Unscale(top - mapGroup.Top())
        Render()
    end

    if scaleOption ~= nil then
        local added = Probe(function()
            scaleOption.OnChanged:Add(ApplyScale)
            return true
        end)
        if added then
            scope:Defer(function()
                local ok, err = pcall(function() scaleOption.OnChanged:Remove(ApplyScale) end)
                if not ok then LOG(LOG_PREFIX .. 'scale subscription cleanup failed: ' .. tostring(err)) end
            end)
        else
            LOG(LOG_PREFIX .. 'scale setting subscription is unavailable')
        end
        local function SaveScalePosition()
            SaveBox()
        end
        local savedSubscription = Probe(function()
            scaleOption.OnSaved:Add(SaveScalePosition)
            return true
        end)
        if savedSubscription then
            scope:Defer(function()
                local ok, err = pcall(function() scaleOption.OnSaved:Remove(SaveScalePosition) end)
                if not ok then LOG(LOG_PREFIX .. 'scale save subscription cleanup failed: ' .. tostring(err)) end
            end)
        end
    end

    local activeDrag
    local function CancelDrag()
        if activeDrag then activeDrag:OnCancel() end
    end
    local function StartDrag(event)
        if locked or activeDrag then return false end
        local draggerModule = Probe(function() return import('/lua/maui/dragger.lua') end)
        local makeDragger = type(draggerModule) == 'table' and Probe(function()
            return draggerModule.Dragger
        end) or nil
        if makeDragger == nil then LOG(LOG_PREFIX .. 'drag is unavailable: Dragger missing'); return false end
        local okRoot, root = pcall(function() return panel:GetRootFrame() end)
        if not okRoot or root == nil then
            LOG(LOG_PREFIX .. 'drag is unavailable: the root frame is missing')
            return false
        end
        local pointerX, pointerY = event.MouseX, event.MouseY
        if type(pointerX) ~= 'number' or type(pointerY) ~= 'number' then
            local getMouse = Probe(function() return GetMouseScreenPos end)
            if type(getMouse) == 'function' then
                local ok, position = pcall(getMouse)
                if ok and type(position) == 'table' then pointerX, pointerY = position[1], position[2] end
            end
        end
        if type(pointerX) ~= 'number' or type(pointerY) ~= 'number' then
            LOG(LOG_PREFIX .. 'drag is unavailable: no pointer position')
            return false
        end
        local startLeft, startTop = panel.Left(), panel.Top()
        local drag = makeDragger()
        local function Release(control)
            if activeDrag == control then activeDrag = nil end
            if type(control.Destroy) == 'function' then pcall(control.Destroy, control) end
        end
        drag.OnMove = function(self, x, y)
            local ok, err = pcall(function()
                local left, top = ClampToScreen(startLeft + (x - pointerX), startTop + (y - pointerY))
                panel.Left:Set(left)
                panel.Top:Set(top)
            end)
            if not ok then LOG(LOG_PREFIX .. 'drag move failed: ' .. tostring(err)) end
        end
        drag.OnRelease = function(self)
            local ok, err = pcall(function()
                box.x = Unscale(panel.Left() - mapGroup.Left())
                box.y = Unscale(panel.Top() - mapGroup.Top())
                SaveBox()
            end)
            if not ok then LOG(LOG_PREFIX .. 'drag release failed: ' .. tostring(err)) end
            Release(self)
        end
        drag.OnCancel = function(self)
            local ok, err = pcall(function()
                panel.Left:Set(startLeft)
                panel.Top:Set(startTop)
            end)
            if not ok then LOG(LOG_PREFIX .. 'drag cancel failed: ' .. tostring(err)) end
            Release(self)
        end
        activeDrag = drag
        local posted, postError = pcall(function() PostDragger(root, event.KeyCode, drag) end)
        if not posted then
            LOG(LOG_PREFIX .. 'drag could not start: ' .. tostring(postError))
            Release(drag)
            return false
        end
        return true
    end

    local function HandleEvent(control, event)
        local eventType = event and event.Type
        if eventType == 'ButtonPress' then
            local modifiers = event.Modifiers
            if modifiers ~= nil and modifiers.Left then
                return StartDrag(event)
            end
        end
        return false
    end

    panel.HandleEvent = function(self, event)
        local ok, handled = pcall(HandleEvent, self, event)
        if not ok then
            LOG(LOG_PREFIX .. 'panel input failed: ' .. tostring(handled))
            return false
        end
        return handled == true
    end

    local function ApplyLock()
        locked = lockOption:Get() == true
        if locked then CancelDrag() end
        if locked or box.deathElapsed ~= nil then panel:DisableHitTest() else panel:EnableHitTest() end
    end
    if lockOption then lockOption.OnChanged:Add(ApplyLock) end
    scope:Defer(function()
        if lockOption then lockOption.OnChanged:Remove(ApplyLock) end
        CancelDrag()
    end)

    ApplySize()
    ApplyPosition()
    panel:Show()
    local refreshed, refreshError = pcall(Refresh)
    if not refreshed then LOG(LOG_PREFIX .. 'initial refresh failed: ' .. tostring(refreshError)) end

    module.setVisibility = function(visible)
        box.visible = visible
        if visible then
            local ok, err = pcall(Refresh)
            if not ok then LOG(LOG_PREFIX .. 'visibility refresh failed: ' .. tostring(err)) end
        else
            CancelDrag()
            SetAlarmPulse(0)
            if box.deathElapsed ~= nil then FinishDeath() end
            label:Hide()
            panel:Hide()
        end
    end

    local GameMain = Probe(function() return import('/lua/ui/game/gamemain.lua') end)
    local addBeat = type(GameMain) == 'table' and Probe(function() return GameMain.AddBeatFunction end) or nil
    local removeBeat = type(GameMain) == 'table' and Probe(function()
        return GameMain.RemoveBeatFunction
    end) or nil
    if type(addBeat) == 'function' and type(removeBeat) == 'function' then
        addBeat(OnBeat)
        scope:Defer(function()
            local ok, err = pcall(removeBeat, OnBeat)
            if not ok then LOG(LOG_PREFIX .. 'beat function could not be removed: ' .. tostring(err)) end
        end)
    else
        LOG(LOG_PREFIX .. 'beat function is unavailable; the panel will not update')
    end

    if localization ~= nil and type(localization.Subscribe) == 'function' then
        local subscribed = pcall(localization.Subscribe, panel, function()
            local ok, err = pcall(Render)
            if not ok then LOG(LOG_PREFIX .. 'language refresh failed: ' .. tostring(err)) end
        end)
        if subscribed then
            scope:Defer(function() pcall(localization.Unsubscribe, panel) end)
        end
    end

    LOG(LOG_PREFIX .. 'started; replay=' .. tostring(isReplay) .. ' scale=' .. tostring(box.scale))
end

-- Driven by the Claret UI toggle; the panel is created once and only shown or
-- hidden, so toggling never rebuilds hooks or loses the saved position.
function module:SetVisible(visible)
    if self.setVisibility then self.setVisibility(visible) end
end

-- FAF's import returns the module environment, not this file's return value, so
-- the feature API is exported as globals. The receiver passed by the host is
-- ignored on purpose: all panel state lives on the private `module` table.
Start = function(self, scope, isReplay, options) return module.Start(module, scope, isReplay, options) end
SetVisible = function(self, visible) return module.SetVisible(module, visible) end
