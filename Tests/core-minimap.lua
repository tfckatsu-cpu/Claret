local function option(value)
    local listeners = {}
    local result = { value = value, OnChanged = {} }
    function result:Get() return self.value end
    function result:Set(nextValue)
        self.value = nextValue
        for _, callback in ipairs(listeners) do callback() end
    end
    function result.OnChanged:Add(callback) table.insert(listeners, callback) end
    function result.OnChanged:Remove(callback)
        for i, entry in ipairs(listeners) do if entry == callback then table.remove(listeners, i); return end end
    end
    return result
end
local function decoration()
    return { SetAlpha = function(self, value) self.alpha = value end }
end
local display = decoration()
display._windowGroup = decoration()
function display:IsHidden() return self.hidden == true end
function display:Hide() self.hidden = true end
function display:Show() self.hidden = false end
local view = {}
for _, key in ipairs({'GlowTL','GlowTR','GlowBL','GlowBR','GlowL','GlowR','GlowT','GlowB',
        'DragTL','DragTR','DragBL','DragBR'}) do view[key] = decoration() end
local minimap = { controls = { displayGroup = display, miniMap = view } }
local saved = true
local zoom = 500
local game = { gameUIHidden = false }
local ticker
local env = setmetatable({
    SessionGetScenarioInfo = function() return {size = {512, 512}} end,
    GetCamera = function() return { GetZoom = function() return zoom end } end,
    import = function(path)
        if path == '/lua/ui/game/minimap.lua' then return minimap end
        if path == '/lua/user/prefs.lua' then return { GetFromCurrentProfile = function() return saved end } end
        if path == '/lua/ui/game/gamemain.lua' then return game end
        if path == '/lua/maui/group.lua' then return { Group = function()
            ticker = { DisableHitTest = function() end, Destroy = function(self) self.destroyed = true end,
                SetNeedsFrameUpdate = function(self, enabled) self.updates = enabled end }
            return ticker
        end } end
        error('unexpected import: ' .. path)
    end,
}, {__index = _G})
assert(loadfile('../mods/ClaretCore/modules/Minimap.lua', 't', env))()
local auto, border = option(false), option(false)
local controller = env.Create(auto, border)
local stop = controller:Start({})
assert(not ticker.updates and not display:IsHidden(), 'disabled auto-hide must not poll or change visibility')
assert(display._windowGroup.alpha == nil, 'disabled border option must not alter other minimap presentation')
auto:Set(true)
zoom = 700
controller:Update()
assert(display:IsHidden() and saved, 'zoom hides the map without changing the user preference')
saved = false
controller:ManualToggle()
zoom = 400
controller:Update()
assert(display:IsHidden(), 'a manually closed map stays closed after zooming in')
saved = true
display:Show()
controller:ManualToggle()
assert(not display:IsHidden(), 'the user can open the map again')
zoom = 700
controller:Update()
auto:Set(false)
assert(not display:IsHidden() and not ticker.updates, 'disabling auto-hide restores an automatically hidden map')
border:Set(true)
assert(display._windowGroup.alpha == 0 and view.DragTL.alpha == 0, 'border option hides window decorations')
controller:LayoutChanged()
border:Set(false)
assert(display._windowGroup.alpha == 1 and view.DragTL.alpha == 1, 'turning off border option restores decorations')
stop()
assert(ticker.destroyed, 'session cleanup destroys the update control')
print('PASS: minimap visibility, manual override, border and cleanup')
