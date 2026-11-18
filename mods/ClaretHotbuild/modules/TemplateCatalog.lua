local function T(key, first, second, third)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key, first, second, third) end
    return key
end
local function SearchText(key)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.SearchText)=='function' then return localization.SearchText(key) end
    return T(key)
end

-- Saved FAF construction templates represented as stable, data-only catalog records.
-- Names and list positions are deliberately excluded from identity.
local WARN = WARN or function() end
local LOG = LOG or function() end
local noTemplatesLogged = false
local function Number(value)
    return type(value)=='number' and value==value and math.abs(value)<=10000
end
local function Fold(value)
    return (string.gsub(string.lower(value),'\208[\129\144-\175]',function(letter)
        local b=string.byte(letter,2)
        if b==129 then return string.char(209,145) end
        if b<160 then return string.char(208,b+32) end
        return string.char(209,b-32)
    end))
end
local function Parse(value,base)
    if type(value)~='table' or type(value.templateData)~='table' then WARN('[ClaretHotbuild] Template rejected: missing data') return nil end
    local source=value.templateData
    local count=table.getn(source)
    if count<3 or count>4098 or not Number(source[1]) or not Number(source[2]) then WARN('[ClaretHotbuild] Template rejected: dimensions/count '..tostring(count)..' '..tostring(source[1])..' '..tostring(source[2])) return nil end
    for key in pairs(source) do
        if type(key)~='number' or key~=math.floor(key) or key<1 or key>count then WARN('[ClaretHotbuild] Template rejected: data key '..tostring(key)) return nil end
    end
    local data={source[1],source[2]}
    local signature={tostring(source[1]),tostring(source[2])}
    local faction,icon,first
    local maxTech,tech=0,'OTHER'
    local ranks={T1=1,T2=2,T3=3,EXPERIMENTAL=4,OTHER=0}
    for index=3,count do
        local entry=source[index]
        if type(entry)~='table' or type(entry[1])~='string'
            or type(entry[2])~='number' or entry[2]~=entry[2] or not Number(entry[3]) or not Number(entry[4]) then WARN('[ClaretHotbuild] Template rejected: entry '..index) return nil end
        for key in pairs(entry) do if key~=1 and key~=2 and key~=3 and key~=4 then WARN('[ClaretHotbuild] Template rejected: entry key '..tostring(key)) return nil end end
        local id=string.lower(entry[1]); local record=base:Get(id)
        if not record or record.kind~='STRUCTURE' or record.faction=='OTHER' then
            WARN('[ClaretHotbuild] Template blueprint unavailable: '..id)
            return nil
        end
        if faction and faction~=record.faction then WARN('[ClaretHotbuild] Template rejected: mixed factions '..faction..' '..record.faction..' '..id) return nil end
        faction=record.faction; icon=icon or record.icon; first=first or id
        if ranks[record.tech]>maxTech then maxTech=ranks[record.tech]; tech=record.tech end
        table.insert(data,{id,entry[2],entry[3],entry[4]})
        table.insert(signature,id..':'..tostring(entry[2])..':'..tostring(entry[3])..':'..tostring(entry[4]))
    end
    local serialized=table.concat(signature,'|')
    local a,b=1,7
    for i=1,string.len(serialized) do
        local byte=string.byte(serialized,i)
        -- FAF Lua uses single-precision numbers: keep intermediate integers
        -- below 2^24 so every byte affects the resulting identifier.
        a=math.mod(a*131+byte,65521); b=math.mod(b*137+byte,65519)
    end
    local name=type(value.name)=='string' and value.name or ''
    name=string.gsub(string.gsub(name,'^%s+',''),'%s+$','')
    if name=='' then name=T('hotbuild.templates.s001')..first end
    local id='claret_template_'..string.format('%08x%08x',a,b)
    return {id=id,name=name,description=T('hotbuild.templates.s002')..(count-2)..T('hotbuild.templates.s003'),
        faction=faction,tech=tech,kind='STRUCTURE',icon=icon,blueprint={},
        templateData=data,firstBlueprint=first,signature=serialized,search=Fold(name..' '..SearchText('hotbuild.templates.s004'))}
end

function Create(base,source,unitGroups)
    local records,byId={},{}
    local families={}
    local equivalents
    if unitGroups then
        equivalents=import('/mods/ClaretHotbuild/modules/Equivalents.lua').Create(base,unitGroups)
    end
    local result={}
    function result:RefreshTemplates()
        records,byId,families={},{},{}
        local values=source()
        if values==nil or (type(values)=='table' and table.getn(values)==0) then
            if not noTemplatesLogged then
                LOG('[ClaretHotbuild] no build templates in profile')
                noTemplatesLogged=true
            end
            return
        end
        if type(values)~='table' then
            LOG('[ClaretHotbuild] Templates unavailable in current profile: '..type(values))
            return
        end
        local function Add(record)
            local previous=byId[record.id]
            if previous and previous.signature~=record.signature then WARN('[ClaretHotbuild] Template ID collision: '..record.id); byId[record.id]=false
            elseif previous==nil then byId[record.id]=record end
        end
        for _,value in ipairs(values) do
            local record=Parse(value,base)
            if record then
                Add(record)
                local family={record.id}
                if equivalents then
                    for _,faction in ipairs({'UEF','AEON','CYBRAN','SERAPHIM'}) do
                        if faction~=record.faction then
                            local data={record.templateData[1],record.templateData[2]}
                            local complete=true
                            for index=3,table.getn(record.templateData) do
                                local cell=record.templateData[index]
                                local target
                                for _,candidate in ipairs(equivalents:Variants(cell[1])) do
                                    if candidate.faction==faction and candidate.kind=='STRUCTURE' then target=candidate end
                                end
                                if not target then complete=false; break end
                                table.insert(data,{target.id,cell[2],cell[3],cell[4]})
                            end
                            if complete then
                                local converted=Parse({name=record.name,templateData=data},base)
                                if converted then Add(converted); table.insert(family,converted.id) end
                            end
                        end
                    end
                end
                table.sort(family)
                for _,id in ipairs(family) do families[id]=family end
            end
        end
        for _,record in pairs(byId) do if record then table.insert(records,record) end end
        table.sort(records,function(a,b) if a.name~=b.name then return a.name<b.name end; return a.id<b.id end)
        LOG('[ClaretHotbuild] Templates loaded: source='..table.getn(values)..', available='..table.getn(records))
    end
    function result:Get(id) return base:Get(id) or byId[id] or nil end
    function result:DisplayName(name,id,blueprint) return base:DisplayName(name,id,blueprint) end
    function result:TemplateVariants(id)
        local list={}
        for _,variant in ipairs(families[id] or {}) do
            local record=byId[variant]
            if record then table.insert(list,record) end
        end
        return list
    end
    function result:TemplateKey(id)
        local family=families[id]
        return family and ('template:'..family[1]) or ('single:'..id)
    end
    function result:List(filters)
        filters=filters or {}
        local list=base:List(filters)
        local search=Fold(type(filters.search)=='string' and filters.search or '')
        for _,record in ipairs(records) do
            if (not filters.faction or filters.faction=='' or filters.faction=='ALL' or filters.faction==record.faction)
                and (not filters.kind or filters.kind=='' or filters.kind=='ALL' or filters.kind=='STRUCTURE')
                and (not filters.tech or filters.tech=='' or filters.tech=='ALL' or filters.tech==record.tech)
                and (search=='' or string.find(record.search,search,1,true)) then table.insert(list,record) end
        end
        return list
    end
    result:RefreshTemplates()
    return result
end
