-- Small RU ClaretCore localization fixture for UI tests using mocked ReUI.
table.getn = table.getn or function(value) return #value end
unpack = unpack or table.unpack
local previousStrings = Strings
Strings = nil
dofile('../mods/ClaretCore/modules/LocalizationStrings.lua')
local coreStrings = Strings
Strings = nil
dofile('../mods/ClaretHotbuild/modules/LocalizationStrings.lua')
local hotbuildStrings = Strings
Strings = previousStrings

local dictionaries = { en = {}, ru = {} }
for _, source in ipairs({ coreStrings, hotbuildStrings }) do
    for _, language in ipairs({ 'en', 'ru' }) do
        for key, value in pairs(source[language]) do dictionaries[language][key] = value end
    end
end
local listeners = {}
local localization = { language = 'ru' }
local function Fold(value)
    local text = string.lower(tostring(value or ''))
    text = string.gsub(text, '\208\129', '\209\145')
    text = string.gsub(text, '\208[\144-\175]', function(letter)
        local second = string.byte(letter, 2)
        if second < 160 then return string.char(208, second + 32) end
        return string.char(209, second - 32)
    end)
    return (string.gsub(text, '\209\145', '\208\181'))
end
function localization.Text(key, ...)
    local value = dictionaries[localization.language][key] or dictionaries.en[key] or tostring(key or '')
    local args = { ... }
    if table.getn(args) > 0 then return string.format(value, unpack(args)) end
    return value
end
function localization.SearchText(key)
    return Fold((dictionaries.en[key] or '') .. ' ' .. (dictionaries.ru[key] or ''))
end
function localization.Fold(value) return Fold(value) end
function localization.Subscribe(owner, callback) listeners[owner] = callback end
function localization.Unsubscribe(owner) listeners[owner] = nil end
function localization.Register(_, tables)
    for _, language in ipairs({ 'en', 'ru' }) do
        for key, value in pairs(tables[language] or {}) do dictionaries[language][key] = value end
    end
    return true
end
function localization.SetLanguage(language)
    localization.language = language
    for _, callback in pairs(listeners) do callback(language) end
end

ReUI = ReUI or {}
ReUI.ClaretCore = ReUI.ClaretCore or {}
ReUI.ClaretCore.Localization = localization
localization.Tables = { core = coreStrings, hotbuild = hotbuildStrings }
return localization
