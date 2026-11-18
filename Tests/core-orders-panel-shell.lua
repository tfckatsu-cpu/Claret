-- Orders view only renders caller-provided definitions and forwards clicks and
-- hover state. The mock models the stock Grid ownership and cell contracts.
local function property()
    local field = {}
    function field:Set(value) self.value = value end
    return field
end

local function control(kind, parent)
    local item = {
        kind = kind, parent = parent, children = {}, destroyed = false,
        Width = property(), Height = property(), Left = property(), Right = property(),
        Top = property(), Bottom = property(), Depth = property(),
    }
    if parent and parent.children then table.insert(parent.children, item) end
    function item:SetTexture(value) self.texture = value end
    function item:SetNewTextures(...) self.textures = { ... } end
    function item:SetCheck(checked, skipEvent) self.checked, self.skipCheckEvent = checked, skipEvent end
    function item:Disable() self.disabled = true end
    function item:Enable() self.disabled = false end
    function item:SetName(value) self.name = value end
    function item:DisableHitTest() self.hitTestDisabled = true end
    function item:Destroy()
        self.destroyed = true
        if self.parent and self.parent.children then
            for index, child in ipairs(self.parent.children) do
                if child == self then table.remove(self.parent.children, index); break end
            end
        end
    end
    return item
end

local function gridFactory(parent, itemWidth, itemHeight)
    local grid = control('grid', parent)
    grid.itemWidth, grid.itemHeight = itemWidth, itemHeight
    grid.cells, grid.rows, grid.columns = {}, 0, 0
    function grid:SetDimensions(width, height) self.width, self.height = width, height end
    function grid:SetName(name) self.name = name end
    function grid:DeleteAll()
        self.cells, self.rows, self.columns = {}, 0, 0
    end
    function grid:AppendRows(count) self.rows = self.rows + count end
    function grid:AppendCols(count) self.columns = self.columns + count end
    function grid:DestroyAllItems()
        for _, cell in pairs(self.cells) do cell:Destroy() end
        self.cells = {}
    end
    function grid:DeleteAndDestroyAll()
        self:DestroyAllItems()
        self.rows, self.columns = 0, 0
    end
    function grid:SetItem(cell, col, row)
        local key = row .. ':' .. col
        if self.cells[key] then self.cells[key]:Destroy() end
        cell.parent = self
        self.cells[key] = cell
        cell.row, cell.col = row, col
    end
    function grid:EndBatch() self.batchEnded = true end
    function grid:GetDimensions() return self.columns, self.rows end
    return grid
end

local factories = {
    group = function(parent) return control('group', parent) end,
    bitmap = function(parent) return control('bitmap', parent) end,
    button = function(parent, ...) local item = control('button', parent); item.constructorArgs = { ... }; return item end,
    checkbox = function(parent, ...) local item = control('checkbox', parent); item.constructorArgs = { ... }; return item end,
    grid = gridFactory,
}
local layout = {}
local layoutCalls = {}
for _, method in ipairs({ 'AtLeftIn', 'AtTopIn', 'ResetRight', 'ResetBottom', 'AtRightIn', 'AtBottomIn', 'ResetLeft', 'ResetTop', 'AtLeftTopIn', 'AtRightTopIn', 'SetDimensions', 'AtCenterIn' }) do
    layout[method] = function(...)
        table.insert(layoutCalls, { method = method, args = { ... } })
    end
end
layout.SetDimensions = function(controlValue, width, height)
    controlValue.width, controlValue.height = width, height
    table.insert(layoutCalls, { method = 'SetDimensions', args = { controlValue, width, height } })
end
local assets = {}
local uiUtil = {
    UIFile = function(path) assets[path] = true; return 'ui:' .. path end,
    SkinnableFile = function(path, flag) assets[path] = true; return 'skin:' .. path end,
}
local env = setmetatable({
    import = function(path) error('unexpected FAF import: ' .. path) end,
    math = math,
    table = table,
    unpack = unpack,
}, { __index = _G })
env.unpack = unpack or table.unpack
assert(loadfile('../mods/ClaretCore/modules/OrdersPanelShell.lua', 't', env))()

local cluster = control('caller-cluster')
local calls = { click = {}, hover = {} }
local panel = env.Create(cluster, {
    onClick = function(data, modifiers, button) table.insert(calls.click, { data = data, modifiers = modifiers, button = button }) end,
    onHover = function(data, entering, button, event) table.insert(calls.hover, { data = data, entering = entering, button = button, event = event }) end,
}, {
    factories = factories,
    uiUtil = uiUtil,
    layoutHelpers = layout,
    gameCommon = { iconWidth = 50, iconHeight = 50 },
    layoutName = 'mini',
})
assert(panel.root.parent == cluster and panel.bg.parent == panel.root)
assert(panel.orderButtonGrid.parent == panel.bg and panel.orderButtonGrid.name == 'Claret Orders Grid')
assert(panel.columns == 7 and panel.rows == 2 and panel.orderButtonGrid.width == 350 and panel.orderButtonGrid.height == 100)
assert(assets['/game/orders-panel/order-panel_bmp.dds'] and assets['/game/bracket-left-energy/bracket_bmp_t.dds'])
local function sawLayout(method, target)
    for _, call in ipairs(layoutCalls) do
        if call.method == method and call.args[1] == target then return true end
    end
    return false
end
assert(sawLayout('AtLeftIn', panel.root), 'mini starts against the left edge of the cluster')

local source = {
    { id = 'RULEUCC_Move', preferredSlot = 1, bitmapId = 'move', helpText = 'order_move', checked = true, mixed = true },
    { id = 'RULEUCC_Attack', preferredSlot = 8, bitmapId = 'attack', controlType = 'button', helpText = 'order_attack', disabled = true },
}
assert(panel:SetOrders(source))
local first, second = panel.orderById.RULEUCC_Move, panel.orderById.RULEUCC_Attack
assert(first.kind == 'checkbox' and second.kind == 'button')
assert(first._data == source[1] and first._order == 'RULEUCC_Move' and first.ID == 'RULEUCC_Move')
assert(first.checked and first.skipCheckEvent and first.mixedModeIcon
    and first._claretState.mixed and not first.disabled,
    'checkbox checked and mixed state are applied without triggering its action callback')
assert(second.disabled and second._claretState.disabled, 'disabled state is applied to button controls')
assert(first.row == 1 and first.col == 1 and second.row == 2 and second.col == 1,
    'preferred native slots keep stock row-major order')
assert(first.constructorArgs[1] == 'skin:/game/orders/move_btn_up.dds')
local modifiers = { Shift = true }
second.OnClick(second, modifiers)
local enter = { Type = 'MouseEnter' }
local leave = { Type = 'MouseExit' }
second.HandleEvent(second, enter)
second.HandleEvent(second, leave)
assert(#calls.click == 1 and calls.click[1].data == source[2] and calls.click[1].modifiers == modifiers)
assert(#calls.hover == 2 and calls.hover[1].entering and not calls.hover[2].entering)

local oldFirst, oldSecond = first, second
panel:SetLayout('right')
assert(panel.layoutName == 'right' and panel.columns == 7 and panel.rows == 2)
assert(panel.orderButtonGrid.width == 350 and panel.orderButtonGrid.height == 100)
assert(panel.bracketRightMin and panel.bracketRightMax and panel.bracketRightMid,
    'right layout owns its additional right bracket pieces')
assert(panel.bg.texture == 'skin:/game/orders-panel/order-panel_bmp.dds')
assert(sawLayout('AtRightIn', panel.root), 'right layout anchors the panel to the right edge')
assert(oldFirst.destroyed and oldSecond.destroyed, 'layout change destroys prior cells before restoring definitions')
local rightBracket = panel.bracketRightMin
panel:SetLayout('left')
assert(panel.layoutName == 'left' and panel.columns == 5 and panel.rows == 3)
assert(panel.orderButtonGrid.width == 250 and panel.orderButtonGrid.height == 150)
assert(not panel.bracketRightMin and rightBracket.destroyed, 'left layout removes the right-only bracket controls')
assert(panel.bg.texture == 'ui:/game/orders-panel_vert/order-panel_bmp.dds')
assert(sawLayout('AtTopIn', panel.root), 'left layout anchors the panel to the top')
local retained = panel.orderById.RULEUCC_Attack
assert(retained and retained.row == 2 and retained.col == 3,
    'existing orders reflow to left-layout row/column positions: ' .. tostring(retained and retained.row) .. ',' .. tostring(retained and retained.col))
local replacement = {
    { id = 'RULEUCC_Stop', slot = 15, bitmapId = 'stop' },
}
assert(panel.layoutName == 'left' and panel.columns == 5 and panel.rows == 3)
assert(panel.orderById.RULEUCC_Stop == nil, 'layout change clears prior renderer before rebuilding definitions')
panel:SetOrders(replacement)
assert(retained.destroyed, 'dynamic replacement destroys the currently rendered cells')
assert(panel.orderById.RULEUCC_Stop.row == 3 and panel.orderById.RULEUCC_Stop.col == 5)
assert(panel.definitions == replacement and panel.buttons[1]._data == replacement[1])

local switched, switchError = pcall(function() panel:SetLayout('right') end)
assert(not switched and string.find(switchError, 'outside the 7x2 grid'))
assert(panel.layoutName == 'left' and panel.orderById.RULEUCC_Stop.row == 3,
    'invalid reflow is rejected before changing the active layout or cells')
panel:SetOrders({ { id = 'RULEUCC_Stop', slot = 14, bitmapId = 'stop' } })
panel:SetLayout('right')
assert(panel.layoutName == 'right' and panel.columns == 7 and panel.rows == 2)
assert(panel.bracketRightMin and panel.orderButtonGrid.width == 350 and panel.orderButtonGrid.height == 100)
assert(panel.orderById.RULEUCC_Stop.row == 2 and panel.orderById.RULEUCC_Stop.col == 7,
    'valid layout reflow retains and re-renders existing definitions')

local rightDefinition = { id = 'RULEUCC_Repair', slot = 14, bitmapId = 'repair' }
panel:SetOrders({ rightDefinition })
assert(panel.orderById.RULEUCC_Repair.row == 2 and panel.orderById.RULEUCC_Repair.col == 7)
local ownedRoot = panel.root
panel:Destroy()
assert(ownedRoot.destroyed and panel.root == nil and cluster.children[1] ~= ownedRoot)
panel:Destroy()
assert(cluster.children[1] == nil, 'destroy is idempotent and does not destroy caller-owned parent')
print('PASS: orders shell contracts, stock geometry, callbacks, replacement and cleanup')
