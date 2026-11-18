-- Pure logic coverage for welcome hotkey text, dismissal toggle and Nunito setup.
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

print('PASS: welcome hotkey, dismissal toggle and Nunito font-block condition')
