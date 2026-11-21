table.getn = table.getn or function(list) return #list end
local controls, markers, callbacks, cleanups = {}, {}, {}, {}
local projections, idleReads, selections = 0, 0, 0
local unitsById, selectable = {}, {}
local selected = { 'player selection' }
local army, zoom, scale = 1, 40, 1
local ignoreSelection, commandMode, capture = false, false, false
local function property(value)
    return setmetatable({
        value = value,
        writes = 0,
        Set = function(self, nextValue) self.value = nextValue end,
        SetValue = function(self, nextValue)
            self.value, self.writes = nextValue, self.writes + 1
        end,
    }, {
        __call = function(self)
            if type(self.value) == 'function' then return self.value() end
            return self.value
        end,
    })
end
local function control(parent)
    local c = {
        parent = parent, Left = property(100), Top = property(50),
        Width = property(1600), Height = property(900), Depth = property(10),
    }
    function c:DisableHitTest() self.passThrough = true end
    function c:SetNeedsFrameUpdate(value) self.updating = value end
    function c:Show() self.hidden = false end
    function c:Hide() self.hidden = true end
    function c:IsHidden() return self.hidden end
    function c:SetTexture(path) self.texture = path end
    function c:SetColorMask(color) self.color = color end
    function c:SetAlpha(alpha) self.alpha = alpha end
    function c:Destroy()
        self.destroyed = true
        for _, child in ipairs(controls) do
            if child.parent == self then child:Destroy() end
        end
    end
    table.insert(controls, c)
    return c
end
local function unit(id, owner, tier, excluded)
    local u = { point = { x = id + 12, y = 100 }, idle = true, army = owner }
    function u:IsDead() return self.dead end
    function u:IsInCategory(category)
        return category == 'ENGINEER' or category == 'TECH' .. tier or category == excluded
    end
    function u:IsIdle() idleReads = idleReads + 1; return self.idle end
    function u:GetArmy() return self.army end
    function u:GetEntityId() return id end
    unitsById[id] = u
    table.insert(selectable, u)
    return u
end

local root, view = control(), control()
local world = { viewLeft = view }
function view:GetScreenPos(u) projections = projections + 1; return u.point end
local modules = {
    ['/lua/maui/bitmap.lua'] = { Bitmap = function(parent)
        local marker = control(parent)
        table.insert(markers, marker)
        return marker
    end },
    ['/lua/maui/group.lua'] = { Group = control },
    ['/lua/maui/layouthelpers.lua'] = { GetPixelScaleFactor = function() return scale end, FillParent = function() end },
    ['/lua/ui/game/gamemain.lua'] = { SetIgnoreSelection = function(value) ignoreSelection = value end },
    ['/lua/ui/game/commandmode.lua'] = { GetCommandMode = function() return { commandMode } end },
    ['/lua/ui/game/worldview.lua'] = world,
    ['/mods/ClaretCore/modules/Theme.lua'] = { Colors = { hudDamage = 'red', hudValue = 'white' } },
}
local camera = {
    GetMinZoom = function() return 10 end,
    GetMaxZoom = function() return 110 end,
    GetZoom = function() return zoom end,
}
local gameTime = 0
local env = setmetatable({
    GetGameTimeSeconds = function() return gameTime end,
    import = function(path) return assert(modules[path], 'unexpected import ' .. path) end,
    GetFrame = function() return root end,
    GetCamera = function() return camera end,
    GetFocusArmy = function() return army end,
    GetInputCapture = function() return capture end,
    GetSelectedUnits = function() return selected end,
    GetUnitById = function(id) return unitsById[id] end,
    UISelectionByCategory = function(category, add, inView)
        assert(category == 'ENGINEER' and not add and not inView and ignoreSelection, 'discovery selects engineers silently across the map')
        selections = selections + 1
        selected = selectable
    end,
    SelectUnits = function(previous)
        assert(ignoreSelection, 'selection is restored before lifting suppression')
        selected = previous
    end,
    IsDestroyed = function(c) return c.destroyed end,
    AddOnSyncCallback = function(callback, key) callbacks[key] = callback end,
    RemoveOnSyncCallback = function(key) callbacks[key] = nil end,
    WARN = function(message) error(message) end,
}, { __index = _G })

assert(loadfile('../mods/ClaretUI/modules/features/EngineerIndicators.lua', 't', env))()
local optionCallbacks = {}
local function option(value)
    return { Get = function() return value end, OnChanged = {} }
end
local hideFar, markerScale, optimize = option(true), option(100), option(false)
local idleOnly = option(false)
local scope = {
    Own = function(_, c) return c end,
    Bind = function(_, event, callback) optionCallbacks[event] = callback end,
    Defer = function(_, callback) table.insert(cleanups, callback) end,
}
local originalSelection = selected
local first = unit(1, 1, 1)
local second = unit(2, 1, 2)
second.point.x = -10
unit(3, 2, 3)
unit(4, 1, 3, 'COMMAND')
unit(5, 1, 3, 'SUBCOMMANDER')
env.Start(nil, scope, false, {
    engineerIndicatorsHideFar = hideFar, engineerIndicatorsScale = markerScale, engineerIndicatorsOptimize = optimize,
    engineerIndicatorsIdleOnly = idleOnly,
})
local driver = controls[3]
env.SetVisible(nil, true)
local _, sync = next(callbacks)
local function frame(delta) driver:OnFrame(delta or 1 / 60) end

frame()
assert(selections == 0 and selected == originalSelection, 'startup leaves the player selection untouched')
gameTime = 15
commandMode = 'build'
frame()
assert(selections == 0, 'active command mode defers roster discovery')
commandMode, capture = false, true
frame()
assert(selections == 0, 'captured input defers roster discovery')
capture = false
frame()
assert(selections == 1 and selected == originalSelection and not ignoreSelection, 'discovery restores player selection')
assert(#markers == 1 and projections == 2, 'only own tiered engineers are projected and only visible ones get a marker')
local marker = markers[1]
assert(marker.passThrough and not marker.hidden and marker.color == 'red', 'idle marker is visible and passes input through')
assert(marker.texture:match('tier%-1%.png$') and marker.Left() == 104
    and marker.Width() == 18 and marker.alpha == 1, 'unit tier, viewport offset and larger default size determine marker appearance')

local oldX = marker.Left()
first.point.x = 17
first.idle = false
frame()
assert(marker.Left() == oldX + 4, 'position follows the unit on the very next frame')
for _ = 1, 12 do frame() end
assert(marker.color == 'white', 'status sampling shows a busy engineer within a sweep')
local writes = marker.Left.writes
frame()
assert(marker.Left.writes == writes, 'stationary markers do not rewrite layout')

first.point.x, second.point.x = -10, 25
frame()
assert(#markers == 1 and not marker.hidden and marker.texture:match('tier%-2%.png$'), 'one pan recycles the outgoing marker for the entering engineer')
scale = 1.5
frame()
assert(marker.Width() == 27 and marker.Height() == 27, 'marker dimensions use the current UI scale')
optionCallbacks[markerScale.OnChanged](nil, 150)
frame()
assert(marker.Width() == 41 and marker.Height() == 41 and #markers == 1, 'slider scales the same pooled marker without reallocating')
optionCallbacks[markerScale.OnChanged](nil, 500)
frame()
assert(marker.Width() == 27, 'malformed saved scale falls back to 100 percent')

for id = 6, 603 do unit(id, 1, 3) end
local updates = {}
for id = 6, 603 do updates[id] = {} end
sync({ UnitData = updates })
first.point.x = 20
frame()
assert(#markers == 25, 'allocation is limited to 24 new controls in a frame')
for _ = 1, 25 do frame() end
assert(#markers == 600, 'one control per engineer after all 600 become visible')
zoom = 70
frame(0.15)
assert(math.abs(marker.alpha - 0.5) < 0.001, 'marker opacity is half at the middle of the zoom band')
zoom = 75
frame()
assert(marker.alpha > 0 and marker.alpha < 0.5 and not marker.hidden, 'a zoom jump fades out over several frames')
frame(0.15)
projections, idleReads = 0, 0
frame()
assert(projections == 0 and idleReads == 0, 'fully hidden markers at 65% skip all per-engineer drawing and state work')
for _, c in ipairs(markers) do assert(c.hidden, 'all markers are hidden above the far-zoom threshold') end
second.idle = false
zoom = 65
frame()
assert(projections == 600 and #markers == 600 and marker.alpha > 0 and marker.alpha < 1, 'zooming in fades the pooled markers back in')
for _, c in ipairs(markers) do
    if c.texture:match('tier%-2%.png$') then
        assert(not c.hidden and c.color == 'white', 'return from far zoom displays the current colour')
    end
end
frame(0.15)
assert(marker.alpha == 1, 'markers are fully opaque again at 55% zoom')
optionCallbacks[hideFar.OnChanged](nil, false)
zoom = 110
projections = 0
frame()
assert(projections == 600 and marker.alpha == 1, 'user can keep labels at maximum zoom')

local function countMarkers(onlyShown)
    local count = 0
    for _, c in ipairs(markers) do
        if not c.destroyed and (not onlyShown or not c.hidden) then count = count + 1 end
    end
    return count
end
local function findMarkerFor(u)
    local x = math.floor(view.Left() + u.point.x - 27 / 2)
    for _, c in ipairs(markers) do
        if not c.hidden and not c.destroyed and c.Left() == x then return c end
    end
end
for _, u in pairs(unitsById) do u.idle = false end
frame(0.21)
optionCallbacks[optimize.OnChanged](nil, true)
frame()
assert(countMarkers(true) == 128, 'optimization immediately caps drawn controls when enabled on a full screen')
for _ = 1, 20 do frame() end
assert(countMarkers(false) == 128, 'optimization gradually frees surplus allocated controls')

local waiting, retained
for id = 10, 603 do
    local u = unitsById[id]
    if findMarkerFor(u) then
        retained = u
    else
        waiting = u
    end
end
assert(waiting and retained, 'the test has both admitted and waiting engineers')
local originalMarker = findMarkerFor(retained)
for _ = 1, 14 do
    projections = 0
    frame()
    assert(projections <= 188, 'stable optimized frames project at most 128 shown and 60 scan candidates')
end
assert(findMarkerFor(retained) == originalMarker and not findMarkerFor(waiting), 'equal-priority engineers keep their assigned controls')
waiting.idle = true
for _ = 1, 14 do
    projections = 0
    frame()
    assert(projections <= 212, 'optimized frames also bound position rechecks for newly admitted markers')
end
local promoted = findMarkerFor(waiting)
assert(promoted and promoted.color == 'red' and countMarkers(true) == 128,
    'an engineer without a marker gets priority when it becomes idle, even at the cap')
local previousX = promoted.Left()
waiting.point.x = waiting.point.x + 1
frame()
assert(promoted.Left() == previousX + 1, 'optimized markers still move every frame')

optionCallbacks[hideFar.OnChanged](nil, true)
zoom = 110
frame(0.15)
projections, idleReads = 0, 0
frame()
assert(projections == 0 and idleReads == 0 and countMarkers(true) == 0, 'optimized candidate scans stop at far zoom')
optionCallbacks[hideFar.OnChanged](nil, false)
for _ = 1, 14 do frame() end
assert(countMarkers(true) == 128, 'optimized scanning fills the pool again after leaving far zoom')

optionCallbacks[idleOnly.OnChanged](nil, true)
for _ = 1, 25 do frame() end
local idleMarker = findMarkerFor(waiting)
assert(idleMarker and countMarkers(true) == 1, 'idle-only mode shows only the single idle engineer in a group of 600')
waiting.idle = false
for _ = 1, 14 do
    frame()
    if idleMarker.alpha < 1 then break end
end
assert(not idleMarker.hidden and idleMarker.alpha > 0 and idleMarker.alpha < 1 and idleMarker.color == 'red',
    'an engineer starting work fades its red marker over several frames')
for _ = 1, 10 do frame() end
projections, idleReads = 0, 0
frame()
assert(countMarkers(true) == 0 and projections == 0 and idleReads > 0,
    'busy engineers have no position queries after fading, and the state scan continues')
waiting.idle = true
local returningMarker
for _ = 1, 14 do
    frame()
    returningMarker = findMarkerFor(waiting)
    if returningMarker then break end
end
assert(returningMarker and returningMarker.alpha > 0 and returningMarker.alpha < 1 and returningMarker.color == 'red',
    'an engineer becoming idle starts with a partially visible red marker')
local initialOpacity = returningMarker.alpha
frame()
assert(returningMarker.alpha > initialOpacity and returningMarker.alpha < 1, 'idle marker fades in over several frames')
for _ = 1, 10 do frame() end
assert(returningMarker.alpha == 1 and countMarkers(true) == 1, 'the returning marker reaches full opacity')
optionCallbacks[optimize.OnChanged](nil, false)
for _ = 1, 14 do frame() end
projections = 0
frame()
assert(projections == 1 and countMarkers(true) == 1, 'idle-only skips position queries independently of the marker limit')
optionCallbacks[idleOnly.OnChanged](nil, false)
for _ = 1, 21 do frame() end
assert(countMarkers(true) == 600, 'turning optimization off restores all markers')
sync({ ReleaseIds = { [2] = true } })
projections = 0
frame()
assert(projections == 599, 'release notification removes a stale unit from projection')
army = 2
frame()
assert(countMarkers(true) == 1 and countMarkers(false) == 600, 'switching the focused army clears the old markers and reuses the pool')
env.SetVisible(nil, false)
assert(not driver.updating and not next(callbacks), 'turning off stops frame and sync work')
for _, c in ipairs(markers) do assert(c.destroyed, 'turning off destroys the pooled controls') end
for _, cleanup in ipairs(cleanups) do cleanup() end
print('PASS: engineer indicators preserve selection, bound optimized position queries and fade idle markers in and out')
