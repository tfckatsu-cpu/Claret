local root = '../mods/ClaretCore/modules/'
local hotbuildRoot = '../mods/ClaretHotbuild/modules/'
local gameLanguage = 'ru-RU'
Sys = { GetLanguage = function() return gameLanguage end }
table.getn = table.getn or function(value) return #value end

dofile(root .. 'LocalizationStrings.lua')
local coreStrings = Strings
local hotbuildStrings
import = function(path)
    if path == '/mods/ClaretCore/modules/LocalizationStrings.lua' then
        return { Strings = coreStrings }
    elseif path == '/mods/ClaretHotbuild/modules/LocalizationStrings.lua' then
        return { Strings = hotbuildStrings }
    end
    error('Unexpected localization import: ' .. tostring(path))
end
dofile(root .. 'Localization.lua')
local localization = Localization

assert(localization.Initialize('auto') == 'ru', 'auto must use the game language')
assert(localization.Text('core.menu.language') == coreStrings.ru['core.menu.language'])

Strings = nil
dofile(hotbuildRoot .. 'LocalizationStrings.lua')
hotbuildStrings = Strings
Strings = coreStrings
assert(localization.Register('hotbuild', hotbuildStrings))
local valid, missing = localization.Validate()
assert(valid, 'every production key must exist in EN and RU: ' .. table.concat(missing, ', '))

local key = 'hotbuild.action.select_acu.label'
assert(localization.Register('search_test', {
    en = { ['test.search'] = 'Select units' },
    ru = { ['test.search'] = 'Выбрать юниты' },
}))
assert(localization.Matches('test.search', 'SELECT'), 'search must match English text regardless of selected language')
assert(localization.Matches('test.search', 'ВЫБРАТЬ'), 'search must match Russian text regardless of selected language')
assert(localization.Fold('ЁЖ') == 'еж', 'search must fold ё to е and ignore case')

local english = localization.Text(key)
assert(localization.SetLanguage('en'))
assert(localization.Text(key) == hotbuildStrings.en[key], 'English selection must use the EN table')
assert(localization.SetLanguage('ru'))
assert(localization.Text(key) == hotbuildStrings.ru[key], 'Russian selection must use the RU table')
assert(localization.Text('core.welcome.menu_key', 'F10') == 'Меню Claret: F10', 'one formatting argument must be substituted')
local twoArgs = localization.Text('hotbuild.compatibility.s026', 'Preset A', 'Set B')
assert(string.find(twoArgs, 'Preset A', 1, true) and string.find(twoArgs, 'Set B', 1, true), 'two formatting arguments must be substituted')
local threeArgs = localization.Text('hotbuild.compatibility.s025', 'Preset A', 'Builder', 'Engineers')
assert(string.find(threeArgs, 'Preset A', 1, true) and string.find(threeArgs, 'Builder', 1, true)
    and string.find(threeArgs, 'Engineers', 1, true), 'three formatting arguments must be substituted')

gameLanguage = 'Turkish'
assert(localization.Initialize('auto') == 'en', 'Turkish must not be mistaken for Russian')
gameLanguage = 'ru-RU'
assert(localization.Initialize('auto') == 'ru')

assert(localization.Register('test', { en = { ['test.fallback'] = 'English fallback' }, ru = {} }))
assert(localization.Text('test.fallback') == 'English fallback', 'a missing selected-language key must fall back to English')
local complete = localization.Validate()
assert(not complete, 'the validator must detect a missing translation')

print('core localization tables, fallback, language selection, and bilingual search passed')
