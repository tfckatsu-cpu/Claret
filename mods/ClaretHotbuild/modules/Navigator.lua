-- Small in-menu page switcher for Hotbuild settings.
-- `pages` is an ordered array of { id, title, description?, open(parent, layout) }.
-- Restores the page ID from optional session memory; each page opener returns its
-- embedded editor control and may expose CanLeave(intent, continueFn).
function Create(parent, layout, pages, memory)
    if type(parent) ~= 'userdata' and type(parent) ~= 'table' then return nil end
    if type(layout) ~= 'table' or type(layout.scale) ~= 'number' then return nil end
    if type(pages) ~= 'table' or table.getn(pages) < 1 then return nil end

    local Theme = import('/mods/ClaretCore/modules/Theme.lua')
    local Localization = ReUI.ClaretCore and ReUI.ClaretCore.Localization or {
        Text = function(key) return key end,
        Subscribe = function() end,
        Unsubscribe = function() end,
    }
    local C = Theme.Colors
    local Group = import('/lua/maui/group.lua').Group
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local UI = import('/lua/ui/uiutil.lua')
    local Helpers = import('/lua/maui/layouthelpers.lua')
    local scale = layout.scale
    local L = ReUI.UI.FloorLayouter(scale)
    local pixel = Helpers.GetPixelScaleFactor()
    local ratio = scale / pixel
    local width, height = 1080, 984
    local navHeight, navGap = 48, 8
    local childHeight = height - navHeight - navGap - 8
    local childScale = scale * childHeight / 920
    local childWidth = width * childScale / scale
    local childLeft = (width - childWidth) / 2
    local root = Group(parent)
    root:DisableHitTest()
    memory = type(memory) == 'table' and memory or {}
    local state = { index = 1, serial = 0, child = nil, disposed = false }

    local function Surface(owner, x, y, w, h, color)
        local control = Bitmap(owner)
        control:SetSolidColor(color or C.surface)
        L(control):AtLeftTopIn(owner, x, y):Width(w):Height(h)
        return control
    end
    local function Text(owner, value, x, y, size, color)
        if type(value)=='string' and string.sub(value,1,9)=='hotbuild.' then value=Localization.Text(value) end
        local control = UI.CreateText(owner, value or '', size * ratio, Theme.Fonts.body)
        control:SetColor(color or C.text)
        control:DisableHitTest()
        L(control):AtLeftTopIn(owner, x, y)
        return control
    end

    local ok, err = pcall(function()
        L(root):AtLeftTopIn(parent, 0, 0):Width(width):Height(height)
        local nav = {}
        local content = Group(root)
        content:DisableHitTest()
        L(content):AtLeftTopIn(root, childLeft, navHeight + navGap):Width(childWidth):Height(childHeight)

        local function SetSelected(index)
            for i, item in ipairs(nav) do
                local active = i == index
                item.control:SetSolidColor(active and C.selected or C.raised)
                item.outline(active and C.selectedBorder or C.border)
                item.label:SetColor(active and C.accentText or C.text)
            end
        end

        local function Open(index)
            if state.disposed or not pages[index] then return end
            state.index = index
            memory.pageId = pages[index].id
            if layout.setHeight then layout.setHeight(nil) end
            SetSelected(index)
            if state.child then state.child:Destroy(); state.child = nil end
            if pages[index].open then
                local child = pages[index].open(content, { scale = childScale, setHeight = function(childHeightValue)
                    if not state.disposed and state.index == index and layout.setHeight then
                        layout.setHeight(childHeightValue and (navHeight+navGap+childHeightValue*childScale/scale) or nil)
                    end
                end })
                state.child = child
            end
        end

        local function AttemptLeave(intent, action, continuation)
            local child = state.child
            if not (child and child.CanLeave) then action(); if continuation then continuation(true) end; return end
            state.serial = state.serial + 1
            local serial = state.serial
            local completed = false
            local function Continue(allowed)
                if completed then return end
                completed = true
                if serial ~= state.serial or state.disposed or state.child ~= child then return end
                if allowed then action() end
                if continuation then continuation(allowed) end
            end
            local allowed
            local success, leaveError = pcall(function() allowed = child.CanLeave(intent, Continue) end)
            if not success then
                state.serial = state.serial + 1
                WARN('[Claret Hotbuild] Navigation leave check failed: ' .. tostring(leaveError))
                if continuation then continuation(false) end
            elseif allowed then
                Continue(true)
            end
        end

        for i, page in ipairs(pages) do
            local pageIndex, pageId = i, page.id
            local x = (i - 1) * (width / table.getn(pages))
            local w = width / table.getn(pages)
            local control = Surface(root, x, 0, w - 6, navHeight, C.raised)
            local outline = Theme.Outline(control, L, w - 6, navHeight)
            local label = Text(control, page.titleKey and Localization.Text(page.titleKey) or page.title or page.id, 8, 0, 15, C.text)
            L(label):AtCenterIn(control)
            local item = { control = control, outline = outline, label = label }
            control.HandleEvent = function(self, event)
                if event.Type == 'MouseEnter' and pageIndex ~= state.index then self:SetSolidColor(C.hover)
                elseif event.Type == 'MouseExit' and pageIndex ~= state.index then self:SetSolidColor(C.raised)
                elseif event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) and pageIndex ~= state.index then
                    AttemptLeave('page:' .. tostring(pageId), function() Open(pageIndex) end)
                end
                return true
            end
            nav[i] = item
        end

        Localization.Subscribe(root,function()
            if state.disposed then return end
            for index,page in ipairs(pages) do
                if nav[index] then nav[index].label:SetText(page.titleKey and Localization.Text(page.titleKey) or page.title or page.id) end
            end
            if state.child and state.child.OnLanguageChanged then state.child.OnLanguageChanged() end
        end)

        state.child = nil
        state.AttemptLeave = AttemptLeave
        local initialIndex = 1
        if type(memory.pageId) == 'string' then
            for index, page in ipairs(pages) do
                if page.id == memory.pageId then initialIndex = index; break end
            end
        end
        -- The host is still hidden while the section is constructed. Building an
        -- embedded editor there leaves size-only Maui controls with a circular
        -- Left/Top chain, so the remembered page is built once it is on screen.
        state.OpenInitial = function()
            if state.opened or state.disposed then return end
            state.opened = true
            Open(initialIndex)
        end
    end)
    if not ok then root:Destroy(); error(err) end

    local oldDestroy = root.OnDestroy
    root.OnDestroy = function(self)
        state.disposed = true
        Localization.Unsubscribe(root)
        state.serial = state.serial + 1
        local child = state.child
        state.child = nil
        if child then child:Destroy() end
        oldDestroy(self)
    end
    root.CanLeave = function(intent, continueFn)
        local answered = false
        local allowed
        state.AttemptLeave(intent, function() allowed = true end, function(result)
            answered = true
            if continueFn then continueFn(result) end
        end)
        if answered then return allowed end
        return false
    end
    root.OnKeyboardEvent = function(event)
        if state.child and state.child.OnKeyboardEvent then state.child.OnKeyboardEvent(event) end
    end
    root.AfterParentShow = function()
        if state.OpenInitial then state.OpenInitial() end
        if state.child and state.child.AfterParentShow then
            state.child:AfterParentShow()
        end
    end
    root.RequestClose = function()
        if state.child and state.child.RequestClose then state.child.RequestClose() end
    end
    return root
end
