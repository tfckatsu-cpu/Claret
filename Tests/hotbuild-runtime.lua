-- Integration logic only: fake Maui controls, real catalog/model/editor/runtime.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn = function(t) return #t end
table.getsize = function(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local objects, modules, engine, warnings, escapeHandlers = {}, {}, {}, {}, {}
local saved, saveCount, failSave = nil, 0, false
local userKeyActions, userKeyMap, userDebugKeyMap, keyDescriptions = {}, {}, {}, {}
local selected, queue = {}, {}
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
        for _, child in ipairs(objects) do if child.parent == self then child:Destroy() end end
    end
    function c:SetText(value) self.text = value; if self.OnTextChanged then self:OnTextChanged(value) end end
    function c:SetColor() end
    function c:DisableHitTest() end
    function c:SetSolidColor() end
    function c:SetNeedsFrameUpdate(v) self.needsFrameUpdate=v end
    function c:SetTexture(value) self.texture = value end
    function c:Show() self.visible = true end
    function c:Hide() self.visible = false end
    objects[#objects + 1] = c
    return c
end
local layout = setmetatable({}, { __index = function(self) return function() return self end end })
local root = control(nil)
local function normalize(key)
    local ctrl = key:find('Ctrl-', 1, true) and 'Ctrl-' or ''
    local shift = key:find('Shift-', 1, true) and 'Shift-' or ''
    local alt = key:find('Alt-', 1, true) and 'Alt-' or ''
    return ctrl .. shift .. alt .. key:match('([^-]+)$')
end
local environment = setmetatable({
    ReUI = { ClaretCore = { Localization = testLocalization }, UI = { FloorLayouter = function() return function() return layout end end } },
    LOC = function(text) return text end,
    __blueprints = {
        uea0101 = { BlueprintId = 'uea0101', General = { UnitName = 'Snoop' }, Description = 'Air scout',
            Categories = {'UEF','AIR','TECH1','BUILTBYTIER1FACTORY'} },
    },
    IsDestroyed = function(c) return not c or c.destroyed end,
    GetSelectedUnits = function() return selected end,
    GetFocusArmy = function() return 1 end,
    GetUnitCommandData = function(units) return {'RULEUCC_Move'}, {}, 'RUNTIME_TEST_BUILDABLE' end,
    EntityCategoryGetUnitList = function(category)
        return category == 'RUNTIME_TEST_BUILDABLE' and {'uea0101'} or {}
    end,
    IssueBlueprintCommand = function(kind, id, count) queue[#queue + 1] = {kind,id,count} end,
    SessionIsActive = function() return false end,
    IN_ClearKeyMap = function() for key in pairs(engine) do engine[key]=nil end end,
    IN_AddKeyMapTable = function(map) for key, action in pairs(map) do engine[key] = action end end,
    IN_RemoveKeyMapTable = function(map) for key in pairs(map) do engine[key] = nil end end,
    SavePreferences = function() if failSave then error('disk save failure') end; saveCount = saveCount + 1 end,
    WARN = function(text) warnings[#warnings + 1] = text end,
}, { __index = _G })
local mapper = {
    NormalizeKeyBinding = normalize,
    GetCurrentKeyMap = function() local result={} for k,v in pairs(userKeyMap) do result[k]=v end for k,v in pairs(userDebugKeyMap) do result[k]=v end return result end,
    GetKeyMappings = function() local result={} for k,v in pairs(userKeyMap) do result[k]=userKeyActions[v] end for k,v in pairs(userDebugKeyMap) do result[k]=userKeyActions[v] end return result end,
    SaveUserKeyMap = function() end,
    SetUserKeyAction = function(id, action) userKeyActions[id] = action end,
}
environment.import = function(path)
    if path == '/lua/ui/dialogs/eschandler.lua' then return {
        PushEscapeHandler = function(handler) table.insert(escapeHandlers,handler) end,
        PopEscapeHandler = function() table.remove(escapeHandlers) end,
    } end
    if path == '/lua/user/prefs.lua' then return {
        GetFromCurrentProfile = function(key)
            if key == 'ClaretHotbuild' then return saved end
            if key == 'UserKeyActions' then return userKeyActions end
            if key == 'UserKeyMap' then return userKeyMap end
            if key == 'UserDebugKeyMap' then return userDebugKeyMap end
            return nil
        end,
        SetToCurrentProfile = function(key, value)
            if key == 'ClaretHotbuild' then saved = value
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
        local combo=control(parent)
        function combo:AddItems(items,index) self.items=items; self.selected=index end
        function combo:ClearItems() self.items={} end
        function combo:SetItem(index) self.selected=index end
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
            button.SetText = nil -- Match native Maui Button: labels are children.
            return button
        end,
        CreateText = function(parent, text) return control(parent, text) end,
        UIFile = function(path) return path end,
        CreateVertScrollbarFor = function(parent) return control(parent) end,
    } end
    if modules[path] then return modules[path] end
    local module = setmetatable({}, { __index = environment })
    assert(loadfile('..' .. path, 't', module))()
    modules[path] = module
    return module
end
local Runtime = environment.import('/mods/ClaretHotbuild/modules/Runtime.lua')
local function actionId(id)
    return 'ClaretHotbuild_' .. string.gsub(id, '.', function(c) return string.format('%02X', string.byte(c)) end)
end
local service = Runtime.Create(false)
local cleanups = {}
service:Start({ Defer = function(self, fn) cleanups[#cleanups + 1] = fn end })
assert(next(engine) == nil, 'examples must not auto-assign keys')
local binding = service.model:Get('b1'); binding.key = 'Ctrl-Alt-E'
assert(service:Commit(binding))
assert(saveCount == 1 and saved.bindings[1].key == 'Ctrl-Alt-E')
assert(userKeyActions[actionId('b1')].category == 'Claret Hotbuild')
assert(userKeyActions[actionId('b1')].action:find('Execute("b1", IsKeyDown(16))',1,true))
assert(next(userKeyMap)==nil and next(userDebugKeyMap)==nil,'actions are registered without assigning profile keys')
selected = {{ IsDead = function() return false end, IsInCategory = function(self, kind) return kind == 'FACTORY' end }}
assert(Runtime.Execute('b1'))
assert(#queue == 1 and queue[1][2] == 'uea0101' and queue[1][3] == 1)

-- UserKeyMap assignments remain FAF-owned, including when a native action occupies a key.
userKeyMap['Ctrl-E']='NativeAction'; userDebugKeyMap['Ctrl-E']='NativeAction'
Runtime.RefreshKeys()
assert(userKeyMap['Ctrl-E']=='NativeAction' and userDebugKeyMap['Ctrl-E']=='NativeAction')
assert(userKeyActions[actionId('b1')].category=='Claret Hotbuild')
failSave = true
binding.name = 'Unsaved name'
assert(not service:Commit(binding))
assert(service.model:Get('b1').name ~= 'Unsaved name' and saved.bindings[1].name ~= 'Unsaved name')
failSave = false

-- Refresh registers action definitions; it never writes over FAF key assignments.
userKeyMap['Ctrl-Alt-E']='NativeAfterRefresh'
Runtime.RefreshKeys()
assert(userKeyMap['Ctrl-Alt-E']=='NativeAfterRefresh')
assert(userKeyActions[actionId('b1')].category=='Claret Hotbuild')
userKeyMap['Ctrl-Alt-E'] = nil
Runtime.RefreshKeys()
assert(userKeyActions[actionId('b1')].category == 'Claret Hotbuild')

-- Build the actual editor, exercise its search, ordering, save and discard paths.
local editor = service:OpenEditor(root)
assert(Runtime.Execute('b1'),'open editor does not block Hotbuild actions')
local function button(label)
    for _, c in ipairs(objects) do
        if not c.destroyed and c.text==label and c.parent and c.parent.HandleEvent then
            return {OnClick=function() c.parent:HandleEvent({Type='ButtonPress',Modifiers={Left=true}}) end}
        end
    end
    error('button missing: ' .. label)
end
local edits = {}
for _, c in ipairs(objects) do if c.OnEnterPressed then edits[#edits + 1] = c end end
assert(#edits == 1,'current editor starts with only its name field')
button('Новый хотбилд'):OnClick()
edits[1]:SetText('Имя на русском')
button('Сохранить'):OnClick()
assert(not service.model:Get('b3'),'non-ASCII Hotbuild names are rejected')
edits[1]:SetText('My scout')
button('Сохранить'):OnClick()
assert(service.model:Get('b3').name == 'My scout' and #service.model:Get('b3').entries==0)
edits[1]:SetText('Discard me')
editor.RequestClose()
assert(not editor.destroyed, 'dirty editor should not silently discard')
button('Не сохранять'):OnClick()
assert(editor.destroyed, 'standalone editor closes after discard is confirmed')
assert(editor.destroyed and userKeyActions[actionId('b3')].category=='Claret Hotbuild')
local reopened=service:OpenEditor(root)
assert(reopened ~= editor, 'can reopen after closing')
reopened.RequestClose()
for i = #cleanups, 1, -1 do cleanups[i]() end
assert(not service.active and service.editor == nil and userKeyActions[actionId('b3')])
assert(not Runtime.Execute('b1'))
service:Destroy()
assert(not Runtime.Execute('b1'))

-- Serialization survives a new service; replay remains editing-only.
local replay = Runtime.Create(true)
replay:Start({ Defer = function() end })
assert(replay.model:Get('b3').name == 'My scout')
assert(next(engine) == nil and not Runtime.Execute('b1'))
replay:Destroy()
-- Standalone entry point registers through Core's generic API and owns its menu/hook.
local posts, hooks, menus = {}, {}, {}
local registration, settingsById = nil, {}
environment.GetPreference = function(path, default)
    error('Hotbuild must not read a legacy enable preference')
end
environment.GetFrame = function() return root end
environment.LOG = function() end
environment.ReUI.Require = function() end
environment.ReUI.Core = {
    Hook = function(path, name, callback) hooks[name] = callback end,
    OnPostCreateUI = function(callback) posts[#posts + 1] = callback end,
}
local function option(initial)
    return { value = initial }
end
environment.ReUI.Options = {
    Mods = {}, OptionValue = option,
    Builder = { AddOptions = function(id, title, builder) menus[id] = builder end,
        Filter = function() return {} end },
}
environment.ReUI.ClaretCore = { Localization=testLocalization, RegisterFeature = function(id, start, enabled)
    registration = { id = id, start = start, enabled = enabled }
    return true
end, RegisterSettingsSection = function(definition) settingsById[definition.id]=definition; return true end }
local standaloneOptions = environment.import('/mods/ClaretHotbuild/Options.lua')
standaloneOptions.Main()
local standalone = environment.import('/mods/ClaretHotbuild/Main.lua').Main(false)
assert(registration.id == 'hotbuild' and registration.enabled.Get() == true, 'Hotbuild is always enabled')
assert(#posts == 1 and hooks.CloseUI and next(menus)==nil)
assert(settingsById.hotbuild.id=='hotbuild' and settingsById.hotbuild.toggles==nil)
assert(settingsById.hotbuild_context==nil, 'composite constructors are a Hotbuild subpage')
posts[1]()
assert(type(settingsById.hotbuild.inline)=='function' and next(engine) == nil, 'Hotbuild starts enabled without changing saved bindings')
assert(standalone.RegisterAction({id='claret.future',label='Future',execute=function() end}))
local extensionCleanup
registration.start({Defer=function(self, fn) extensionCleanup = fn end})
assert(userKeyActions[actionId('b1')].category=='Claret Hotbuild')
local originals = 0
local close = hooks.CloseUI(function() originals = originals + 1; return 'closed' end)
engine = {} -- F1 rebuilt the runtime map.
assert(close() == 'closed' and originals == 1 and userKeyActions[actionId('b1')].category=='Claret Hotbuild')
extensionCleanup()
assert(next(engine) == nil)
root:Destroy()
assert(not Runtime.Execute('b1'))
print('PASS: Hotbuild save/rollback, FAF-owned key assignments/actions, exact production, editor validation/add/save/discard, cleanup, reload and replay guard')
