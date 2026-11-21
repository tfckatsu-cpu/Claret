local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Dragger = import('/lua/maui/dragger.lua').Dragger
local UI = import('/lua/ui/uiutil.lua')
local Helpers = import('/lua/maui/layouthelpers.lua')
local Borders = import('/lua/ui/game/borders.lua')
local World = import('/lua/ui/game/worldview.lua')
local Construction = import('/lua/ui/game/construction.lua')
local Theme = import('/mods/ClaretCore/modules/Theme.lua')

local C, M = Theme.Colors, Theme.Metrics
local WIDTH, HEADER, ROW, VISIBLE = 352, 34, 40, 5
local outlineOffsets = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

local function Fade(opacity, visible, delta)
    if visible then return math.min(1, opacity + delta / 0.18) end
    return math.max(0, opacity - delta / 0.22)
end

local function Setting(option, default, minimum, maximum)
    local value = option:Get()
    if type(value) ~= 'number' or value ~= value then return default end
    return math.max(minimum, math.min(maximum, value))
end

local function PhaseColor(phase)
    if phase == 'done' then return C.success end
    if phase == 'cancelled' or phase == 'interrupted' then return C.warning end
    return C.accentText
end

local function PositionValues(position)
    if type(position) ~= 'table' then return nil end
    local x, y, z = position[1], position[2], position[3]
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return nil end
    return x, y, z
end

function Create(scope, options)
    local parent = Borders.GetMapGroup()
    local frame = GetFrame(0)
    local pixel = Helpers.GetPixelScaleFactor()
    local scale = pixel
    local labelScale = pixel
    local layout = ReUI.UI.FloorLayouter(scale)
    local localization = ReUI.ClaretCore.Localization
    local root = scope:Own(Group(parent))
    layout(root):Fill(parent)
    root:DisableHitTest()
    root.Depth:Set(function() return parent.Depth() + 80 end)

    local panel = Group(root)
    panel:DisableHitTest()
    panel:Hide()
    panel.Depth:Set(function() return root.Depth() + 1 end)
    layout(panel):Width(WIDTH):Height(HEADER + VISIBLE * ROW)
    local function PanelScale() return panel.Width() / WIDTH end
    local background = Bitmap(panel)
    background:SetSolidColor(C.canvas)
    background:DisableHitTest()
    background.Depth:Set(function() return panel.Depth() + 1 end)
    background.Left:Set(panel.Left); background.Right:Set(panel.Right)
    background.Top:Set(panel.Top); background.Bottom:Set(panel.Bottom)
    local topRule = Bitmap(panel)
    topRule:SetSolidColor(C.accent)
    topRule:DisableHitTest()
    topRule.Depth:Set(function() return panel.Depth() + 2 end)
    topRule.Left:Set(panel.Left); topRule.Right:Set(panel.Right)
    topRule.Top:Set(panel.Top); topRule.Height:Set(math.max(2, math.floor(2 * scale)))

    local title = UI.CreateText(panel, localization.Text('claretui.infoshare.title'),
        M.heading * scale / pixel, Theme.Fonts.heading)
    title:SetColor(C.text)
    title:DisableHitTest()
    title.Depth:Set(function() return panel.Depth() + 3 end)
    title.Left:Set(function() return panel.Left() + math.floor(10 * PanelScale()) end)
    title.Top:Set(function() return panel.Top() + math.floor(7 * PanelScale()) end)
    localization.Subscribe(title, function()
        title:SetText(localization.Text('claretui.infoshare.title'))
    end)
    scope:Defer(function() localization.Unsubscribe(title) end)

    local rowControls = {}
    local function CreateRow(index)
        local group = Group(panel)
        layout(group):Fill(panel)
        group:DisableHitTest()
        local y = HEADER + (index - 1) * ROW
        local rowBackground = Bitmap(group)
        rowBackground:SetSolidColor(C.surface)
        rowBackground:DisableHitTest()
        rowBackground.Depth:Set(function() return panel.Depth() + 1 end)
        rowBackground.Left:Set(function() return panel.Left() + math.floor(4 * PanelScale()) end)
        rowBackground.Right:Set(function() return panel.Right() - math.floor(4 * PanelScale()) end)
        rowBackground.Top:Set(function() return panel.Top() + math.floor(y * PanelScale()) end)
        rowBackground.Height:Set(math.floor((ROW - 2) * scale))

        local fill = Bitmap(group)
        fill:DisableHitTest()
        fill.Depth:Set(function() return panel.Depth() + 2 end)
        fill.Left:Set(rowBackground.Left)
        fill.Top:Set(rowBackground.Top)
        fill.Height:Set(rowBackground.Height)
        fill:Hide()

        local iconBackground = Bitmap(group)
        iconBackground:SetSolidColor(C.raised)
        iconBackground:DisableHitTest()
        iconBackground.Depth:Set(function() return panel.Depth() + 3 end)
        iconBackground.Left:Set(function() return panel.Left() + math.floor(8 * PanelScale()) end)
        iconBackground.Top:Set(function() return panel.Top() + math.floor((y + 4) * PanelScale()) end)
        iconBackground.Right:Set(function() return iconBackground.Left() + math.floor(30 * PanelScale()) end)
        iconBackground.Bottom:Set(function() return iconBackground.Top() + math.floor(30 * PanelScale()) end)

        local icon = Bitmap(group)
        icon:DisableHitTest()
        icon.Depth:Set(function() return panel.Depth() + 4 end)
        icon.Left:Set(iconBackground.Left)
        icon.Right:Set(iconBackground.Right)
        icon.Top:Set(iconBackground.Top)
        icon.Bottom:Set(iconBackground.Bottom)
        local entry = { group = group, background = rowBackground, fill = fill, icon = icon, iconBackground = iconBackground }


        local player = UI.CreateText(group, '', M.secondaryText * scale / pixel, Theme.Fonts.body)
        player:SetColor(C.muted)
        player:DisableHitTest()
        player.Depth:Set(function() return panel.Depth() + 3 end)
        player.Left:Set(function() return panel.Left() + math.floor(10 * PanelScale()) end)
        player.Top:Set(function() return panel.Top() + math.floor((y + 3) * PanelScale()) end)

        local work = UI.CreateText(group, '', M.secondaryText * scale / pixel, Theme.Fonts.body)
        work:SetColor(C.text)
        work:DisableHitTest()
        work.Depth:Set(function() return panel.Depth() + 3 end)
        work.Left:Set(player.Left)
        work.Top:Set(function() return panel.Top() + math.floor((y + 19) * PanelScale()) end)

        player:SetClipToWidth(true)
        work:SetClipToWidth(true)
        player.Width:Set(math.floor((WIDTH - 122) * scale))
        work.Width:Set(math.floor((WIDTH - 122) * scale))

        local status = UI.CreateText(group, '', M.secondaryText * scale / pixel, Theme.Fonts.body)
        status:SetColor(C.accentText)
        status:DisableHitTest()
        status.Depth:Set(function() return panel.Depth() + 3 end)
        status.Right:Set(function() return panel.Right() - math.floor(10 * PanelScale()) end)
        status.Top:Set(function() return panel.Top() + math.floor((y + 12) * PanelScale()) end)
        entry.player, entry.work, entry.status = player, work, status
        return entry
    end

    local positionOption = options.infoSharePosition
    local function Place(left, top)
        local maxLeft = math.max(frame.Left(), frame.Right() - panel.Width())
        local maxTop = math.max(frame.Top(), frame.Bottom() - panel.Height())
        panel.Left:Set(math.max(frame.Left(), math.min(maxLeft, left)))
        panel.Top:Set(math.max(frame.Top(), math.min(maxTop, top)))
    end
    local function Restore()
        local saved = positionOption and positionOption:Get()
        if type(saved) == 'table' and type(saved.x) == 'number' and type(saved.y) == 'number' then
            Place(frame.Left() + saved.x * pixel, frame.Top() + saved.y * pixel)
        else
            layout(panel):AtLeftTopIn(frame, 18, 190)
        end
    end
    Restore()

    local locked = options.infoShareLocked
    local drag
    local prior = panel.HandleEvent
    panel.HandleEvent = function(control, event)
        if locked:Get() then return false end
        if event.Type == 'WheelRotation' and type(event.WheelRotation) == 'number' then
            local delta = event.WheelRotation > 0 and -1 or 1
            local count = table.getn(root.rows or {})
            root.rowOffset = math.max(0, math.min(math.max(0, count - VISIBLE), (root.rowOffset or 0) + delta))
            root:RenderRows()
            return true
        end
        if event.Type == 'ButtonPress' and event.Modifiers and event.Modifiers.Left
            and type(event.MouseY) == 'number' and event.MouseY <= panel.Top() + HEADER * scale and not drag then
            local startX, startY = event.MouseX, event.MouseY
            local left, top = panel.Left(), panel.Top()
            if type(startX) ~= 'number' or type(startY) ~= 'number' then return false end
            drag = Dragger()
            drag.OnMove = function(_, x, y)
                Place(left + x - startX, top + y - startY)
            end
            drag.OnRelease = function(self, x, y)
                if type(x) == 'number' and type(y) == 'number' then self:OnMove(x, y) end
                drag = nil
                self:Destroy()
                if positionOption and (panel.Left() ~= left or panel.Top() ~= top) then
                    positionOption:Set({ x = (panel.Left() - frame.Left()) / pixel,
                        y = (panel.Top() - frame.Top()) / pixel })
                    positionOption:Save()
                    SavePreferences()
                end
            end
            drag.OnCancel = function(self) drag = nil; self:Destroy(); Restore() end
            PostDragger(frame, event.KeyCode, drag)
            return true
        end
        return prior and prior(control, event) or false
    end

    local iconSize = math.floor(M.fieldHeight * 0.65 * labelScale)
    local iconGap = math.floor(5 * labelScale)
    local outlineWidth = math.max(1, math.floor(labelScale + 0.5))
    local iconPaths = {}

    local function IconPath(row)
        local blueprint = row.blueprint
        if not blueprint then return nil end
        local key = row.enhancement and blueprint .. ':' .. row.enhancement or blueprint
        if iconPaths[key] == nil then
            local path
            if row.kind == 'acu' then
                local bp = __blueprints[blueprint]
                local upgrade = bp and bp.Enhancements and bp.Enhancements[row.enhancement]
                if upgrade and upgrade.Icon then path = Construction.GetEnhancementTextures(blueprint, upgrade.Icon) end
            else
                path = UI.UIFile('/icons/units/' .. blueprint .. '_icon.dds', true)
            end
            iconPaths[key] = path and DiskGetFileInfo(path) and path or false
        end
        return iconPaths[key]
    end

    local function NewWorldLabel(view)
        local group = Group(view)
        group:DisableHitTest()
        group.Depth:Set(function() return view.Depth() + 80 end)
        group:Hide()

        local text = UI.CreateText(group, '', M.secondaryText * labelScale / pixel, Theme.Fonts.body)
        text:SetColor(C.hudValue)
        text:DisableHitTest()
        text.Depth:Set(function() return group.Depth() + 2 end)
        text.Top:Set(function() return group.Top() + math.floor((group.Height() - text.Height()) / 2) end)

        local outline = {}
        for _, offset in ipairs(outlineOffsets) do
            local dx, dy = offset[1] * outlineWidth, offset[2] * outlineWidth
            local edge = UI.CreateText(group, '', M.secondaryText * labelScale / pixel, Theme.Fonts.body)
            edge:SetColor(C.canvas)
            edge:DisableHitTest()
            edge.Depth:Set(function() return group.Depth() + 1 end)
            edge.Left:Set(function() return text.Left() + dx end)
            edge.Top:Set(function() return text.Top() + dy end)
            table.insert(outline, edge)
        end
        return { group = group, text = text, outline = outline, opacity = 0 }
    end

    local function SetWorldIcon(item, path, kind)
        if path == item.iconPath and labelScale == item.iconScale then return end
        local pathChanged = item.iconPath ~= path
        item.iconPath, item.iconScale = path, labelScale
        if path then
            local size = kind == 'experimental' and iconSize or math.floor(M.fieldHeight * labelScale / 2)
            item.iconSize = size
            if not item.icon then
                local icon = Bitmap(item.group)
                icon:DisableHitTest()
                icon.Depth:Set(function() return item.group.Depth() + 2 end)
                icon.Left:Set(item.group.Left)
                icon.Top:Set(function() return item.group.Top() + math.floor((item.group.Height() - icon.Height()) / 2) end)
                item.icon = icon
            end
            item.icon.Width:Set(size)
            item.icon.Height:Set(size)
            if pathChanged then item.icon:SetTexture(path) end
            item.icon:Show()
        elseif item.icon then
            item.icon:Hide()
        end
        local inset = path and item.iconSize + iconGap or 0
        item.text.Left:Set(function() return item.group.Left() + inset end)
        item.group.Width:Set(function() return item.text.Width() + inset end)
        item.group.Height:Set(function() return math.max(item.text.Height(), path and item.iconSize or 0) end)
    end

    local worldLabels = {}
    local worldView
    local function ClearWorld()
        if worldView and not IsDestroyed(worldView) then
            for _, item in pairs(worldLabels) do item.group:Destroy() end
        end
        worldLabels = {}
    end

    local function RenderWorld(rows)
        local view = World.viewLeft
        if view ~= worldView then
            ClearWorld()
            worldView = view
        end
        if not view or IsDestroyed(view) then
            return
        end
        local active = {}
        local experimentalIcon = options.infoShareExperimentalIcon:Get()
        local smdIcon = options.infoShareSmdIcon:Get()
        for _, row in ipairs(rows) do
            local x, y, z = PositionValues(row.position)
            if x then
                local item = worldLabels[row.key]
                if not item then
                    item = NewWorldLabel(view)
                    worldLabels[row.key] = item
                end
                local useIcon = row.kind == 'acu' or row.kind == 'experimental' and experimentalIcon or row.kind == 'smd' and smdIcon
                SetWorldIcon(item, useIcon and IconPath(row) or false, row.kind)
                active[row.key] = true
                item.position = Vector(x, y, z)
                local caption = row.name .. ' · ' .. row.status
                if caption ~= item.caption then
                    item.text:SetText(caption)
                    for _, edge in ipairs(item.outline) do edge:SetText(caption) end
                    item.caption = caption
                end
            end
        end
        for key, item in pairs(worldLabels) do item.visible = active[key] == true end
    end

    local panelAlpha = 1
    local panelOpacity, panelWanted = 0, false
    local function PaintPanel()
        local opacity = panelAlpha * panelOpacity
        background:SetAlpha(opacity)
        topRule:SetAlpha(opacity)
        title:SetAlpha(panelOpacity)
        for _, row in ipairs(rowControls) do
            if row.active then
                row.background:SetAlpha(opacity)
                row.player:SetAlpha(panelOpacity)
                row.work:SetAlpha(panelOpacity)
                row.status:SetAlpha(panelOpacity)
                if row.hasFill then row.fill:SetAlpha(panelOpacity) end
                if row.iconPath then
                    row.icon:SetAlpha(panelOpacity)
                    row.iconBackground:SetAlpha(panelOpacity)
                end
            end
        end
    end
    root.RenderRows = function()
        local rows = root.rows or {}
        local offset = root.rowOffset or 0
        for index, controls in ipairs(rowControls) do
            local row = rows[offset + index]
            controls.active = row ~= nil
            if row then
                controls.background:Show(); controls.player:Show(); controls.work:Show(); controls.status:Show()
                local path = IconPath(row)
                if controls.iconPath ~= path then
                    controls.iconPath = path
                    if path then controls.icon:SetTexture(path) end
                    local inset = path and 46 or 10
                    controls.player.Left:Set(function() return panel.Left() + math.floor(inset * PanelScale()) end)
                    controls.work.Left:Set(controls.player.Left)
                end
                local textWidth = math.floor((WIDTH - (path and 158 or 122)) * scale)
                controls.player.Width:Set(textWidth)
                controls.work.Width:Set(textWidth)
                if path then
                    controls.iconBackground:Show()
                    controls.icon:Show()
                else
                    controls.iconBackground:Hide()
                    controls.icon:Hide()
                end
                controls.player:SetText(row.player or '')
                controls.work:SetText(row.name or '')
                controls.status:SetText(row.status or '')
                controls.status:SetColor(PhaseColor(row.phase))
                local progress = row.phase == 'done' and 100 or row.progress
                controls.hasFill = type(progress) == 'number' and progress > 0
                if controls.hasFill then
                    controls.fill:SetSolidColor(row.phase == 'done' and C.selected or C.accent)
                    controls.fill:SetAlpha(panelOpacity)
                    controls.fill.Right:Set(controls.background.Left()
                        + math.floor((controls.background.Right() - controls.background.Left()) * math.min(progress, 100) / 100))
                    controls.fill:Show()
                else
                    controls.fill:Hide()
                end
            else
                controls.icon:Hide(); controls.iconBackground:Hide()
                controls.fill:Hide(); controls.background:Hide(); controls.player:Hide(); controls.work:Hide(); controls.status:Hide()
            end
        end
    end
    root.OnFrame = function(self, delta)
        local nextOpacity = Fade(panelOpacity, panelWanted, delta)
        if nextOpacity ~= panelOpacity then
            panelOpacity = nextOpacity
            PaintPanel()
            if panelOpacity == 0 then panel:Hide() end
        end

        local view = worldView
        if view and (IsDestroyed(view) or World.viewLeft ~= view) then
            ClearWorld()
            worldView = nil
        elseif view and next(worldLabels) then
            self:UpdateWorldLabels(view, delta)
        end
        self:SetNeedsFrameUpdate(next(worldLabels) ~= nil or (panelWanted and panelOpacity < 1)
            or (not panelWanted and panelOpacity > 0))
    end

    root.UpdateWorldLabels = function(self, view, delta)
        local left, top, right, bottom = view.Left(), view.Top(), view.Right(), view.Bottom()
        for key, item in pairs(worldLabels) do
            local label = item.group
            local point = view:Project(item.position)
            local x = point and math.floor(left + point.x - label.Width() / 2)
            local y = point and math.floor(top + point.y - label.Height() - 12 * pixel)
            local onScreen = x and x >= left and x + label.Width() <= right and y >= top and y + label.Height() <= bottom
            item.opacity = Fade(item.opacity, item.visible and onScreen, delta)
            if item.opacity == 0 then
                label:Hide()
                if not item.visible then
                    label:Destroy()
                    worldLabels[key] = nil
                end
            else
                if x then label.Left:Set(x); label.Top:Set(y) end
                item.text:SetAlpha(item.opacity)
                for _, edge in ipairs(item.outline) do edge:SetAlpha(item.opacity) end
                if item.iconPath then item.icon:SetAlpha(item.opacity) end
                label:Show()
            end
        end
    end

    local function ApplyAppearance()
        local nextScale = pixel * Setting(options.infoShareScale, 100, 50, 200) / 100
        if scale ~= nextScale then
            scale = nextScale
            layout = ReUI.UI.FloorLayouter(scale)
            layout(panel):Width(WIDTH)
            topRule.Height:Set(math.max(2, math.floor(2 * scale)))
            title:SetFont(Theme.Fonts.heading, M.heading * scale / pixel)
            for _, row in ipairs(rowControls) do
                row.background.Height:Set(math.floor((ROW - 2) * scale))
                row.player.Width:Set(math.floor((WIDTH - 122) * scale))
                row.work.Width:Set(math.floor((WIDTH - 122) * scale))
                row.player:SetFont(Theme.Fonts.body, M.secondaryText * scale / pixel)
                row.work:SetFont(Theme.Fonts.body, M.secondaryText * scale / pixel)
                row.status:SetFont(Theme.Fonts.body, M.secondaryText * scale / pixel)
            end
        end
        panelAlpha = 1 - Setting(options.infoShareTransparency, 0, 0, 100) / 100
        local nextLabelScale = pixel * Setting(options.infoShareLabelScale, 100, 50, 200) / 100
        if labelScale ~= nextLabelScale then
            labelScale = nextLabelScale
            iconSize = math.floor(M.fieldHeight * 0.65 * labelScale)
            iconGap = math.floor(5 * labelScale)
            outlineWidth = math.max(1, math.floor(labelScale + 0.5))
            local fontSize = M.secondaryText * labelScale / pixel
            for _, item in pairs(worldLabels) do
                local text = item.text
                text:SetFont(Theme.Fonts.body, fontSize)
                for index, edge in ipairs(item.outline) do
                    local offset = outlineOffsets[index]
                    local dx, dy = offset[1] * outlineWidth, offset[2] * outlineWidth
                    edge:SetFont(Theme.Fonts.body, fontSize)
                    edge.Left:Set(function() return text.Left() + dx end)
                    edge.Top:Set(function() return text.Top() + dy end)
                end
            end
        end
    end

    local display = {}
    local listVisible, worldVisible
    function display:Render(rows, showList, showWorld)
        listVisible, worldVisible = showList, showWorld
        ApplyAppearance()
        local count = table.getn(rows or {})
        panelWanted = showList and count > 0
        if panelWanted then
            root.rows = rows
            root.rowOffset = math.min(root.rowOffset or 0, math.max(0, count - VISIBLE))
            local visibleCount = math.min(VISIBLE, count)
            for index = table.getn(rowControls), visibleCount + 1, -1 do
                rowControls[index].group:Destroy()
                rowControls[index] = nil
            end
            for index = table.getn(rowControls) + 1, visibleCount do
                rowControls[index] = CreateRow(index)
            end
            layout(panel):Height(HEADER + visibleCount * ROW)
            if panel.Right() > frame.Right() or panel.Bottom() > frame.Bottom() then
                Place(panel.Left(), panel.Top())
            end
            if locked:Get() then
                if drag then drag:OnCancel() end
                panel:DisableHitTest()
            else
                panel:EnableHitTest()
            end
            panel:Show()
            root:RenderRows()
            PaintPanel()
        else
            panel:DisableHitTest()
            if panelOpacity == 0 then panel:Hide() end
        end
        root.latestRows = rows
        RenderWorld(showWorld and rows or {})
        root:SetNeedsFrameUpdate(next(worldLabels) ~= nil or (panelWanted and panelOpacity < 1)
            or (not panelWanted and panelOpacity > 0))
    end
    local function RefreshAppearance()
        display:Render(root.latestRows, listVisible, worldVisible)
    end
    for _, key in ipairs({ 'Scale', 'Transparency', 'LabelScale', 'ExperimentalIcon', 'SmdIcon', 'Locked' }) do
        scope:Bind(options['infoShare' .. key].OnChanged, RefreshAppearance)
    end

    scope:Defer(function()
        if drag then drag:Destroy(); drag = nil end
        ClearWorld()
    end)
    return display
end
