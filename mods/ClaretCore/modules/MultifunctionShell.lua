-- Independent, unregistered shell for the stock-style multifunction panel.
-- The caller owns the shared cluster and supplies behavior through callbacks.

local overlayDefinitions = {
    { id = 'mapoptions', bitmap = 'control', tooltip = 'mfd_strat_view' },
    { id = 'teamcolor', bitmap = 'team-color', tooltip = 'mfd_defense' },
    { id = 'economy', bitmap = 'economy', tooltip = 'mfd_economy' },
    { id = 'military', bitmap = 'military-radar', tooltip = 'mfd_military' },
}

local pingDefinitions = {
    { id = 'alert', bitmap = 'ping-alert', cursor = 'RULEUCC_Guard', tooltip = 'mfd_alert_ping' },
    { id = 'move', bitmap = 'ping-move', cursor = 'RULEUCC_Move', tooltip = 'mfd_move_ping' },
    { id = 'attack', bitmap = 'ping-attack', cursor = 'RULEUCC_Attack', tooltip = 'mfd_attack_ping' },
    { id = 'marker', bitmap = 'ping-marker', cursor = 'MESSAGE', tooltip = 'mfd_marker_ping' },
}

local function Resolve(options, name, path, symbol)
    local factories = options.factories
    if factories and factories[name] then return factories[name] end
    return import(path)[symbol]
end

local function StockFile(UIUtil, path)
    return UIUtil.UIFile(path)
end

function Create(parent, callbacks, options)
    callbacks = callbacks or {}
    options = options or {}

    local Group = Resolve(options, 'group', '/lua/maui/group.lua', 'Group')
    local Bitmap = Resolve(options, 'bitmap', '/lua/maui/bitmap.lua', 'Bitmap')
    local Checkbox = Resolve(options, 'checkbox', '/lua/maui/checkbox.lua', 'Checkbox')
    local Button = Resolve(options, 'button', '/lua/maui/button.lua', 'Button')
    local UIUtil = options.uiUtil or import('/lua/ui/uiutil.lua')
    local Tooltip = options.tooltip or import('/lua/ui/game/tooltip.lua')
    local LayoutHelpers = options.layoutHelpers or import('/lua/maui/layouthelpers.lua')

    local controls = {
        root = Group(parent),
        overlayButtons = {},
        pingButtons = {},
        callbacks = callbacks,
        collapsed = options.collapsed == true,
        minimapEnabled = options.minimapEnabled ~= false,
    }
    controls.parent = parent
    controls.bg = Group(controls.root)
    controls.panel = Bitmap(controls.bg)
    controls.leftBrace = Bitmap(controls.bg)
    controls.leftGlow = Bitmap(controls.bg)
    controls.rightGlowTop = Bitmap(controls.bg)
    controls.rightGlowMiddle = Bitmap(controls.bg)
    controls.rightGlowBottom = Bitmap(controls.bg)
    controls.collapseArrow = Checkbox(controls.root)
    controls.collapseArrow:SetTexture(StockFile(UIUtil, '/game/tab-l-btn/tab-close_btn_up.dds'))
    controls.collapseArrow:SetNewTextures(
        StockFile(UIUtil, '/game/tab-l-btn/tab-close_btn_up.dds'),
        StockFile(UIUtil, '/game/tab-l-btn/tab-open_btn_up.dds'),
        StockFile(UIUtil, '/game/tab-l-btn/tab-close_btn_over.dds'),
        StockFile(UIUtil, '/game/tab-l-btn/tab-open_btn_over.dds'),
        StockFile(UIUtil, '/game/tab-l-btn/tab-close_btn_dis.dds'),
        StockFile(UIUtil, '/game/tab-l-btn/tab-open_btn_dis.dds'))
    controls.collapseArrow:SetCheck(controls.collapsed, true)
    if Tooltip.AddCheckboxTooltip then Tooltip.AddCheckboxTooltip(controls.collapseArrow, 'mfd_collapse') end

    local function CreateOverlayButton(definition, index)
        local base = '/game/mfd_btn/' .. definition.bitmap
        local button = Checkbox(controls.bg,
            StockFile(UIUtil, base .. '_btn_up.dds'),
            StockFile(UIUtil, base .. '_btn_over.dds'),
            StockFile(UIUtil, base .. '_btn_down.dds'),
            StockFile(UIUtil, base .. '_btn_down.dds'),
            StockFile(UIUtil, base .. '_btn_dis.dds'),
            StockFile(UIUtil, base .. '_btn_dis.dds'),
            'UI_Tab_Click_01', 'UI_Tab_Rollover_01')
        button.ID = definition.id
        button.Data = definition
        button._claretChecked = false
        button.OnCheck = function(self, checked)
            local accepted
            if callbacks.onOverlay then accepted = callbacks.onOverlay(definition, checked, index, self) end
            if accepted == false then
                self:SetCheck(self._claretChecked, true)
            else
                self._claretChecked = checked
            end
        end
        if Tooltip.AddCheckboxTooltip then Tooltip.AddCheckboxTooltip(button, definition.tooltip) end
        return button
    end

    local function CreatePingButton(definition, index)
        local base = '/game/mfd_btn/' .. definition.bitmap
        local buttonFactory = options.factories and options.factories.createButtonStd
        local button
        if buttonFactory then
            button = buttonFactory(controls.bg, base, nil, nil, nil, nil, 'UI_Tab_Click_01', 'UI_Tab_Rollover_01')
        elseif UIUtil.CreateButtonStd then
            button = UIUtil.CreateButtonStd(controls.bg, base, nil, nil, nil, nil,
                'UI_Tab_Click_01', 'UI_Tab_Rollover_01')
        else
            button = Button(controls.bg,
                StockFile(UIUtil, base .. '_btn_up.dds'),
                StockFile(UIUtil, base .. '_btn_down.dds'),
                StockFile(UIUtil, base .. '_btn_over.dds'),
                StockFile(UIUtil, base .. '_btn_dis.dds'),
                'UI_Tab_Click_01', 'UI_Tab_Rollover_01')
        end
        button.ID = definition.id
        button.Cursor = definition.cursor
        button.Data = definition
        button.OnClick = function(self, modifiers)
            if callbacks.onPing then callbacks.onPing(definition, modifiers, index, self) end
        end
        if Tooltip.AddButtonTooltip then Tooltip.AddButtonTooltip(button, definition.tooltip) end
        return button
    end

    for index, definition in ipairs(overlayDefinitions) do
        controls.overlayButtons[index] = CreateOverlayButton(definition, index)
    end
    for index, definition in ipairs(pingDefinitions) do
        controls.pingButtons[index] = CreatePingButton(definition, index)
    end

    controls.collapseArrow.OnCheck = function(_, checked)
        local previous = controls.collapsed
        controls.collapsed = checked
        local accepted
        if callbacks.onCollapse then accepted = callbacks.onCollapse(checked, controls) end
        if accepted == false then
            controls.collapsed = previous
            controls.collapseArrow:SetCheck(previous, true)
        end
    end

    -- Mini is the installed stock layout with a known full asset set. The caller
    -- may position the root or provide an applyLayout callback for other layouts.
    function controls:ApplyLayout()
        self.panel:SetTexture(StockFile(UIUtil, '/game/filter-ping-panel/filter-ping-panel02_bmp.dds'))
        self.leftBrace:SetTexture(StockFile(UIUtil, '/game/filter-ping-panel/bracket-left_bmp.dds'))
        self.leftGlow:SetTexture(StockFile(UIUtil, '/game/filter-ping-panel/bracket-energy-l_bmp.dds'))
        self.rightGlowTop:SetTexture(StockFile(UIUtil, '/game/bracket-right-energy/bracket_bmp_t.dds'))
        self.rightGlowMiddle:SetTexture(StockFile(UIUtil, '/game/bracket-right-energy/bracket_bmp_m.dds'))
        self.rightGlowBottom:SetTexture(StockFile(UIUtil, '/game/bracket-right-energy/bracket_bmp_b.dds'))
        LayoutHelpers.AtLeftTopIn(self.panel, self.bg, 2)
        LayoutHelpers.AnchorToLeft(self.leftBrace, self.bg, -11)
        LayoutHelpers.AtTopIn(self.leftBrace, self.bg, 2)
        LayoutHelpers.AtLeftIn(self.leftGlow, self.leftBrace, 12)
        LayoutHelpers.AtTopIn(self.leftGlow, self.bg)
        self.leftGlow.Depth:Set(function() return self.leftBrace.Depth() - 1 end)
        LayoutHelpers.AtTopIn(self.rightGlowTop, self.bg, 3)
        LayoutHelpers.AnchorToRight(self.rightGlowTop, self.bg, -9)
        LayoutHelpers.AtBottomIn(self.rightGlowBottom, self.bg, 3)
        self.rightGlowBottom.Left:Set(self.rightGlowTop.Left)
        self.rightGlowMiddle.Top:Set(self.rightGlowTop.Bottom)
        self.rightGlowMiddle.Bottom:Set(function() return math.max(self.rightGlowTop.Bottom(), self.rightGlowBottom.Top()) end)
        self.rightGlowMiddle.Right:Set(function() return self.rightGlowTop.Right() end)
        self.bg.Height:Set(self.panel.Height)
        self.bg.Width:Set(self.panel.Width)
        LayoutHelpers.AtLeftTopIn(self.bg, self.root)
        self.root.Height:Set(self.bg.Height)
        self.root.Width:Set(self.bg.Width)
        LayoutHelpers.AtLeftBottomIn(self.root, self.parent, 15, 0)

        LayoutHelpers.AtLeftTopIn(self.collapseArrow, GetFrame(0), -3, 97)
        self.collapseArrow.Depth:Set(function() return self.bg.Depth() + 10 end)
        for index, button in ipairs(self.overlayButtons) do
            if index == 1 then LayoutHelpers.AtLeftTopIn(button, self.bg, 3, 33)
            else LayoutHelpers.RightOf(button, self.overlayButtons[index - 1], -7) end
        end
        for index, button in ipairs(self.pingButtons) do
            if index == 1 then LayoutHelpers.AtLeftTopIn(button, self.bg, 15, 6)
            else LayoutHelpers.RightOf(button, self.pingButtons[index - 1], -7) end
        end
    end

    function controls:RequestMinimapToggle(enabled)
        if enabled == nil then enabled = not self.minimapEnabled end
        local previous = self.minimapEnabled
        self.minimapEnabled = enabled == true
        local accepted
        if callbacks.onMinimapToggle then accepted = callbacks.onMinimapToggle(self.minimapEnabled, self) end
        if accepted == false then
            self.minimapEnabled = previous
            return false
        end
        return self.minimapEnabled
    end

    function controls:SetCollapsed(collapsed)
        self.collapsed = collapsed == true
        self.collapseArrow:SetCheck(self.collapsed, true)
    end

    function controls:SetAccess(access)
        if type(access) ~= 'table' then return false, 'access state must be a table' end
        if access.replay ~= nil and type(access.replay) ~= 'boolean' then return false, 'replay must be boolean' end
        if access.readOnly ~= nil and type(access.readOnly) ~= 'boolean' then return false, 'readOnly must be boolean' end
        if access.canPing ~= nil and type(access.canPing) ~= 'boolean' then return false, 'canPing must be boolean' end
        if access.replay ~= nil then self.replay = access.replay end
        if access.readOnly ~= nil then self.readOnly = access.readOnly end
        if access.canPing ~= nil then self.canPing = access.canPing end
        local pingDisabled = self.replay == true or self.readOnly == true or self.canPing == false
        for _, button in ipairs(self.pingButtons) do
            if pingDisabled then button:Disable() else button:Enable() end
        end
        local teamColor = self.overlayButtons[2]
        if teamColor then
            if self.replay == true then teamColor:Disable() else teamColor:Enable() end
        end
        return true
    end

    local destroyed = false
    function controls:Destroy()
        if destroyed then return end
        destroyed = true
        if self.root and self.root.Destroy then self.root:Destroy() end
        self.root = nil
        self.bg = nil
        self.parent = nil
        self.overlayButtons = {}
        self.pingButtons = {}
        self.callbacks = nil
    end

    if options.applyLayout then options.applyLayout(controls)
    elseif options.layout ~= false then controls:ApplyLayout() end
    controls:SetAccess(options)
    return controls
end
