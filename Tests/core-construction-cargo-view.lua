-- Cargo renderer integration with the FAF SpecialGrid contract.
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

local controls = {}
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
    function control:SetAlpha(value) self.alpha = value end
    function control:SetNeedsFrameUpdate(value) self.needsFrameUpdate = value end
    function control:Enable() self.disabled = false end
    function control:Disable() self.disabled = true end
    control.BitmapWidth = function() return control.width end
    control.BitmapHeight = function() return control.height end
    function control:Show() self.visible = true end
    function control:Hide() self.visible = false end
    function control:Destroy() self.destroyed = true end
    table.insert(controls, control)
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
    grid.CreateElement = function()
        local cell = Button(grid)
        cell.Icon = Bitmap(cell)
        cell.Count = NewControl(cell)
        cell.Count.SetText = function(self, value) self.text = value end
        cell.StratIcon = Bitmap(cell.Icon)
        cell.LowFuel = Bitmap(cell)
        cell.LowFuelIcon = Bitmap(cell.LowFuel)
        return cell
    end
    grid.SetControlToType = function(cell, kind)
        assert(kind ~= 'claretCargo', 'base renderer must never receive cargo data')
        cell.kind = kind
        if kind == 'queue' then
            cell.OnClick = function() cell.queueClicked = true end
            cell.Count:SetText('9')
            cell.StratIcon:SetSolidColor('ffffffff')
            cell.LowFuel:SetAlpha(0.25)
            cell.LowFuel:SetNeedsFrameUpdate(true)
        end
    end
    grid.Right = setmetatable({}, { __call = function() return grid.width end })
    grid.Right.OnDirty = function() grid:ClearItems() end

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
            item.left = (itemIndex - 1) * 48
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
    function grid:ScrollLines(lines)
        self.top = math.max(1, math.min(self.top + lines,
            table.getn(self.DisplayData) - table.getn(self.Items) + 1))
        self:CalcVisible()
    end
    function grid:SetupScrollControls(scrollMin, scrollMax, pageMin, pageMax)
        self._scrollMin, self._scrollMax = scrollMin, scrollMax
        self._pageMin, self._pageMax = pageMin, pageMax
        scrollMin.OnClick = function() self:ScrollLines(-1) end
        scrollMax.OnClick = function() self:ScrollLines(1) end
        pageMin.OnClick = function() self.top = 1; self:CalcVisible() end
        pageMax.OnClick = function()
            self.top = table.getn(self.DisplayData) - table.getsize(self.Items) + 1
            self:CalcVisible()
        end
    end
    function grid:SetToVertical(vertical)
        self.top = 1
        self._vertical = vertical
        self:ClearItems()
        self:CalcVisible()
    end
    return grid
end

local module = setmetatable({}, { __index = _G })
module.ReUI = { UI = { FloorLayoutFor = function(control) return Layout(control) end } }
_G.DiskGetFileInfo = function() return true end
module.import = function(path)
    if path == '/lua/maui/button.lua' then return { FixableButton = Button } end
    if path == '/lua/maui/bitmap.lua' then return { Bitmap = Bitmap } end
    if path == '/lua/ui/uiutil.lua' then
        return { UIFile = function(value) return value end }
    end
    error('unexpected import: ' .. path)
end
assert(loadfile('../mods/ClaretCore/modules/ConstructionCargoView.lua', 't', module))()
assert(type(module.Create) == 'function', 'FAF import exports global Create')

local cargo = {}
local toggled, ranged = {}, {}
local cargoState = {
    IsSelected = function(_, index) return cargo[index] and cargo[index].selected or false end,
    Toggle = function(_, index)
        table.insert(toggled, index)
        cargo[index].selected = not cargo[index].selected
    end,
    AddRange = function(_, index) table.insert(ranged, index) end,
    SetCargo = function(self, source)
        local result, seen = {}, {}
        for _, unit in ipairs(source or {}) do
            if not seen[unit] then seen[unit] = true; table.insert(result, unit) end
        end
        cargo = result
        self.cargo = result
    end,
}

local units = {}
for index = 1, 13 do
    units[index] = { GetBlueprint = function()
        return { BlueprintId = 'unit' .. index, General = { Icon = 'land' },
            StrategicIconName = index == 1 and 'cargo_strategic' or nil }
    end }
end

local grid = NewSpecialGrid(144)
grid:SetToVertical(true)
local scrollControls = { Button(grid), Button(grid), Button(grid), Button(grid) }
local originalCreateElement = grid.CreateElement
local originalSetControlToType = grid.SetControlToType
grid:SetupScrollControls(scrollControls[1], scrollControls[2], scrollControls[3], scrollControls[4])
local view = module.Create(NewControl(nil), cargoState, { grid = grid })
assert(view:Activate({ units[1], units[1], units[2] }), 'Activate initializes cargo view')
assert(#view.units == 2 and grid.DisplayData[1].unit == units[1]
    and grid.DisplayData[2].unit == units[2], 'SetUnits dedupes in the service index order')
assert(table.getsize(grid.Items) == 2 and grid.Items[1].width == 48,
    'SpecialGrid creates a one-row 48px cargo cell per visible item')
assert(scrollControls[2].OnClick ~= nil and scrollControls[4].OnClick ~= nil,
    'caller-owned dedicated controls remain connected to the supplied grid')

grid.Items[1].OnClick(grid.Items[1], {})
assert(toggled[1] == 1, 'ordinary click delegates the SpecialGrid data index to Toggle')
cargo[1].selected = true
view:Refresh()
assert(grid.Items[1].overrideEnabled and grid.Items[1].overrideTexture == grid.Items[1].textures.down,
    'selected cell forces the stock down texture')
cargo[1].selected = false
view:Refresh()
assert(not grid.Items[1].overrideEnabled, 'unselected cell allows normal hover texture')
grid.Items[2].OnClick(grid.Items[2], { Shift = true })
assert(ranged[1] == 2, 'Shift-click delegates to range selection')

view:SetUnits(units)
assert(table.getsize(grid.Items) == 3, 'visible row capacity is derived from the caller grid width')
grid:ScrollLines(1)
assert(grid.top == 2 and grid.Items[1].Data.index == 2,
    'SpecialGrid line scrolling advances the horizontal viewport')
grid:ScrollLines(-1)
assert(grid.top == 1 and grid.Items[1].Data.index == 1,
    'cargo state refresh retains the current SpecialGrid viewport')
grid._pageMax.OnClick(grid._pageMax)
assert(grid.top == 11 and grid.Items[1].Data.index == 11,
    'SpecialGrid page control jumps to the last visible row segment')
grid._pageMin.OnClick(grid._pageMin)
assert(grid.top == 1, 'SpecialGrid page control returns to the first items')

local queueData = {}
for index = 1, 7 do table.insert(queueData, { type = 'queue', id = 'queued-' .. index }) end
grid:Refresh(queueData)
assert(grid.Items[1].kind == 'queue' and grid.Items[1].queueClicked == nil,
    'non-cargo data delegates to the caller renderer')
grid.Items[1].OnClick(grid.Items[1])
assert(grid.Items[1].queueClicked, 'base queue click handler is restored on data-mode change')
grid:ScrollLines(2)
local queueDataReference = grid.DisplayData
local queueTop = grid.top
assert(view:Deactivate(), 'Deactivate restores the caller renderers')
assert(grid.CreateElement == originalCreateElement and grid.SetControlToType == originalSetControlToType,
    'only the view-owned renderer functions are restored')
assert(grid.DisplayData == queueDataReference and grid.Items[1].visible,
    'deactivation leaves active queue data and controls intact')
assert(grid.top == queueTop, 'deactivation preserves the unrelated queue viewport')
assert(grid._vertical, 'deactivation restores the original grid orientation')

local previousData = grid.DisplayData
assert(view:Activate({ units[1], units[2] }), 'view can be activated again')
assert(grid.DisplayData ~= previousData and grid.DisplayData[1].type == 'claretCargo',
    'reactivation switches the shared grid to cargo display data')
view:Deactivate(queueData)
assert(grid.DisplayData == queueData and grid.Items[1].kind == 'queue',
    'explicit deactivation data is rendered after restoring the caller implementation')
assert(grid._vertical, 'explicit data is installed before orientation is restored')

assert(view:Activate({ units[1], units[2] }), 'view can reactivate after queue mode')
assert(grid.Items[1].Count.text == '' and grid.Items[1].LowFuel.alpha == 0
    and not grid.Items[1].LowFuel.needsFrameUpdate,
    'cargo renderer clears stale queue count and low-fuel overlays')
assert(grid.Items[1].StratIcon.texture
    == '/textures/ui/common/game/strategicicons/cargo_strategic_rest.dds',
    'cargo renderer replaces queue strategic overlay with cargo unit icon')
assert(view:Deactivate(), 'passive deactivation clears this view-owned display')
assert(table.getn(grid.DisplayData) == 0, 'passive deactivation never leaves cargo data to base renderers')
assert(grid._vertical, 'passive deactivation restores vertical orientation safely')
grid:CalcVisible()
assert(table.getsize(grid.Items) == 0, 'later layout recalculation cannot render stale cargo rows')
view:Destroy()
assert(grid.CreateElement == originalCreateElement and grid.SetControlToType == originalSetControlToType,
    'Destroy restores handlers without destroying the caller-owned grid')

print('PASS: construction cargo uses FAF SpecialGrid renderer, viewport and queue coexistence contract')
