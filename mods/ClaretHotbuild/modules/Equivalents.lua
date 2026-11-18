-- Read FAF's semantic unit groups as data; never infer equivalence from ID prefixes.
local order = {UEF=1, AEON=2, CYBRAN=3, SERAPHIM=4, OTHER=5}
function Create(catalog, source)
    local groups, byId = {}, {}
    local aliases = {
        T1_Assault_Bot='T1_Tank', T1_Combat_Scout='T1_Land_Scout',
        T3_Armored_Assault_Bot='T3_Heavy_Tank', T3_Tank='T3_Heavy_Tank',
        T2_Mobile_Anti_Air_Cannon='T2_Mobile_AA_Flak_Artillery',
    }
    -- FAF3840 keeps Seraphim's Iashavoh in a separate singleton AA group.
    local additions = {T2_Mobile_AA_Flak_Artillery={'xsl0205'}}
    -- Keep legacy HQ IDs and cross-faction variants resolvable for saved presets.
    local hq = {
        HQ_Land_T2={'ueb0201','uab0201','urb0201','xsb0201'},
        HQ_Air_T2={'ueb0202','uab0202','urb0202','xsb0202'},
        HQ_Naval_T2={'ueb0203','uab0203','urb0203','xsb0203'},
        HQ_Land_T3={'ueb0301','uab0301','urb0301','xsb0301'},
        HQ_Air_T3={'ueb0302','uab0302','urb0302','xsb0302'},
        HQ_Naval_T3={'ueb0303','uab0303','urb0303','xsb0303'},
    }
    local combined={}
    for name,ids in pairs(source or {}) do combined[name]=ids end
    for name,ids in pairs(hq) do combined[name]=ids end
    for name,ids in pairs(additions) do
        local group=combined[name] or {}; local present={}
        for _,id in ipairs(group) do present[id]=true end
        for _,id in ipairs(ids) do if not present[id] then table.insert(group,id); present[id]=true end end
        combined[name]=group
    end
    local names = {}
    for name in pairs(combined) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
        local ids = combined[name]
        local leaf = type(ids) == 'table' and table.getn(ids) > 0
        if leaf then
            for _, id in ipairs(ids) do
                -- Parent hotkey groups contain symbolic references, not blueprints.
                if type(id) ~= 'string' or not string.find(id, '^[a-z]+%d+$') then leaf=false; break end
            end
        end
        if leaf and name ~= 'Experimental' then
            for _, id in ipairs(ids) do
                local r = catalog:Get(id)
                if r and r.faction ~= 'OTHER' then
                    local key = (aliases[name] or name) .. ':' .. r.tech .. ':' .. r.kind
                    groups[key] = groups[key] or {}
                    groups[key][id] = r
                end
            end
        end
    end
    local keys = {}
    for key in pairs(groups) do table.insert(keys,key) end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local list, seen, ambiguous = {}, {}, false
        for _, r in pairs(groups[key]) do
            if seen[r.faction] then ambiguous=true end
            seen[r.faction]=true; table.insert(list,r)
        end
        table.sort(list,function(a,b) return order[a.faction] < order[b.faction] end)
        -- Ambiguous sets must not silently choose one of two different faction units.
        if not ambiguous then
            groups[key]=list
            for _, r in ipairs(list) do if not byId[r.id] then byId[r.id]=key end end
        end
    end
    -- Factory analogues use blueprint roles, so inconsistent localized names
    -- such as “Land Factory” and “Armored Support” do not split the factions.
    local factoryGroups = {}
    for _, record in ipairs(catalog:List()) do
        local bp = record.blueprint or {}
        local categories = rawget(bp, 'CategoriesHash') or {}
        local function Has(category)
            if categories[category] then return true end
            for _, value in ipairs(rawget(bp, 'Categories') or {}) do
                if value == category then return true end
            end
            return false
        end
        if record.kind == 'STRUCTURE' and Has('FACTORY') then
            local environment = Has('AIR') and 'AIR' or Has('LAND') and 'LAND' or Has('NAVAL') and 'NAVAL'
            local role = Has('SUPPORTFACTORY') and 'SUPPORT'
                or Has('RESEARCH') and 'HQ' or 'FACTORY'
            if environment then
                local key = 'ClaretFactory:' .. environment .. ':' .. role .. ':' .. record.tech
                factoryGroups[key] = factoryGroups[key] or {}
                factoryGroups[key][record.id] = record
            end
        end
    end
    for key, byFactoryId in pairs(factoryGroups) do
        local list, seen, ambiguous = {}, {}, false
        for _, record in pairs(byFactoryId) do
            if seen[record.faction] then ambiguous = true end
            seen[record.faction] = true
            table.insert(list, record)
        end
        table.sort(list, function(a, b) return order[a.faction] < order[b.faction] end)
        if not ambiguous and table.getn(list) > 1 then
            groups[key] = list
            for _, record in ipairs(list) do byId[record.id] = key end
        end
    end
    local result = {}
    function result:Key(id)
        local record=catalog:Get(id)
        if record and record.templateData and rawget(catalog,'TemplateKey') then return catalog:TemplateKey(id) end
        return byId[id] or ('single:' .. id)
    end
    function result:Variants(id)
        local record=catalog:Get(id)
        if record and record.templateData and rawget(catalog,'TemplateVariants') then return catalog:TemplateVariants(id) end
        local key=byId[id]
        local list={}
        if key then for _,r in ipairs(groups[key]) do table.insert(list,r) end
        else local r=catalog:Get(id); if r then table.insert(list,r) end end
        return list
    end
    -- Only adjacent variants collapse. Existing custom priorities never get reordered.
    function result:Rows(entries)
        local rows={}
        for i,e in ipairs(entries) do
            local key=e.kind=='blueprint' and self:Key(e.id) or ('action:' .. e.id)
            local previous=rows[table.getn(rows)]
            if previous and previous.key==key then
                previous.last=i; table.insert(previous.entries,e)
            else table.insert(rows,{key=key,first=i,last=i,entries={e}}) end
        end
        return rows
    end
    return result
end
