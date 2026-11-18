-- Integration between the real order presentation model and real panel shell.
-- FAF controls/layout are mocked; no native behavior or engine command runs.
table.getn = table.getn or function(value) return #value end
math.mod = math.mod or math.fmod

local function prop()
    local value = {}
    function value:Set(nextValue) self.value = nextValue end
    return value
end

local function control(kind, parent)
    local item = {
        kind = kind, parent = parent, children = {}, destroyed = false,
        Width = prop(), Height = prop(), Left = prop(), Right = prop(), Top = prop(), Bottom = prop(), Depth = prop(),
    }
    if parent and parent.children then table.insert(parent.children, item) end
    function item:SetTexture(texture) self.texture = texture end
    function item:SetNewTextures(...) self.textures = { ... } end
    function item:SetName(name) self.name = name end
    function item:SetCheck(value, silent) self.checked, self.silent = value, silent end
    function item:Disable() self.disabled = true end
    function item:Enable() self.disabled = false end
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
    grid.cells, grid.rows, grid.columns = {}, 0, 0
    function grid:SetDimensions(width, height) self.width, self.height = width, height end
    function grid:SetName(name) self.name = name end
    function grid:DeleteAll() self.cells, self.rows, self.columns = {}, 0, 0 end
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
        cell.parent, cell.row, cell.col = self, row, col
        self.cells[key] = cell
    end
    function grid:EndBatch() self.batchEnded = true end
    return grid
end

local factories = {
    group = function(parent) return control('group', parent) end,
    bitmap = function(parent) return control('bitmap', parent) end,
    button = function(parent) return control('button', parent) end,
    checkbox = function(parent) return control('checkbox', parent) end,
    grid = gridFactory,
}
local layoutCalls = {}
local layout = {}
for _, method in ipairs({ 'AtLeftIn', 'AtTopIn', 'ResetRight', 'ResetBottom', 'AtRightIn', 'AtBottomIn', 'ResetLeft', 'ResetTop', 'AtLeftTopIn', 'AtRightTopIn', 'SetDimensions', 'AtCenterIn' }) do
    layout[method] = function(...)
        table.insert(layoutCalls, { method = method, args = { ... } })
    end
end
layout.SetDimensions = function(value, width, height) value.width, value.height = width, height end
local uiUtil = {
    UIFile = function(path) return 'ui:' .. path end,
    SkinnableFile = function(path) return 'skin:' .. path end,
}

local function loadModule(path)
    local module = setmetatable({
        import = function(name) error('unexpected import: ' .. name) end,
        unpack = unpack or table.unpack,
    }, { __index = _G })
    assert(loadfile(path, 't', module))()
    return module
end
local modelModule = loadModule('../mods/ClaretCore/modules/OrdersPanelModel.lua')
local shellModule = loadModule('../mods/ClaretCore/modules/OrdersPanelShell.lua')
local catalogModule = loadModule('../mods/ClaretCore/modules/OrdersCatalog.lua')
local catalog = catalogModule.Create()
assert(catalog:RegisterExtension('Mod_CustomOrder', {
    helpText = 'custom_order', bitmapId = 'mod-custom', preferredSlot = 14,
    behaviorKey = 'ModOrderBehavior',
}))
local definitions = catalog:GetDefinitions()
local model = modelModule.Create({
    definitions = definitions,
    commonOrder = catalog:GetCommonIds(),
    firstAltSlot = 8,
    totalSlots = 14,
})

local initial = {
    availableOrders = {
        'RULEUCC_Move', 'RULEUCC_Stop', 'RULEUCC_Overcharge', 'RULEUCC_Transport', 'RULEUCC_Nuke',
    },
    availableToggles = { 'RULEUTC_ShieldToggle', 'RULEUTC_ProductionToggle', 'Mod_CustomOrder' },
    checkboxStates = {
        RULEUCC_Move = { checked = true, mixed = true },
        RULEUTC_ShieldToggle = true,
    },
}
assert(model:SetSnapshot(initial))
local parent = control('shared-order-cluster')
local clickCalls, hoverCalls = {}, {}
local panel = shellModule.Create(parent, {
    onClick = function(data, modifiers, button)
        table.insert(clickCalls, { data = data, modifiers = modifiers, button = button })
    end,
    onHover = function(data, entering, button) table.insert(hoverCalls, { data = data, entering = entering, button = button }) end,
}, {
    factories = factories,
    uiUtil = uiUtil,
    layoutHelpers = layout,
    gameCommon = { iconWidth = 50, iconHeight = 50 },
    layoutName = 'mini',
})

panel:SetOrders(model:GetItems())
local move = panel.orderById.RULEUCC_Move
local stop = panel.orderById.RULEUCC_Stop
local patrol = panel.orderById.RULEUCC_Patrol
local overcharge = panel.orderById.RULEUCC_Overcharge
local transport = panel.orderById.RULEUCC_Transport
local nuke = panel.orderById.RULEUCC_Nuke
local shield = panel.orderById.RULEUTC_ShieldToggle
local production = panel.orderById.RULEUTC_ProductionToggle
local extension = panel.orderById.Mod_CustomOrder
assert(move and stop and overcharge and transport and nuke and shield and production and extension)
for _, id in ipairs(catalog:GetCommonIds()) do
    assert(panel.orderById[id] and panel.orderById[id]._data.common,
        'catalog common ID is preserved through the model and shell: ' .. id)
end
assert(move.ID == 'RULEUCC_Move' and move._data.id == 'RULEUCC_Move')
assert(move.checked and move.silent and move.mixedModeIcon,
    'normalized checkbox checked/mixed state reaches a silent FAF control update')
assert(not move.disabled and not stop.disabled and patrol.disabled,
    'common order availability maps to enabled/disabled controls')
assert(overcharge.row == 2 and overcharge.col == 1 and transport.row == 2 and transport.col == 2
    and nuke.row == 2 and nuke.col == 3 and shield.row == 2 and shield.col == 4
    and production.row == 2 and production.col == 5 and extension.row == 2 and extension.col == 7,
    'native and extension slot conflicts resolve into stock Mini Grid coordinates')
assert(shield.checked and not shield.disabled and not production.disabled,
    'native toggle capability and checked state reach the rendered control')
assert(extension._data.id == 'Mod_CustomOrder', 'injected third-party IDs survive the model and shell')
assert(catalog:Get('RULEUTC_ShieldToggle').preferredSlot == 8
    and catalog:Get('RULEUTC_ProductionToggle').preferredSlot == 10
    and catalog:Get('RULEUCC_Nuke').preferredSlot == 10,
    'model overflow and panel placement do not mutate catalog source slots')

local modifiers = { Shift = true }
move.OnClick(move, modifiers)
extension.OnClick(extension, { Alt = true })
move.HandleEvent(move, { Type = 'MouseEnter' })
move.HandleEvent(move, { Type = 'MouseExit' })
assert(#clickCalls == 2 and clickCalls[1].data.id == 'RULEUCC_Move'
    and clickCalls[1].modifiers == modifiers and clickCalls[1].button == move)
assert(clickCalls[2].data.id == 'Mod_CustomOrder' and clickCalls[2].button == extension,
    'registered extension callback survives catalog-to-model-to-shell flow')
assert(#hoverCalls == 2 and hoverCalls[1].entering and not hoverCalls[2].entering)
assert(type(move._data.source.behaviorKey) == 'string'
    and type(move._data.source.behavior) ~= 'function', 'catalog exposes symbolic behavior only')

local oldControls = {}
for id, button in pairs(panel.orderById) do oldControls[id] = button end
assert(model:SetSnapshot({
    availableOrders = { 'RULEUCC_Stop' },
    availableToggles = {},
}))
panel:SetOrders(model:GetItems())
for _, button in pairs(oldControls) do
    assert(button.destroyed, 'capability update destroys previous control ' .. tostring(button.ID))
end
assert(panel.orderById.RULEUCC_Move.disabled and not panel.orderById.RULEUCC_Stop.disabled)
assert(panel.orderById.RULEUCC_Overcharge == nil and panel.orderById.RULEUCC_Transport == nil
    and panel.orderById.RULEUCC_Nuke == nil and panel.orderById.RULEUTC_ShieldToggle == nil
    and panel.orderById.RULEUTC_ProductionToggle == nil and panel.orderById.Mod_CustomOrder == nil,
    'stale dynamic orders disappear when capabilities are removed')

panel:SetLayout('right')
assert(panel.columns == 7 and panel.rows == 2 and panel.orderButtonGrid.width == 350 and panel.orderButtonGrid.height == 100)
local rightMove = panel.orderById.RULEUCC_Move
assert(rightMove.row == 1 and rightMove.col == 2 and panel.bracketRightMin)
local previousRightMove = rightMove
panel:SetLayout('left')
assert(previousRightMove.destroyed and panel.columns == 5 and panel.rows == 3)
assert(panel.orderButtonGrid.width == 250 and panel.orderButtonGrid.height == 150)
assert(not panel.bracketRightMin and panel.orderById.RULEUCC_Move.row == 1
    and panel.orderById.RULEUCC_Move.col == 2,
    'layout reflow retains native display slots and removes right-only frame pieces')

local beforeReplay = panel.orderById.RULEUCC_Stop
assert(model:SetSnapshot({
    availableOrders = { 'RULEUCC_Stop' },
    availableToggles = { 'Mod_CustomOrder' },
    replay = true,
}))
panel:SetOrders(model:GetItems())
assert(beforeReplay.destroyed and panel.orderById.RULEUCC_Stop.disabled
    and panel.orderById.Mod_CustomOrder.disabled,
    'replay mode disables every visible action including extension orders')

local ownedRoot = panel.root
panel:Destroy()
assert(ownedRoot.destroyed and parent.children[1] == nil)
assert(#clickCalls == 2 and panel.orderById.RULEUCC_Move == nil,
    'only the click callback was invoked and cleanup clears the presentation controls')
print('PASS: order model-to-shell integration, selection availability, state, replay and extensions')
