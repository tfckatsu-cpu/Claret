local function T(key, first)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key, first) end
    return key
end
local function SearchText(key)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.SearchText)=='function' then return localization.SearchText(key) end
    return T(key)
end

-- Saved FAF factory queue templates (profile key build_templates_factory) as
-- stable, data-only catalog records. Names and list positions are excluded from
-- identity; member units, their order and their counts are not.
local WARN = WARN or function() end
local LOG = LOG or function() end
local noTemplatesLogged = false
local MAX_ENTRIES = 64
local MAX_UNITS = 500
local factionNames = {UEF=true, AEON=true, CYBRAN=true, SERAPHIM=true}
local unitKinds = {LAND=true, AIR=true, NAVAL=true, SACU=true}
local ranks = {T1=1, T2=2, T3=3, EXPERIMENTAL=4, OTHER=0}

local function Fold(value)
    return (string.gsub(string.lower(value),'\208[\129\144-\175]',function(letter)
        local b=string.byte(letter,2)
        if b==129 then return string.char(209,145) end
        if b<160 then return string.char(208,b+32) end
        return string.char(209,b-32)
    end))
end
local function Identifier(value)
    return type(value)=='string' and string.len(value)<=96
        and string.find(value,'^[%w_][%w_%-]*$')~=nil
end
-- A structure inside a factory queue is a factory upgrade the queue builds first.
local function IsUpgrade(record)
    local bp=record and record.blueprint
    local general=type(bp)=='table' and rawget(bp,'General') or nil
    local from=type(general)=='table' and rawget(general,'UpgradesFrom') or nil
    return type(from)=='string' and from~='' and from~='none'
end

local function Parse(value, base)
    if type(value)~='table' or type(value.templateData)~='table' then WARN('[ClaretHotbuild] Unit template rejected: missing data') return nil end
    local source=value.templateData
    local count=table.getn(source)
    if count<1 or count>MAX_ENTRIES then WARN('[ClaretHotbuild] Unit template rejected: entries '..tostring(count)) return nil end
    for key in pairs(source) do
        if type(key)~='number' or key~=math.floor(key) or key<1 or key>count then WARN('[ClaretHotbuild] Unit template rejected: data key '..tostring(key)) return nil end
    end
    local entries,signature={},{}
    local faction,kind,first,icon
    local maxRank,tech=0,'OTHER'
    local total=0
    for index=1,count do
        local item=source[index]
        if type(item)~='table' then WARN('[ClaretHotbuild] Unit template rejected: entry '..index) return nil end
        local id=type(item.id)=='string' and string.lower(item.id) or nil
        if not Identifier(id) then WARN('[ClaretHotbuild] Unit template rejected: entry id '..index) return nil end
        local amount=item.count
        if amount==nil then amount=1 end
        if type(amount)~='number' or amount~=amount or amount<1 or amount>MAX_UNITS or amount~=math.floor(amount) then
            WARN('[ClaretHotbuild] Unit template rejected: entry count '..id..' '..tostring(amount)) return nil
        end
        local record=base:Get(id)
        if not record or record.faction=='OTHER' or not factionNames[record.faction] then
            WARN('[ClaretHotbuild] Unit template blueprint unavailable: '..id) return nil
        end
        local upgrade=record.kind=='STRUCTURE'
        if upgrade then
            -- Only factory upgrades may appear as structures in a queue.
            if not IsUpgrade(record) then WARN('[ClaretHotbuild] Unit template rejected: structure '..id) return nil end
        elseif not unitKinds[record.kind] then
            WARN('[ClaretHotbuild] Unit template rejected: unit kind '..tostring(record.kind)..' '..id) return nil
        elseif kind and kind~=record.kind then
            WARN('[ClaretHotbuild] Unit template rejected: mixed kinds '..kind..' '..record.kind) return nil
        else
            kind=record.kind
        end
        if faction and faction~=record.faction then WARN('[ClaretHotbuild] Unit template rejected: mixed factions '..faction..' '..record.faction..' '..id) return nil end
        faction=record.faction
        -- Default names and icons describe the first unit, not a leading upgrade.
        if not upgrade then
            first=first or record
            icon=icon or id
        end
        total=total+amount
        if total>MAX_UNITS then WARN('[ClaretHotbuild] Unit template rejected: unit count '..tostring(total)) return nil end
        local rank=ranks[record.tech] or 0
        if rank>maxRank then maxRank=rank; tech=record.tech end
        table.insert(entries,{id,amount,upgrade})
        table.insert(signature,id..':'..tostring(amount))
    end
    if not kind or not first or not icon then WARN('[ClaretHotbuild] Unit template rejected: no units') return nil end
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
    if name=='' then name=T('hotbuild.templates.s001')..first.name end
    local iconId=type(value.icon)=='string' and string.lower(value.icon) or nil
    if not iconId or not base:Get(iconId) then iconId=icon end
    return {id='claret_unit_template_'..string.format('%08x%08x',a,b),name=name,
        description=T('hotbuild.templates.s005')..total..T('hotbuild.templates.s006'),
        faction=faction,tech=tech,kind=kind,icon='/icons/units/'..iconId..'_icon.dds',
        unitTemplate=true,queueData=entries,unitCount=total,signature=serialized,
        search=Fold(name..' '..SearchText('hotbuild.templates.s007'))}
end

-- Wraps the construction template catalog so both template kinds share one API.
-- Queue templates stay faction-bound: no cross-faction variants are created.
function Create(base, source)
    local records,byId={},{}
    local result={}
    local function Add(record)
        local previous=byId[record.id]
        if previous and previous.signature~=record.signature then
            WARN('[ClaretHotbuild] Unit template ID collision: '..record.id); byId[record.id]=false
        elseif previous==nil then
            byId[record.id]=record
        end
    end
    function result:RefreshTemplates()
        local refresh=rawget(base,'RefreshTemplates')
        if type(refresh)=='function' then base:RefreshTemplates() end
        records,byId={},{}
        local values=type(source)=='function' and source() or nil
        if values==nil or (type(values)=='table' and table.getn(values)==0) then
            if not noTemplatesLogged then
                LOG('[ClaretHotbuild] no factory queue templates in profile')
                noTemplatesLogged=true
            end
            return
        end
        if type(values)~='table' then
            LOG('[ClaretHotbuild] Factory queue templates unavailable in current profile: '..type(values))
            return
        end
        for _,value in ipairs(values) do
            local record=Parse(value,base)
            if record then Add(record) end
        end
        for _,record in pairs(byId) do if record then table.insert(records,record) end end
        table.sort(records,function(a,b) if a.name~=b.name then return a.name<b.name end; return a.id<b.id end)
        LOG('[ClaretHotbuild] Unit templates loaded: source='..table.getn(values)..', available='..table.getn(records))
    end
    function result:Get(id) return base:Get(id) or byId[id] or nil end
    function result:DisplayName(name,id,blueprint) return base:DisplayName(name,id,blueprint) end
    function result:List(filters)
        filters=filters or {}
        local list=base:List(filters)
        local search=Fold(type(filters.search)=='string' and filters.search or '')
        local faction=string.upper(type(filters.faction)=='string' and filters.faction or '')
        local tech=string.upper(type(filters.tech)=='string' and filters.tech or '')
        local kind=string.upper(type(filters.kind)=='string' and filters.kind or '')
        for _,record in ipairs(records) do
            if (faction=='' or faction=='ALL' or faction==record.faction)
                and (tech=='' or tech=='ALL' or tech==record.tech)
                and (kind=='' or kind=='ALL'
                    or (kind=='GATE' and record.kind=='SACU')
                    or (kind~='GATE' and kind==record.kind))
                and (search=='' or string.find(record.search,search,1,true)) then
                table.insert(list,record)
            end
        end
        return list
    end
    result:RefreshTemplates()
    return result
end
