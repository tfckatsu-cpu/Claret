-- Regression: a malformed saved record must be quarantined without disabling
-- Hotbuild, losing the raw record, or dropping existing FAF assignments.
table.getn = function(t) return #t end
table.getsize = function(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

local testLocalization = dofile('Tests/localization-test-helper.lua')
local modules, engine, warnings = {}, {}, {}
local savedPresets, savedKeyboard, savedContexts
local userKeyActions, userKeyMap, userDebugKeyMap, keyDescriptions = {}, {}, {}, {}
local selected = {}

local function variable(value)
    return setmetatable({ value = value, Set = function(self, v) self.value = v end }, {
        __call = function(self) return self.value end,
    })
end
local function control(parent, text)
    local c = { parent = parent, text = text, destroyed = false, visible = true,
        Width = variable(1920), Height = variable(1080), Depth = variable(0) }
    function c:OnDestroy() end
    function c:Destroy()
        if self.destroyed then return end
        self:OnDestroy()
        self.destroyed = true
    end
    function c:SetText(value) self.text = value; if self.OnTextChanged then self.OnTextChanged(value) end end
    function c:SetColor() end
    function c:DisableHitTest() end
    function c:SetSolidColor() end
    function c:SetNeedsFrameUpdate(v) self.needsFrameUpdate = v end
    function c:SetTexture(value) self.texture = value end
    function c:Show() self.visible = true end
    function c:Hide() self.visible = false end
    return c
end
local layout = setmetatable({}, { __index = function(self) return function() return self end end })
local function normalize(key)
    local ctrl = key:find('Ctrl-', 1, true) and 'Ctrl-' or ''
    local shift = key:find('Shift-', 1, true) and 'Shift-' or ''
    local alt = key:find('Alt-', 1, true) and 'Alt-' or ''
    return ctrl .. shift .. alt .. key:match('([^-]+)$')
end
local function enc(id)
    return (string.gsub(id, '.', function(c) return string.format('%02X', string.byte(c)) end))
end

local environment = setmetatable({
    ReUI = { ClaretCore = { Localization = testLocalization }, UI = { FloorLayouter = function() return function() return layout end end } },
    LOC = function(text) return text end,
    __blueprints = {
        uea0101 = { BlueprintId = 'uea0101', General = { UnitName = 'Snoop' }, Description = 'Air scout',
            Categories = {'UEF', 'AIR', 'TECH1'} },
    },
    IsDestroyed = function(c) return not c or c.destroyed end,
    GetSelectedUnits = function() return selected end,
    GetFocusArmy = function() return 1 end,
    GetUnitCommandData = function() return {'RULEUCC_Move'}, {}, 'TEST_BUILDABLE' end,
    EntityCategoryGetUnitList = function(category) return category == 'TEST_BUILDABLE' and {'uea0101'} or {} end,
    IssueBlueprintCommand = function() end,
    SessionIsActive = function() return false end,
    IN_ClearKeyMap = function() for key in pairs(engine) do engine[key] = nil end end,
    IN_AddKeyMapTable = function(map) for key, action in pairs(map) do engine[key] = action end end,
    IN_RemoveKeyMapTable = function(map) for key in pairs(map) do engine[key] = nil end end,
    SavePreferences = function() end,
    WARN = function(text) warnings[#warnings + 1] = text end,
    LOG = function() end,
}, { __index = _G })

local mapper = {
    NormalizeKeyBinding = normalize,
    GetCurrentKeyMap = function()
        local result = {}
        for k, v in pairs(userKeyMap) do result[k] = v end
        for k, v in pairs(userDebugKeyMap) do result[k] = v end
        return result
    end,
    GetKeyMappings = function()
        local result = {}
        for k, v in pairs(userKeyMap) do result[k] = userKeyActions[v] end
        for k, v in pairs(userDebugKeyMap) do result[k] = userKeyActions[v] end
        return result
    end,
    SaveUserKeyMap = function() end,
    SetUserKeyAction = function(id, action) userKeyActions[id] = action end,
    SetUserKeyMapping = function(chord, index, id)
        if id then userKeyMap[chord] = id else userKeyMap[chord] = nil end
    end,
    ClearUserKeyMapping = function(chord) userKeyMap[chord] = nil end,
}

environment.import = function(path)
    if path == '/lua/user/prefs.lua' then return {
        GetFromCurrentProfile = function(key)
            if key == 'ClaretHotbuild' then return savedPresets end
            if key == 'ClaretHotbuildContexts' then return savedContexts end
            if key == 'ClaretHotbuildKeyboard' then return savedKeyboard end
            if key == 'UserKeyActions' then return userKeyActions end
            if key == 'UserKeyMap' then return userKeyMap end
            if key == 'UserDebugKeyMap' then return userDebugKeyMap end
            return nil
        end,
        SetToCurrentProfile = function(key, value)
            if key == 'ClaretHotbuild' then savedPresets = value
            elseif key == 'ClaretHotbuildContexts' then savedContexts = value
            elseif key == 'ClaretHotbuildKeyboard' then savedKeyboard = value
            elseif key == 'UserKeyActions' then userKeyActions = value
            elseif key == 'UserKeyMap' then userKeyMap = value
            elseif key == 'UserDebugKeyMap' then userDebugKeyMap = value end
        end,
    } end
    if path == '/lua/keymap/keymapper.lua' then return mapper end
    if path == '/lua/keymap/keydescriptions.lua' then return { keyDescriptions = keyDescriptions } end
    if path == '/lua/keymap/unitkeygroups.lua' then return { unitkeygroups = {} } end
    if path == '/lua/ui/game/commandmode.lua' then return {
        GetCommandMode = function() return {'normal'} end,
        StartCommandMode = function() end,
    } end
    if path == '/lua/maui/group.lua' then return { Group = control } end
    if path == '/lua/maui/bitmap.lua' then return { Bitmap = control } end
    if path == '/lua/maui/edit.lua' then return { Edit = function(parent) return control(parent, '') end } end
    if path == '/lua/maui/layouthelpers.lua' then return { GetPixelScaleFactor = function() return 1 end } end
    if path == '/lua/ui/game/tooltip.lua' then return {
        AddAutoUpdatedControlTooltip = function() end, DestroyMouseoverDisplay = function() end,
    } end
    if path == '/lua/ui/controls/combo.lua' then return { Combo = function(parent)
        local combo = control(parent)
        function combo:AddItems(items, index) self.items = items; self.selected = index end
        function combo:ClearItems() self.items = {} end
        function combo:SetItem(index) self.selected = index end
        return combo
    end } end
    if path == '/lua/ui/game/construction.lua' then return {
        RefreshUI = function() end,
        GetCurrentTechTab = function() return 1 end,
    } end
    if path == '/lua/ui/uiutil.lua' then return {
        bodyFont = 'Arial', SetupEditStd = function() end,
        CreateButtonStd = function(parent, resource, text)
            local button = control(parent)
            button.label = control(button, text)
            button.SetText = nil
            return button
        end,
        CreateText = function(parent, text) return control(parent, text) end,
        UIFile = function(path) return path end,
        CreateVertScrollbarFor = function(parent) return control(parent) end,
    } end
    if path == '/lua/ui/dialogs/eschandler.lua' then return {
        PushEscapeHandler = function() end, PopEscapeHandler = function() end,
    } end
    if modules[path] then return modules[path] end
    local module = setmetatable({}, { __index = environment })
    assert(loadfile('..' .. path, 't', module))()
    modules[path] = module
    return module
end

local Runtime = environment.import('/mods/ClaretHotbuild/modules/Runtime.lua')

local function freshWorld()
    for key in pairs(engine) do engine[key] = nil end
    userKeyActions, userKeyMap, userDebugKeyMap = {}, {}, {}
    warnings = {}
end

local function startService()
    local service = Runtime.Create(false)
    service:Start({ Defer = function() end })
    return service
end

local function validPreset()
    return { version = 1, bindings = {
        { id = 'ok1', name = 'Valid scout', key = 'Q',
            entries = { { kind = 'blueprint', id = 'uea0101' } },
            grid = { buildings = {}, units = {} } },
    } }
end

-- A. One malformed preset among valid ones: the valid one works, the raw
-- record survives a save, and its existing FAF action/key assignment survive.
savedPresets = { version = 1, bindings = {
    { id = 'ok1', name = 'Valid scout', key = 'Q',
        entries = { { kind = 'blueprint', id = 'uea0101' } },
        grid = { buildings = {}, units = {} } },
    { id = 'bad1', name = 'Broken', key = 'W',
        entries = { { kind = 'blueprint', id = 'uea0101' } },
        grid = {} },
} }
savedKeyboard, savedContexts = nil, nil
freshWorld()
userKeyMap['Ctrl-B'] = 'ClaretHotbuild_' .. enc('bad1')
userKeyActions['ClaretHotbuild_' .. enc('bad1')] = { category = 'Claret Hotbuild', action = 'old action' }
local a = startService()
assert(a.model:Get('ok1'), 'A: the valid preset loads')
assert(#a.model:GetQuarantine() == 1, 'A: the malformed preset is quarantined')
assert(a.keyboardBindings:GetPairError() == nil, 'A: one bad preset does not disable the keyboard profile')
assert(a:RefreshKeys(), 'A: key refresh succeeds with a quarantined preset')
assert(userKeyActions['ClaretHotbuild_' .. enc('ok1')], 'A: the valid preset action is registered')
assert(userKeyActions['ClaretHotbuild_' .. enc('bad1')].action == 'old action'
    and userKeyMap['Ctrl-B'] == 'ClaretHotbuild_' .. enc('bad1'),
    'A: the quarantined preset keeps its FAF action and key assignment')
local edited = a.model:Get('ok1'); edited.name = 'Renamed'
assert(a:Commit(edited), 'A: saving a valid preset is allowed')
assert(#savedPresets.bindings == 2, 'A: save keeps both records')
assert(savedPresets.bindings[1].name == 'Renamed', 'A: the edited record is saved')
assert(savedPresets.bindings[2].id == 'bad1' and savedPresets.bindings[2].name == 'Broken'
    and savedPresets.bindings[2].key == 'W' and next(savedPresets.bindings[2].grid) == nil,
    'A: the malformed record is preserved verbatim in its original position')
a:Destroy()

-- B. One malformed keyboard record: valid pairs apply, the bad chord is skipped,
-- the preset profile still saves, and a keyboard write keeps the raw record.
savedPresets = validPreset()
savedKeyboard = { version = 2, assignments = {
    ['Ctrl-Q'] = { preset = 'ok1', unexpected = 'x' },
    ['Ctrl-W'] = { preset = 'ok1' },
} }
savedContexts = nil
freshWorld()
userKeyMap['Ctrl-W'] = 'ClaretHotkeyPair_' .. enc('Ctrl-W')
userKeyMap['Ctrl-Q'] = 'ClaretHotkeyPair_' .. enc('Ctrl-Q')
local b = startService()
assert(b.keyboardBindings:GetPairError() == nil, 'B: a bad pair record does not disable the profile')
assert(#b.keyboardBindings:GetPairWarnings() == 1, 'B: the bad pair record is reported')
assert(b:RefreshKeys(), 'B: key refresh succeeds')
assert(engine['Ctrl-W'] ~= nil, 'B: the valid pair is applied')
assert(engine['Ctrl-Q'] == nil, 'B: the quarantined pair is never applied')
local bEdited = b.model:Get('ok1'); bEdited.name = 'Renamed'
assert(b:Commit(bEdited), 'B: preset saving works with a quarantined pair')
assert(b.keyboardBindings:ClearChord('Ctrl-W', {}), 'B: valid keyboard edits are allowed')
assert(savedKeyboard.assignments['Ctrl-Q'] and savedKeyboard.assignments['Ctrl-Q'].unexpected == 'x',
    'B: the quarantined pair record is preserved verbatim')
assert(savedKeyboard.assignments['Ctrl-W'] == nil, 'B: the cleared managed pair is removed')
b:Destroy()

-- C. One malformed context record: the valid context saves, the raw record stays.
savedPresets = validPreset()
savedKeyboard = nil
savedContexts = { version = 3, bindings = {
    { id = 'ctx_ok', name = 'Valid context', rows = { { context = 'empty', action = 'select_acu' } } },
    { id = 'ctx_bad', name = 'Broken context', rows = { { context = 'land' } } },
} }
freshWorld()
local c = startService()
assert(c.contextModel:Get('ctx_ok'), 'C: the valid context loads')
assert(c.contextModel:CanSave(), 'C: damaged rows do not disable context saving')
local contextSaved = c:CommitContext({ id = 'ctx_new', name = 'New', rows = { { context = 'empty', action = 'select_acu' } } })
assert(contextSaved, 'C: saving a valid context is allowed')
assert(#savedContexts.bindings == 3, 'C: context save keeps all records')
assert(savedContexts.bindings[2].id == 'ctx_bad' and savedContexts.bindings[2].rows[1].context == 'land',
    'C: the malformed context record is preserved verbatim in place')
assert(savedContexts.bindings[3].id == 'ctx_new', 'C: the new context is appended')
c:Destroy()

-- D. Unknown profile versions stay read-only without blocking other profiles.
savedPresets = { version = 2, bindings = {} }
savedKeyboard, savedContexts = nil, nil
freshWorld()
local d = startService()
assert(d.model:CanWrite() == false, 'D: an unknown preset version is read-only')
assert(not d:Commit({ id = 'x', name = 'X', key = '', entries = {} }), 'D: preset writes are refused')
assert(d:RefreshKeys(), 'D: refresh does not fail on an unknown preset version')
assert(savedPresets.version == 2, 'D: the unknown preset profile is not rewritten')
d:Destroy()

savedPresets = validPreset()
savedKeyboard = { version = 3, assignments = {} }
savedContexts = nil
freshWorld()
local e = startService()
assert(e.keyboardBindings:GetPairError() ~= nil, 'E: an unknown keyboard version marks pairs unavailable')
local eEdited = e.model:Get('ok1'); eEdited.name = 'Renamed'
local eSaved,eSaveError=e:Commit(eEdited)
assert(eSaved,'E: preset saving works when only the keyboard profile is unknown: '..tostring(eSaveError))
assert(not e.keyboardBindings:ClearChord('Q', {}), 'E: keyboard writes are refused for an unknown version')
e:Destroy()

savedPresets = validPreset()
savedKeyboard = nil
savedContexts = { version = 4, bindings = {} }
freshWorld()
local f = startService()
assert(not f.contextModel:CanSave(), 'F: an unknown context version is read-only')
assert(not f:CommitContext({ id = 'x', name = 'X', rows = {} }), 'F: context writes are refused')
local fEdited = f.model:Get('ok1'); fEdited.name = 'Renamed'
assert(f:Commit(fEdited), 'F: preset saving works when only the context profile is unknown')
f:Destroy()

print('PASS: malformed Hotbuild records are quarantined, preserved and never executed; independent profiles keep working')
