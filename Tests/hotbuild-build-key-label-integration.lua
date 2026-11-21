-- Main hook integration with a stubbed ReUI keymap path; no engine calls.
table.getn = table.getn or function(value) return #value end

local function loadModule(path, env)
    env = env or setmetatable({}, { __index = _G })
    assert(loadfile(path, 't', env))()
    return env
end

local buildLabels = assert(loadfile('../mods/ClaretHotbuild/modules/BuildKeyLabels.lua'))()
local bindingData = {
    one = { entries = {
        { kind = 'blueprint', id = 'uel0002' },
        { kind = 'blueprint', id = 'ual0001' },
        { kind = 'action', id = 'claret.order.move' },
    } },
}
local assignments = {
    { key = 'W', modifiers = {}, ref = { kind = 'preset', id = 'one' }, foreign = false,
        linkedRef = { kind = 'composite', id = 'ctx1' } },
    { key = 'X', modifiers = {}, ref = { kind = 'preset', id = 'one' }, foreign = false },
    -- Duplicate map entry for the same chord must not create a third badge key.
    { key = 'W', modifiers = {}, ref = { kind = 'preset', id = 'one' }, foreign = false },
}
local serviceCalls = { assignments = 0, start = 0, destroy = 0 }
local failAssignments = false
local runtimeModule = {
    Create = function()
        local service = {
            active = false,
            model = { Get = function(_, id) return bindingData[id] end },
            KeyboardAssignments = function()
                serviceCalls.assignments = serviceCalls.assignments + 1
                if failAssignments then error('assignment snapshot failed') end
                return assignments
            end,
        }
        function service:Start(scope) self.active = true; self.scope = scope; serviceCalls.start = serviceCalls.start + 1 end
        function service:Destroy() self.active = false; serviceCalls.destroy = serviceCalls.destroy + 1 end
        function service:RefreshKeys() return true end
        function service:BreakQuick() end
        return service
    end,
}

local hookFactories, featureStarter, postCreate, ownerCreated = {}, nil, nil, nil
local options = { enabled = true }
local env = {
    Version = nil,
    LOG = function() end,
    WARN = function() end,
    SavePreferences = function() end,
    GetFrame = function() return {} end,
    import = function(path)
        if path == '/mods/ClaretHotbuild/modules/Runtime.lua' then return runtimeModule end
        if path == '/mods/ClaretHotbuild/modules/BuildKeyLabels.lua' then return buildLabels end
        if path == '/mods/ClaretHotbuild/modules/CtrlInput.lua' then return { Install = function() end } end
        if path == '/mods/ClaretHotbuild/modules/LocalizationStrings.lua' then return { Strings = { en = {}, ru = {} } } end
        if path == '/lua/maui/group.lua' then
            return { Group = function(parent)
                local owner = { parent = parent, OnDestroy = function() end }
                function owner:DisableHitTest() end
                ownerCreated = owner
                return owner
            end }
        end
        error('unexpected import: ' .. path)
    end,
}
env.ReUI = {
    Require = function() end,
    Core = {
        Hook = function(path, name, factory) hookFactories[path .. ':' .. name] = factory end,
        OnPostCreateUI = function(callback) postCreate = callback end,
    },
    Options = { Mods = { ClaretHotbuild = options } },
    ClaretCore = {
        Localization = { Register = function() return true end, Text = function(key) return key end },
        RegisterFeature = function(_, callback) featureStarter = callback; return true end,
        RegisterSettingsSection = function() return true end,
        IsMenuOpen = function() return false end,
    },
}
setmetatable(env, { __index = _G })
loadModule('../mods/ClaretHotbuild/Main.lua', env)
env.Main(false)

local getKeyTablesFactory = assert(hookFactories['/lua/keymap/hotkeylabels.lua:getKeyTables'])
local nativeLabel = { key = 'N', colour = 'ffffffff', textsize = 18 }
local nativeOrder = { attack = { key = 'A' } }
local nativeUpgrade = { key = 'U' }
local originalRelations = { ual0001 = nativeLabel }
local originalCalls = 0
local original = function()
    originalCalls = originalCalls + 1
    return originalRelations, nativeUpgrade, nativeOrder
end
local getKeyTables = getKeyTablesFactory(original)

local beforeReady, beforeUpgrade, beforeOrder = getKeyTables()
assert(originalCalls == 1 and beforeReady == originalRelations
    and beforeUpgrade == nativeUpgrade and beforeOrder == nativeOrder,
    'before-ready hook returns untouched native values after one original call')
assert(serviceCalls.assignments == 0, 'before-ready path does not snapshot assignments')

featureStarter({ feature = true })
local labels, upgrade, orderKeys = getKeyTables()
assert(originalCalls == 2 and serviceCalls.assignments == 1,
    'active hook calls original once and takes one keyboard assignment snapshot')
assert(labels ~= originalRelations and labels.uel0002,
    'Claret-only blueprint receives its badge through the returned BPID map')
assert(labels.ual0001 and labels.ual0001.key == 'W' and originalRelations.ual0001 == nativeLabel,
    'Claret key takes precedence while the native map stays untouched')
assert(upgrade == nativeUpgrade and orderKeys == nativeOrder,
    'upgrade and order relations pass through unchanged')
assert(labels.uel0002.ambiguous and labels.uel0002.key == 'W'
    and labels.uel0002.chordCount == 2
    and labels.uel0002.chords[1] == 'W' and labels.uel0002.chords[2] == 'X',
    'multiple Claret keys show the first stable key and retain complete chord metadata')

failAssignments = true
local fallback, fallbackUpgrade, fallbackOrder = getKeyTables()
assert(originalCalls == 3 and serviceCalls.assignments == 2
    and fallback == originalRelations and fallbackUpgrade == nativeUpgrade and fallbackOrder == nativeOrder,
    'snapshot exception falls back to untouched native values')
failAssignments = false

local serviceActive = true
-- The feature service is held by Main; lifecycle destruction below validates the no-service path.
assert(serviceActive)
postCreate()
assert(ownerCreated and type(ownerCreated.OnDestroy) == 'function', 'post-create callback owns the service lifecycle')
ownerCreated:OnDestroy()
local afterDestroy, destroyUpgrade, destroyOrder = getKeyTables()
assert(serviceCalls.destroy == 1 and originalCalls == 4 and serviceCalls.assignments == 2
    and afterDestroy == originalRelations and destroyUpgrade == nativeUpgrade and destroyOrder == nativeOrder,
    'destroyed service returns native values without taking another snapshot')

print('PASS: hotkeylabels hook decorates only active service calls and preserves native behavior')
