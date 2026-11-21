local function T(key, first, second, third)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key, first, second, third) end
    return key
end
local function SearchText(key)
    local core=ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.SearchText)=='function' then return localization.SearchText(key) end
    return T(key)
end

-- Native FAF profile bindings used by the main Hotbuild keyboard page.
-- Existing preset and absolute-composite action IDs are intentionally reused.
function Create(runtime)
    local Prefs=import('/lua/user/prefs.lua')
    local Mapper=import('/lua/keymap/keymapper.lua')
    local descriptions=import('/lua/keymap/keydescriptions.lua').keyDescriptions
    local ContextActions=import('/mods/ClaretHotbuild/modules/ContextActions.lua')
    local Compatibility=import('/mods/ClaretHotbuild/modules/Compatibility.lua')
    local service={}
    local actionPrefix='ClaretHotkeyContext_'
    local compositePrefix='ClaretHotkeyComposite_'
    local pairPrefix='ClaretHotkeyPair_'
    local acuOrderTargets={
        overcharge=true, move=true, attack=true, attack_move=true, patrol=true,
        reclaim=true, assist=true, repair=true, capture=true, teleport=true, stop=true,
    }
    local transportOrderTargets={
        move=true, attack=true, attack_move=true, transport_order=true, ferry=true,
        append_transport_cargo=true, dock=true, stop=true, soft_stop=true,
    }
    local doubleTargets={
        select_acu=acuOrderTargets,
        select_acu_only=acuOrderTargets,
        select_transport={select_transport_screen=true,select_transport_map=true},
        select_transport_nearest={select_transport_screen=true,select_transport_map=true},
        select_scout={select_all_scouts=true},
    }
    local transportActions={'append_transport_cargo','ferry','transport_order'}
    local previousTransport={dock=true,dock_damaged=true,append_transport_cargo=true,ferry=true,transport_order=true,load_transports=true,select_transports_accumulate=true}
    local pairWarnings={}
    local quarantinedChords={}
    local rawAssignments
    local managed={}
    doubleTargets.dock={dock_damaged=true}
    doubleTargets.dock_damaged={dock=true}
    for _,first in ipairs(transportActions) do
        local targets={}
        for _,second in ipairs(transportActions) do
            if first~=second then targets[second]=true end
        end
        doubleTargets[first]=targets
    end
    for _,first in ipairs({'select_transport','select_transport_nearest'}) do
        for target in pairs(transportOrderTargets) do
            doubleTargets[first][target]=true
        end
        doubleTargets[first].load_transports=true
    end
    doubleTargets.select_transports_accumulate=transportOrderTargets
    doubleTargets.select_all_idle_transports={load_transports=true}
    local removedDoubleActions={build_storage_nearest=true,build_fabs_nearest=true}
    local profileName='ClaretHotbuildKeyboard'
    local pairsByKey={}
    local pairError

    local function Enc(id)
        return string.gsub(id,'.',function(c) return string.format('%02X',string.byte(c)) end)
    end
    local function Dec(value)
        if type(value)~='string' or math.mod(string.len(value),2)~=0 then return nil end
        local result={}
        for i=1,string.len(value),2 do
            local byte=tonumber(string.sub(value,i,i+1),16); if not byte then return nil end
            table.insert(result,string.char(byte))
        end
        return table.concat(result)
    end
    local function ActionId(ref)
        if ref.kind=='preset' then return 'ClaretHotbuild_'..Enc(ref.id) end
        if ref.kind=='composite' then return ref.legacy and ('ClaretHotbuildAbsolute_'..Enc(ref.id)) or (compositePrefix..Enc(ref.id)) end
        if ref.kind=='action' then return actionPrefix..Enc(ref.id) end
    end
    local function KeyboardCompositeId(ref) return compositePrefix..Enc(ref.id) end
    local function PairId(chord) return pairPrefix..Enc(chord) end
    local function Chord(key,mods)
        local bits={}
        if mods and mods.ctrl then table.insert(bits,'Ctrl') end
        if mods and mods.alt then table.insert(bits,'Alt') end
        if mods and mods.shift then table.insert(bits,'Shift') end
        table.insert(bits,key)
        return Mapper.NormalizeKeyBinding(table.concat(bits,'-'))
    end
    local function Parse(key)
        local normalized=Mapper.NormalizeKeyBinding(key)
        local parsed=Mapper.NormalizeKey(normalized)
        return parsed
    end
    local function Label(ref)
        if ref.kind=='pair' then
            local pair=pairsByKey[ref.id] or {}
            local preset=pair.preset and Label({kind='preset',id=pair.preset})
            local composite=pair.composite and Label({kind='composite',id=pair.composite})
            local action=pair.action and Label({kind='action',id=pair.action})
            local label=preset and composite and (preset..' · '..composite) or preset or composite
            if action then label=label and (label..' · '..action) or action end
            return label or ref.id
        end
        if ref.kind=='preset' then local b=runtime.model:Get(ref.id); return b and b.name or ref.id end
        if ref.kind=='composite' then local b=runtime.contextModel:Get(ref.id); return b and b.name or ref.id end
        if ref.kind=='action' then local a=ContextActions.Get(ref.id); return a and ((a.id=='smart_missile' and T('hotbuild.keyboard_bindings.s001') or a.label)..(a.obsolete and T('hotbuild.keyboard_bindings.s002') or '')) or ref.id end
        return ref.id or T('hotbuild.keyboard_bindings.s003')
    end
    local function GetMap(name) return Prefs.GetFromCurrentProfile(name) or {} end
    local function CopyMap(value)
        if type(value)~='table' then return value end
        local result={}; for key,item in pairs(value) do result[key]=item end
        return result
    end
    local function CurrentMap() return type(Mapper.GetCurrentKeyMap)=='function' and (Mapper.GetCurrentKeyMap() or {}) or {} end
    local function DebugMap() return type(Mapper.GetUserDebugKeyMap)=='function' and (Mapper.GetUserDebugKeyMap() or {}) or {} end
    local function AllMaps() return {GetMap('UserKeyMap'),GetMap('UserDebugKeyMap'),CurrentMap(),DebugMap()} end
    local function OwnIds()
        local ids={}
        for chord in pairs(pairsByKey) do ids[PairId(chord)]={kind='pair',id=chord} end
        for _,b in ipairs(runtime.model:List()) do ids[ActionId({kind='preset',id=b.id})]={kind='preset',id=b.id} end
        for _,b in ipairs(runtime.contextModel:List()) do
            local ref={kind='composite',id=b.id}
            ids['ClaretHotbuildAbsolute_'..Enc(ref.id)]={kind='composite',id=ref.id,legacy=true} -- Keep disabled absolute links visible and inert.
            ids[KeyboardCompositeId(ref)]=ref
        end
        for _,a in ipairs(ContextActions.List()) do ids[ActionId({kind='action',id=a.id})]={kind='action',id=a.id} end
        for _,map in ipairs({GetMap('UserKeyMap'),GetMap('UserDebugKeyMap')}) do
            for _,id in pairs(map) do
                local prefix='ClaretHotbuildAbsolute_'
                if type(id)=='string' and string.sub(id,1,string.len(prefix))==prefix and not ids[id] then
                    local decoded=Dec(string.sub(id,string.len(prefix)+1))
                    if decoded then ids[id]={kind='composite',id=decoded,legacy=true} end
                end
                -- Preserve direct action IDs that were saved by older catalogs
                -- but are no longer returned by ContextActions.List().
                local directPrefix=actionPrefix
                if type(id)=='string' and string.sub(id,1,string.len(directPrefix))==directPrefix and not ids[id] then
                    local decoded=Dec(string.sub(id,string.len(directPrefix)+1))
                    if decoded and ContextActions.Get(decoded) then
                        ids[id]={kind='action',id=decoded,legacy=true}
                    end
                end
            end
        end
        return ids
    end
    local function Register(id,ref)
        local label=Label(ref)
        local script
        if ref.kind=='pair' then script=string.format('UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").ExecuteKeyboardPair(%q, IsKeyDown(16))',ref.id)
        elseif ref.kind=='preset' then script=string.format('UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").Execute(%q, IsKeyDown(16))',ref.id)
        elseif ref.kind=='composite' then
            if id=='ClaretHotbuildAbsolute_'..Enc(ref.id) then
                script=string.format('UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").ExecuteAbsolute(%q)',ref.id)
            else
                script=string.format('UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").ExecuteKeyboardComposite(%q)',ref.id)
            end
        else script=string.format('UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").ExecuteKeyboardAction(%q)',ref.id) end
        local definition={action=script,category='Claret Hotbuild'}
        Mapper.SetUserKeyAction(id,definition)
        descriptions[id]=label
    end
    local function OwnKeys(id)
        local result={}
        for _,map in ipairs({GetMap('UserKeyMap'),GetMap('UserDebugKeyMap')}) do
            for key,action in pairs(map) do if action==id then table.insert(result,key) end end
        end
        return result
    end
    local function Candidate(ref)
        if type(ref)~='table' or type(ref.kind)~='string' or type(ref.id)~='string' then return false end
        if ref.kind=='preset' then return runtime.model:Get(ref.id)~=nil end
        if ref.kind=='composite' then return ref.legacy==true or runtime.contextModel:Get(ref.id)~=nil end
        if ref.kind=='action' then local action=ContextActions.Get(ref.id); return action~=nil and not action.obsolete end
        return false
    end
    local function ForeignAt(chord,except)
        for _,map in ipairs(AllMaps()) do
            for key,id in pairs(map) do
                if Mapper.NormalizeKeyBinding(key)==chord and id~=except then return id end
            end
        end
        local generated=type(Mapper.GenerateHotbuildModifiers)=='function' and (Mapper.GenerateHotbuildModifiers() or {}) or {}
        for key in pairs(generated) do
            if Mapper.NormalizeKeyBinding(key)==chord then return 'Hotbuild modifier' end
        end
    end
    local PairIsMapped
    local function WithShift(chord)
        local parts={}
        for part in string.gmatch(chord,'[^%-]+') do table.insert(parts,part) end
        if table.getn(parts)<1 then return nil end
        local key=table.remove(parts)
        for _,modifier in ipairs(parts) do if modifier=='Shift' then return nil end end
        table.insert(parts,'Shift')
        table.insert(parts,key)
        return Mapper.NormalizeKeyBinding(table.concat(parts,'-'))
    end
    local function FactoryShiftOverrides()
        local generated=type(Mapper.GenerateHotbuildModifiers)=='function'
            and (Mapper.GenerateHotbuildModifiers() or {}) or {}
        local generatedByChord={}
        for key,definition in pairs(generated) do
            local normalized=Mapper.NormalizeKeyBinding(key)
            if normalized then generatedByChord[normalized]=definition end
        end
        local overrides={}
        for chord,pair in pairs(pairsByKey) do
            if pair.preset and PairIsMapped(chord) then
                local shifted=WithShift(chord)
                local native=shifted and generatedByChord[shifted]
                local userOwnsShifted=false
                if shifted then
                    for _,map in ipairs({GetMap('UserKeyMap'),GetMap('UserDebugKeyMap')}) do
                        for key in pairs(map) do
                            if Mapper.NormalizeKeyBinding(key)==shifted then userOwnsShifted=true; break end
                        end
                        if userOwnsShifted then break end
                    end
                end
                if shifted and not userOwnsShifted then
                    local fallback=type(native)=='table' and type(native.action)=='string' and native.action
                        or string.format(
                            'UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").ExecuteKeyboardPair(%q,false)',
                            chord)
                    local copy={category='Claret Hotbuild'}
                    if type(native)=='table' then
                        for field,value in pairs(native) do copy[field]=value end
                    end
                    copy.action=string.format(
                        'UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").ExecuteFactoryShift(%q,%q)',
                        chord,fallback)
                    overrides[shifted]=copy
                end
            end
        end
        return overrides
    end
    local function CopyPairs(source)
        local result={}
        for chord,pair in pairs(source) do result[chord]={preset=pair.preset,composite=pair.composite,action=pair.action,doubleFirst=pair.doubleFirst,doubleSecond=pair.doubleSecond} end
        return result
    end
    local function LoadPairs()
        local saved=Prefs.GetFromCurrentProfile(profileName)
        rawAssignments=nil
        if saved==nil then return {} end
        if type(saved)~='table' or (saved.version~=1 and saved.version~=2) or type(saved.assignments)~='table' then
            return nil,nil,T('hotbuild.keyboard_bindings.s004')
        end
        for field in pairs(saved) do
            if field~='version' and field~='assignments' then return nil,nil,T('hotbuild.keyboard_bindings.s004') end
        end
        rawAssignments=saved.assignments
        quarantinedChords={}
        local result,warnings={},{}
        for chord,pair in pairs(saved.assignments) do
            local reason
            if type(chord)~='string' or chord=='' or Mapper.NormalizeKeyBinding(chord)~=chord then
                reason='invalid key chord'
            elseif type(pair)~='table' then
                reason='invalid assignment record'
            else
                for field,value in pairs(pair) do
                    if field~='preset' and field~='composite' and field~='action' and field~='doubleFirst' and field~='doubleSecond' then
                        reason='unknown assignment field: '..tostring(field); break
                    end
                    if type(value)~='string' or value=='' then
                        reason='invalid assignment field: '..tostring(field); break
                    end
                end
            end
            if not reason and (pair.doubleFirst==nil)~=(pair.doubleSecond==nil) then
                reason='incomplete double assignment'
            end
            local doubleFirst,doubleSecond
            if not reason then
                doubleFirst=pair.doubleFirst
                doubleSecond=pair.doubleSecond
                if removedDoubleActions[doubleFirst] or removedDoubleActions[doubleSecond] then
                    doubleFirst=nil
                    doubleSecond=nil
                end
                if doubleFirst and not (doubleTargets[doubleFirst] and doubleTargets[doubleFirst][doubleSecond])
                    and not (previousTransport[doubleFirst] and previousTransport[doubleSecond] and doubleFirst~=doubleSecond) then
                    reason='incompatible double assignment'
                end
            end
            if reason then
                if type(chord)=='string' then quarantinedChords[chord]=true end
                table.insert(warnings, {chord=tostring(chord),reason=reason})
            elseif pair.preset or pair.composite or pair.action or doubleFirst then
                result[chord]={preset=pair.preset,composite=pair.composite,action=pair.action,doubleFirst=doubleFirst,doubleSecond=doubleSecond}
                managed[chord]=true
            end
        end
        return result,warnings
    end
    -- Quarantined raw records are merged back verbatim; only managed chords
    -- removed by the user disappear from the saved profile.
    local function Profile(pairsValue)
        local assignments={}
        for chord,pair in pairs(rawAssignments or {}) do assignments[chord]=pair end
        for chord in pairs(managed) do
            if not pairsValue[chord] then assignments[chord]=nil end
        end
        for chord,pair in pairs(pairsValue) do
            managed[chord]=true
            assignments[chord]={preset=pair.preset,composite=pair.composite,action=pair.action,doubleFirst=pair.doubleFirst,doubleSecond=pair.doubleSecond}
        end
        return {version=2,assignments=assignments}
    end
    local function Migrate()
        local loaded,warnings,shapeError=LoadPairs()
        pairWarnings=warnings or {}
        if not loaded then pairError=shapeError or T('hotbuild.keyboard_bindings.s004'); pairsByKey={}; return end
        pairsByKey=loaded
        local maps={CopyMap(Prefs.GetFromCurrentProfile('UserKeyMap') or CurrentMap()) or {},
            CopyMap(Prefs.GetFromCurrentProfile('UserDebugKeyMap') or DebugMap()) or {}}
        local proposed=CopyPairs(loaded)
        local ids=OwnIds()
        local changed=false
        for _,map in ipairs(maps) do
            for key,id in pairs(map) do
                local ref=ids[id]
                if type(id)=='string' and string.sub(id,1,string.len(pairPrefix))==pairPrefix then
                    local decoded=Dec(string.sub(id,string.len(pairPrefix)+1))
                    if decoded and quarantinedChords[decoded] then
                        -- The raw pair record stays quarantined; its assignment is kept as is.
                    else
                        local chord=Mapper.NormalizeKeyBinding(key)
                        if not ref or ref.kind~='pair' or ref.id~=chord then
                            pairError=T('hotbuild.keyboard_bindings.s006')..chord..T('hotbuild.keyboard_bindings.s007'); return
                        end
                    end
                end
                if ref and (ref.kind=='preset' or (ref.kind=='composite' and not ref.legacy)) then
                    local chord=Mapper.NormalizeKeyBinding(key)
                    local pair
                    if ref.kind=='preset' then
                        local preset=runtime.model:Get(ref.id)
                        pair={preset=ref.id,composite=preset and preset.grid and preset.grid.context}
                    else pair={composite=ref.id} end
                    local existing=proposed[chord]
                    if existing and (existing.preset~=pair.preset or existing.composite~=pair.composite) then
                        pairError=T('hotbuild.keyboard_bindings.s008')..chord..T('hotbuild.keyboard_bindings.s009'); return
                    end
                    local old=proposed[chord]
                    if old then pair.doubleFirst=old.doubleFirst; pair.doubleSecond=old.doubleSecond; pair.action=old.action end
                    proposed[chord]=pair
                    map[key]=PairId(chord); changed=true
                end
            end
        end
        if not changed then return end
        local beforeProfile=Prefs.GetFromCurrentProfile(profileName)
        local beforeUser=Prefs.GetFromCurrentProfile('UserKeyMap')
        local beforeDebug=Prefs.GetFromCurrentProfile('UserDebugKeyMap')
        local beforeActions=CopyMap(Prefs.GetFromCurrentProfile('UserKeyActions'))
        local beforeDescriptions=CopyMap(descriptions)
        local ok,err=pcall(function()
            pairsByKey=proposed
            Prefs.SetToCurrentProfile(profileName,Profile(proposed))
            Prefs.SetToCurrentProfile('UserKeyMap',maps[1]); Prefs.SetToCurrentProfile('UserDebugKeyMap',maps[2])
            for chord in pairs(proposed) do Register(PairId(chord),{kind='pair',id=chord}) end
            SavePreferences()
        end)
        if not ok then
            pairsByKey=loaded
            Prefs.SetToCurrentProfile(profileName,beforeProfile)
            Prefs.SetToCurrentProfile('UserKeyMap',beforeUser); Prefs.SetToCurrentProfile('UserDebugKeyMap',beforeDebug)
            Prefs.SetToCurrentProfile('UserKeyActions',beforeActions)
            for id in pairs(descriptions) do descriptions[id]=nil end
            for id,value in pairs(beforeDescriptions or {}) do descriptions[id]=value end
            pcall(SavePreferences)
            pairError=T('hotbuild.keyboard_bindings.s010')..tostring(err)
        end
    end
    function service:GetPair(chord)
        local pair=pairsByKey[chord]
        return pair and {preset=pair.preset,composite=pair.composite,action=pair.action,doubleFirst=pair.doubleFirst,doubleSecond=pair.doubleSecond} or nil
    end
    function service:GetDoubleForKey(key,mods)
        local chord=Chord(key,mods); local pair=chord and pairsByKey[chord]
        return pair and pair.doubleFirst and {first=pair.doubleFirst,second=pair.doubleSecond} or nil
    end
    function service:GetDouble(chord)
        local pair=pairsByKey[chord]
        return pair and pair.doubleFirst and {first=pair.doubleFirst,second=pair.doubleSecond} or nil
    end
    function service:GetDoubleChoices(actionId)
        local result={}; for target in pairs(doubleTargets[actionId] or {}) do
            local action=ContextActions.Get(target); if action and not action.obsolete then table.insert(result,{id=target,label=action.label}) end
        end
        table.sort(result,function(a,b) return a.id<b.id end); return result
    end
    function service:SetDoubleForKey(key,mods,first,second)
        if pairError then return false,pairError end
        local chord=Chord(key,mods); local allowed=doubleTargets[first]
        if not chord or not allowed or not allowed[second] then return false,T('hotbuild.keyboard_bindings.s011') end
        local secondAction=ContextActions.Get(second)
        if not secondAction or secondAction.obsolete then return false,T('hotbuild.keyboard_bindings.s011') end
        local mapped=CurrentMap(); local id
        for mappedKey,value in pairs(mapped) do
            if Mapper.NormalizeKeyBinding(mappedKey)==chord then id=value; break end
        end
        local ref=id and OwnIds()[id]
        local pair=pairsByKey[chord]
        local assignedAction=pair and pair.action or (ref and ref.kind=='action' and ref.id)
        if assignedAction~=first then return false,T('hotbuild.keyboard_bindings.s012') end
        local proposed=CopyPairs(pairsByKey); pair=proposed[chord] or {}
        pair.doubleFirst=first; pair.doubleSecond=second; proposed[chord]=pair
        local beforePairs=CopyPairs(pairsByKey)
        local before=Prefs.GetFromCurrentProfile(profileName)
        local ok,err=pcall(function() pairsByKey=proposed; Prefs.SetToCurrentProfile(profileName,Profile(proposed)); SavePreferences() end)
        if not ok then pairsByKey=beforePairs; Prefs.SetToCurrentProfile(profileName,before); return false,T('hotbuild.keyboard_bindings.s013')..tostring(err) end
        return true
    end
    function service:ClearDoubleForKey(key,mods)
        if pairError then return false,pairError end
        local chord=Chord(key,mods); local old=pairsByKey[chord]
        if not old or not old.doubleFirst then return true end
        local proposed=CopyPairs(pairsByKey); local pair=proposed[chord]
        pair.doubleFirst=nil; pair.doubleSecond=nil
        if not pair.preset and not pair.composite and not pair.action then proposed[chord]=nil end
        local beforePairs=CopyPairs(pairsByKey)
        local before=Prefs.GetFromCurrentProfile(profileName)
        local ok,err=pcall(function() pairsByKey=proposed; Prefs.SetToCurrentProfile(profileName,Profile(proposed)); SavePreferences() end)
        if not ok then pairsByKey=beforePairs; Prefs.SetToCurrentProfile(profileName,before); return false,T('hotbuild.keyboard_bindings.s014')..tostring(err) end
        return true
    end
    function service:GetPairError() return pairError end
    function service:GetPairWarnings()
        local result={}
        for i,warning in ipairs(pairWarnings) do result[i]={chord=warning.chord,reason=warning.reason} end
        return result
    end
    PairIsMapped=function(chord)
        local id=PairId(chord)
        for _,map in ipairs({GetMap('UserKeyMap'),GetMap('UserDebugKeyMap')}) do
            for key,value in pairs(map) do
                if Mapper.NormalizeKeyBinding(key)==chord then
                    if value==id then return true end
                    local pair=pairsByKey[chord]
                    local ref=OwnIds()[value]
                    if pair and pair.doubleFirst and ref and ref.kind=='action' and ref.id==pair.doubleFirst then return true end
                end
            end
        end
        return false
    end
    function service:PairedBindings(model)
        local result={}
        for chord,pair in pairs(pairsByKey) do
            local binding=pair.preset and model:Get(pair.preset)
            if binding and pair.composite and PairIsMapped(chord) then
                binding.grid=binding.grid or {buildings={},units={}}
                binding.grid.context=pair.composite; binding.key=chord
                table.insert(result,binding)
            end
        end
        return result
    end
    function service:Validate(ref,key,mods)
        if pairError then return false,pairError end
        if not Candidate(ref) then return false,T('hotbuild.keyboard_bindings.s015') end
        if ref.legacy then return false,T('hotbuild.keyboard_bindings.s016') end
        local chord=Chord(key,mods)
        if not chord or chord=='' then return false,T('hotbuild.keyboard_bindings.s017') end
        local pair=pairsByKey[chord]
        if pair and not PairIsMapped(chord) then
            local occupant
            for _,map in ipairs(AllMaps()) do
                for mappedKey,id in pairs(map) do
                    if Mapper.NormalizeKeyBinding(mappedKey)==chord then
                        if occupant and occupant~=id then return false,T('hotbuild.keyboard_bindings.s018') end
                        occupant=id
                    end
                end
            end
            local generated=not occupant and ForeignAt(chord,PairId(chord))=='Hotbuild modifier'
            local label=generated and T('hotbuild.keyboard_bindings.s019')
                or (occupant and (Mapper.GetActionName(occupant) or occupant))
            local message=label and (T('hotbuild.keyboard_bindings.s020')..tostring(label)..'?')
                or T('hotbuild.keyboard_bindings.s021')
            return false,message,{kind='conflict',id='stale:'..chord}
        end
        local except=pair and PairId(chord) or (ref.kind=='action' and ActionId(ref) or PairId(chord))
        local foreign=ForeignAt(chord,except)
        if foreign and (ref.kind=='preset' or ref.kind=='composite') then
            local existing=OwnIds()[foreign]
            if existing and (existing.kind=='action' or existing.kind=='composite') then foreign=nil end
        end
        if foreign and ref.kind=='action' then
            local existing=OwnIds()[foreign]
            if existing and existing.kind=='composite' then foreign=nil end
        end
        if foreign=='Hotbuild modifier' then
            return false,T('hotbuild.keyboard_bindings.s022'),
                {kind='conflict',id=foreign}
        end
        if ref.kind=='preset' or ref.kind=='composite' then
            local presetId=ref.kind=='preset' and ref.id or (pair and pair.preset)
            local contextId=ref.kind=='composite' and ref.id or (pair and pair.composite)
            if presetId and contextId then
                local preset=runtime.model:Get(presetId)
                if not preset then return false,T('hotbuild.keyboard_bindings.s023') end
                preset.grid=preset.grid or {buildings={},units={}}
                preset.grid.context=contextId
                local valid,_,details=Compatibility.ValidateBinding(preset,runtime.contextModel,runtime:Catalog())
                if not valid then
                    local kind=details and details.kind
                    if kind=='build_context' then return false,T('hotbuild.keyboard_bindings.s024') end
                    if kind=='factory' then return false,T('hotbuild.keyboard_bindings.s025') end
                    if kind=='absolute_link' then return false,T('hotbuild.keyboard_bindings.s026') end
                    return false,T('hotbuild.keyboard_bindings.s027')
                end
            end
        end
        if foreign then
            for _,map in ipairs(AllMaps()) do
                for mappedKey,id in pairs(map) do
                    if Mapper.NormalizeKeyBinding(mappedKey)==chord and id~=except and id~=foreign then
                        return false,T('hotbuild.keyboard_bindings.s028')
                    end
                end
            end
            return false,T('hotbuild.keyboard_bindings.s029')..tostring(Mapper.GetActionName(foreign) or foreign),{kind='conflict',id=foreign}
        end
        return true
    end
    local function Snapshot(includeForeign,perf)
        local snapshotStart=perf and perf:Now()
        local result,seen,labels={},{},{}
        if perf then perf.totals.own_ids=0; perf.totals.labels=0 end
        local maps=AllMaps()
        local ownStart=perf and perf:Now()
        local ids=OwnIds()
        if perf then perf:Add('own_ids',ownStart) end
        for _,map in ipairs(maps) do
            for key,id in pairs(map) do
                local ref=ids[id]
                if ref then
                    local normalized=Mapper.NormalizeKeyBinding(key)
                    local parsed=Mapper.NormalizeKey(normalized)
                    local token=normalized..'|'..id
                    if not seen[token] then
                        seen[token]=true
                        local label=labels[id]
                        if not label then
                            local labelStart=perf and perf:Now(); label=Label(ref)
                            if perf then perf:Add('labels',labelStart) end
                            labels[id]=label
                        end
                        local context=ref.kind=='action' and (ContextActions.Get(ref.id).contexts or {}) or nil
                        local linkedLabel,linkedRef,presetLabel
                        if ref.kind=='pair' then
                            local pair=pairsByKey[ref.id]
                            if pair.preset then
                                ref={kind='preset',id=pair.preset}
                                presetLabel=Label(ref)
                                if pair.composite then linkedRef={kind='composite',id=pair.composite}; linkedLabel=Label(linkedRef) end
                                if pair.action then linkedRef={kind='action',id=pair.action}; linkedLabel=Label(linkedRef) end
                            elseif pair.action then ref={kind='action',id=pair.action}
                            else ref={kind='composite',id=pair.composite} end
                        elseif ref.kind=='preset' then
                            presetLabel=label
                            local preset=pairError and runtime.model:Get(ref.id)
                            local linkedId=preset and preset.grid and preset.grid.context
                            local linked=linkedId and runtime.contextModel:Get(linkedId)
                            if linkedId then
                                linkedRef={kind='composite',id=linkedId}
                                linkedLabel=linked and linked.name or (T('hotbuild.keyboard_bindings.s030')..linkedId)
                            end
                            if linked then label=label..' · '..linked.name end
                        end
                        local pair=pairsByKey[normalized]
                        local second=pair and pair.doubleSecond and ContextActions.Get(pair.doubleSecond)
                        local doubleLabel=second and (second.label..(second.obsolete and T('hotbuild.keyboard_bindings.s002') or ''))
                        table.insert(result,{key=parsed.key,modifiers={ctrl=parsed.Ctrl==true,alt=parsed.Alt==true,shift=parsed.Shift==true},ref=ref,label=label,context=context,foreign=false,legacy=ref.legacy==true,tooltip=label,linkedRef=linkedRef,linkedLabel=linkedLabel,presetLabel=presetLabel,doubleLabel=doubleLabel})
                    end
                elseif includeForeign then
                    local normalized=Mapper.NormalizeKeyBinding(key)
                    local parsed=Mapper.NormalizeKey(normalized)
                    local token=normalized..'|'..tostring(id)
                    local actionName=type(Mapper.GetActionName)=='function' and Mapper.GetActionName(id) or nil
                    if not seen[token] then seen[token]=true; table.insert(result,{key=parsed.key,modifiers={ctrl=parsed.Ctrl==true,alt=parsed.Alt==true,shift=parsed.Shift==true},ref={kind='foreign',id=id},label=actionName or tostring(id),foreign=true,tooltip=actionName or tostring(id)}) end
                end
            end
        end
        if perf then
            perf:Add('snapshot_total',snapshotStart)
            perf:Emit('snapshot_total'); perf:Emit('own_ids'); perf:Emit('labels')
        end
        return result
    end
    function service:GetAssignments(perf) return Snapshot(true,perf) end
    function service:KeysFor(ref)
        local result,seen={},{}
        for _,assignment in ipairs(Snapshot(false)) do
            local assigned=assignment.ref
            local matches=assigned and assigned.kind==ref.kind and assigned.id==ref.id
            if ref.kind=='composite' and assignment.linkedRef then matches=assignment.linkedRef.id==ref.id end
            if matches then
                local chord=Chord(assignment.key,assignment.modifiers)
                if not seen[chord] then seen[chord]=true; table.insert(result,chord) end
            end
        end
        table.sort(result)
        return result
    end
    function service:HasAssignment(ref)
        return table.getn(self:KeysFor(ref))>0
    end
    function service:HasDirectAssignment(ref)
        if type(ref)~='table' or ref.kind~='composite' or type(ref.id)~='string' then return false end
        for _,pair in pairs(pairsByKey) do if pair.composite==ref.id then return true end end
        local ids=OwnIds()
        for _,map in ipairs({GetMap('UserKeyMap'),GetMap('UserDebugKeyMap')}) do
            for _,id in pairs(map) do
                local assigned=ids[id]
                if assigned and assigned.kind=='composite' and assigned.id==ref.id then return true end
            end
        end
        return false
    end
    function service:GetChoices()
        local choices={presets={},composites={},actions={}}
        for _,b in ipairs(runtime.model:List()) do table.insert(choices.presets,{ref={kind='preset',id=b.id},label=b.name}) end
        for _,b in ipairs(runtime.contextModel:List()) do table.insert(choices.composites,{ref={kind='composite',id=b.id},label=b.name,absolute=b.absolute==true}) end
        for _,a in ipairs(ContextActions.List()) do
            if not a.legacy and not a.hidden and a.id~='sacu_tech' then
                local label = a.id == 'smart_missile' and T('hotbuild.keyboard_bindings.s031')
                    or T(a.labelKey or a.label or a.id)
                table.insert(choices.actions,{ref={kind='action',id=a.id},label=label,
                    searchLabel=SearchText(a.labelKey or a.label or a.id),context=a.contexts})
            end
        end
        return choices
    end
    local function SamePair(a,b)
        if a==nil or b==nil then return a==b end
        return a.preset==b.preset and a.composite==b.composite and a.action==b.action
            and a.doubleFirst==b.doubleFirst and a.doubleSecond==b.doubleSecond
    end
    local function WritePairs(proposed,extraChanged,cleanupIds,clearAll)
        local changed={}
        for chord in pairs(extraChanged or {}) do changed[chord]=true end
        for chord,pair in pairs(pairsByKey) do if not SamePair(pair,proposed[chord]) then changed[chord]=true end end
        for chord,pair in pairs(proposed) do if not SamePair(pair,pairsByKey[chord]) then changed[chord]=true end end
        if not next(changed) then return true end
        local beforePairs=CopyPairs(pairsByKey)
        local beforeProfile=Prefs.GetFromCurrentProfile(profileName)
        local beforeUser=CopyMap(Prefs.GetFromCurrentProfile('UserKeyMap'))
        local beforeDebug=CopyMap(Prefs.GetFromCurrentProfile('UserDebugKeyMap'))
        local beforeActions=CopyMap(Prefs.GetFromCurrentProfile('UserKeyActions'))
        local beforeDescriptions=CopyMap(descriptions)
        local userMap=CopyMap(beforeUser or CurrentMap()) or {}
        local debugMap=CopyMap(beforeDebug or DebugMap()) or {}
        local good,err=pcall(function()
            pairsByKey=proposed
            Prefs.SetToCurrentProfile(profileName,Profile(proposed))
            for index,name in ipairs({'UserKeyMap','UserDebugKeyMap'}) do
                local map=index==1 and userMap or debugMap
                for existing in pairs(map) do
                    local chord=Mapper.NormalizeKeyBinding(existing)
                    local mappedId=map[existing]
                    if changed[chord] and (clearAll and clearAll[chord] or cleanupIds and cleanupIds[mappedId]
                        or beforePairs[chord] and mappedId==PairId(chord)) then map[existing]=nil end
                end
                Prefs.SetToCurrentProfile(name,map)
            end
            for chord in pairs(changed) do
                if proposed[chord] then
                    local id=PairId(chord)
                    Register(id,{kind='pair',id=chord})
                    Mapper.SetUserKeyMapping(chord,nil,id)
                else Mapper.ClearUserKeyMapping(chord) end
            end
            -- Mapper APIs operate on the active map; restore unrelated debug and
            -- foreign mappings from the profile snapshots after the mutation.
            for chord in pairs(changed) do if proposed[chord] then userMap[chord]=PairId(chord) end end
            Prefs.SetToCurrentProfile('UserKeyMap',userMap)
            Prefs.SetToCurrentProfile('UserDebugKeyMap',debugMap)
            for chord in pairs(changed) do if not proposed[chord] and table.getn(OwnKeys(PairId(chord)))==0 then
                local actions=CopyMap(Prefs.GetFromCurrentProfile('UserKeyActions')) or {}
                actions[PairId(chord)]=nil
                Prefs.SetToCurrentProfile('UserKeyActions',actions)
                descriptions[PairId(chord)]=nil
            end end
            for id in pairs(cleanupIds or {}) do if table.getn(OwnKeys(id))==0 then
                local actions=CopyMap(Prefs.GetFromCurrentProfile('UserKeyActions')) or {}
                actions[id]=nil
                Prefs.SetToCurrentProfile('UserKeyActions',actions)
                descriptions[id]=nil
            end end
            Mapper.SaveUserKeyMap()
            SavePreferences()
            local refreshed,refreshError=service:Refresh(); if refreshed==false then error(refreshError or 'refresh failed') end
        end)
        if not good then
            pairsByKey=beforePairs
            Prefs.SetToCurrentProfile(profileName,beforeProfile)
            Prefs.SetToCurrentProfile('UserKeyMap',beforeUser)
            Prefs.SetToCurrentProfile('UserDebugKeyMap',beforeDebug)
            Prefs.SetToCurrentProfile('UserKeyActions',beforeActions)
            for id in pairs(descriptions) do descriptions[id]=nil end
            for id,value in pairs(beforeDescriptions or {}) do descriptions[id]=value end
            pcall(SavePreferences)
            pcall(function() service:Refresh() end)
            return false,T('hotbuild.keyboard_bindings.s032')..tostring(err)
        end
        return true
    end
    local function WriteAssignment(chord,proposed,newId,newRef)
        local beforePairs=CopyPairs(pairsByKey)
        local beforeProfile=Prefs.GetFromCurrentProfile(profileName)
        local beforeUser=CopyMap(Prefs.GetFromCurrentProfile('UserKeyMap'))
        local beforeDebug=CopyMap(Prefs.GetFromCurrentProfile('UserDebugKeyMap'))
        local beforeActions=CopyMap(Prefs.GetFromCurrentProfile('UserKeyActions'))
        local beforeDescriptions=CopyMap(descriptions)
        local userMap=CopyMap(beforeUser or CurrentMap()) or {}
        local debugMap=CopyMap(beforeDebug or DebugMap()) or {}
        local good,err=pcall(function()
            pairsByKey=proposed
            Prefs.SetToCurrentProfile(profileName,Profile(proposed))
            for index,name in ipairs({'UserKeyMap','UserDebugKeyMap'}) do
                local map=index==1 and userMap or debugMap
                for existing in pairs(map) do
                    if Mapper.NormalizeKeyBinding(existing)==chord then map[existing]=nil end
                end
                Prefs.SetToCurrentProfile(name,map)
            end
            if newId then
                Register(newId,newRef)
                Mapper.SetUserKeyMapping(chord,nil,newId)
            else
                Mapper.ClearUserKeyMapping(chord)
            end
            if not proposed[chord] and table.getn(OwnKeys(PairId(chord)))==0 then
                local actions=CopyMap(Prefs.GetFromCurrentProfile('UserKeyActions')) or {}
                actions[PairId(chord)]=nil
                Prefs.SetToCurrentProfile('UserKeyActions',actions)
                descriptions[PairId(chord)]=nil
            end
            Mapper.SaveUserKeyMap()
            SavePreferences()
            local refreshed,refreshError=service:Refresh(); if refreshed==false then error(refreshError or 'refresh failed') end
        end)
        if not good then
            pairsByKey=beforePairs
            Prefs.SetToCurrentProfile(profileName,beforeProfile)
            Prefs.SetToCurrentProfile('UserKeyMap',beforeUser)
            Prefs.SetToCurrentProfile('UserDebugKeyMap',beforeDebug)
            Prefs.SetToCurrentProfile('UserKeyActions',beforeActions)
            for id in pairs(descriptions) do descriptions[id]=nil end
            for id,value in pairs(beforeDescriptions or {}) do descriptions[id]=value end
            pcall(SavePreferences)
            pcall(function() service:Refresh() end)
            return false,T('hotbuild.keyboard_bindings.s033')..tostring(err)
        end
        return true
    end
    function service:ClearCompositeAssignments(id)
        if pairError then return false,pairError end
        if type(id)~='string' or id=='' then return false,T('hotbuild.keyboard_bindings.s034') end
        local proposed=CopyPairs(pairsByKey)
        local found=false
        local extraChanged,cleanupIds={},{}
        for chord,pair in pairs(proposed) do
            if pair.composite==id then
                found=true
                pair.composite=nil
                if not pair.preset and not pair.action and not pair.doubleFirst then proposed[chord]=nil end
            end
        end
        local ids=OwnIds()
        for _,map in ipairs({GetMap('UserKeyMap'),GetMap('UserDebugKeyMap')}) do
            for key,mappedId in pairs(map) do
                local assigned=ids[mappedId]
                if assigned and assigned.kind=='composite' and assigned.id==id then
                    local chord=Mapper.NormalizeKeyBinding(key)
                    if chord then extraChanged[chord]=true; cleanupIds[mappedId]=true; found=true end
                end
            end
        end
        if not found then return true end
        return WritePairs(proposed,extraChanged,cleanupIds)
    end
    function service:ClearPresetAssignments(id)
        if pairError then return false,pairError end
        if type(id)~='string' or id=='' then return false,T('hotbuild.keyboard_bindings.s034') end
        local proposed=CopyPairs(pairsByKey)
        local found=false
        local extraChanged,cleanupIds={},{ }
        for chord,pair in pairs(proposed) do
            if pair.preset==id then
                found=true
                pair.preset=nil
                if not pair.composite and not pair.action and not pair.doubleFirst then proposed[chord]=nil end
            end
        end
        local ids=OwnIds()
        for _,map in ipairs({GetMap('UserKeyMap'),GetMap('UserDebugKeyMap')}) do
            for key,mappedId in pairs(map) do
                local assigned=ids[mappedId]
                if assigned and assigned.kind=='preset' and assigned.id==id then
                    local chord=Mapper.NormalizeKeyBinding(key)
                    if chord then extraChanged[chord]=true; cleanupIds[mappedId]=true; found=true end
                end
            end
        end
        if not found then return true end
        return WritePairs(proposed,extraChanged,cleanupIds)
    end
    -- Clear every assignment for exactly this chord in one profile transaction.
    function service:ClearChord(key,mods)
        if pairError then return false,pairError end
        local chord=Chord(key,mods)
        local ids=OwnIds()
        local cleanup,found={},false
        for _,map in ipairs(AllMaps()) do
            for mappedKey,id in pairs(map) do
                if Mapper.NormalizeKeyBinding(mappedKey)==chord then
                    if ids[id] then cleanup[id]=true end
                    found=true
                end
            end
        end
        if pairsByKey[chord] then found=true end
        if not found then return false,T('hotbuild.keyboard_bindings.s035') end
        local proposed=CopyPairs(pairsByKey)
        proposed[chord]=nil
        return WritePairs(proposed,{[chord]=true},cleanup,{[chord]=true})
    end
    function service:Set(ref,key,mods,confirmedConflict)
        local ok,msg,details=self:Validate(ref,key,mods)
        if not ok and (not details or details.kind~='conflict' or details.id~=confirmedConflict) then return false,msg end
        local chord=Chord(key,mods)
        local proposed=CopyPairs(pairsByKey)
        local replaceStale=details and details.id=='stale:'..chord and confirmedConflict==details.id
        if replaceStale then
            proposed[chord]=nil
        end
        local id,mappedRef
        if ref.kind=='preset' or ref.kind=='composite' or (ref.kind=='action' and proposed[chord]~=nil) then
            local pair=proposed[chord] or {}
            if ref.kind=='preset' then pair.preset=ref.id elseif ref.kind=='composite' then pair.composite=ref.id end
            if not replaceStale and (ref.kind=='preset' or ref.kind=='composite') then
                local mapped=CurrentMap()
                for mappedKey,mappedId in pairs(mapped) do
                    if Mapper.NormalizeKeyBinding(mappedKey)==chord then
                        local existing=OwnIds()[mappedId]
                        if existing and (existing.kind=='action' or existing.kind=='composite') then
                            if ref.kind=='preset' and existing.kind=='action' then pair.action=existing.id end
                            if ref.kind=='preset' and existing.kind=='composite' then pair.composite=existing.id end
                            if ref.kind=='composite' then pair.action=nil; pair.doubleFirst=nil; pair.doubleSecond=nil end
                        end
                    end
                end
            end
            if ref.kind=='composite' then pair.action=nil; pair.doubleFirst=nil; pair.doubleSecond=nil end
            if ref.kind=='action' then
                pair.action=ref.id
                pair.composite=nil
                if pair.doubleFirst and pair.doubleFirst~=ref.id then pair.doubleFirst=nil; pair.doubleSecond=nil end
            end
            proposed[chord]=pair
            id=PairId(chord); mappedRef={kind='pair',id=chord}
        elseif ref.kind=='action' then
            proposed[chord]=nil
            id=ActionId(ref); mappedRef=ref
        else
            proposed[chord]=nil
            id=ActionId(ref); mappedRef=ref
        end
        return WriteAssignment(chord,proposed,id,mappedRef)
    end
    function service:Clear(ref,key,mods)
        if pairError then return false,pairError end
        if type(ref)~='table' or type(ref.id)~='string' then return false,T('hotbuild.keyboard_bindings.s036') end
        local chord=Chord(key,mods)
        local proposed=CopyPairs(pairsByKey)
        local pair=proposed[chord]
        if pair then
            if ref.kind=='action' and pair.doubleFirst==ref.id and not pair.action then
                proposed[chord]=nil
                local oldId=ActionId(ref)
                local found=false; for _,owned in ipairs(OwnKeys(oldId)) do if Mapper.NormalizeKeyBinding(owned)==chord then found=true end end
                if not found then return false,T('hotbuild.keyboard_bindings.s037') end
                return WriteAssignment(chord,proposed,nil,nil)
            end
            if ref.kind=='preset' and pair.preset==ref.id then pair.preset=nil
            elseif ref.kind=='composite' and pair.composite==ref.id then pair.composite=nil
            elseif ref.kind=='action' and pair.action==ref.id then pair.action=nil; pair.doubleFirst=nil; pair.doubleSecond=nil
            else return false,T('hotbuild.keyboard_bindings.s038') end
            if not pair.preset and not pair.composite and not pair.action and not pair.doubleFirst then proposed[chord]=nil end
            local id=proposed[chord] and PairId(chord) or nil
            return WriteAssignment(chord,proposed,id,id and {kind='pair',id=chord} or nil)
        end
        local id=ref.legacy and ActionId(ref) or (ref.kind=='composite' and KeyboardCompositeId(ref) or ActionId(ref))
        local found=false
        for _,owned in ipairs(OwnKeys(id)) do if Mapper.NormalizeKeyBinding(owned)==chord then found=true end end
        if not found then return false,T('hotbuild.keyboard_bindings.s039') end
        return WriteAssignment(chord,proposed,nil,nil)
    end
    function service:Refresh()
        local ids=OwnIds()
        for id,ref in pairs(ids) do
            if table.getn(OwnKeys(id))>0 then Register(id,ref) end
        end
        local mappings=Mapper.GetKeyMappings(true)
        local current=CurrentMap()
        -- Preserve saved action IDs while passing the actual physical chord to
        -- the runtime. Multiple keys may refer to the same legacy action ID.
        for key,id in pairs(current) do
            local ref=ids[id]
            local definition=mappings[key]
            if ref and ref.kind~='pair' and type(definition)=='table' then
                local method=ref.kind=='preset' and 'ExecuteMappedPreset'
                    or (ref.kind=='action' and 'ExecuteKeyboardAction'
                    or (ref.legacy and 'ExecuteMappedAbsolute' or 'ExecuteMappedComposite'))
                local copy={}
                for field,value in pairs(definition) do copy[field]=value end
                copy.action=string.format('UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").%s(%q,%q)',
                    method,ref.id,Mapper.NormalizeKeyBinding(key))
                mappings[key]=copy
            end
        end
        local options=ReUI.Options and ReUI.Options.Mods and ReUI.Options.Mods['ClaretCore']
        local probe=options and options.probeEnabled
        for key,id in pairs(current) do
            if ids[id] and not mappings[key] then
                if probe and probe:Get() then LOG('[Claret][keys] key='..key..' action='..id..' defined=false') end
                return false, 'No action definition for '..tostring(key)..': '..tostring(id)
            end
        end
        if probe and probe:Get() then LOG('[Claret][keymap] op=clear by=KeyboardBindings:Refresh') end
        IN_ClearKeyMap()
        if probe and probe:Get() then LOG('[Claret][keymap] op=add by=KeyboardBindings:Refresh') end
        IN_AddKeyMapTable(mappings)
        if SessionIsActive() then
            if probe and probe:Get() then LOG('[Claret][keymap] op=add by=FAF.hotbuild:addModifiers') end
            import('/lua/keymap/hotbuild.lua').addModifiers()
            local overrides=FactoryShiftOverrides()
            if next(overrides) then
                if probe and probe:Get() then
                    for key in pairs(overrides) do LOG('[Claret][keymap] factory_shift_intercept key='..key) end
                end
                IN_AddKeyMapTable(overrides)
            end
            import('/lua/keymap/hotkeylabels.lua').init()
        end
        if probe and probe:Get() then
            for key,id in pairs(current) do
                if ids[id] then LOG('[Claret][keys] key='..key..' action='..id..' defined='..tostring(mappings[key]~=nil)) end
            end
        end
    end
    function service:Start() self:Refresh() end
    function service:Stop() end
    Migrate()
    if pairError then WARN('[ClaretHotbuild] '..pairError) end
    if not pairError then service:Refresh() end
    return service
end
