-- Welcome settings and layout checks against a mock of MAUI.
local localization = dofile('Tests/localization-test-helper.lua')
local env = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/Welcome.lua', 't', env))()

local bound = { Get = function() return 'Ctrl-Alt-C' end }
assert(env.GetMenuBindingText(bound, function(key, ...) return localization.Text(key, ...) end)
    == 'Меню Claret: Ctrl-Alt-C')
local unbound = { Get = function() return '' end }
assert(env.GetMenuBindingText(unbound, function(key, ...) return localization.Text(key, ...) end)
    == 'Сочетание для меню не назначено — назначьте его в F10 → Claret')
assert(env.ShouldShowWelcome(false), 'show the welcome window before dismissal')
assert(not env.ShouldShowWelcome(true), 'hide the welcome window after dismissal')

local dismissed = { value = false, saves = 0 }
function dismissed:Get() return self.value end
function dismissed:Set(value) self.value = value end
function dismissed:Save() self.saves = self.saves + 1 end
local preferenceSaves = 0
local function SavePreferences() preferenceSaves = preferenceSaves + 1 end
assert(env.ToggleWelcomeDismissal(dismissed, SavePreferences) and dismissed:Get(),
    'enable dismissal from the checkbox')
assert(env.ToggleWelcomeDismissal(dismissed, SavePreferences) and not dismissed:Get(),
    'clicking the active checkbox again disables dismissal')
assert(dismissed.saves == 2 and preferenceSaves == 2, 'persist both checkbox states')
assert(env.ShouldShowFontBlock(), 'always show the optional Nunito setup block')
assert(env.ShouldShowFontBlock(function() return true end),
    'show the Nunito block even when both fonts are installed')
assert(env.ShouldShowFontBlock(function() error('VFS lookup failed') end),
    'font block visibility does not depend on VFS lookup')

local controls, screen, pixelScale, escape = {}, nil, 1, nil
local openedUrls, copiedUrls = {}, {}
local function variable(initial)
    return setmetatable({ value = initial, Set = function(self, value) self.value = value end }, {
        __call = function(self)
            if type(self.value) == 'function' then return self.value() end
            return self.value
        end,
    })
end
local function control(parent)
    local item = { parent = parent, Left = variable(0), Top = variable(0), Width = variable(0),
        Height = variable(0), Depth = variable(0) }
    function item:SetText(text) self.text = text end
    function item:SetColor(color) self.color = color end
    function item:SetSolidColor(color) self.fill = color end
    function item:SetTexture(texture) self.texture = texture end
    function item:EnableHitTest() self.hitTest = true end
    function item:DisableHitTest() self.hitTest = false end
    function item:OnDestroy() end
    function item:Destroy() self.destroyed = true; self:OnDestroy() end
    function item:GetTopmostDepth() return 10 end
    table.insert(controls, item)
    return item
end
local function layouter(scale)
    return function(item)
        local layout = {}
        function layout:Width(w) item.Width:Set(math.floor(w * scale)); return self end
        function layout:Height(h) item.Height:Set(math.floor(h * scale)); return self end
        function layout:AtLeftTopIn(parent, x, y)
            item.Left:Set(function() return parent.Left() + math.floor(x * scale) end)
            item.Top:Set(function() return parent.Top() + math.floor(y * scale) end)
            return self
        end
        function layout:AtCenterIn(parent)
            item.Left:Set(function() return parent.Left() + (parent.Width() - item.Width()) / 2 end)
            item.Top:Set(function() return parent.Top() + (parent.Height() - item.Height()) / 2 end)
            return self
        end
        function layout:Fill(parent)
            item.Left:Set(function() return parent.Left() end)
            item.Top:Set(function() return parent.Top() end)
            item.Width:Set(function() return parent.Width() end)
            item.Height:Set(function() return parent.Height() end)
            return self
        end
        return layout
    end
end
local modules = {
    ['/mods/ClaretCore/modules/Localization.lua'] = { Localization = localization },
    ['/lua/maui/group.lua'] = { Group = control },
    ['/lua/maui/bitmap.lua'] = { Bitmap = control },
    ['/lua/maui/multilinetext.lua'] = { MultiLineText = control },
    ['/lua/maui/layouthelpers.lua'] = { GetPixelScaleFactor = function() return pixelScale end },
    ['/lua/ui/uiutil.lua'] = { CreateText = function(parent, text, size)
        local item = control(parent)
        item.Height:Set(size * pixelScale * 1.2)
        item.Width:Set(function() return utf8.len(item.text) * size * pixelScale * 0.54 end)
        item:SetText(text)
        return item
    end },
    ['/lua/ui/dialogs/eschandler.lua'] = {
        PushEscapeHandler = function(fn) assert(not escape); escape = fn end,
        PopEscapeHandler = function() assert(escape); escape = nil end,
    },
}
env.import = function(path) return assert(modules[path], path) end
env.ReUI = { UI = { FloorLayouter = layouter } }
env.GetFrame = function() return screen end
env.SavePreferences = SavePreferences
env.OpenURL = function(url, parent) table.insert(openedUrls, { url = url, parent = parent }) end
env.CopyToClipboard = function(url) table.insert(copiedUrls, url); return true end
env.WARN = error
localization.GetLanguage = function() return localization.language end
local theme = setmetatable({}, { __index = env })
assert(loadfile('../mods/ClaretCore/modules/Theme.lua', 't', theme))()
modules['/mods/ClaretCore/modules/Theme.lua'] = theme
local language = { value = 'ru', Get = dismissed.Get, Set = dismissed.Set, Save = function() end }
local function Find(key)
    local value = localization.Text(key)
    for _, item in ipairs(controls) do if item.text == value then return item end end
    error('Missing welcome control: ' .. key)
end
local function Click(key, modifiers)
    local button = Find(key).parent
    assert(button.hitTest and button:HandleEvent({ Type = 'ButtonPress', Modifiers = modifiers }))
end
for _, mode in ipairs({ {1280, 720, 1.5}, {1920, 1080, 1}, {2560, 1440, 1.25} }) do
    controls, pixelScale = {}, mode[3]
    screen = control()
    screen.Width:Set(mode[1]); screen.Height:Set(mode[2])
    localization.SetLanguage('ru'); language.value = 'ru'
    local root = env.Create(screen, bound, dismissed, language)
    local title = Find('core.welcome.title')
    local panel = title.parent
    assert(panel.Left() >= 24 and panel.Top() >= 24)
    assert(panel.Left() + panel.Width() <= mode[1] - 24 and panel.Top() + panel.Height() <= mode[2] - 24)
    local github = Find('core.welcome.project_link').parent
    local discord = Find('core.welcome.discord_link').parent
    assert(title.Left() + title.Width() < github.Left())
    assert(github.Top() + github.Height() < discord.Top(), 'community actions have distinct hit areas')
    Click('core.language.english')
    assert(language:Get() == 'en' and title.text == 'Welcome to Claret')
    Click('core.welcome.project_link'); Click('core.welcome.discord_link')
    assert(openedUrls[#openedUrls - 1].url == 'http://github.com/tfckatsu-cpu/Claret')
    assert(openedUrls[#openedUrls].url == 'http://discord.gg/JupcdJbu7U' and openedUrls[#openedUrls].parent == root)
    local openedCount = #openedUrls
    Click('core.welcome.project_link', { Right = true }); Click('core.welcome.discord_link', { Right = true })
    assert(#openedUrls == openedCount, 'copy does not open the browser dialog')
    assert(copiedUrls[#copiedUrls - 1] == 'https://github.com/tfckatsu-cpu/Claret')
    assert(copiedUrls[#copiedUrls] == 'https://discord.gg/JupcdJbu7U')
    assert(Find('core.welcome.link_copied'))
    local previousDismissal = dismissed:Get()
    Click('core.welcome.dismiss')
    assert(dismissed:Get() ~= previousDismissal)
    Click('core.welcome.close')
    assert(root.destroyed and not escape)
    localization.SetLanguage('ru')
    assert(title.text == 'Welcome to Claret', 'closing unsubscribes all welcome labels')
end

print('PASS: welcome geometry, language refresh, community links, dismissal, and cleanup')
