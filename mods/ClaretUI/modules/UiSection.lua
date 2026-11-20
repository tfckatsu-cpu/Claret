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

local LIST_WIDTH = 224
local DETAIL_WIDTH = 384
local DETAIL_GAP = M.panelGap
local ROW_HEIGHT = M.rowHeight
local ROW_GAP = 8
local DETAIL_HEADER_HEIGHT = 68
local DETAIL_ROW_GAP = 8

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

    local groups = {
        {
            labelKey = 'claretui.tab.commander',
            descriptionKey = 'claretui.tab.commander_description',
            entries = {
                { labelKey = 'claretui.setting.acu', option = options.acuHealth, height = M.coreRowHeight },
                { labelKey = 'claretui.setting.acu_scale', option = options.acuScale, kind = 'slider', height = 62 },
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
        for _, entry in ipairs(group.entries) do
            local option = entry.option
            local row = Group(page)
            row.Depth:Set(function() return page.Depth() + 1 end)
            L(row):AtLeftTopIn(page, 0, y):AtRightIn(page, 0):Height(entry.height)
            local label = Text(row, entry.labelKey, 16, 6, M.buttonText, C.text)
            if entry.kind == 'slider' then
                L(label):AtLeftTopIn(row, 16, 2)
                local sliderWidth = DETAIL_WIDTH - 32
                local slider = IntegerSlider(
                    row, false, 50, 200, 5,
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
                if type(initial) ~= 'number' or initial ~= initial or initial < 50 or initial > 200 then initial = 100 end
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
                y = y + entry.height + DETAIL_ROW_GAP
            else
                label:SetFont(Theme.Fonts.body, M.text * ratio)
                L(label):AtLeftTopIn(row, 16, math.floor((entry.height - M.text) / 2) - 4)
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
                    Paint()
                end)
                y = y + entry.height + DETAIL_ROW_GAP
            end
        end
        refreshDetail = function()
            title:SetText(T(group.labelKey))
            description:SetText(T(group.descriptionKey))
            for _, refresh in ipairs(refreshRows) do refresh() end
        end
    end

    local function ApplySize()
        if not selected then
            layout.setSize(LIST_WIDTH, listHeight)
            return
        end
        local detailHeight = DETAIL_HEADER_HEIGHT
        for index, entry in ipairs(selected.entries) do
            detailHeight = detailHeight + entry.height
            if index > 1 then detailHeight = detailHeight + DETAIL_ROW_GAP end
        end
        layout.setSize(detailLeft + DETAIL_WIDTH, math.max(listHeight, detailHeight), {
            split = LIST_WIDTH + DETAIL_GAP / 2,
            left = listHeight,
            right = detailHeight,
        })
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
