-- Original, unregistered order-panel shell. Definitions and behavior are
-- supplied by the caller; this view never issues commands or installs hooks.

local layouts = {
    mini = { columns = 7, rows = 2, anchor = 'left-bottom', panel = '/game/orders-panel/order-panel_bmp.dds' },
    right = { columns = 7, rows = 2, anchor = 'right-bottom', panel = '/game/orders-panel/order-panel_bmp.dds' },
    left = { columns = 5, rows = 3, anchor = 'left-top', panel = '/game/orders-panel_vert/order-panel_bmp.dds' },
}

local function Resolve(options, key, path, symbol)
    if options.factories and options.factories[key] then return options.factories[key] end
    return import(path)[symbol]
end

local function TextureNames(UIUtil, bitmapId)
    local prefix = '/game/orders/' .. tostring(bitmapId or 'basic-empty') .. '_btn_'
    return {
        UIUtil.SkinnableFile(prefix .. 'up.dds', true),
        UIUtil.SkinnableFile(prefix .. 'up_sel.dds', true),
        UIUtil.SkinnableFile(prefix .. 'over.dds', true),
        UIUtil.SkinnableFile(prefix .. 'over_sel.dds', true),
        UIUtil.SkinnableFile(prefix .. 'dis.dds', true),
        UIUtil.SkinnableFile(prefix .. 'dis_sel.dds', true),
        'UI_Action_MouseDown', 'UI_Action_Rollover',
    }
end

function Create(parent, callbacks, options)
    callbacks = callbacks or {}
    options = options or {}
    local Group = Resolve(options, 'group', '/lua/maui/group.lua', 'Group')
    local Bitmap = Resolve(options, 'bitmap', '/lua/maui/bitmap.lua', 'Bitmap')
    local Button = Resolve(options, 'button', '/lua/maui/button.lua', 'Button')
    local Checkbox = Resolve(options, 'checkbox', '/lua/maui/checkbox.lua', 'Checkbox')
    local Grid = Resolve(options, 'grid', '/lua/maui/grid.lua', 'Grid')
    local UIUtil = options.uiUtil or import('/lua/ui/uiutil.lua')
    local LayoutHelpers = options.layoutHelpers or import('/lua/maui/layouthelpers.lua')
    local GameCommon = options.gameCommon or import('/lua/ui/game/gamecommon.lua')

    local layoutName = options.layoutName or 'mini'
    local geometry = layouts[layoutName]
    if not geometry then error('Unsupported orders panel layout: ' .. tostring(layoutName)) end
    local iconWidth = options.iconWidth or GameCommon.iconWidth
    local iconHeight = options.iconHeight or GameCommon.iconHeight
    local controls = {
        root = Group(parent), parent = parent, callbacks = callbacks,
        buttons = {}, orderById = {}, layoutName = layoutName,
        columns = geometry.columns, rows = geometry.rows,
    }
    controls.bg = Bitmap(controls.root)
    controls.bracket = Bitmap(controls.bg)
    controls.bracketMax = Bitmap(controls.bg)
    controls.bracketMid = Bitmap(controls.bg)
    controls.orderButtonGrid = Grid(controls.bg, iconWidth, iconHeight)
    controls.orderButtonGrid:SetName('Claret Orders Grid')
    controls.orderButtonGrid:DeleteAll()

    local function ApplyPanelLayout()
        local bg = controls.bg
        local root = controls.root
        local grid = controls.orderButtonGrid
        if layoutName ~= 'right' and controls.bracketRightMin then
            controls.bracketRightMin:Destroy()
            controls.bracketRightMax:Destroy()
            controls.bracketRightMid:Destroy()
            controls.bracketRightMin = nil
            controls.bracketRightMax = nil
            controls.bracketRightMid = nil
        end
        if layoutName == 'left' then
            bg:SetTexture(UIUtil.UIFile(geometry.panel))
            LayoutHelpers.AtLeftIn(root, parent, 17)
            LayoutHelpers.AtTopIn(root, parent, 0)
            LayoutHelpers.ResetRight(root)
            LayoutHelpers.ResetBottom(root)
            controls.bracket:SetTexture(UIUtil.UIFile('/game/bracket-left/bracket_bmp_t.dds'))
            LayoutHelpers.AtLeftIn(controls.bracket, bg, -17)
            LayoutHelpers.AtTopIn(controls.bracket, bg, -2)
            LayoutHelpers.ResetBottom(controls.bracket)
            LayoutHelpers.ResetRight(controls.bracket)
            controls.bracketMax:SetTexture(UIUtil.UIFile('/game/bracket-left/bracket_bmp_b.dds'))
            LayoutHelpers.AtLeftIn(controls.bracketMax, controls.bracket)
            LayoutHelpers.AtBottomIn(controls.bracketMax, bg, -2)
            controls.bracketMid:SetTexture(UIUtil.UIFile('/game/bracket-left/bracket_bmp_m.dds'))
            LayoutHelpers.AtLeftIn(controls.bracketMid, controls.bracket)
        else
            bg:SetTexture(UIUtil.SkinnableFile(geometry.panel))
            if layoutName == 'right' then
                LayoutHelpers.AtRightIn(root, parent, 10)
                LayoutHelpers.AtBottomIn(root, parent)
                LayoutHelpers.ResetLeft(root)
                LayoutHelpers.ResetTop(root)
            else
                LayoutHelpers.AtLeftIn(root, parent, 17)
                LayoutHelpers.AtBottomIn(root, parent)
                LayoutHelpers.ResetRight(root)
                LayoutHelpers.ResetTop(root)
            end
            controls.bracket:SetTexture(UIUtil.UIFile('/game/bracket-left-energy/bracket_bmp_t.dds'))
            LayoutHelpers.AtLeftIn(controls.bracket, bg, -6)
            LayoutHelpers.AtTopIn(controls.bracket, bg, 2)
            LayoutHelpers.ResetBottom(controls.bracket)
            LayoutHelpers.ResetRight(controls.bracket)
            controls.bracketMax:SetTexture(UIUtil.UIFile('/game/bracket-left-energy/bracket_bmp_b.dds'))
            LayoutHelpers.AtLeftIn(controls.bracketMax, controls.bracket)
            LayoutHelpers.AtBottomIn(controls.bracketMax, bg, 2)
            controls.bracketMid:SetTexture(UIUtil.UIFile('/game/bracket-left-energy/bracket_bmp_m.dds'))
            LayoutHelpers.AtLeftIn(controls.bracketMid, controls.bracket)
        end
        controls.bracketMid.Top:Set(controls.bracket.Bottom)
        controls.bracketMid.Bottom:Set(controls.bracketMax.Top)
        LayoutHelpers.AtLeftTopIn(bg, root)
        root.Width:Set(bg.Width)
        root.Height:Set(bg.Height)
        LayoutHelpers.SetDimensions(grid, iconWidth * geometry.columns, iconHeight * geometry.rows)
        LayoutHelpers.AtCenterIn(grid, bg, 0, -1)
        grid:AppendRows(geometry.rows)
        grid:AppendCols(geometry.columns)

        if layoutName == 'right' then
            if not controls.bracketRightMin then
                controls.bracketRightMin = Bitmap(bg)
                controls.bracketRightMax = Bitmap(bg)
                controls.bracketRightMid = Bitmap(bg)
                controls.bracketRightMin:DisableHitTest()
                controls.bracketRightMax:DisableHitTest()
                controls.bracketRightMid:DisableHitTest()
            end
            controls.bracketRightMin:SetTexture(UIUtil.UIFile('/game/bracket-right/bracket_bmp_t.dds'))
            controls.bracketRightMax:SetTexture(UIUtil.UIFile('/game/bracket-right/bracket_bmp_b.dds'))
            controls.bracketRightMid:SetTexture(UIUtil.UIFile('/game/bracket-right/bracket_bmp_m.dds'))
            controls.bracketRightMin.Top:Set(bg.Top)
            controls.bracketRightMin.Right:Set(function() return bg.Right() + 11 end)
            controls.bracketRightMax.Bottom:Set(bg.Bottom)
            controls.bracketRightMax.Right:Set(controls.bracketRightMin.Right)
            controls.bracketRightMid.Bottom:Set(controls.bracketRightMax.Top)
            controls.bracketRightMid.Top:Set(controls.bracketRightMin.Bottom)
            controls.bracketRightMid.Right:Set(function() return controls.bracketRightMin.Right() - 7 end)
        end
    end

    local function MakeButton(definition)
        local kind = definition.controlType or definition.widget or 'checkbox'
        if kind ~= 'button' and kind ~= 'checkbox' then
            error('Unsupported order control type: ' .. tostring(kind))
        end
        local constructor = kind == 'button' and Button or Checkbox
        local textures = TextureNames(UIUtil, definition.bitmapId)
        local button
        if kind == 'button' then
            button = constructor(controls.orderButtonGrid, textures[1], textures[2], textures[3], textures[5], textures[7], textures[8])
        else
            button = constructor(controls.orderButtonGrid, unpack(textures))
        end
        button._data = definition
        button._order = definition.id
        button._curHelpText = definition.helpText
        button.ID = definition.id
        button._claretState = {
            checked = definition.checked == true,
            mixed = definition.mixed == true,
            disabled = definition.disabled == true,
        }
        if kind == 'checkbox' and button.SetCheck then
            button:SetCheck(button._claretState.checked, true)
        end
        if button._claretState.mixed then
            button.mixedModeIcon = Bitmap(button, UIUtil.UIFile('/game/orders-panel/question-mark_bmp.dds'))
            LayoutHelpers.AtRightTopIn(button.mixedModeIcon, button)
            button.mixedModeIcon:DisableHitTest()
        end
        if button._claretState.disabled then
            if button.Disable then button:Disable() end
        elseif button.Enable then
            button:Enable()
        end
        if button.OnClick ~= nil or kind == 'button' then
            button.OnClick = function(self, modifiers)
                if callbacks.onClick then callbacks.onClick(definition, modifiers, self) end
            end
        else
            button.OnClick = function(self, modifiers)
                if callbacks.onClick then callbacks.onClick(definition, modifiers, self) end
            end
        end
        local inheritedHandleEvent = button.HandleEvent
        button.HandleEvent = function(self, event)
            if callbacks.onHover and event and (event.Type == 'MouseEnter' or event.Type == 'MouseExit') then
                callbacks.onHover(definition, event.Type == 'MouseEnter', self, event)
            end
            if inheritedHandleEvent then return inheritedHandleEvent(self, event) end
        end
        return button
    end

    local function ValidateDefinitions(definitions, columns, rows)
        local ids, slots = {}, {}
        for index, definition in ipairs(definitions or {}) do
            local id = definition.id
            if id == nil then error('Order definition at index ' .. index .. ' is missing native id') end
            if ids[id] then error('Order id ' .. tostring(id) .. ' is duplicated') end
            ids[id] = true
            local slot = definition.slot or definition.preferredSlot or index
            if slots[slot] then error('Order slot ' .. tostring(slot) .. ' is assigned more than once') end
            slots[slot] = true
            if type(slot) ~= 'number' or slot < 1 or slot > columns * rows or slot ~= math.floor(slot) then
                error('Order slot ' .. tostring(slot) .. ' is outside the ' .. columns .. 'x' .. rows .. ' grid')
            end
        end
    end

    function controls:SetOrders(definitions)
        if self.destroyed then return false end
        ValidateDefinitions(definitions, self.columns, self.rows)
        self.orderButtonGrid:DestroyAllItems(true)
        self.buttons = {}
        self.orderById = {}
        self.definitions = definitions or {}
        for index, definition in ipairs(definitions or {}) do
            local id = definition.id
            local slot = definition.slot or definition.preferredSlot or index
            local col = math.mod(slot - 1, self.columns) + 1
            local row = math.ceil(slot / self.columns)
            local button = MakeButton(definition)
            self.orderButtonGrid:SetItem(button, col, row, true)
            self.buttons[index] = button
            self.orderById[id] = button
        end
        self.orderButtonGrid:EndBatch()
        return true
    end

    function controls:SetLayout(name)
        if self.destroyed then return false end
        local nextGeometry = layouts[name]
        if not nextGeometry then error('Unsupported orders panel layout: ' .. tostring(name)) end
        ValidateDefinitions(self.definitions, nextGeometry.columns, nextGeometry.rows)
        self.orderButtonGrid:DeleteAndDestroyAll(true)
        local definitions = self.definitions or {}
        layoutName = name
        self.layoutName = name
        self.columns = nextGeometry.columns
        self.rows = nextGeometry.rows
        geometry = nextGeometry
        ApplyPanelLayout()
        self:SetOrders(definitions)
        return true
    end

    function controls:Destroy()
        if self.destroyed then return end
        self.destroyed = true
        if self.orderButtonGrid and self.orderButtonGrid.DeleteAndDestroyAll then
            self.orderButtonGrid:DeleteAndDestroyAll(true)
        end
        if self.root and self.root.Destroy then self.root:Destroy() end
        self.root = nil
        self.bg = nil
        self.orderButtonGrid = nil
        self.parent = nil
        self.buttons = {}
        self.orderById = {}
        self.definitions = nil
        self.callbacks = nil
    end

    if options.applyLayout then options.applyLayout(controls)
    else ApplyPanelLayout() end
    if options.definitions then controls:SetOrders(options.definitions) end
    return controls
end
