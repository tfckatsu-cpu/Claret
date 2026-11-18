-- Integration between real CargoSelection and a caller-owned SpecialGrid view.
math.mod = math.mod or math.fmod
table.getn = table.getn or function(value) return #value end
table.getsize = table.getsize or function(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function Layout(control)
    local layout = {}
    function layout:AtCenterIn() return self end
    function layout:Width(value) control.width = value; return self end
    function layout:Height(value) control.height = value; return self end
    return layout
end

local function NewControl(parent)
    local control = { parent = parent, visible = true, overrideEnabled = false, width = 48 }
    function control:DisableHitTest() end
    function control:SetTexture(texture) self.texture = texture end
    function control:SetSolidColor(color) self.solid = color end
    function control:SetNewTextures(up, down, over, disabled)
        self.textures = { up = up, down = down, over = over, disabled = disabled }
    end
    function control:SetOverrideTexture(texture) self.overrideTexture = texture end
    function control:SetOverrideEnabled(value) self.overrideEnabled = value end
    function control:Enable() self.disabled = false end
    function control:Disable() self.disabled = true end
    function control:Show() self.visible = true end
    function control:Hide() self.visible = false end
    function control:Destroy() self.destroyed = true end
    return control
end

local Button = function(parent)
    local button = NewControl(parent)
    button.OnClick = function() button.baseClicked = true end
    return button
end
local Bitmap = function(parent) return NewControl(parent) end
local function NewSpecialGrid(width)
    local grid = NewControl(nil)
    grid.width = width
    grid.top = 1
    grid.Items = {}
    grid.DisplayData = {}
    grid._vertical = false
    grid.CreateElement = function() return Button(grid) end
    grid.SetControlToType = function(cell, kind)
        assert(kind ~= 'claretCargo', 'base renderer must never receive cargo data')
        cell.kind = kind
        if kind == 'queue' then cell.OnClick = function() cell.queueClicked = true end end
    end
    function grid:ClearItems()
        for index, item in pairs(self.Items) do item:Destroy(); self.Items[index] = nil end
    end
    function grid:CalcVisible()
        local capacity = math.max(0, math.floor(self.width / 48))
        local itemIndex = 1
        for index = self.top, table.getn(self.DisplayData) do
            if itemIndex > capacity then break end
            local item = self.Items[itemIndex]
            if not item then item = self.CreateElement(); self.Items[itemIndex] = item end
            item.Data = self.DisplayData[index]
            item:Show()
            self.SetControlToType(item, item.Data.type)
            itemIndex = itemIndex + 1
        end
        for index = itemIndex, table.getsize(self.Items) do
            local item = self.Items[index]
            if item then item:Hide() end
        end
    end
    function grid:Refresh(data)
        self.top = 1
        self.DisplayData = data
        self:CalcVisible()
    end
    function grid:SetToVertical(vertical)
        self.top = 1
        self._vertical = vertical
        self:ClearItems()
        self:CalcVisible()
    end
    return grid
end

local sharedImport = function(path)
    if path == '/lua/maui/button.lua' then return { FixableButton = Button } end
    if path == '/lua/maui/bitmap.lua' then return { Bitmap = Bitmap } end
    if path == '/lua/ui/uiutil.lua' then
        return { UIFile = function(value) return value end }
    end
    error('unexpected import: ' .. path)
end

local selectionModule = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/CargoSelection.lua', 't', selectionModule))()
local viewModule = setmetatable({}, { __index = _G })
viewModule.ReUI = { UI = { FloorLayoutFor = function(control) return Layout(control) end } }
_G.DiskGetFileInfo = function() return true end
viewModule.import = sharedImport
assert(loadfile('../mods/ClaretCore/modules/ConstructionCargoView.lua', 't', viewModule))()

local a, b, c, d = {}, {}, {}, {}
local queued = {}
local added, removed = {}, {}
local view
local refreshCount = 0
local service = selectionModule.Create({
    add = function(unit) table.insert(added, unit) end,
    remove = function(unit) table.insert(removed, unit) end,
    isQueued = function(unit) return queued[unit] == true end,
    refresh = function()
        refreshCount = refreshCount + 1
        if view then view:Refresh() end
    end,
})
local function Unit(id)
    return { GetBlueprint = function() return { BlueprintId = id, General = { Icon = 'land' } } end }
end
a, b, c, d = Unit('a'), Unit('b'), Unit('c'), Unit('d')

local grid = NewSpecialGrid(240)
local baseCreateElement, baseSetControlToType = grid.CreateElement, grid.SetControlToType
view = viewModule.Create(NewControl(nil), service, { grid = grid })
assert(view:Activate({ a, b, c }), 'activation sets initial cargo data')
assert(refreshCount == 1, 'initial state update invokes one view callback')
assert(grid.DisplayData[1].unit == a and grid.Items[1].Data.index == 1,
    'cargo state and visible grid share index order')

local beforeAppend = refreshCount
assert(service:AppendNext(), 'hotkey append selects first available cargo')
assert(service:IsSelected(1), 'hotkey append updates service state')
assert(grid.Items[1].overrideEnabled and grid.Items[1].overrideTexture == grid.Items[1].textures.down,
    'state refresh updates the visible cell without recursion')
assert(refreshCount == beforeAppend + 1, 'append callback runs once')

grid.Items[2].OnClick(grid.Items[2], {})
assert(service:IsSelected(2) and added[2] == b, 'grid click delegates to the real Toggle method')
assert(grid.Items[2].overrideEnabled, 'toggle callback updates the visible cell')

queued[c] = true
assert(service:SetCargo({ a, b, c }), 'queue transition updates cargo state')
view:SetUnits({ a, b, c })
assert(service:IsSelected(3) and grid.Items[3].overrideEnabled,
    'queued cargo renders as selected')
assert(not service:Toggle(3), 'queued cargo cannot be manually toggled')
queued[c] = nil
assert(service:SetCargo({ a, b, c }), 'queue clear updates cargo state')
view:SetUnits({ a, b, c })
assert(not service:IsSelected(3) and not grid.Items[3].overrideEnabled,
    'queue clear restores the unselected cell state')

assert(service:Toggle(3), 'cargo can be selected after queue clears')
view:SetUnits({ a, b, c })
assert(service:Toggle(1), 'first cargo can be toggled off')
view:SetUnits({ a, b, c })
assert(service:SetCargo({ d, c, b, a }), 'reordered cargo updates service order')
view:SetUnits({ d, c, b, a })
assert(service:IsSelected(2) and grid.Items[2].Data.unit == c and grid.Items[2].overrideEnabled,
    'selection remains tied to unit identity after reorder')
assert(service:Toggle(4), 'previously unselected stale unit can be selected')
view:SetUnits({ d, c, b, a })

local removedBeforeStale = #removed
assert(service:SetCargo({ d, c, b }), 'stale cargo is removed')
view:SetUnits({ d, c, b })
assert(#removed == removedBeforeStale + 1 and removed[#removed] == a,
    'state removes ownership of stale cargo')
assert(grid.Items[1].Data.unit == d and service:IsSelected(2),
    'state callback and explicit SetUnits keep the view aligned')

local beforeCleanup = #removed
service:Destroy()
assert(#removed == beforeCleanup + 2, 'service cleanup removes remaining owned cargo')
assert(grid.SetControlToType ~= baseSetControlToType,
    'service callback during cleanup remains safe while cargo view is active')
view:Destroy()
assert(grid.CreateElement == baseCreateElement and grid.SetControlToType == baseSetControlToType,
    'view cleanup restores the caller-owned SpecialGrid renderers')
assert(not grid.destroyed, 'view does not destroy its caller-owned grid')
assert(table.getn(grid.DisplayData) == 0, 'destroy clears view-owned cargo display data')
grid:CalcVisible()
assert(table.getsize(grid.Items) == 0, 'layout recalculation after destroy has no stale cargo cells')

print('PASS: real cargo state integrates with caller-owned SpecialGrid lifecycle')
