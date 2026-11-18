-- Original Claret catalog. Built once from the caller's blueprint snapshot.
-- The catalog describes candidates; current-selection buildability is checked by execution.

local factionOrder = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, OTHER = 5 }
local techOrder = { T1 = 1, T2 = 2, T3 = 3, EXPERIMENTAL = 4, OTHER = 5 }
local stockSacuFactionById = { uel0301 = 'UEF', ual0301 = 'AEON', url0301 = 'CYBRAN', xsl0301 = 'SERAPHIM' }


-- Lua's byte-oriented string.lower does not fold Russian UTF-8 names.
local function Fold(text)
    local folded = string.gsub(string.lower(text), '\208[\129\144-\175]', function(letter)
        local second = string.byte(letter, 2)
        if second == 129 then return string.char(209, 145) end
        if second < 160 then return string.char(208, second + 32) end
        return string.char(209, second - 32)
    end)
    return (string.gsub(folded, '\209\145', '\208\181'))
end

---@param value any
---@return string
local function String(value)
    if type(value) == 'string' then return value end
    return ''
end

---@param bp table
---@return table
local function Categories(bp)
    local result = {}
    local list = rawget(bp, 'Categories')
    if type(list) == 'table' then
        for _, category in ipairs(list) do
            if type(category) == 'string' then result[string.upper(category)] = true end
        end
    end
    local hash = rawget(bp, 'CategoriesHash')
    if type(hash) == 'table' then
        for category, present in pairs(hash) do
            if present and type(category) == 'string' then result[string.upper(category)] = true end
        end
    end
    return result
end

---@param cats table
---@return boolean
local function IsBuildCandidate(cats)
    if cats.CIVILIAN or cats.DUMMY or cats.DUMMYUNIT then return false end
    for category in pairs(cats) do
        if string.find(category, '^BUILTBY') or string.find(category, '^TRANSPORTBUILTBY') then
            return true
        end
    end
    return false
end

local function IsEngineerBuildable(cats)
    for category in pairs(cats) do
        if string.find(category, '^BUILTBY.*ENGINEER') then return true end
    end
    return false
end

local function IsBuildingSonar(cats)
    return cats.SONAR and IsEngineerBuildable(cats)
        and (cats.TECH3 or (cats.SERAPHIM and cats.TECH2))
end

---@param value any
---@param localize function
---@return string
local function Label(value, localize)
    local text = String(value)
    if text == '' then return '' end
    local ok, result = pcall(localize, text)
    if ok and type(result) == 'string' and result ~= '' then text = result end
    -- The visible fallback keeps the text following an unresolved LOC token.
    return (string.gsub(text, '^<LOC [^>]+>', ''))
end

local function DisplayName(name, id, blueprint)
    local core = ReUI and ReUI.ClaretCore
    local localization = core and core.Localization
    local language = localization and type(localization.GetLanguage) == 'function'
        and localization.GetLanguage() or nil
    local categories = Categories(blueprint or {})
    if categories.SUPPORTFACTORY and categories.LAND then
        if language == 'en' then return 'Armored Support' end
        if language == 'ru' then return 'Бронетанковый Support' end
    end
    if categories.SUPPORTFACTORY and categories.AIR then
        if language == 'en' then return 'Air Factory Support' end
        if language == 'ru' then return 'Авиазавод Support' end
    end
    if categories.FACTORY and categories.AIR and not categories.SUPPORTFACTORY and not categories.RESEARCH then
        if language == 'en' then return 'Air Factory' end
        if language == 'ru' then return 'Авиазавод' end
    end
    if not localization or type(localization.GetLanguage) ~= 'function'
        or localization.GetLanguage() ~= 'en' or type(blueprint) ~= 'table' then
        return name
    end
    -- LOC resolves by the game locale; Claret English uses the blueprint fallback.
    local function EnglishFallback(value)
        local text = String(value)
        return (string.gsub(text, '^<LOC [^>]+>', ''))
    end
    local text = EnglishFallback(rawget(blueprint, 'Description'))
    if text ~= '' then return text end
    local interface = rawget(blueprint, 'Interface')
    if type(interface) == 'table' then
        text = EnglishFallback(rawget(interface, 'HelpText'))
        if text ~= '' then return text end
    end
    local general = rawget(blueprint, 'General')
    if type(general) == 'table' then
        text = EnglishFallback(rawget(general, 'UnitName'))
        if text ~= '' then return text end
    end
    return name
end
---@param bp table
---@param general table
---@param cats table
---@return string
local function Faction(general, cats, id)
    local name = string.upper(String(rawget(general, 'FactionName')))
    if factionOrder[name] then return name end
    for _, candidate in ipairs({ 'UEF', 'AEON', 'CYBRAN', 'SERAPHIM' }) do
        if cats[candidate] then return candidate end
    end
    return stockSacuFactionById[id] or 'OTHER'
end

---@param cats table
---@return string
local function Tech(cats)
    if cats.EXPERIMENTAL then return 'EXPERIMENTAL' end
    if cats.TECH3 then return 'T3' end
    if cats.TECH2 then return 'T2' end
    if cats.TECH1 then return 'T1' end
    return 'OTHER'
end

---@param cats table
---@return string
local function Kind(cats, id)
    if cats.SUBCOMMANDER or stockSacuFactionById[id] then return 'SACU' end
    if cats.STRUCTURE or IsBuildingSonar(cats) then return 'STRUCTURE' end
    if cats.AIR then return 'AIR' end
    if cats.NAVAL then return 'NAVAL' end
    if cats.LAND then return 'LAND' end
    return 'OTHER'
end

---@param blueprints table
---@param localize? fun(text:string):string
---@return table
function Create(blueprints, localize)
    localize = localize or function(text) return text end
    local records = {}
    local byId = {}
    local sourceKeys = {}
    for key, bp in pairs(blueprints or {}) do
        if type(bp) == 'table' then
            local general = rawget(bp, 'General')
            local cats = Categories(bp)
            local id = String(rawget(bp, 'BlueprintId'))
            if id == '' and type(key) == 'string' then id = key end
            id = string.lower(id)
            if id ~= '' and type(general) == 'table'
                and (IsBuildCandidate(cats) or cats.SUBCOMMANDER or stockSacuFactionById[id]) then
                local name = Label(rawget(bp, 'Description'), localize)
                local description = name
                local interface = rawget(bp, 'Interface')
                if description == '' and type(interface) == 'table' then
                    description = Label(rawget(interface, 'HelpText'), localize)
                end
                if name == '' then name = description end
                if name == '' then name = Label(rawget(general, 'UnitName'), localize) end
                if name == '' then name = description end
                if name == '' then name = id end
                local record = {
                    id = id,
                    name = name,
                    description = description,
                    faction = Faction(general, cats, id),
                    tech = Tech(cats),
                    kind = Kind(cats, id),
                    icon = '/icons/units/' .. id .. '_icon.dds',
                    blueprint = bp,
                }
                local rawName = String(rawget(general, 'UnitName'))
                local rawDescription = String(rawget(bp, 'Description'))
                rawName = string.gsub(rawName, '^<LOC [^>]+>', '')
                rawDescription = string.gsub(rawDescription, '^<LOC [^>]+>', '')
                local searchAliases = ''
                if cats.SUPPORTFACTORY and cats.LAND then
                    searchAliases = ' Завод наземной техники Бронетанковый Support Land Factory Armored Support'
                elseif cats.SUPPORTFACTORY and cats.AIR then
                    searchAliases = ' Авиазавод Авиазавод Support Air Factory Support'
                elseif cats.FACTORY and cats.AIR and not cats.SUPPORTFACTORY and not cats.RESEARCH then
                    searchAliases = ' Авиационный завод Авиазавод Air Factory'
                end
                record.search = Fold(id .. ' ' .. name .. ' ' .. description .. ' ' .. rawName .. ' ' .. rawDescription .. searchAliases)
                record._sortName = Fold(name)
                -- Engine snapshots normally have one entry per BlueprintId. If aliases
                -- duplicate the same ID, the authoritative ID-keyed entry wins.
                local sourceKey = tostring(key)
                local canonical = sourceKey == id
                local previousKey = sourceKeys[id]
                if not byId[id] or (canonical and previousKey ~= id)
                    or (previousKey ~= id and sourceKey < previousKey) then
                    byId[id] = record
                    sourceKeys[id] = sourceKey
                end
            end
        end
    end
    for _, record in pairs(byId) do table.insert(records, record) end
    table.sort(records, function(a, b)
        if a.faction ~= b.faction then return factionOrder[a.faction] < factionOrder[b.faction] end
        if a.tech ~= b.tech then return techOrder[a.tech] < techOrder[b.tech] end
        local left = a._sortName
        local right = b._sortName
        if left ~= right then return left < right end
        return a.id < b.id
    end)

    local catalog = {}
    ---@param id string
    ---@return table?
    function catalog:Get(id)
        if type(id) ~= 'string' then return nil end
        return byId[string.lower(id)]
    end

    function catalog:DisplayName(name, id, blueprint)
        return DisplayName(String(name), string.lower(String(id)), blueprint)
    end

    ---@param filters? table
    ---@return table[]
    function catalog:List(filters)
        filters = filters or {}
        local search = Fold(String(filters.search))
        local faction = string.upper(String(filters.faction))
        local tech = string.upper(String(filters.tech))
        local kind = string.upper(String(filters.kind))
        local result = {}
        for _, record in ipairs(records) do
            local cats = Categories(record.blueprint)
            if not cats.RESEARCH
                and (faction == '' or faction == 'ALL' or faction == record.faction)
                and (tech == '' or tech == 'ALL' or tech == record.tech)
                and (kind == '' or kind == 'ALL'
                    or (kind == 'STRUCTURE' and (record.kind == 'STRUCTURE'
                        or (record.tech == 'EXPERIMENTAL' and IsEngineerBuildable(cats))))
                    or (kind == 'GATE' and record.kind == 'SACU')
                    or (kind ~= 'STRUCTURE' and kind ~= 'GATE' and kind == record.kind and record.tech ~= 'EXPERIMENTAL'))
                and (search == '' or string.find(record.search, search, 1, true)) then
                table.insert(result, record)
            end
        end
        return result
    end
    return catalog
end
