local tabs = {
    {'general', 'cinema.drawer_general'},
    {'move', 'cinema.drawer_move'},
    {'pan', 'cinema.drawer_pan'},
    {'spin', 'cinema.drawer_spin'},
}
local texture = '/mods/ClaretCinema/textures/ui/'

function Create(parent, director, runtime)
    local Group = import('/lua/maui/group.lua').Group
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local UI = import('/lua/ui/uiutil.lua')
    local Slider = import('/lua/maui/slider.lua').IntegerSlider
    local specs = import('/mods/ClaretCinema/modules/Director.lua')
    local Theme = import('/mods/ClaretCore/modules/Theme.lua')
    local Tooltip = import('/lua/ui/game/tooltip.lua')
    local localization = ReUI.ClaretCore.Localization
    local T, C, M = localization.Text, Theme.Colors, Theme.Metrics
    local pixel = import('/lua/maui/layouthelpers.lua').GetPixelScaleFactor()
    local width, top, dockWidth, dockGap = 432, 152, 48, 8
    local inset = M.panelGap
    local contentWidth, pageTop, footerHeight = width - 2 * inset, 112, 32
    local sliderStep, buttonStep = 44, 40
    local generalActionsTop = table.getn(specs.Visual) * sliderStep + 8
    local generalHeight = generalActionsTop + 3 * buttonStep + 4 + M.buttonHeight
    local maxHeight = pageTop + generalHeight + footerHeight
    local groupWidth = width + dockWidth + dockGap
    local scale = math.min(pixel, (parent.Height() - inset) / (maxHeight + top + inset),
        (parent.Width() - inset) / (groupWidth + inset))
    local ratio = scale / pixel
    local L = ReUI.UI.FloorLayouter(scale)
    local state = {tab = 'general', opened = false, slide = 0}
    local tooltipOwner
    local function DismissButtonTooltip()
        if tooltipOwner then Tooltip.DestroyMouseoverDisplay(); tooltipOwner = nil end
    end
    local owner = Group(parent)
    owner:DisableHitTest()
    L(owner):AtLeftTopIn(parent, 0, 0):Width(groupWidth):Height(maxHeight + top)
    owner.Depth:Set(function() return parent.Depth() + 30 end)

    local function Text(host, value, x, y, size, color, bold)
        local control = UI.CreateText(host, value, size * ratio, bold and Theme.Fonts.heading or Theme.Fonts.body)
        control:SetColor(color or C.text)
        control:DisableHitTest()
        control.Depth:Set(function() return host.Depth() + 2 end)
        L(control):AtLeftTopIn(host, x, y)
        return control
    end

    local function Block(host, color, x, y, w, h, depth)
        local control = Bitmap(host)
        control:SetSolidColor(color)
        control:DisableHitTest()
        control.Depth:Set(function() return host.Depth() + depth end)
        L(control):AtLeftTopIn(host, x, y):Width(w):Height(h)
        return control
    end

    local function Button(host, value, x, y, w, h, click, tab)
        local control = Bitmap(host)
        L(control):AtLeftTopIn(host, x, y):Width(w):Height(h)
        control.Depth:Set(function() return host.Depth() + 1 end)
        local edge, indicator
        if tab then
            indicator = Block(control, C.accentText, 8, h - 2, w - 16, 2, 1)
        else
            edge = Theme.Outline(control, L, w, h)
        end
        local button = {control = control}
        if value ~= nil then
            button.label = Text(control, value, 0, 0, M.buttonText)
            L(button.label):AtCenterIn(control)
        end
        local function Paint()
            control:SetSolidColor(button.pressed and C.pressed or button.selected and (button.hover and C.accentPressed or C.selected)
                or button.hover and C.hover or tab and C.surface or C.raised)
            if indicator then
                indicator:SetHidden(not button.selected)
                button.label:SetColor(button.selected and C.text or C.muted)
            else
                edge((button.hover or button.selected) and C.selectedBorder or C.border)
            end
        end
        button.SetBound = function(key, id)
            local chord, blocked
            if id then chord, blocked = runtime.GetChord(id) end
            local base = T(key)
            local full = base .. (chord and ' · ' .. chord or '')
                .. (blocked and ' · ' .. T('cinema.bind_blocked') or '')
            local display = base .. (chord and ' · ' .. chord .. (blocked and ' !' or '') or '')
            if button.label:GetStringAdvance(display) > (w - 16) * scale then
                display = base .. (chord and (blocked and ' · … !' or ' · …') or '')
            end
            button.label:SetText(display)
            button.tooltip = chord and full or nil
            if tooltipOwner == control then
                DismissButtonTooltip()
                if button.tooltip and state.opened then
                    Tooltip.CreateMouseoverDisplay(control, {text = button.tooltip})
                    tooltipOwner = control
                end
            end
        end
        button.Select = function(value) button.selected = value; Paint() end
        control.HandleEvent = function(self, event)
            if event.Type == 'MouseEnter' then
                button.hover = true; Paint()
                if button.tooltip and state.opened then
                    DismissButtonTooltip()
                    Tooltip.CreateMouseoverDisplay(self, {text = button.tooltip})
                    tooltipOwner = self
                end
            elseif event.Type == 'MouseExit' then
                button.hover, button.pressed = false, false; Paint()
                if tooltipOwner == self then DismissButtonTooltip() end
            elseif event.Type == 'ButtonRelease' then button.pressed = false; Paint()
            elseif event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then
                button.pressed = true; Paint(); click()
            end
            return true
        end
        Paint()
        return button
    end

    local pane, title, status, mode, resize, buildPage, refreshPage
    local tabButtons = {}
    local edgeTab
    local function Position()
        L(pane):AtLeftTopIn(owner, -width + groupWidth * state.slide, top)
    end

    local function Report(ok, message)
        state.error = not ok and message or nil
        if status then
            status:SetColor(state.error and C.danger or C.muted)
            local key = state.error or state.motion
            status:SetText(key and T(key) or '')
        end
    end

    local function RefreshMode()
        if not mode then return end
        local active, chord = runtime.GetState()
        local text = T(active and 'cinema.mode_on' or 'cinema.mode_off')
        mode.label:SetText(chord and text .. ' · ' .. chord or text)
        mode.Select(active)
    end

    local function SliderRow(host, spec, y, read, write)
        Text(host, T(spec.label), 0, y, M.buttonText)
        local value = Text(host, '', 0, y, M.buttonText, C.accentText, true)
        value.Left:Set(function() return host.Right() - value.Width() end)
        local steps = math.floor((spec.max - spec.min) / spec.step + 0.5)
        local slider = Slider(host, false, 0, steps, 1, texture .. 'thumb.png',
            texture .. 'thumb-over.png', texture .. 'thumb-down.png')
        local background, thumb = slider._background, slider._thumb
        L(slider):AtLeftTopIn(host, 0, y + 16):Width(contentWidth):Height(28)
        slider.Depth:Set(function() return host.Depth() + 1 end)
        background.Width:Set(slider.Width)
        background.Height:Set(slider.Height)
        background.Depth:Set(function() return slider.Depth() + 1 end)
        background:SetSolidColor(C.transparent)
        L(thumb):Width(16):Height(24)
        thumb.Depth:Set(function() return background.Depth() + 3 end)
        local track = Block(background, C.border, 8, 12, contentWidth - 16, 4, 1)
        local fill = Block(track, C.selectedBorder, 0, 0, 0, 4, 1)
        fill.Width:Set(function() return math.max(0, thumb.Left() + thumb.Width() / 2 - track.Left()) end)
        -- The native slider measures from the thumb's left edge; our track uses its center.
        local calculate = slider.CalculateValueFromMouse
        slider.CalculateValueFromMouse = function(self, x, y)
            return calculate(self, x - thumb.Width() / 2, y)
        end
        local updating = false
        local function Display()
            updating = true
            local number = read()
            value:SetText(string.format('%.5g', number))
            slider:SetValue(math.floor((number - spec.min) / spec.step + 0.5))
            updating = false
        end
        Display()
        local original = slider.OnValueChanged
        slider.OnValueChanged = function(self, index)
            if original then original(self, index) end
            if updating then return end
            local ok, message = write(math.min(spec.max, spec.min + spec.step * index))
            value:SetText(string.format('%.5g', read()))
            Report(ok, message)
        end
        return Display
    end

    local function General(page)
        local refresh = {}
        for index, spec in ipairs(specs.Visual) do
            local field = spec
            refresh[index] = SliderRow(page, field, (index - 1) * sliderStep,
                function() return director.GetVisual(field.id) end,
                function(value) return director.SetVisual(field, value) end)
        end
        local buttons = {{'free', 'cinema.free_short'}, {'ease', 'cinema.ease_short'}, {'boxes', 'cinema.boxes_short'},
            {'decals', 'cinema.decals_short'}, {'hud', 'cinema.hud_short'}, {'reset', 'cinema.reset'}}
        Block(page, C.border, 0, generalActionsTop - 8, contentWidth, 1, 1)
        local half = (contentWidth - 8) / 2
        for index, entry in ipairs(buttons) do
            local id = entry[1]
            local column, row = math.mod(index - 1, 2), math.floor((index - 1) / 2)
            Button(page, T(entry[2]), column * (half + 8), generalActionsTop + row * buttonStep, half, M.buttonHeight,
                function() Report(runtime.RunDrawer(id)) end)
        end
        Button(page, T('cinema.reset_visual'), 0, generalHeight - M.buttonHeight, contentWidth, M.buttonHeight, function()
            Report(director.ResetVisual())
            for _, update in ipairs(refresh) do update() end
        end)
        return generalHeight
    end

    local function MotionPage(page, tab)
        local y = 0
        local updates = {}
        local function Pose(slot, captureKey)
            local row = y
            local id = tab .. '_' .. slot
            local button = Button(page, '', 0, row, contentWidth - 140, M.buttonHeight,
                function() Report(runtime.RunDrawer(id)) end)
            local jumpId = tab == 'move' and 'move_jump_' .. slot or nil
            local jump = Button(page, T('cinema.jump_pose'), contentWidth - 132, row, 132, M.buttonHeight,
                function()
                    if jumpId then Report(runtime.RunDrawer(jumpId)) else Report(director.Jump(tab, slot)) end
                end)
            local summary = Text(page, '', 0, row + 40, M.secondaryText, C.muted)
            table.insert(updates, function()
                button.SetBound(captureKey, id)
                if jumpId then jump.SetBound('cinema.jump_pose', jumpId) end
                local pose = director.Get(tab, slot)
                local detail = pose and pose.Focus
                summary:SetText(detail and string.format('XYZ %.0f / %.0f / %.0f   ·   %s %.2f',
                    detail.x, detail.y, detail.z, T('cinema.zoom_short'), pose.Zoom) or T('cinema.pose_empty'))
            end)
            y = y + 64
        end
        Pose('origin', 'cinema.capture_origin')
        if tab == 'move' then Pose('target', 'cinema.capture_target') end
        local switch = Group(page)
        L(switch):AtLeftTopIn(page, 0, y):Width(contentWidth):Height(M.rowHeight)
        switch.Depth:Set(function() return page.Depth() + 1 end)
        Text(switch, T('cinema.use_origin'), 0, 10, M.secondaryText)
        local paint = Theme.SettingsSwitch(switch, L, contentWidth, M.rowHeight, ratio, true)
        local function UpdateSwitch() paint(director.Get(tab, 'useOrigin') == true) end
        table.insert(updates, UpdateSwitch)
        UpdateSwitch()
        switch.HandleEvent = function(self, event)
            if event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then
                Report(director.ToggleOrigin(tab)); UpdateSwitch()
            end
            return true
        end
        y = y + 48
        for _, spec in ipairs(specs.Motion[tab]) do
            local field = spec
            SliderRow(page, field, y, function() return director.Get(tab, field.id) end,
                function(value) return director.Set(tab, field, value) end)
            y = y + sliderStep
        end
        y = y + 8
        Button(page, T('cinema.preview'), 0, y, 148, M.buttonHeight, function() Report(director.Play(tab, true)) end)
        local play = Button(page, '', 156, y, 148, M.buttonHeight,
            function() Report(runtime.RunDrawer(tab .. '_play')) end)
        local stop = Button(page, '', 312, y, contentWidth - 312, M.buttonHeight,
            function() Report(runtime.RunDrawer('motion_stop')) end)
        table.insert(updates, function()
            play.SetBound('cinema.play', tab .. '_play')
            stop.SetBound('cinema.stop', 'motion_stop')
        end)
        refreshPage = function() for _, update in ipairs(updates) do update() end end
        refreshPage()
        return y + M.buttonHeight
    end

    buildPage = function()
        DismissButtonTooltip()
        refreshPage = nil
        if state.page then state.page:Destroy() end
        local page = Group(pane)
        page:DisableHitTest()
        L(page):AtLeftTopIn(pane, inset, pageTop):Width(contentWidth)
        page.Depth:Set(function() return pane.Depth() + 2 end)
        state.page = page
        local pageHeight
        if state.tab == 'general' then pageHeight = General(page) else pageHeight = MotionPage(page, state.tab) end
        local height = pageTop + pageHeight + footerHeight
        L(page):Height(pageHeight)
        L(pane):Height(height)
        L(status):AtLeftTopIn(pane, inset, pageTop + pageHeight + 8)
        resize(width, height)
        for id, button in pairs(tabButtons) do button.Select(id == state.tab) end
    end

    local function Build()
        pane = Bitmap(owner)
        L(pane):Width(width):Height(maxHeight)
        Position()
        pane.Depth:Set(function() return owner.Depth() + 1 end)
        pane.HandleEvent = function() return true end
        resize = Theme.RoundedPanel(pane, L, width, maxHeight, C.canvas, C.border, true)
        title = Text(pane, T('cinema.drawer_title'), inset, 18, M.heading, C.text, true)
        local modeWidth = 248
        mode = Button(pane, '', width - inset - modeWidth, 12, modeWidth, M.buttonHeight, function() Report(runtime.Toggle()) end)
        Block(pane, C.border, inset, 56, contentWidth, 1, 3)
        local tabWidth = (contentWidth - 24) / 4
        for index, pair in ipairs(tabs) do
            local id = pair[1]
            tabButtons[id] = Button(pane, T(pair[2]), inset + (index - 1) * (tabWidth + 8), 64, tabWidth, M.buttonHeight, function()
                if state.tab == id then return end
                state.tab = id
                Report(true)
                buildPage()
            end, true)
        end
        status = Text(pane, '', inset, 0, M.label, C.muted)
        RefreshMode()
        Report(not state.error, state.error)
        buildPage()
        local previous = pane.OnFrame
        pane.OnFrame = function(self, elapsed)
            if previous then previous(self, elapsed) end
            local goal = state.opened and 1 or 0
            if state.opened then state.slide = math.min(1, state.slide + elapsed / 0.16)
            else state.slide = math.max(0, state.slide - elapsed / 0.16) end
            Position()
            if state.slide == goal then
                self:SetNeedsFrameUpdate(false)
                if not state.opened then self:Hide() end
            end
        end
    end

    edgeTab = Button(owner, nil, 0, top + 8, dockWidth, M.rowHeight, function()
        if not pane then
            local ok, message = pcall(Build)
            if not ok then
                if pane then pane:Destroy() end
                pane, title, mode, status, resize, state.page = nil, nil, nil, nil, nil, nil
                tabButtons = {}
                WARN('[ClaretCinema] Could not open the shooting drawer: ' .. tostring(message))
                return
            end
        end
        state.opened = not state.opened
        if not state.opened then DismissButtonTooltip() end
        edgeTab.Select(state.opened)
        if state.opened then
            if state.refreshOnShow then state.refreshOnShow = nil; buildPage() end
            pane:Show()
        end
        if UI.GetAnimationPrefs() then
            pane:SetNeedsFrameUpdate(true)
        else
            state.slide = state.opened and 1 or 0
            Position()
            if not state.opened then pane:Hide() end
        end
    end)
    local dock = edgeTab.control
    dock.Depth:Set(function() return owner.Depth() + 12 end)
    local icon = Bitmap(dock, texture .. 'camera.png')
    icon:DisableHitTest()
    icon.Depth:Set(function() return dock.Depth() + 2 end)
    L(icon):Width(28):Height(28):AtCenterIn(dock)
    local dockEvent = dock.HandleEvent
    dock.HandleEvent = function(self, event)
        local handled = dockEvent(self, event)
        if event.Type == 'MouseEnter' then
            Tooltip.CreateMouseoverDisplay(self, {text = T(state.opened and 'cinema.drawer_hide' or 'cinema.drawer_show')})
        elseif event.Type == 'MouseExit' or event.Type == 'ButtonPress' then
            Tooltip.DestroyMouseoverDisplay()
        end
        return handled
    end

    director.Listen(function(statusKey)
        if statusKey == 'cinema.camera_unavailable' then
            state.error = statusKey
            state.motion = nil
        else
            state.motion = statusKey
        end
        Report(not state.error, state.error)
    end)
    runtime.Subscribe(owner, function(kind, ok, message)
        RefreshMode()
        if kind == 'action' then Report(ok, message) end
        if refreshPage then refreshPage() end
    end)
    localization.Subscribe(owner, function()
        if not pane then return end
        title:SetText(T('cinema.drawer_title'))
        for _, pair in ipairs(tabs) do tabButtons[pair[1]].label:SetText(T(pair[2])) end
        RefreshMode()
        Report(not state.error, state.error)
        if state.opened then buildPage() else state.refreshOnShow = true end
    end)
    local previousDestroy = owner.OnDestroy
    owner.OnDestroy = function(self)
        DismissButtonTooltip()
        if edgeTab.hover then Tooltip.DestroyMouseoverDisplay() end
        runtime.Unsubscribe(owner)
        localization.Unsubscribe(owner)
        director.Listen(nil)
        previousDestroy(self)
    end
    return owner
end
