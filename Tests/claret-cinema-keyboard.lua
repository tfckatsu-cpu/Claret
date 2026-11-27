table.getn = table.getn or function(value) return #value end
local root = '../mods/ClaretCinema/'
local function Load(name, env)
    return assert(loadfile(root .. name, 't', setmetatable(env or {}, {__index = _G})))
end

local layout = {}
Load('modules/KeyboardLayout.lua', layout)()
local strings = {}
Load('modules/Localization.lua', strings)()
local commands = {}
Load('modules/Commands.lua', commands)()
local section
local locale = {
    Register = function(namespace, value) return namespace == 'cinema' and value == strings.Strings end,
    Text = function(key, value)
        local text = assert(strings.Strings.en[key], 'missing Cinema label: ' .. key)
        return value and string.format(text, value) or text
    end,
    Fold = string.lower,
    Matches = function(key, query) return string.find(string.lower(strings.Strings.en[key]), string.lower(query), 1, true) ~= nil end,
    Subscribe = function() end,
    Unsubscribe = function() end,
}
local core = {
    RegisterSettingsSection = function(value) section = value; return true end,
    Localization = locale,
}

local controls, escape, fields = {}, {}, {}
local function Lazy(read)
    return setmetatable({Set = function(self, anchor) self.anchor = anchor end}, {
        __call = function(self) return self.anchor and self.anchor() or read() end,
    })
end
local function Control(parent, label)
    local c = {parent = parent, label = label}
    table.insert(controls, c)
    function c:SetText(text) self.label = text end
    function c:GetText() return self.label or '' end
    function c:Show() self.hidden = false end
    function c:Hide() self.hidden = true end
    function c:SetHidden(hidden) self.hidden = hidden end
    function c:GetStringAdvance(text) return string.len(text) * 6 end
    function c:Destroy()
        if self.destroyed then return end
        self.destroyed = true
        if self.OnDestroy then self:OnDestroy() end
    end
    function c:OnDestroy() end
    function c:SetColor() end
    function c:DisableHitTest() end
    function c:SetNeedsFrameUpdate() end
    c.Width = Lazy(function() return c.label and string.len(c.label) * 6 or 1920 end)
    c.Height = Lazy(function() return 1080 end)
    function c:Right() return 384 end
    c.Left = Lazy(function() return 0 end)
    c.Depth = Lazy(function() return 0 end)
    return c
end
local function Find(text)
    for index = table.getn(controls), 1, -1 do
        local c = controls[index]
        if c.label == text then
            local ancestor = c
            while ancestor and not ancestor.destroyed and not ancestor.hidden do ancestor = ancestor.parent end
            if not ancestor then return c end
        end
    end
end
local function Click(text, right)
    local label = assert(Find(text), 'expected visible label: ' .. text)
    assert(label.parent.HandleEvent, 'expected interactive control: ' .. text)
    label.parent:HandleEvent({Type = 'ButtonPress', Modifiers = {Right = right}})
end

local chain = setmetatable({}, {__index = function() return function(self) return self end end})
local afterUI
local reui = {
    ClaretCore = core, Require = function() end, UI = {FloorLayouter = function() return function() return chain end end},
    Core = {OnPostCreateUI = function(callback) afterUI = callback end},
}
local active, hud, changed, toggle = false, 'H', nil, 'Ctrl-Alt-F9'
local choices = {}
for _, choice in ipairs(commands.Choices) do table.insert(choices, choice) end
table.insert(choices, {id = 'faf:debug_bones', label = 'cinema.bone_names', reason = 'cinema.needs_local_view', group = 'debug'})
table.insert(choices, {id = 'faf:pause', name = 'Pause game', group = 'replay'})
for index = 1, 12 do
    table.insert(choices, {id = 'faf:camera' .. index, name = 'Camera test ' .. index, group = 'camera'})
end
local runtime = {
    GetState = function() return active, toggle end,
    GetChoices = function() return choices end,
    IsMenuChord = function(key) return key == 'Ctrl-M' end,
    GetAssignment = function(key) if key == toggle then return 'mode' elseif key == hud then return 'hud' end end,
    GetNormalAction = function(chord) if chord == 'Ctrl-G' then return 'stock order', true end end,
    Toggle = function() active = not active; changed(); return true end,
    Assign = function(id, key)
        if id == 'mode' then toggle = key else hud = key end
        changed()
        return true
    end,
    Clear = function() hud = ''; changed(); return true end,
    Subscribe = function(owner, callback) changed = callback end,
    Unsubscribe = function() changed = nil end,
}
local directorSpecs = {}
Load('modules/Director.lua', directorSpecs)()
local captured = {}
local motionListener
local drawerChanged
local drawerChord, drawerBlocked = 'Ctrl-G', false
local tooltip
local demoCamera = {SaveSettings = function() return {Focus = {x = 1, y = 2, z = 3}, Zoom = 45} end}
local drawerRuntime = {
    GetState = runtime.GetState,
    GetChord = function(id) if id == 'move_origin' then return drawerChord, drawerBlocked end end,
    Toggle = function() return true end,
    RunDrawer = function(id)
        if id == 'move_origin' then captured.moveorigin = true; drawerChanged() end
        return true
    end,
    Subscribe = function(owner, callback) drawerChanged = callback end,
    Unsubscribe = function() drawerChanged = nil end,
}
local drawerDirector = {
    GetVisual = function(id)
        for _, spec in ipairs(directorSpecs.Visual) do if spec.id == id then return spec.initial end end
    end,
    Get = function(tab, id)
        if captured[tab .. id] then return demoCamera:SaveSettings() end
        for _, spec in ipairs(directorSpecs.Motion[tab]) do if spec.id == id then return spec.initial end end
    end,
    Capture = function(tab, id) captured[tab .. id] = true; return true end,
    Listen = function(callback) motionListener = callback end,
    Play = function() return true end,
}
local stubs = {
    ['/mods/ClaretCinema/modules/Runtime.lua'] = runtime,
    ['/mods/ClaretCinema/modules/KeyboardLayout.lua'] = layout,
    ['/mods/ClaretCinema/modules/Localization.lua'] = strings,
    ['/mods/ClaretCinema/modules/Commands.lua'] = commands,
    ['/mods/ClaretCinema/modules/Director.lua'] = directorSpecs,
    ['/mods/ClaretCore/modules/Theme.lua'] = {
        Colors = setmetatable({}, {__index = function(self, field) return field end}),
        Metrics = {buttonText = 15, title = 22, heading = 18, secondaryText = 14, text = 16, label = 13,
            buttonHeight = 36, rowHeight = 40, panelGap = 16},
        Fonts = {body = 'b', heading = 'h'},
        Outline = function() return function() end end,
        RoundedPanel = function(control, layout, width, height, fill, border)
            assert(fill and border, 'supply the shared palette to RoundedPanel')
            control:SetSolidColor(fill)
            return function(w, h) control.panelHeight = h end
        end,
        SettingsSwitch = function() return function() end end,
    },
    ['/lua/maui/group.lua'] = {Group = Control},
    ['/lua/maui/edit.lua'] = {Edit = function(parent)
        local edit = Control(parent)
        table.insert(fields, edit)
        return edit
    end},
    ['/lua/maui/bitmap.lua'] = {Bitmap = function(parent, texture)
        local bitmap = Control(parent)
        bitmap.texture = texture
        function bitmap:SetSolidColor() end
        return bitmap
    end},
    ['/lua/maui/slider.lua'] = {IntegerSlider = function(parent, vertical, start, finish, indent, thumb, over, down)
        assert(thumb and over and down, 'supply drawer-specific slider artwork for all three states')
        local c = Control(parent)
        c._background = Control(c)
        c._thumb = Control(c)
        function c._background:SetSolidColor() end
        function c:CalculateValueFromMouse(x) return x end
        function c:SetValue(value) self.value = value end
        return c
    end},
    ['/lua/ui/uiutil.lua'] = {
        CreateText = Control, SetupEditStd = function() end, SkinnableFile = function(path) return path end,
        GetAnimationPrefs = function() return false end,
    },
    ['/lua/ui/game/tooltip.lua'] = {
        CreateMouseoverDisplay = function(control, display) tooltip = display.text end,
        DestroyMouseoverDisplay = function() tooltip = nil end,
    },
    ['/lua/maui/layouthelpers.lua'] = {GetPixelScaleFactor = function() return 1 end},
    ['/lua/ui/dialogs/eschandler.lua'] = {
        PushEscapeHandler = function(callback) table.insert(escape, callback) end,
        PopEscapeHandler = function() table.remove(escape) end,
    },
}
local function Import(path) return assert(stubs[path], 'unexpected import: ' .. path) end
local editor = {ReUI = reui, import = Import, IsKeyDown = function() return false end}
Load('modules/KeyboardEditor.lua', editor)()
stubs['/mods/ClaretCinema/modules/KeyboardEditor.lua'] = editor
local picker = {}
Load('modules/ActionPicker.lua', picker)()
stubs['/mods/ClaretCinema/modules/ActionPicker.lua'] = picker
local main = {ReUI = reui, import = Import, LOG = function() end}
Load('Main.lua', main)()
main.Main(false)
assert(section and section.id == 'cinema', 'replace the Cinema placeholder through the public Core API')
assert(type(afterUI) == 'function', 'defer mounting the drawer until FAF has built its game UI')
local height
local page = section.inline(Control(), {scale = 1, setHeight = function(value) height = value end})
assert(not changed, 'defer keyboard construction until Core shows its host')
page:AfterParentShow()
assert(height == 626 and Find('Cinema: OFF · Ctrl-Alt-F9'), 'show the collapsed keyboard and its active toggle chord')
Click('Show NumPad')
assert(height == 906 and Find('Num7'), 'render the additional NumPad keys and resize the settings panel')
Click('Hide NumPad')
assert(height == 626 and not Find('Num7'), 'remove NumPad controls on collapse')
Click('Ctrl')
Click('M')
assert(Find('This combination opens the Claret menu in both modes.'), 'explain the menu shortcut exception')
assert(escape[1](), 'close the read-only menu shortcut picker')
Click('G')
assert(height == 976 and Find('Key assignment: Ctrl-G') and Find('Normal: stock order'),
    'show both layouts for the selected key and modifier')
assert(Find('Camera') and Find('Toggle free camera') and Find('Toggle selection boxes'),
    'offer the technical command catalogue in the picker')
Click('Game & Replay')
assert(Find('Pause game'), 'offer game controls without a replay-only warning')
Click('Debug')
assert(Find('Show bone names · Replay or offline game only') and not Find('Toggle selection boxes'),
    'show the visual debug group and explain disabled commands')
Click('Show bone names · Replay or offline game only')
assert(hud == 'H', 'unavailable debug rows cannot save a binding')
Click('Camera')
assert(Find('Camera test 1') and not Find('Camera test 12'), 'bound the initial visible catalogue rows')
Click('›')
assert(Find('Camera test 12') and not Find('Camera test 1'), 'page through commands without overflowing the picker')
local field = fields[table.getn(fields)]
field:OnTextChanged('bone')
assert(Find('Show bone names · Replay or offline game only') and not Find('Camera test 12'),
    'search across groups, not only the selected tab')
Click('Cinema controls')
Click('Move To')
assert(Find('Move To: capture start') and Find('Stop camera motion') and not Find('Pan: capture start'))
Click('Pan')
assert(Find('Pan: capture start') and Find('Stop camera motion') and not Find('Spin: play'))
Click('Spin')
assert(Find('Spin: play') and Find('Stop camera motion') and not Find('Move To: capture start'))
Click('Cinema controls')
Click('Hide / restore the HUD')
assert(hud == 'Ctrl-G' and height == 626 and table.getn(escape) == 0, 'assign the key and close its picker')
Click('G', true)
assert(hud == '', 'right-click clears only the chosen Cinema chord')
Click('J')
Click('Toggle Cinema mode')
assert(Find('Cinema: OFF · Ctrl-J'), 'the picker can rebind the mode switch itself')
Click('Cinema: OFF · Ctrl-J')
assert(active and Find('Cinema: ON · Ctrl-J'), 'switch mode and refresh the visible status')
Click('G')
assert(Find('Turn off Cinema to change bindings.'), 'show a read-only picker while Cinema owns input')
assert(escape[1]() and height == 626 and table.getn(escape) == 0, 'Escape closes the picker without closing the section')
page:Destroy()
assert(not changed, 'destroying the settings section removes runtime subscriptions')

local drawer = {ReUI = reui, import = Import, WARN = function(message) error(message) end}
Load('modules/Drawer.lua', drawer)()
local edge = drawer.Create(Control(), drawerDirector, drawerRuntime)
local dock
for _, control in ipairs(controls) do
    if control.texture == '/mods/ClaretCinema/textures/ui/camera.png' then dock = control.parent end
end
assert(dock and not Find('Near field of view'), 'start with only the movie camera button mounted')
dock:HandleEvent({Type = 'MouseEnter'})
assert(tooltip == 'Open Cinema drawer', 'explain the icon until it is clicked')
dock:HandleEvent({Type = 'ButtonPress'})
assert(not tooltip and Find('Near field of view') and Find('Shadow resolution'),
    'open the drawer with the original general controls')
local pane = assert(Find('Claret Cinema')).parent
local generalHeight = assert(pane.panelHeight)
Click('Move To')
assert(Find('Capture start · Ctrl-G') and Find('Capture end') and Find('Duration, s'), 'show the move editor and assigned chord')
assert(pane.panelHeight < generalHeight, 'remove empty space below a shorter tab')
Click('Capture start · Ctrl-G')
assert(captured.moveorigin and Find('XYZ 1 / 2 / 3   ·   Zoom 45.00'), 'show a newly captured pose')
local captureButton = assert(Find('Capture start · Ctrl-G')).parent
captureButton:HandleEvent({Type = 'MouseEnter'})
assert(tooltip == 'Capture start · Ctrl-G', 'show the full chord in the tooltip')
drawerChord, drawerBlocked = 'Ctrl-Shift-Alt-PrintScreen', true
drawerChanged('bindings')
assert(Find('Capture start · … !') and tooltip:find('Blocked by Claret menu', 1, true),
    'retain the blocked indicator and update an open tooltip')
drawerChord = nil
drawerChanged('bindings')
assert(not tooltip and Find('Capture start'), 'clearing a hovered binding dismisses its tooltip')
Click('Pan')
assert(Find('Pan speed on X') and Find('Pan speed on Z') and Find('Duration, s'), 'show adjustable pan controls')
Click('Spin')
assert(Find('Rotation speed') and Find('Zoom speed') and Find('Stop'), 'show the spin transport')
local rate = assert(Find('0.1'), 'display the current rotation speed')
assert(rate.Left.anchor and rate.Left.anchor() > 300, 'anchor slider values on the right, independently from the caption')
dock:HandleEvent({Type = 'MouseExit'})
dock:HandleEvent({Type = 'MouseEnter'})
assert(tooltip == 'Close Cinema drawer', 'indicate that the camera button now folds the drawer')
dock:HandleEvent({Type = 'ButtonPress'})
assert(not Find('Rotation speed'), 'hide the full drawer when the camera button is clicked again')
dock:HandleEvent({Type = 'ButtonPress'})
assert(Find('Rotation speed'), 'reopen on the active tab')
edge:Destroy()
assert(not motionListener, 'release the camera status callback on UI teardown')
print('PASS: Cinema mounts the keyboard and operates the separate edge drawer')
