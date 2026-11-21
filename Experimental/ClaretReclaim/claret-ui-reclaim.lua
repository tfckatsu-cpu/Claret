table.getn = table.getn or function(list) return #list end
local controls, labels, callbacks, cleanups, logs = {}, {}, {}, {}, {}
local nativeUpdates, nativeAreas, nativeToggles, nativeGraph = 0, 0, 0, 0
local projections, unprojections, zoom, span, pan, pixel = 0, 0, 80, 1, 0, 1
local controlKey = false

local function property(value)
    return setmetatable({
        Set = function(self, nextValue) self.value, self.initialized = nextValue, true end,
        SetValue = function(self, nextValue) self.value = nextValue end,
        value = value,
    }, {
        __call = function(self)
            if type(self.value) == 'function' then return self.value() end
            return self.value
        end,
    })
end

local function control(parent)
    local c = {
        parent = parent, Left = property(100), Top = property(50), Right = property(900),
        Bottom = property(650), Height = property(12), Depth = property(10)
    }
    function c:DisableHitTest() self.passThrough = true end
    function c:SetNeedsFrameUpdate(value) self.updating = value end
    local function checkLayout(self)
        assert(self.Left.initialized and self.Top.initialized, 'MAUI needs anchored edges before visibility changes')
    end
    function c:Show() checkLayout(self); self.hidden = false end
    function c:Hide() checkLayout(self); self.hidden = true end
    function c:IsHidden() return self.hidden end
    function c:SetColor() end
    function c:SetDropShadow() end
    function c:SetFont(_, point) self.font = point; self.Height:SetValue(point * pixel) end
    function c:GetStringAdvance(value) return #value * self.font * pixel * 0.5 end
    function c:SetText(value) self.text = value end
    function c:Destroy()
        self.destroyed = true
        for _, child in ipairs(controls) do
            if child.parent == self then child:Destroy() end
        end
    end
    table.insert(controls, c)
    return c
end

local root, view = control(), control()
local world = { viewLeft = view }
local cellHeight
function view:Project(pos)
    projections = projections + 1
    if pos[1] == 128 and pos[3] == 128 then cellHeight = pos[2] end
    return { x = 100 + (pos[1] - pan) / span, y = 50 + pos[3] / span }
end

local modules = {
    ['/lua/maui/group.lua'] = { Group = control },
    ['/lua/maui/text.lua'] = { Text = function(parent)
        local label = control(parent)
        table.insert(labels, label)
        return label
    end },
    ['/lua/maui/layouthelpers.lua'] = {
        FillParent = function(c, parent)
            c.Left:Set(parent.Left())
            c.Top:Set(parent.Top())
        end,
        AtLeftTopIn = function(c, parent)
            c.Left:Set(parent.Left())
            c.Top:Set(parent.Top())
        end,
        GetPixelScaleFactor = function() return pixel end,
    },
    ['/lua/ui/game/worldview.lua'] = world,
    ['/mods/ClaretCore/modules/Theme.lua'] = {
        Colors = { hudMass = 'green' }, Fonts = { body = 'Nunito' }, Metrics = { caption = 12 },
    },
}

local function environment(fields)
    local env = setmetatable(fields or {}, { __index = _G })
    env._G = env
    env.import = function(path) return assert(modules[path], path) end
    return env
end

local function install(path, env)
    assert(loadfile('Experimental/ClaretReclaim/ClaretUI/' .. path, 't', env))()
    return env
end

local engineMath = {}
for key, value in pairs(math) do
    if key ~= 'huge' then engineMath[key] = value end
end
local feedEnv = environment({ math = engineMath })
local feed = install('modules/ReclaimFeed.lua', feedEnv)
modules['/mods/ClaretUI/modules/ReclaimFeed.lua'] = feed
local index = install('modules/ReclaimIndex.lua', environment())
modules['/mods/ClaretUI/modules/ReclaimIndex.lua'] = index
local native = install('hook/lua/ui/game/reclaim.lua', environment({
    UpdateReclaim = function() nativeUpdates = nativeUpdates + 1 end,
    SetPlayableArea = function() nativeAreas = nativeAreas + 1 end,
    ToggleReclaim = function() nativeToggles = nativeToggles + 1 end,
    OnCommandGraphShow = function() nativeGraph = nativeGraph + 1 end,
    ShowReclaim = function(show) world.viewLeft.ShowingReclaim = show end,
}))
modules['/lua/ui/game/reclaim.lua'] = native
local feature = install('modules/features/Reclaim.lua', environment({
    LOG = function(message) table.insert(logs, message) end,
    GetCamera = function() return {
        GetZoom = function() return zoom end,
        GetFocusPosition = function() return { pan, 0, 0 } end,
        SaveSettings = function() return { Pitch = 1, Heading = 0 } end,
    } end,
    GetFrame = function() return root end,
    SessionGetScenarioInfo = function() return { size = { 2048, 1024 } } end,
    IsDestroyed = function(c) return c.destroyed end,
    IsKeyDown = function(key) assert(key == 'Control'); return controlKey end,
    Vector = function(x, y, z) return { x, y, z } end,
    Vector2 = function(x, y) return { x, y } end,
    UnProject = function(_, p)
        unprojections = unprojections + 1
        return { pan + (p[1] - 100) * span, 0, (p[2] - 50) * span }
    end,
}))

local function option(value)
    return { Get = function() return value end, OnChanged = {} }
end
local minimum, scale = option(10), option(100)
local scope = {
    Own = function(_, c) return c end,
    Bind = function(_, event, callback) callbacks[event] = callback end,
    Defer = function(_, callback) table.insert(cleanups, callback) end,
}
local function point(mass, x, z, height) return { mass = mass, position = { x, height or 8, z } } end
local starting = {
    [1] = point(40, 100, 100), [2] = point(10, 100, 100), [3] = point(25, 220, 120, 17),
    [4] = point(1 / 0, 10, 10), [5] = point(25, 0 / 0, 10),
}
native.UpdateReclaim(starting)
starting[1].mass = 900
native.SetPlayableArea({ 0, 0, 2048, 1024 })
native.ToggleReclaim()
assert(nativeUpdates == 1 and nativeAreas == 1 and nativeToggles == 1, 'early hook chains to FAF')
assert(feed.Get(1).mass == 40, 'the feed owns its copy of each sync record')
assert(feed.State().count == 3, 'finite records work without math.huge and invalid numbers are ignored')
feature.Start(nil, scope, false, { reclaimMinimumMass = minimum, reclaimLabelScale = scale })
local driver = controls[3]
assert(driver.Left.initialized and driver.Top.initialized, 'frame driver has valid MAUI geometry')

local function frame(count)
    for _ = 1, count or 1 do
        projections, unprojections = 0, 0
        local created = #controls
        if driver.updating then driver:OnFrame(1 / 60) end
        assert(projections <= 160, 'projection budget includes the live and candidate passes')
        assert(unprojections == 0 or unprojections == 4, 'viewport reads only use its four corners')
        assert(#controls - created <= 8, 'control creation budget includes initial layer setup')
        local living = 0
        for _, label in ipairs(labels) do
            if not label.destroyed then living = living + 1 end
        end
        assert(living <= 129, 'hard pool cap, including the measurement control')
    end
end

local function shown(value)
    local found, count = nil, 0
    for _, label in ipairs(labels) do
        if not label.destroyed and not label.hidden and label.text then
            count = count + 1
            if label.text == value then found = label end
            assert(label.passThrough, 'world labels never capture game input')
        end
    end
    return found, count
end

feature.SetVisible(nil, true)
frame(3)
assert(projections == 0 and not driver.updating, 'closed overlay finishes indexing without projecting')
native.ToggleReclaim()
frame()
assert(shown('40') and shown('25') and not shown('10'), 'near labels prioritize mass when text overlaps')
local positionBeforePan = shown('40').Left()
pan = 7
frame()
assert(shown('40').Left() == positionBeforePan - 7, 'existing positions follow pan on the next frame')

native.UpdateReclaim({ [1] = point(11, 100, 100), [4] = point(30, 360, 130) })
frame()
assert(shown('11') and not shown('40') and shown('30'), 'partial and new entries update on a stationary camera')
native.UpdateReclaim({ [1] = false, [4] = point(30, 360, 130), [5] = point(30, 363, 130) })
frame(2)
assert(not shown('11') and shown('10') and shown('30').Left() == 447, 'remove and ties use the lowest ID')

native.ToggleReclaim()
frame()
assert(select(2, shown()) == 0 and projections == 0 and not driver.updating, 'closing stops projection')
local graphBefore = nativeGraph
native.OnCommandGraphShow(true)
frame()
assert(projections == 0, 'command graph alone does not show reclaim')
controlKey = true
frame()
assert(shown('30') and nativeGraph == graphBefore, 'Control with command graph previews Claret only')
native.OnCommandGraphShow(false)
frame()
assert(select(2, shown()) == 0, 'closing command graph clears the preview')

-- Zoomed-out cells sum the whole world cell and update from sync with no camera movement.
native.UpdateReclaim({ [5] = false })
zoom, span = 150, 2
native.ToggleReclaim()
frame(2)
assert(shown('Σ 35') and shown('Σ 30') and not shown('10'), 'far groups nearby records by world cell')
assert(cellHeight == 17, 'cell projects with a synced prop elevation and no simulation API')
native.UpdateReclaim({ [3] = false, [2] = point(13, 100, 100) })
zoom = 145
frame()
assert(shown('Σ 13') and not shown('Σ 35'), 'sum reflects deletions and zoom hysteresis holds')
cellHeight, pan = nil, pan + 1
frame()
assert(cellHeight == 17, 'existing cell anchor stays stable when its heaviest object disappears')
zoom, span = 139, 1
frame()
assert(shown('13') and shown('30') and not shown('Σ 13'), 'near mode returns below the exit threshold')
callbacks[minimum.OnChanged](nil, 20)
frame()
assert(shown('30') and not shown('13'), 'minimum mass change rebuilds filtering')
pixel = 1.5
callbacks[scale.OnChanged](nil, 150)
frame()
assert(shown('30').font == 18 and shown('30').Height() == 27, 'label setting and UI scale are each applied once')
callbacks[scale.OnChanged](nil, 100)
pixel = 1

-- A dense on-screen battlefield and a larger off-screen cluster exercise independent budgets.
local battle = {}
for i = 1, 2400 do
    battle[100 + i] = point(50 + i, 24 + (i % 75) * 10, 30 + math.floor(i / 75) * 15)
    battle[3000 + i] = point(10000 + i, 1600, 500)
end
native.UpdateReclaim(battle)
frame(85)
assert(select(2, shown()) == 128 and shown('2450'), 'dense field fills the pool in mass order')
assert(not shown('12400') and projections == 0, 'stationary near view reuses existing screen positions')
pan = pan + 8
frame()
assert(projections >= 128, 'moving a full pool reprojects all existing labels within the shared budget')

zoom, span = 400, 3
frame(25)
assert(select(2, shown()) < 128, 'nearly whole map uses aggregate labels instead of individual objects')
assert(projections == 0, 'stable overview also reuses screen positions')
pan = pan + 6
frame()
assert(projections == select(2, shown()), 'moving overview projects one point per shown cell')
native.SetPlayableArea({ 0, 0, 900, 600 })
frame(85)
local summed = 0
for _, label in ipairs(labels) do
    if not label.destroyed and not label.hidden and label.text then
        summed = summed + assert(tonumber(label.text:match('(%d+)$')))
    end
end
assert(summed == (51 + 2450) * 2400 / 2 + 30, 'playable-area change rebuilds totals without the off-map cluster')
local diagnostics = table.concat(logs, '\n')
assert(diagnostics:find('minimum=20 map=2048x1024 area=0,0,900,600 rejected mass=1 map=0 area=2400', 1, true),
    'a completed rebuild reports the actual threshold, dimensions and exclusions')
assert(diagnostics:find('indexing=false', 1, true), 'completed indexing makes the first settled search observable')

feature.SetVisible(nil, false)
assert(world.viewLeft.ShowingReclaim and not driver.updating, 'disabling an active Claret pin restores stock display')
native.ToggleReclaim()
assert(nativeToggles == 2, 'stock key is restored')
for _, cleanup in ipairs(cleanups) do cleanup() end
feedEnv.__active_mods = { { name = 'ReUI.Reclaim' } }
local before = #controls
feature.Start(nil, scope, false, {})
assert(#controls == before, 'active ReUI.Reclaim prevents a second renderer')
