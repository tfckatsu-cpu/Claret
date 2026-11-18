-- ConstructionItemsView callback and SpecialGrid recycling tests.
math.mod = math.mod or math.fmod
table.getn = table.getn or function(value) return #value end

local function Layout(control)
    local layout = {}
    function layout:AtCenterIn() return self end
    function layout:AtLeftTopIn() return self end
    function layout:AtLeftBottomIn() return self end
    function layout:AtBottomIn() return self end
    function layout:AtRightIn() return self end
    function layout:Fill() return self end
    function layout:Width(value) control.width = value; return self end
    function layout:Height(value) control.height = value; return self end
    return layout
end

local function NewControl(parent)
    local control = { parent = parent, width = 48, height = 48, visible = true, alpha = 1 }
    control.Depth = { Set = function() end }
    function control:DisableHitTest() end
    function control:SetTexture(value) self.texture = value end
    function control:SetSolidColor(value) self.solid = value end
    function control:SetNewTextures(up, down, over, disabled)
        self.textures = { up = up, down = down, over = over, disabled = disabled }
    end
    function control:SetOverrideTexture(value) self.overrideTexture = value end
    function control:SetOverrideEnabled(value) self.overrideEnabled = value end
    function control:SetAlpha(value) self.alpha = value end
    function control:SetNeedsFrameUpdate(value) self.needsFrameUpdate = value end
    function control:SetText(value) self.text = value end
    function control:SetColor(value) self.color = value end
    function control:SetDropShadow(value) self.dropShadow = value end
    control.BitmapWidth = function() return control.width end
    control.BitmapHeight = function() return control.height end
    function control:Enable() self.disabled = false end
    function control:Disable() self.disabled = true end
    function control:Show() self.visible = true end
    function control:Hide() self.visible = false end
    function control:Destroy() self.destroyed = true end
    return control
end

local Button = {}
function Button.HandleEvent(self, event)
    if (event.Type == 'ButtonPress' or event.Type == 'ButtonDClick') and self.OnClick then
        self:OnClick(event.Modifiers)
    end
    return true
end
local function NewButton(parent)
    local control = NewControl(parent)
    control.HandleEvent = Button.HandleEvent
    control.OnClick = function() control.baseClicked = true end
    return control
end
local function NewBitmap(parent)
    return NewControl(parent)
end

local function NewGrid()
    local grid = { top = 1, Items = {}, DisplayData = {}, _vertical = false }
    -- Native SpecialGrid's default CreateElement is a no-op.
    grid.CreateElement = function() end
    grid.SetControlToType = function(cell, kind)
        cell.kind = kind
        cell.OnClick = function() cell.baseClicked = true end
    end
    function grid:ClearItems()
        for index, item in pairs(self.Items) do item:Destroy(); self.Items[index] = nil end
    end
    function grid:CalcVisible()
        for index, data in ipairs(self.DisplayData) do
            local cell = self.Items[index]
            if not cell then cell = self.CreateElement(); self.Items[index] = cell end
            cell.Data = data
            self.SetControlToType(cell, data.type)
        end
    end
    function grid:Refresh(data)
        self.DisplayData = data
        self.top = 1
        self:CalcVisible()
    end
    return grid
end

local blueprints = {
    ueb0101 = { General = { Icon = 'air' }, Description = 'unit.air', StrategicIconName = 'air_icon' },
    ueb0201 = { General = { Icon = 'land' }, Description = 'unit.land' },
    ueb0301 = { General = { Icon = 'sea' }, Description = 'unit.sea' },
}
_G.__blueprints = blueprints
local diskChecks = 0
_G.DiskGetFileInfo = function(path)
    diskChecks = diskChecks + 1
    return string.find(path, 'missing', 1, true) == nil
end
local imported = {
    ['/lua/maui/button.lua'] = { Button = Button, FixableButton = NewButton },
    ['/lua/maui/bitmap.lua'] = { Bitmap = NewBitmap },
    ['/lua/ui/uiutil.lua'] = {
        bodyFont = 'mock-font',
        UIFile = function(path) return path end,
        CreateText = function(parent)
            local control = NewControl(parent)
            return control
        end,
    },
}
local module = setmetatable({}, { __index = _G })
module.ReUI = { UI = { FloorLayoutFor = function(control) return Layout(control) end } }
module.import = function(path)
    if imported[path] then return imported[path] end
    error('unexpected import: ' .. path)
end
assert(loadfile('../mods/ClaretCore/modules/ConstructionItemsView.lua', 't', module))()
assert(type(module.Create) == 'function', 'FAF module import exports global Create')

local clicks, rollovers = {}, {}
local grid = NewGrid()
local oldCreate, oldSetter = grid.CreateElement, grid.SetControlToType
local view = module.Create(grid, {
    OnClick = function(data, modifiers) table.insert(clicks, { data = data, modifiers = modifiers }) end,
    OnRollover = function(data, entering) table.insert(rollovers, { data = data, entering = entering }) end,
})

local data = {
    { type = 'item', id = 'ueb0101' },
    { type = 'unitstack', id = 'ueb0201', units = { {}, {} }, lowFuel = true },
    { type = 'queuestack', id = 'ueb0301', count = 4 },
    { type = 'enhancementqueue', unitID = 'ueb0101', icon = 'enhancement_icon', name = 'Queued upgrade' },
    { type = 'enhancement', unitID = 'ueb0101', icon = 'enhancement_icon', enhTable = { Name = 'Upgrade' }, Selected = true },
    { type = 'templates', template = { icon = 'ueb0201', name = 'Template', key = 65 } },
    { type = 'spacer' },
    { type = 'arrow' },
}
grid:Refresh(data)
assert(grid.Items[1].width == 48 and grid.Items[1].height == 48,
    'unit buttons use the stock 48px size')
assert(grid.Items[1].Icon.texture == '/icons/units/ueb0101_icon.dds',
    'unit icon uses the unit-specific FAF resource')
assert(diskChecks > 0, 'resource lookup uses FAF global DiskGetFileInfo')
assert(grid.Items[1].StratIcon.texture == '/textures/ui/common/game/strategicicons/air_icon_rest.dds',
    'blueprint strategic icon is shown when available')
assert(grid.Items[2].Count.text == '2' and grid.Items[2].LowFuel.alpha == 0.25,
    'unitstack count and low-fuel state are rendered')
assert(grid.Items[3].Count.text == '4', 'queuestack count is rendered')
assert(string.find(grid.Items[4].textures.up, '/game/uef-enhancements/', 1, true),
    'enhancement queue selects the faction texture resources')
assert(grid.Items[5].overrideEnabled
    and string.find(grid.Items[5].overrideTexture, '_btn_sel.dds', 1, true),
    'selected enhancement uses its selected state')
assert(grid.Items[6].Count.text == 'A' and grid.Items[6].BuildKey == 65,
    'template key is rendered and retained')
assert(grid.Items[7].width == 20 and grid.Items[7].height == 48,
    'horizontal spacer has stock dimensions')
assert(grid.Items[8].width == 20 and grid.Items[8].height == 48,
    'horizontal arrow has stock dimensions')
grid._vertical = true
grid:Refresh({ { type = 'spacer' }, { type = 'arrow' } })
assert(grid.Items[1].width == 48 and grid.Items[1].height == 20
    and grid.Items[2].width == 48 and grid.Items[2].height == 20,
    'spacer and arrow adopt stock vertical dimensions')
grid._vertical = false
grid:Refresh(data)

local modifiers = { Shift = true }
grid.Items[1]:HandleEvent({ Type = 'ButtonPress', Modifiers = modifiers })
assert(clicks[1].data == data[1] and clicks[1].modifiers == modifiers,
    'click callback receives data and modifiers without issuing commands')
grid.Items[1]:HandleEvent({ Type = 'MouseEnter' })
grid.Items[1]:HandleEvent({ Type = 'MouseExit' })
assert(rollovers[1].data == data[1] and rollovers[1].entering == true
    and rollovers[2].entering == false, 'rollover callback reports enter and exit')

local recycled = grid.Items[2]
grid:Refresh({ { type = 'item', id = 'ueb0201' }, { type = 'spacer' } })
assert(recycled.Count.text == '' and recycled.StratIcon.solid == '00000000'
    and recycled.LowFuel.alpha == 0 and not recycled.LowFuel.needsFrameUpdate,
    'reused controls clear count, strategic icon and low-fuel state')
assert(recycled.width == 20 and recycled.height == 48,
    'recycled unit button adopts spacer dimensions')
assert(grid.Items[1].Count.text == '', 'item rendering clears stale stack counts')

grid:Refresh({
    { type = 'item', id = 'ueb0201' },
    { type = 'spacer' },
    { type = 'queuestack', id = 'ueb0301', count = 3 },
    { type = 'enhancementqueue', unitID = 'ueb0101', icon = 'enhancement_icon', name = 'Queued' },
    { type = 'item', id = 'ueb0101' },
    { type = 'unitstack', id = 'ueb0201', units = { {} } },
    { type = 'spacer' },
    { type = 'arrow' },
})
assert(not grid.Items[5].overrideEnabled and grid.Items[5].Count.text == '',
    'item rendering clears selected enhancement override and key/count label')
assert(grid.Items[6].Count.text == '' and grid.Items[6].LowFuel.alpha == 0,
    'unitstack rendering clears template key and previous fuel overlay')

local unadaptedFactory = { kind = 'factory', id = 'ueb0301', count = 5 }
grid:Refresh({ unadaptedFactory })
assert(grid.Items[1].kind == nil,
    'model kind=factory is not silently treated as native type=queuestack')
grid:Refresh({ { type = 'external' } })
assert(grid.Items[1].kind == 'external', 'unsupported types delegate to the prior renderer')
local externalDisplay = grid.DisplayData
assert(view:Destroy(), 'renderer restores prior callbacks when an external type is displayed')
assert(grid.CreateElement == oldCreate and grid.SetControlToType == oldSetter,
    'prior grid handlers are restored')
assert(grid.DisplayData == externalDisplay and grid.Items[1].kind == 'external',
    'destroy preserves unrelated data and its rendered control')

local factoryData = { kind = 'factory', id = 'ueb0301', count = 5 }
local modelGrid = NewGrid()
local modelClick
local modelView = module.Create(modelGrid, {
    AdaptData = function(value)
        if value.kind == 'factory' then
            return { type = 'queuestack', id = value.id, count = value.count }
        elseif value.kind == 'enhancement' then
            return { type = 'enhancementqueue', unitID = value.unitID, icon = value.icon, name = value.name }
        end
    end,
    OnClick = function(value) modelClick = value end,
})
local modelEnhancement = { kind = 'enhancement', unitID = 'ueb0101', icon = 'enhancement_icon', name = 'Model upgrade' }
modelGrid:Refresh({ factoryData, modelEnhancement })
assert(modelGrid.Items[1].Count.text == '5', 'explicit adapter converts factory queue model data')
assert(string.find(modelGrid.Items[2].textures.up, '/game/uef-enhancements/', 1, true),
    'explicit adapter converts model enhancement data')
modelGrid.Items[1].OnClick(modelGrid.Items[1], { Shift = true })
assert(modelClick == factoryData, 'adapter leaves callback payload in original model form')
assert(modelView:Destroy(), 'adapted renderer cleans up its owned display')

local ownedGrid = NewGrid()
local ownedView = module.Create(ownedGrid, {})
ownedGrid:Refresh({ { type = 'item', id = 'ueb0101' } })
assert(ownedView:Destroy(), 'renderer restores prior callbacks after its own display')
assert(#ownedGrid.DisplayData == 0, 'destroy clears its owned display before restoring callbacks')

print('PASS: construction items render types, callbacks, recycling and safe handler restoration')
