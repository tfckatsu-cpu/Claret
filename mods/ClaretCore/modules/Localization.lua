-- Shared EN/RU strings and language selection for every Claret mod.
local dictionaries = import('/mods/ClaretCore/modules/LocalizationStrings.lua').Strings
local listeners = {}
local preference = 'en'
local gameLanguage = 'en'
local activeLanguage = 'en'

local function NormalizeLanguage(value)
    local text = string.lower(tostring(value or ''))
    if text == 'ru' or string.find(text, '^ru[-_]') or string.find(text, '^russian') then return 'ru' end
    return 'en'
end

local function DetectGameLanguage()
    local sys = rawget(_G, 'Sys')
    local getter = type(sys) == 'table' and rawget(sys, 'GetLanguage') or nil
    if type(getter) == 'function' then
        local ok, value = pcall(getter)
        if ok and value ~= nil then return NormalizeLanguage(value) end
    end
    local getter = rawget(_G, 'GetLanguage')
    if type(getter) == 'function' then
        local ok, value = pcall(getter)
        if ok and value ~= nil then return NormalizeLanguage(value) end
    end
    return 'en'
end

local function Fold(value)
    local text = string.lower(tostring(value or ''))
    text = string.gsub(text, '\208\129', '\209\145') -- ё -> е
    local folded = string.gsub(text, '\208[\144-\175]', function(letter)
        local second = string.byte(letter, 2)
        if second < 160 then return string.char(208, second + 32) end
        return string.char(209, second - 32)
    end)
    return (string.gsub(folded, '\209\145', '\208\181'))
end

local function Notify()
    local pending = {}
    for owner, callback in pairs(listeners) do table.insert(pending, { owner, callback }) end
    for _, entry in ipairs(pending) do
        if listeners[entry[1]] == entry[2] then
            local ok, err = pcall(entry[2], activeLanguage)
            if not ok and WARN then WARN('[Claret] language refresh failed: ' .. tostring(err)) end
        end
    end
end

Localization = {}

function Localization.DetectGameLanguage()
    return DetectGameLanguage()
end

function Localization.Initialize(languageId)
    gameLanguage = DetectGameLanguage()
    if languageId == 'ru' or languageId == 'en' then preference = languageId
    else preference = gameLanguage end
    activeLanguage = preference
    return activeLanguage
end

function Localization.SetLanguage(languageId)
    if languageId ~= 'en' and languageId ~= 'ru' then return false end
    preference = languageId
    local nextLanguage = preference
    if nextLanguage ~= activeLanguage then
        activeLanguage = nextLanguage
        Notify()
    end
    return true
end

function Localization.GetLanguage()
    return activeLanguage
end

function Localization.GetGameLanguage()
    return gameLanguage
end

function Localization.GetPreference()
    return preference
end

function Localization.Text(key, first, second, third)
    local locale = dictionaries[activeLanguage] or dictionaries.en
    local value = locale and locale[key] or nil
    if value == nil then value = dictionaries.en and dictionaries.en[key] end
    if value == nil then return tostring(key or '') end
    if third ~= nil then
        local ok, formatted = pcall(string.format, value, first, second, third)
        if ok then return formatted end
    elseif second ~= nil then
        local ok, formatted = pcall(string.format, value, first, second)
        if ok then return formatted end
    elseif first ~= nil then
        local ok, formatted = pcall(string.format, value, first)
        if ok then return formatted end
    end
    return value
end

function Localization.SearchText(key)
    local english = dictionaries.en and dictionaries.en[key] or ''
    local russian = dictionaries.ru and dictionaries.ru[key] or ''
    return Fold(english .. ' ' .. russian)
end

function Localization.Fold(value)
    return Fold(value)
end

function Localization.Matches(key, query)
    local needle = Fold(query)
    return needle == '' or string.find(Localization.SearchText(key), needle, 1, true) ~= nil
end

function Localization.Register(namespace, tables)
    if type(namespace) ~= 'string' or namespace == '' or type(tables) ~= 'table'
        or type(tables.en) ~= 'table' or type(tables.ru) ~= 'table' then
        return false, 'Localization namespace and EN/RU tables required'
    end
    for _, language in ipairs({ 'en', 'ru' }) do
        for key, value in pairs(tables[language]) do
            if type(key) ~= 'string' or type(value) ~= 'string' then
                return false, 'Localization keys and values must be strings'
            end
            dictionaries[language][key] = value
        end
    end
    return true
end

function Localization.Subscribe(owner, callback)
    if owner == nil or type(callback) ~= 'function' then return false end
    listeners[owner] = callback
    return true
end

function Localization.Unsubscribe(owner)
    listeners[owner] = nil
end

function Localization.Validate()
    local missing = {}
    for key in pairs(dictionaries.en or {}) do
        if not dictionaries.ru or dictionaries.ru[key] == nil then table.insert(missing, 'ru:' .. key) end
    end
    for key in pairs(dictionaries.ru or {}) do
        if not dictionaries.en or dictionaries.en[key] == nil then table.insert(missing, 'en:' .. key) end
    end
    return table.getn(missing) == 0, missing
end

