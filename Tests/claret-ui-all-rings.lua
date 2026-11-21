-- Exercise the FAF cursor and native rendering entry points through small stubs.
table.getn = table.getn or function(items) return #items end
local source = '../mods/ClaretUI/modules/features/'
local data
local registered = {}
local viewApi = {
    GetWorldViews = function() return registered end,
    RegisterWorldView = function(view) registered[view._cameraName] = view end,
    UnregisterWorldView = function(view) registered[view._cameraName] = nil end,
}
local enhancements = {}
local command, rollover, selection, keys, draws = {}, nil, {}, {}, {}
local cursor = { 100, 0, 200 }
local styles = setmetatable({}, {
    __index = function() return { NormalColor = '00ffffff', Outer = { 0.04 }, Type = 1 } end,
})
function import(path)
    if path == '/lua/ui/game/rangeoverlayparams.lua' then return { RangeOverlayParams = styles } end
    if path == '/lua/enhancementcommon.lua' then
        return { GetEnhancements = function(id) return enhancements[id] end }
    end
    if path == '/lua/ui/game/commandmode.lua' then return { GetCommandMode = function() return command end } end
    if path == '/lua/ui/game/worldview.lua' then return viewApi end
    if path == '/mods/ClaretUI/modules/features/AllRingsData.lua' then return data end
    error('Unexpected import: ' .. path)
end

categories = { REPAIR = 1, RECLAIM = 2, xrl0403 = 4, ENGINEER = 8, FACTORY = 16 }
function EntityCategoryContains(category, unit) return unit.categories[category] end
function Vector(x, y, z) return { x, y, z } end
function GetSelectedUnits() return selection end
function GetMouseWorldPos() return cursor end
function GetRolloverInfo() return rollover end
function IsKeyDown(key) return keys[key] end
function IsDestroyed() return false end
function UI_DrawCircle(position, radius) table.insert(draws, { position = position, radius = radius }) end
ReUI = { Core = { Hook = function(path, key, callback) viewApi[key] = callback(viewApi[key]) end } }

local env = setmetatable({}, { __index = _G })
assert(loadfile(source .. 'AllRingsData.lua', 't', env))()
data = env
local rings = setmetatable({}, { __index = _G })
assert(loadfile(source .. 'AllRings.lua', 't', rings))()
rings.Install()

local function NewView(name)
    local view = { _cameraName = name, CursorOverWorld = true, cursorCalls = 0 }
    function view:OnUpdateCursor() self.cursorCalls = self.cursorCalls + 1 end
    function view:IsHidden() return false end
    function view:AddShape(shape, key) self.shape, self.shapeKey = shape, key end
    function view:RemoveShape(key) assert(self.shapeKey == key); self.shape = nil end
    return view
end
local world = NewView('WorldCamera')
local baseCursor = world.OnUpdateCursor
viewApi.RegisterWorldView(world)
local callbacks = {}
local scope = {}
function scope:Defer(callback) table.insert(callbacks, callback) end
function scope:Bind(event, callback)
    event.callback = callback
    self:Defer(function() event.callback = nil end)
end

local options = {}
for _, key in ipairs({
    'ringsDirectFire', 'ringsIndirectFire', 'ringsAntiAir', 'ringsAntiNavy', 'ringsCountermeasure',
    'ringsRadar', 'ringsSonar', 'ringsOmni', 'ringsCounterIntel', 'ringsActualBuild', 'ringsMinimap',
    'ringSelectionKey', 'ringBuildKey',
}) do
    local option = { value = true, OnChanged = {} }
    function option:Get() return self.value end
    function option:Set(value)
        self.value = value
        self.OnChanged.callback()
    end
    options[key] = option
end
options.ringsActualBuild.value = false
options.ringsMinimap.value = false
options.ringSelectionKey.value = 'CONTROL'
options.ringBuildKey.value = 'SHIFT'
local bp = {
    BlueprintId = 'url0001',
    Weapon = { { RangeCategory = 'UWRC_DirectFire', Label = 'RightRipper', MaxRadius = 22 } },
    Intel = { RadarRadius = 10 },
    Enhancements = { Gun = { NewMaxRadius = 30, NewRadarRadius = 15 } },
    Economy = { MaxBuildDistance = 10 },
    Footprint = { SizeX = 2, SizeZ = 3 },
}
__blueprints = { url0001 = bp, target = { Physics = { SkirtSizeX = 4, SkirtSizeZ = 6 } } }
local builder = { categories = { [7] = true, [24] = true } }
function builder:GetBlueprint() return bp end
function builder:GetEntityId() return 17 end
function builder:GetInterpolatedPosition() return { 12, 0, 35 } end
function builder:GetCommandQueue() return { { type = 'Move', position = { 28.2, 0, 40.7 } } } end

local function Render(view)
    draws = {}
    view.shape:Render()
    return draws
end
local function AtRadius(items, radius)
    for _, ring in ipairs(items) do if ring.radius == radius then return ring.position end end
end

rings.Start(rings, scope, false, options)
assert(world.shape == nil, 'disabled feature must not attach a renderer')
rings.SetVisible(rings, true)
local minimap = NewView('MiniMap')
viewApi.RegisterWorldView(minimap)
keys.CONTROL = true
rollover = { blueprintId = 'url0001' }
world:OnUpdateCursor()
assert(world.cursorCalls == 1 and AtRadius(Render(world), 22) == cursor)
assert(#Render(minimap) == 0, 'minimap is disabled by default')
options.ringsMinimap:Set(true)
assert(AtRadius(Render(minimap), 10) == cursor, 'minimap shares the active preview')
options.ringsDirectFire:Set(false)
assert(not AtRadius(Render(world), 22), 'filters take effect without reopening the view')
options.ringsDirectFire:Set(true)

selection = { builder }
world:OnUpdateCursor()
assert(AtRadius(Render(world), 22) == cursor and not AtRadius(draws, 12), 'CTRL attack works independently of SHIFT build')
keys = { SHIFT = true }
world:OnUpdateCursor()
assert(AtRadius(Render(world), 12) == cursor and not AtRadius(draws, 22), 'SHIFT build works independently of CTRL attack')
options.ringSelectionKey:Set('SHIFT')

keys = { SHIFT = true }
selection = { builder, builder }
rollover = nil
enhancements[17] = { GunSlot = 'Gun' }
world:OnUpdateCursor()
assert(#Render(world) == 3 and AtRadius(draws, 30) == cursor and AtRadius(draws, 15) == cursor)
assert(AtRadius(draws, 12) == cursor, 'simple build preview follows the cursor')
enhancements[17] = {}
world:OnUpdateCursor()
assert(AtRadius(Render(world), 22) == cursor and not AtRadius(draws, 30), 'upgrade sync updates cached ranges')

command = { 'build', { name = 'target' } }
options.ringsActualBuild:Set(true)
world:OnUpdateCursor()
local queued = AtRadius(Render(world), 19)
assert(#draws == 1 and queued[1] == 28.5 and queued[3] == 40.5, 'build preview uses target skirt and queued position')
command = {}
keys = { [18] = true }
world:OnUpdateCursor()
assert(#Render(world) == 1 and AtRadius(draws, 28) == cursor, 'Alt shows the reclaim radius')
world.CursorOverWorld = false
assert(#Render(world) == 0 and #Render(minimap) == 0, 'leaving the world clears the preview')
rings.SetVisible(rings, false)
assert(#Render(world) == 0, 'disabling clears the overlay immediately')
for index = #callbacks, 1, -1 do callbacks[index]() end
assert(world.OnUpdateCursor == baseCursor and world.shape == nil and minimap.shape == nil, 'scope disposal removes hooks and shapes')
print('PASS: All Rings previews, filters, upgrades, minimap and cleanup')
