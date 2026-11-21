-- Claret UI section: a list of feature groups on the left and the selected
-- group's settings on the right. Only the right column changes width.
local Theme = import('/mods/ClaretCore/modules/Theme.lua')
local C = Theme.Colors
local M = Theme.Metrics
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UI = import('/lua/ui/uiutil.lua')
local Helpers = import('/lua/maui/layouthelpers.lua')
local IntegerSlider = import('/lua/maui/slider.lua').IntegerSlider
local selectionFields = import('/mods/ClaretUI/modules/SelectionHudFields.lua').Fields

local LIST_WIDTH = 224
local DETAIL_WIDTH = 384
local DETAIL_GAP = M.panelGap
local ROW_HEIGHT = M.rowHeight
local ROW_GAP = 8
local DETAIL_HEADER_HEIGHT = 68
local DETAIL_ROW_GAP = 8
local PREVIEW_KEYS = {
    { value = 'SHIFT', labelKey = 'claretui.key.shift', width = 60 },
    { value = 'CONTROL', labelKey = 'claretui.key.control', width = 60 },
}

local function VisibleEntries(group)
    if not group.advancedOpen then return group.entries end
    local entries = {}
    for _, entry in ipairs(group.entries) do table.insert(entries, entry) end
    for _, entry in ipairs(group.advancedEntries) do table.insert(entries, entry) end
    return entries
end

-- The section factory is a module global: FAF's import returns the module
-- environment, and a `local` name is never visible to the caller.
function Create(parent, layout, options, coreOptions)
    local scale = layout.scale
    local pixel = Helpers.GetPixelScaleFactor()
    local ratio = scale / pixel
    local L = ReUI.UI.FloorLayouter(scale)
    local Localization = ReUI.ClaretCore.Localization

    local function T(key)
        return Localization.Text(key) or key
    end

    local function Text(owner, key, x, y, size, color)
        local control = UI.CreateText(owner, key and T(key) or '', size * ratio, Theme.Fonts.body)
        control:SetColor(color)
        control:DisableHitTest()
        L(control):AtLeftTopIn(owner, x, y)
        control.Depth:Set(function() return owner.Depth() + 2 end)
        return control
    end

    local selectionEntries = {
        { labelKey = 'claretui.selection.enabled', option = options.selectionHud, height = M.coreRowHeight },
        { labelKey = 'claretui.selection.dynamic', option = options.selectionDynamic, height = ROW_HEIGHT },
        { labelKey = 'claretui.selection.labels', option = options.selectionLabels, height = ROW_HEIGHT },
        { labelKey = 'claretui.mex.panel_locked', option = options.selectionLocked, height = ROW_HEIGHT },
        { labelKey = 'claretui.mex.panel_scale', option = options.selectionScale, kind = 'slider', height = 62 },
        { labelKey = 'claretui.mex.panel_transparency', option = options.selectionTransparency,
            kind = 'slider', height = 62, min = 0, max = 100, defaultValue = 0 },
        { labelKey = 'claretui.selection.advanced', kind = 'disclosure', height = ROW_HEIGHT },
    }
    local selectionAdvanced = {}
    for _, field in ipairs(selectionFields) do
        table.insert(selectionAdvanced, { labelKey = 'claretui.selection.' .. field.key,
            option = options['selection_' .. field.key], height = ROW_HEIGHT })
    end

    local groups = {
        {
            labelKey = 'claretui.positions.title',
            descriptionKey = 'claretui.positions.description',
            entries = {
                { labelKey = 'claretui.positions.enabled', option = options.revealPositions, height = M.coreRowHeight },
                { labelKey = 'claretui.positions.duration', option = options.revealPositionsDuration, kind = 'choice', height = ROW_HEIGHT,
                    choices = {
                        { value = 0, labelKey = 'claretui.positions.never', width = 48 },
                        { value = 60, labelKey = 'claretui.positions.one_minute', width = 42 },
                        { value = 300, labelKey = 'claretui.positions.five_minutes', width = 42 },
                        { value = 600, labelKey = 'claretui.positions.ten_minutes', width = 42 },
                    },
                },
                { labelKey = 'claretui.positions.scale', option = options.revealPositionsScale, kind = 'slider', height = 62 },
                { labelKey = 'claretui.positions.fill_transparency', option = options.revealPositionsFillTransparency,
                    kind = 'slider', height = 62, min = 0, max = 100, defaultValue = 100 },
            },
        },
        {
            labelKey = 'claretui.tab.commander',
            descriptionKey = 'claretui.tab.commander_description',
            entries = {
                { labelKey = 'claretui.setting.acu', option = options.acuHealth, height = M.coreRowHeight },
                { labelKey = 'claretui.setting.acu_locked', option = options.acuLocked, height = M.coreRowHeight },
                { labelKey = 'claretui.setting.acu_scale', option = options.acuScale, kind = 'slider', height = 62 },
            },
        },
        {
            labelKey = 'claretui.selection.title',
            descriptionKey = 'claretui.selection.description',
            entries = selectionEntries,
            advancedEntries = selectionAdvanced,
        },
        {
            labelKey = 'claretui.engineers.title',
            descriptionKey = 'claretui.engineers.description',
            entries = {
                { labelKey = 'claretui.engineers.enabled', option = options.engineerIndicators, height = M.coreRowHeight },
                { labelKey = 'claretui.engineers.scale', option = options.engineerIndicatorsScale, kind = 'slider', height = 62 },
                { labelKey = 'claretui.engineers.hide_far', option = options.engineerIndicatorsHideFar, height = ROW_HEIGHT },
                { labelKey = 'claretui.engineers.idle_only', option = options.engineerIndicatorsIdleOnly, height = ROW_HEIGHT },
                { labelKey = 'claretui.engineers.optimize', hintKey = 'claretui.engineers.optimize_hint',
                    option = options.engineerIndicatorsOptimize, height = M.coreRowHeight },
            },
        },
        {
            labelKey = 'claretui.tab.minimap',
            descriptionKey = 'claretui.tab.minimap_description',
            entries = {
                { labelKey = 'claretui.setting.minimap_auto', option = coreOptions.minimapAutoHide, height = M.coreRowHeight },
                { labelKey = 'claretui.setting.minimap_border', option = coreOptions.minimapBorderless, height = M.coreRowHeight },
            },
        },
        {
            labelKey = 'claretui.tab.rings',
            descriptionKey = 'claretui.tab.rings_description',
            entries = {
                { labelKey = 'claretui.setting.rings_attack_key', kind = 'keypair', option = options.ringSelectionKey, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_build_key', kind = 'keypair', option = options.ringBuildKey, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_enabled', option = options.allRings, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_reclaim_hint', kind = 'hint', height = 28 },
                { labelKey = 'claretui.setting.rings_advanced', kind = 'disclosure', height = ROW_HEIGHT },
            },
            advancedEntries = {
                { labelKey = 'claretui.setting.rings_minimap', option = options.ringsMinimap, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_actual_build', option = options.ringsActualBuild, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_direct_fire', option = options.ringsDirectFire, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_indirect_fire', option = options.ringsIndirectFire, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_anti_air', option = options.ringsAntiAir, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_anti_navy', option = options.ringsAntiNavy, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_countermeasure', option = options.ringsCountermeasure, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_omni', option = options.ringsOmni, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_radar', option = options.ringsRadar, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_sonar', option = options.ringsSonar, height = ROW_HEIGHT },
                { labelKey = 'claretui.setting.rings_counter_intel', option = options.ringsCounterIntel, height = ROW_HEIGHT },
            },
        },
        {
            labelKey = 'claretui.mex.title',
            descriptionKey = 'claretui.mex.description',
            entries = {
                { labelKey = 'claretui.mex.panel', option = options.mexPanel, height = ROW_HEIGHT },
                { labelKey = 'claretui.mex.panel_mode', option = options.mexPanelMode, kind = 'choice', height = ROW_HEIGHT,
                    choices = {
                        { value = 'static', labelKey = 'claretui.mex.mode_static', width = 82 },
                        { value = 'dynamic', labelKey = 'claretui.mex.mode_dynamic', width = 106 },
                    },
                },
                { labelKey = 'claretui.mex.overlay', option = options.mexOverlay, height = ROW_HEIGHT },
                { labelKey = 'claretui.mex.numbers', option = options.mexNumbers, height = ROW_HEIGHT },
                { labelKey = 'claretui.mex.panel_locked', option = options.mexPanelLocked, height = ROW_HEIGHT },
                { labelKey = 'claretui.mex.panel_scale', option = options.mexPanelScale, kind = 'slider', height = 62 },
                { labelKey = 'claretui.mex.panel_transparency', option = options.mexPanelTransparency,
                    kind = 'slider', height = 62, min = 0, max = 100, defaultValue = 0 },
            },
        },
        {
            labelKey = 'claretui.infoshare.title',
            descriptionKey = 'claretui.infoshare.description',
            entries = {
                { labelKey = 'claretui.infoshare.List', option = options.infoShareList, height = ROW_HEIGHT },
                { labelKey = 'claretui.infoshare.World', option = options.infoShareWorld, height = ROW_HEIGHT },
                { labelKey = 'claretui.infoshare.Locked', option = options.infoShareLocked, height = ROW_HEIGHT },
                { labelKey = 'claretui.infoshare.Scale', option = options.infoShareScale, kind = 'slider', height = 62 },
                { labelKey = 'claretui.infoshare.Transparency', option = options.infoShareTransparency,
                    kind = 'slider', height = 62, min = 0, max = 100, defaultValue = 0 },
                { labelKey = 'claretui.infoshare.LabelScale', option = options.infoShareLabelScale, kind = 'slider', height = 62 },
                { labelKey = 'claretui.selection.advanced', kind = 'disclosure', height = ROW_HEIGHT },
            },
            advancedEntries = {
                { labelKey = 'claretui.infoshare.ExperimentalIcon', option = options.infoShareExperimentalIcon, height = ROW_HEIGHT },
                { labelKey = 'claretui.infoshare.SmdIcon', option = options.infoShareSmdIcon, height = ROW_HEIGHT },
                { labelKey = 'claretui.infoshare.Own', option = options.infoShareOwn, height = ROW_HEIGHT },
                { labelKey = 'claretui.infoshare.Allies', option = options.infoShareAllies, height = ROW_HEIGHT },
                { labelKey = 'claretui.infoshare.Smd', option = options.infoShareSmd, height = ROW_HEIGHT },
                { labelKey = 'claretui.infoshare.Experimental', option = options.infoShareExperimental, height = ROW_HEIGHT },
                { labelKey = 'claretui.infoshare.Acu', option = options.infoShareAcu, height = ROW_HEIGHT },
            },
        },
        {
            labelKey = 'claretui.notifications.title',
            descriptionKey = 'claretui.notifications.description',
            entries = {
                { labelKey = 'claretui.notifications.hq_enabled', option = options.notificationsHQ, height = M.coreRowHeight },
                { labelKey = 'claretui.notifications.acu_enabled', option = options.notificationsACU, height = ROW_HEIGHT },
                { labelKey = 'claretui.notifications.nuke_enabled', option = options.notificationsNuke, height = ROW_HEIGHT },
                { labelKey = 'claretui.notifications.experimental_enabled', option = options.notificationsExperimental, height = ROW_HEIGHT },
                { labelKey = 'claretui.notifications.smd_enabled', option = options.notificationsSmd, height = ROW_HEIGHT },
                { labelKey = 'claretui.notifications.mode', option = options.notificationsMode, kind = 'choice', height = ROW_HEIGHT,
                    choices = {
                        { value = 'compact', labelKey = 'claretui.notifications.mode_compact', width = 112 },
                        { value = 'center', labelKey = 'claretui.notifications.mode_center', width = 112 },
                    },
                },
                { labelKey = 'claretui.notifications.scale', option = options.notificationsScale, kind = 'slider', height = 62 },
            },
        },
    }

    local root = Group(parent)
    root:DisableHitTest()
    L(root):Fill(parent)
    root.Depth:Set(function() return parent.Depth() + 1 end)
    local list = Group(root); list:DisableHitTest()
    list.Depth:Set(function() return root.Depth() + 1 end)
    local listHeight = table.getn(groups) * (ROW_HEIGHT + ROW_GAP) - ROW_GAP
    L(list):AtLeftTopIn(root, 0, 0):Width(LIST_WIDTH):Height(listHeight)

    local rows = {}
    local detail
    local refreshDetail
    local selected
    local detailLeft = LIST_WIDTH + DETAIL_GAP

    -- Match the two-pixel corners and outline of Core's Interactive control.
    local function ButtonSurface(control, width, height)
        local function Part(x, y, w, h)
            local part = Bitmap(control)
            part:DisableHitTest()
            part.Depth:Set(function() return control.Depth() + 1 end)
            L(part):AtLeftTopIn(control, x, y):Width(w):Height(h)
            return part
        end
        local fills = { Part(2, 0, width - 4, height), Part(0, 2, width, height - 4) }
        local borders = {
            Part(2, 0, width - 4, 1), Part(2, height - 1, width - 4, 1),
            Part(0, 2, 1, height - 4), Part(width - 1, 2, 1, height - 4),
            Part(1, 1, 1, 1), Part(width - 2, 1, 1, 1),
            Part(1, height - 2, 1, 1), Part(width - 2, height - 2, 1, 1),
        }
        return function(fill, edge)
            for _, part in ipairs(fills) do part:SetSolidColor(fill) end
            for _, part in ipairs(borders) do part:SetSolidColor(edge) end
        end
    end

    local function PaintRows()
        for _, row in ipairs(rows) do
            local active = selected == row.group
            local fill = row.pressed and C.pressed or row.hover and C.hover or active and C.selected or C.canvas
            row.paint(fill, active and C.selectedBorder or C.border)
            row.name:SetColor(C.text)
        end
    end

    local function ClearDetail()
        if detail then
            detail:Destroy()
            detail = nil
            refreshDetail = nil
        end
    end

    local function ApplySize()
        if not selected then
            layout.setSize(LIST_WIDTH, listHeight)
            return
        end
        local detailHeight = DETAIL_HEADER_HEIGHT
        for index, entry in ipairs(VisibleEntries(selected)) do
            detailHeight = detailHeight + entry.height
            if index > 1 then detailHeight = detailHeight + DETAIL_ROW_GAP end
        end
        layout.setSize(detailLeft + DETAIL_WIDTH, math.max(listHeight, detailHeight), {
            split = LIST_WIDTH + DETAIL_GAP / 2,
            left = listHeight,
            right = detailHeight,
        })
    end

    local function BuildDetail(group)
        local page = Group(root)
        page:DisableHitTest()
        page.Depth:Set(function() return root.Depth() + 1 end)
        L(page):AtLeftTopIn(root, detailLeft, 0):AtRightIn(root, 0):AtBottomIn(root, 0)
        detail = page

        local title = Text(page, group.labelKey, 0, 0, M.heading, C.text)
        title:SetFont(Theme.Fonts.heading, M.heading * ratio)
        local description = Text(page, group.descriptionKey, 0, 32, M.secondaryText, C.muted)
        local refreshRows = {}
        local y = DETAIL_HEADER_HEIGHT
        for _, entry in ipairs(VisibleEntries(group)) do
            local option = entry.option
            local row = Group(page)
            row.Depth:Set(function() return page.Depth() + 1 end)
            L(row):AtLeftTopIn(page, 0, y):AtRightIn(page, 0):Height(entry.height)
            local label = Text(row, entry.labelKey, 16, 6, M.buttonText, C.text)
            if entry.kind == 'slider' then
                L(label):AtLeftTopIn(row, 16, 2)
                local min, max = entry.min or 50, entry.max or 200
                local sliderWidth = DETAIL_WIDTH - 32
                local slider = IntegerSlider(
                    row, false, min, max, 5,
                    UI.SkinnableFile('/slider02/slider_btn_up.dds'),
                    UI.SkinnableFile('/slider02/slider_btn_over.dds'),
                    UI.SkinnableFile('/slider02/slider_btn_down.dds'),
                    UI.SkinnableFile('/dialogs/options-02/slider-back_bmp.dds')
                )
                L(slider):AtLeftTopIn(row, 16, 22):Width(sliderWidth):Height(36)
                slider._background.Width:Set(slider.Width)
                slider._background.Height:Set(slider.Height)
                slider._thumb.Top:Set(function()
                    return slider.Top() + (slider.Height() - slider._thumb.Height()) / 2 - 4 * scale
                end)
                local value = Text(row, nil, 0, 2, M.secondaryText, C.accentText)
                value.Left:Set(function() return slider.Right() - value.Width() end)
                local initial = option:Get()
                if type(initial) ~= 'number' or initial ~= initial or initial < min or initial > max then initial = entry.defaultValue or 100 end
                slider:SetValue(initial)
                value:SetText(string.format('%d%%', slider:GetValue()))
                slider.OnValueChanged = function(control, newValue)
                    value:SetText(string.format('%d%%', newValue))
                    option:Set(newValue)
                end
                slider.OnValueSet = function(control, newValue)
                    option:Set(newValue)
                    option:Save()
                end
                local labelKey = entry.labelKey
                table.insert(refreshRows, function() label:SetText(T(labelKey)) end)
            elseif entry.kind == 'keypair' or entry.kind == 'choice' then
                label:SetFont(Theme.Fonts.body, M.secondaryText * ratio)
                L(label):AtLeftTopIn(row, 16, math.floor((entry.height - M.secondaryText) / 2) - 4)
                local choices = entry.choices or PREVIEW_KEYS
                local x = DETAIL_WIDTH - 12
                for _, choice in ipairs(choices) do x = x - choice.width - 4 end
                x = x + 4
                local paints = {}
                for _, choice in ipairs(choices) do
                    local valueKey, labelKey = choice.value, choice.labelKey
                    local button = Group(row)
                    button:EnableHitTest()
                    button.Depth:Set(function() return row.Depth() + 2 end)
                    L(button):AtLeftTopIn(row, x, 4):Width(choice.width):Height(entry.height - 8)
                    x = x + choice.width + 4
                    local paintButton = ButtonSurface(button, choice.width, entry.height - 8)
                    local value = Text(button, labelKey, 0, 0, M.label, C.text)
                    L(value):AtCenterIn(button)
                    local mark = Bitmap(button)
                    mark:DisableHitTest()
                    mark.Depth:Set(function() return button.Depth() + 2 end)
                    L(mark):AtLeftTopIn(button, (choice.width - 12) / 2, entry.height - 12):Width(12):Height(2)
                    local hover, pressed = false, false
                    local function Paint()
                        local active = option:Get() == valueKey
                        mark:SetSolidColor(active and C.accentText or C.transparent)
                        paintButton(pressed and C.pressed or hover and C.hover or active and C.selected or C.canvas,
                            active and C.selectedBorder or C.border)
                    end
                    button.HandleEvent = function(self, event)
                        if event.Type == 'MouseEnter' then hover = true
                        elseif event.Type == 'MouseExit' then hover, pressed = false, false
                        elseif event.Type == 'ButtonRelease' then pressed = false
                        elseif event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then
                            pressed = true
                            if option:Get() ~= valueKey then
                                option:Set(valueKey)
                                option:Save()
                            end
                        end
                        Paint()
                        return true
                    end
                    table.insert(paints, Paint)
                    table.insert(refreshRows, function() value:SetText(T(labelKey)) end)
                end
                local function Sync()
                    for _, paint in ipairs(paints) do paint() end
                end
                option.OnChanged:Add(Sync)
                local oldDestroy = row.OnDestroy
                row.OnDestroy = function(self)
                    option.OnChanged:Remove(Sync)
                    if oldDestroy then oldDestroy(self) end
                end
                Sync()
                local labelKey = entry.labelKey
                table.insert(refreshRows, function() label:SetText(T(labelKey)) end)
            elseif entry.kind == 'hint' then
                label:SetFont(Theme.Fonts.body, M.caption * ratio)
                label:SetColor(C.muted)
                L(label):AtLeftTopIn(row, 16, 6)
                local labelKey = entry.labelKey
                table.insert(refreshRows, function() label:SetText(T(labelKey)) end)
            elseif entry.kind == 'disclosure' then
                local paintDisclosure = ButtonSurface(row, DETAIL_WIDTH, entry.height)
                local top = math.floor((entry.height - M.buttonText) / 2) - 4
                local mark = Text(row, nil, 16, top, M.buttonText, C.accentText)
                mark:SetText(group.advancedOpen and '−' or '+')
                L(label):AtLeftTopIn(row, 40, top)
                local hover = false
                local function Paint()
                    paintDisclosure(hover and C.hover or C.surface, C.border)
                end
                row.HandleEvent = function(self, event)
                    if event.Type == 'MouseEnter' then hover = true
                    elseif event.Type == 'MouseExit' then hover = false
                    elseif event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then
                        group.advancedOpen = not group.advancedOpen
                        ClearDetail()
                        ApplySize()
                        BuildDetail(group)
                        return true
                    end
                    Paint()
                    return true
                end
                local labelKey = entry.labelKey
                table.insert(refreshRows, function() label:SetText(T(labelKey)) end)
                Paint()
            else
                label:SetFont(Theme.Fonts.body, M.text * ratio)
                local hint
                local hintKey = entry.hintKey
                if hintKey then
                    L(label):AtLeftTopIn(row, 16, 9)
                    hint = Text(row, hintKey, 16, 31, M.caption, C.muted)
                else
                    L(label):AtLeftTopIn(row, 16, math.floor((entry.height - M.text) / 2) - 4)
                end
                local paintSurface = ButtonSurface(row, DETAIL_WIDTH, entry.height)
                local paintSwitch = Theme.SettingsSwitch(row, L, DETAIL_WIDTH, entry.height, ratio, true)
                local hover, pressed = false, false
                local function Paint()
                    paintSwitch(option:Get())
                    paintSurface(pressed and C.pressed or hover and C.hover or C.surface, C.border)
                end
                row.HandleEvent = function(self, event)
                    if event.Type == 'MouseEnter' then
                        hover = true
                    elseif event.Type == 'MouseExit' then
                        hover, pressed = false, false
                    elseif event.Type == 'ButtonRelease' then
                        pressed = false
                    elseif event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then
                        pressed = true
                        option:Set(not option:Get())
                        option:Save()
                    end
                    Paint()
                    return true
                end
                local function Sync()
                    Paint()
                    PaintRows()
                end
                option.OnChanged:Add(Sync)
                local oldDestroy = row.OnDestroy
                row.OnDestroy = function(self)
                    option.OnChanged:Remove(Sync)
                    if oldDestroy then oldDestroy(self) end
                end
                Paint()
                local labelKey = entry.labelKey
                table.insert(refreshRows, function()
                    label:SetText(T(labelKey))
                    if hint then hint:SetText(T(hintKey)) end
                    Paint()
                end)
            end
            y = y + entry.height + DETAIL_ROW_GAP
        end
        refreshDetail = function()
            title:SetText(T(group.labelKey))
            description:SetText(T(group.descriptionKey))
            for _, refresh in ipairs(refreshRows) do refresh() end
        end
    end

    local function Navigate(group)
        ClearDetail()
        if selected == group then selected = nil else selected = group end
        ApplySize()
        if selected then BuildDetail(selected) end
    end

    for index, group in ipairs(groups) do
        local pageGroup = group
        local control = Group(list)
        control.Depth:Set(function() return list.Depth() + 1 end)
        local y = (index - 1) * (ROW_HEIGHT + ROW_GAP)
        L(control):AtLeftTopIn(list, 0, y):Width(LIST_WIDTH):Height(ROW_HEIGHT)
        local paint = ButtonSurface(control, LIST_WIDTH, ROW_HEIGHT)
        local name = Text(control, group.labelKey, 0, 0, M.launcherText, C.text)
        L(name):AtCenterIn(control)
        local row = { group = pageGroup, control = control, name = name, paint = paint }
        control.HandleEvent = function(self, event)
            if event.Type == 'MouseEnter' then
                row.hover = true
            elseif event.Type == 'MouseExit' then
                row.hover, row.pressed = false, false
            elseif event.Type == 'ButtonRelease' then
                row.pressed = false
            elseif event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then
                row.pressed = true
                Navigate(pageGroup)
            end
            PaintRows()
            return true
        end
        table.insert(rows, row)
    end

    PaintRows()

    return {
        AfterParentShow = ApplySize,
        OnLanguageChanged = function()
            ApplySize()
            for _, row in ipairs(rows) do row.name:SetText(T(row.group.labelKey)) end
            PaintRows()
            if refreshDetail then refreshDetail() end
        end,
        CanLeave = function() return true end,
    }
end
