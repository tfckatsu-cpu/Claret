local function Build(root, layout, memory)
    local base = '/mods/ClaretCinema/modules/'
    local Runtime = import(base .. 'Runtime.lua')
    local Keys = import(base .. 'KeyboardLayout.lua')
    local choices = Runtime.GetChoices()
    local Theme = import('/mods/ClaretCore/modules/Theme.lua')
    local Group = import('/lua/maui/group.lua').Group
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local Edit = import('/lua/maui/edit.lua').Edit
    local UI = import('/lua/ui/uiutil.lua')
    local Escape = import('/lua/ui/dialogs/eschandler.lua')
    local Localization = ReUI.ClaretCore.Localization
    local T, C, M = Localization.Text, Theme.Colors, Theme.Metrics
    local L = ReUI.UI.FloorLayouter(layout.scale)
    local ratio = layout.scale / import('/lua/maui/layouthelpers.lua').GetPixelScaleFactor()
    local state = {manual = {}, held = {}, keys = {}, modifiers = {}}
    local frame = Group(root)
    frame:DisableHitTest()
    frame.Depth:Set(function() return root.Depth() + 1 end)
    L(frame):AtLeftTopIn(root, 0, 56):Width(1080):Height(570)

    local function Panel(parent, x, y, w, h, color)
        local control = Bitmap(parent)
        L(control):AtLeftTopIn(parent, x, y):Width(w):Height(h)
        control.Depth:Set(function() return parent.Depth() + 1 end)
        control:SetSolidColor(color)
        return control
    end

    local function Text(parent, value, x, y, size, color, heading)
        local text = UI.CreateText(parent, value, size * ratio, heading and Theme.Fonts.heading or Theme.Fonts.body)
        text:SetColor(color or C.text)
        text:DisableHitTest()
        L(text):AtLeftTopIn(parent, x, y)
        text.Depth:Set(function() return parent.Depth() + 2 end)
        return text
    end

    local function Button(parent, value, x, y, w, h, size, click, right, hover)
        local control = Panel(parent, x, y, w, h, C.raised)
        local edge = Theme.Outline(control, L, w, h)
        local label = Text(control, value, 0, 0, size)
        L(label):AtCenterIn(control)
        local item = {control = control, label = label}
        local function Paint()
            control:SetSolidColor(not item.enabled and C.surface or item.pressed and C.pressed
                or item.hover and C.hover or item.fill)
            edge(item.enabled and (item.hover and C.selectedBorder or item.edge) or C.border)
            label:SetColor(item.enabled and C.text or C.disabledText)
        end
        function item.Style(fill, border, enabled)
            item.fill, item.edge, item.enabled = fill, border, enabled
            Paint()
        end
        item.Style(C.raised, C.border, true)
        if click then
            control.HandleEvent = function(self, event)
                if event.Type == 'WheelRotation' then return false end
                if event.Type == 'MouseEnter' or event.Type == 'MouseExit' then
                    item.hover = event.Type == 'MouseEnter'
                    if not item.hover then item.pressed = false end
                    Paint()
                    if hover then hover(item.hover) end
                elseif event.Type == 'ButtonRelease' then
                    item.pressed = false
                    Paint()
                elseif event.Type == 'ButtonPress' and item.enabled then
                    local action = click
                    if event.Modifiers and event.Modifiers.Right then action = right end
                    if action then item.pressed = true; Paint(); action() end
                end
                return true
            end
        else
            control:DisableHitTest()
        end
        return item
    end

    local tab = Button(root, '', 0, 0, 354, 48, M.buttonText)
    tab.Style(C.selected, C.selectedBorder, true)
    tab.label:SetColor(C.accentText)
    Panel(frame, 24, 20, 4, 24, C.accent):DisableHitTest()
    local title = Text(frame, '', 40, 16, M.title, C.text, true)
    local instructions = Text(frame, '', 24, 54, M.secondaryText, C.muted)
    local legend = Text(frame, '', 24, 510, 13, C.muted)
    local status = Text(frame, '', 24, 540, 13, C.muted)
    local keyboard = Group(frame)
    keyboard:DisableHitTest()
    keyboard.Depth:Set(function() return frame.Depth() + 1 end)
    L(keyboard):AtLeftTopIn(frame, 24, 148):Width(1032):Height(346)

    local function Report(key)
        state.error = key
        status:SetColor(key and C.danger or C.muted)
        status:SetText(key and T(key) or not state.toggle and T('cinema.map_wait') or '')
    end

    local function Chord(key)
        local m, h = state.manual, state.held
        return Keys.Chord(key, m.ctrl or h.ctrl, m.shift or h.shift, m.alt or h.alt)
    end

    local function ChoiceLabel(choice)
        return choice.label and T(choice.label) or choice.name
    end

    local function Assignment(chord)
        local id = Runtime.GetAssignment(chord)
        for _, choice in ipairs(choices) do
            if choice.id == id then return ChoiceLabel(choice) end
        end
        return T('cinema.unassigned')
    end

    local function Normal(chord)
        local label, occupied = Runtime.GetNormalAction(chord)
        return T('cinema.normal', label or T(occupied and 'cinema.normal_runtime' or 'cinema.unassigned'))
    end

    local function Tooltip(cell)
        if state.tooltip then state.tooltip:Destroy(); state.tooltip = nil end
        if not cell or state.dialog then return end
        local chord = Chord(cell.key)
        local w, h = 480, 100
        local x, y = math.min(1056 - w, 24 + cell.x), 148 + cell.y + cell.height + 6
        if y + h > frame.desiredHeight then y = 148 + cell.y - h - 6 end
        local popup = Panel(frame, x, y, w, h, C.surface)
        popup.Depth:Set(function() return frame.Depth() + 60 end)
        popup:DisableHitTest()
        state.tooltip = popup
        Theme.Outline(popup, L, w, h)
        local heading = Text(popup, chord, 0, 12, 14, C.accentText)
        L(heading):AtLeftTopIn(popup, (w - heading:GetStringAdvance(chord) / ratio) / 2, 12)
        Text(popup, Normal(chord), 16, 38, 13, C.muted)
        Text(popup, T('cinema.assigned', Assignment(chord)), 16, 62, 13)
    end

    local function Size()
        local h = state.dialog and 920 or memory.numpad and 850 or 570
        frame.desiredHeight = h
        L(frame):Height(h)
        L(root):Height(56 + h)
        L(legend):AtLeftTopIn(frame, 24, memory.numpad and 800 or 510)
        L(status):AtLeftTopIn(frame, 24, memory.numpad and 824 or 540)
        layout.setHeight(56 + h)
    end

    local function CloseDialog(resize)
        local dialog = state.dialog
        if not dialog then return end
        state.dialog = nil
        if dialog.escape then Escape.PopEscapeHandler() end
        dialog.overlay:Destroy()
        if resize then Size() end
    end

    local toggleButton = Button(frame, '', 204, 92, 256, 36, M.buttonText, function()
        local ok, message = Runtime.Toggle()
        Report(not ok and message or nil)
    end)

    local function Refresh()
        local wasActive = state.active
        state.active, state.toggle = Runtime.GetState()
        if state.active and not wasActive and state.dialog then CloseDialog(true) end
        local mode = T(state.active and 'cinema.mode_on' or 'cinema.mode_off')
        toggleButton.label:SetText(state.toggle and (mode .. ' · ' .. state.toggle) or mode)
        toggleButton.Style(state.active and C.accent or C.raised, state.active and C.selectedBorder or C.border, state.toggle ~= nil)
        Report(state.error)
        for _, cell in ipairs(state.keys) do
            local chord = Chord(cell.key)
            local assigned = Runtime.GetAssignment(chord) ~= nil
            cell.item.Style(assigned and C.accent or C.raised, assigned and C.selectedBorder or C.border, true)
        end
        for _, cell in ipairs(state.modifiers) do
            local selected = state.manual[cell.modifier] or state.held[cell.modifier]
            cell.item.Style(selected and C.selected or C.raised, selected and C.selectedBorder or C.border, true)
        end
        Tooltip(state.hover)
    end

    local function OpenChoices(chord)
        CloseDialog(false)
        state.hover = nil
        Tooltip(nil)
        local overlay = Panel(frame, 0, 0, 1080, 920, C.transparent)
        overlay.Depth:Set(function() return frame.Depth() + 80 end)
        overlay.HandleEvent = function() return true end
        state.dialog = {overlay = overlay}
        Size()
        local box = Panel(overlay, 0, 0, 760, 760, C.canvas)
        L(box):AtCenterIn(overlay)
        Theme.Outline(box, L, 760, 760)
        Text(box, T('cinema.picker', chord), 24, 18, 20, C.text, true)
        Text(box, Normal(chord), 24, 52, 13, C.muted)
        Text(box, T('cinema.assigned', Assignment(chord)), 24, 72, 13, C.muted)
        Button(box, T('cinema.close'), 638, 12, 98, 32, M.buttonText, function() CloseDialog(true) end)
        local restriction = Runtime.IsMenuChord(chord) and 'cinema.menu_reserved'
            or not Keys.IsAssignable(chord) and 'cinema.reserved'
            or state.active and 'cinema.turn_off_to_edit'
        if restriction then
            Text(box, T(restriction), 24, 156, 14, C.muted)
            if not state.active and Runtime.GetAssignment(chord) then
                Button(box, T('cinema.clear'), 578, 668, 158, 32, M.buttonText, function()
                    local ok, message = Runtime.Clear(chord)
                    if ok then CloseDialog(true); Report(nil) else Report(message) end
                end)
            end
        else
            local modalStatus = Text(box, '', 24, 724, 13, C.danger)
            local function Save(id)
                local ok, message
                if id then ok, message = Runtime.Assign(id, chord)
                else ok, message = Runtime.Clear(chord) end
                if ok then
                    CloseDialog(true)
                    Report(nil)
                elseif message then
                    modalStatus:SetText(T(message))
                end
            end
            local search = Edit(box)
            search.Depth:Set(function() return box.Depth() + 2 end)
            L(search):AtLeftTopIn(box, 24, 196):Width(300):Height(36)
            UI.SetupEditStd(search, C.text, nil, C.text, C.selected, Theme.Fonts.body, M.text * ratio, 100)
            Text(box, T('cinema.search'), 340, 205, 13, C.muted)
            local picker = import(base .. 'ActionPicker.lua')
            picker.Build({
                box = box, search = search, choices = choices, label = ChoiceLabel, save = Save,
                button = Button, text = Text, panel = Panel, colors = C, T = T, metrics = M,
                matches = Localization.Matches, fold = Localization.Fold,
                showError = function(key) modalStatus:SetText(T(key)) end,
            })
            local assigned = Runtime.GetAssignment(chord)
            if assigned then
                local isMode = assigned == 'mode'
                Button(box, T(isMode and 'cinema.auto' or 'cinema.clear'), 578, 668, 158, 32, M.buttonText, function() Save(nil) end)
            end
        end
        state.dialog.escape = function() CloseDialog(true); return true end
        Escape.PushEscapeHandler(state.dialog.escape)
    end

    local function DrawRows(owner, numpad)
        for _, row in ipairs(Keys.Rows) do
            if (row[2] >= 370) == numpad then
                local x = row[1]
                for _, spec in ipairs(row[3]) do
                    local key, modifier = spec[2], spec[5]
                    local units, height = spec[3] or 1, spec[6] or 50
                    x = x + (spec[4] or 0) * 56
                    local cell = {key = key, modifier = modifier, x = x, y = row[2], height = height, numpad = numpad}
                    local function Click()
                        if modifier then state.manual[modifier] = not state.manual[modifier]; Refresh()
                        else OpenChoices(Chord(key)) end
                    end
                    local function Clear()
                        if key and Runtime.GetAssignment(Chord(key)) then
                            local ok, message = Runtime.Clear(Chord(key))
                            Report(not ok and message or nil)
                        end
                    end
                    local function Hover(entered)
                        if key then
                            state.hover = entered and cell or nil
                            Tooltip(state.hover)
                        end
                    end
                    local mouseLabel = key == 'XButton1' and 'cinema.mouse4' or key == 'XButton2' and 'cinema.mouse5'
                    cell.mouseLabel = mouseLabel
                    cell.item = Button(owner, mouseLabel and T(mouseLabel) or spec[1], x, row[2], units * 56 - 4,
                        height, key and (string.len(spec[1]) > 6 and 11 or 14) or M.buttonText, Click, Clear, Hover)
                    table.insert(modifier and state.modifiers or state.keys, cell)
                    x = x + units * 56
                end
            end
        end
    end

    local function DrawNumpad()
        Tooltip(nil)
        state.hover = nil
        if memory.numpad then
            state.numpad = Group(keyboard)
            state.numpad:DisableHitTest()
            L(keyboard):Height(640)
            L(state.numpad):Fill(keyboard)
            DrawRows(state.numpad, true)
        else
            if state.numpad then state.numpad:Destroy(); state.numpad = nil end
            L(keyboard):Height(346)
            for index = table.getn(state.keys), 1, -1 do
                if state.keys[index].numpad then table.remove(state.keys, index) end
            end
        end
    end

    local numpad = Button(frame, '', 24, 92, 160, 36, M.buttonText, function()
        memory.numpad = not memory.numpad
        DrawNumpad()
        Size()
        Refresh()
        state.numpadButton.label:SetText(T(memory.numpad and 'cinema.numpad_open' or 'cinema.numpad_closed'))
    end)
    state.numpadButton = numpad

    local function Language()
        CloseDialog(false)
        Size()
        tab.label:SetText(T('cinema.keyboard'))
        title:SetText(T('cinema.keyboard'))
        instructions:SetText(T('cinema.instructions'))
        legend:SetText(T('cinema.legend'))
        numpad.label:SetText(T(memory.numpad and 'cinema.numpad_open' or 'cinema.numpad_closed'))
        for _, cell in ipairs(state.keys) do
            if cell.mouseLabel then cell.item.label:SetText(T(cell.mouseLabel)) end
        end
        Report(state.error)
        Refresh()
    end

    local watcher = Group(frame)
    watcher:DisableHitTest()
    watcher.OnFrame = function()
        local ctrl, shift, alt = IsKeyDown(17), IsKeyDown(16), IsKeyDown(18)
        local h = state.held
        if h.ctrl == ctrl and h.shift == shift and h.alt == alt then return end
        h.ctrl, h.shift, h.alt = ctrl, shift, alt
        Refresh()
    end
    local oldHide = root.OnHide
    root.OnHide = function(self, hidden)
        watcher:SetNeedsFrameUpdate(not hidden)
        if hidden then
            state.hover = nil
            Tooltip(nil)
            state.held = {}
        else
            watcher:OnFrame()
        end
        if oldHide then return oldHide(self, hidden) end
    end
    local oldDestroy = root.OnDestroy
    root.OnDestroy = function(self)
        Runtime.Unsubscribe(root)
        CloseDialog(false)
        oldDestroy(self)
    end
    root.CanLeave = function() CloseDialog(true); return true end
    root.OnLanguageChanged = Language

    DrawRows(keyboard, false)
    DrawNumpad()
    Language()
    watcher:SetNeedsFrameUpdate(true)
    watcher:OnFrame()
    Runtime.Subscribe(root, Refresh)
end

function Create(parent, layout, memory)
    local root = import('/lua/maui/group.lua').Group(parent)
    root:DisableHitTest()
    root.Depth:Set(function() return parent.Depth() + 1 end)
    ReUI.UI.FloorLayouter(layout.scale)(root):AtLeftTopIn(parent, 0, 0):Width(1080):Height(626)
    local opened = false
    root.AfterParentShow = function(self)
        if opened then return end
        opened = true
        local ok, message = pcall(Build, self, layout, memory)
        if not ok then
            self:Destroy()
            error(message)
        end
    end
    return root
end
