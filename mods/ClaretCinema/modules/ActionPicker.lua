local groups = {
    {'cinema', 'cinema.command_group'},
    {'move', 'cinema.drawer_move'},
    {'pan', 'cinema.drawer_pan'},
    {'spin', 'cinema.drawer_spin'},
    {'camera', 'cinema.group_camera'},
    {'presentation', 'cinema.group_presentation'},
    {'replay', 'cinema.group_replay'},
    {'debug', 'cinema.group_debug'},
}

function Build(ui)
    local box, C, T = ui.box, ui.colors, ui.T
    local tabs, rows = {}, {}
    local selected, first, query, count = 'cinema', 1, '', 0
    local slots, rowStep = 8, 46
    local viewport = ui.panel(box, 24, 248, 712, slots * rowStep, C.canvas)
    local caption = ui.text(box, '', 24, 632, 13, C.muted)

    local function Match(choice)
        if query == '' then
            return (choice.group or 'cinema') == selected
                or choice.id == 'motion_stop' and (selected == 'move' or selected == 'pan' or selected == 'spin')
        end
        if choice.label and ui.matches(choice.label, query) then return true end
        local needle = ui.fold(query)
        return string.find(ui.fold(ui.label(choice)), needle, 1, true) ~= nil
            or string.find(ui.fold(choice.id), needle, 1, true) ~= nil
    end

    local function Refresh()
        local matches = {}
        for _, choice in ipairs(ui.choices) do
            if Match(choice) then table.insert(matches, choice) end
        end
        count = table.getn(matches)
        first = math.max(1, math.min(first, count - slots + 1))
        for index, row in ipairs(rows) do
            local choice = matches[first + index - 1]
            row.choice = choice
            if choice then
                local label = ui.label(choice)
                row.item.label:SetText(choice.reason and label .. ' · ' .. T(choice.reason) or label)
                row.item.Style(C.raised, C.border, true)
                if choice.reason then row.item.label:SetColor(C.muted) end
                row.item.control:Show()
            else
                row.item.control:Hide()
            end
        end
        local groupCaption = T('cinema.search_results')
        if query == '' then
            for _, group in ipairs(groups) do if group[1] == selected then groupCaption = T(group[2]) end end
        end
        caption:SetText(count > 0 and (groupCaption .. ' · ' .. first .. '–' .. math.min(count, first + slots - 1) .. ' / ' .. count)
            or T('cinema.no_commands'))
        for id, tab in pairs(tabs) do
            local active = query == '' and id == selected
            tab.Style(active and C.accent or C.raised, active and C.selectedBorder or C.border, true)
        end
    end

    for index = 1, slots do
        local row = {}
        row.item = ui.button(viewport, '', 0, (index - 1) * rowStep, 712, 36, ui.metrics.buttonText, function()
            local choice = row.choice
            if not choice then return end
            if choice.reason then ui.showError(choice.reason) else ui.save(choice.id) end
        end)
        rows[index] = row
    end
    for index, group in ipairs(groups) do
        local id = group[1]
        local column, row = math.mod(index - 1, 4), math.floor((index - 1) / 4)
        tabs[id] = ui.button(box, T(group[2]), 24 + column * 179, 100 + row * 44, 175, 36, ui.metrics.buttonText, function()
            selected, first = id, 1
            if query ~= '' then query = ''; ui.search:SetText('') end
            Refresh()
        end)
    end
    local function Scroll(delta)
        first = first + delta
        Refresh()
    end
    viewport.HandleEvent = function(self, event)
        if event.Type == 'WheelRotation' then Scroll(event.WheelRotation > 0 and -1 or 1) end
        return true
    end
    ui.button(box, '‹', 650, 616, 40, 32, ui.metrics.buttonText, function() Scroll(-slots) end)
    ui.button(box, '›', 696, 616, 40, 32, ui.metrics.buttonText, function() Scroll(slots) end)
    ui.search.OnTextChanged = function(self, value)
        query = value or self:GetText()
        first = 1
        Refresh()
    end
    ui.search.OnEnterPressed = function() return true end
    Refresh()
end
