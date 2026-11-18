-- Native key service: persistence, conflict refusal, scoped engine updates and recovery.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn=function(t) return #t end
local profile,engine,generated,descriptions,warnings = {},{['Alt-Z']={action='foreign overlay'}},{},{},{}
local failSave,failAdd,saveCount,opened = false,false,0,0
local id='ClaretCore_OpenMenu'
local function normalize(key)
    local parts={}
    for part in key:gmatch('[^-]+') do parts[part]=true end
    local base=''
    for part in key:gmatch('[^-]+') do if part~='Ctrl' and part~='Shift' and part~='Alt' then base=part end end
    return (parts.Ctrl and 'Ctrl-' or '')..(parts.Shift and 'Shift-' or '')..(parts.Alt and 'Alt-' or '')..base
end
local mapper={
    GetActionName=function(action) return action=='attack' and 'Атака' or action end,
    GetCurrentKeyMap=function() return profile.UserKeyMap or {} end,
    GetUserDebugKeyMap=function() return profile.UserDebugKeyMap or {} end,
    GetKeyCodeLookup=function() return {[67]='C',[75]='K',[88]='X',[89]='Y',[65]='A',[27]='Escape',[17]='Ctrl',[16]='Shift',[18]='Alt'} end,
    NormalizeKeyBinding=normalize,
    NormalizeKey=function(key) return {key=normalize(key):match('([^-]+)$')} end,
    GenerateHotbuildModifiers=function() return generated end,
    SetUserKeyAction=function(name,value)
        profile.UserKeyActions=profile.UserKeyActions or {}; profile.UserKeyActions[name]=value
    end,
    ClearUserKeyMapping=function(key)
        for _,name in ipairs({'UserKeyMap','UserDebugKeyMap'}) do
            if profile[name] then profile[name][key]=nil end
        end
    end,
    SetUserKeyMapping=function(key,old,action)
        profile.UserKeyMap=profile.UserKeyMap or {}; profile.UserKeyMap[key]=action
    end,
}
local env=setmetatable({
    ReUI={Options={Mods={}}},
    import=function(path)
        if path=='/mods/ClaretCore/modules/Localization.lua' then return {Localization=testLocalization} end
        if path=='/lua/keymap/keymapper.lua' then return mapper end
        if path=='/lua/keymap/keydescriptions.lua' then return {keyDescriptions=descriptions} end
        assert(path=='/lua/user/prefs.lua')
        return {GetFromCurrentProfile=function(key) return profile[key] end,
            SetToCurrentProfile=function(key,value) profile[key]=value end}
    end,
    SavePreferences=function() if failSave then error('disk error') end; saveCount=saveCount+1 end,
    IN_AddKeyMapTable=function(map)
        for key,value in pairs(map) do
            engine[key]=value
            if failAdd then failAdd=false; error('partial engine failure') end
        end
    end,
    IN_RemoveKeyMapTable=function(map) for key in pairs(map) do engine[key]=nil end end,
    WARN=function(message) warnings[#warnings+1]=message end,
},{__index=_G})
assert(loadfile('../mods/ClaretCore/modules/MenuKey.lua','t',env))()
assert(not env.Open())
local keys=env.Create(function() opened=opened+1 end)
keys:Initialize()
assert(keys:Get()=='Ctrl-Alt-C' and profile.UserKeyActions[id] and descriptions[id])
keys:Start(); assert(engine['Ctrl-Alt-C'] and engine['Alt-Z'].action=='foreign overlay')
assert(env.Open() and opened==1)
assert(keys:FromEvent({Type='KeyDown',RawKeyCode=75,Modifiers={Alt=true,Ctrl=true,Shift=true}})=='Ctrl-Shift-Alt-K')
assert(not keys:FromEvent({Type='KeyDown',RawKeyCode=17,Modifiers={Ctrl=true}}))
assert(not keys:FromEvent({Type='KeyDown',RawKeyCode=999,Modifiers={}}))
assert(not keys:Validate('Escape'))
profile.UserKeyMap['Shift-Ctrl-X']='attack'
profile.UserDebugKeyMap={['Alt-Y']='debug'}
generated['Shift-A']={action='hotbuild'}
assert(not keys:Set('Ctrl-Shift-X'))
local valid, conflict=keys:Validate('Ctrl-Shift-X')
assert(not valid and conflict:find('Атака',1,true),'conflict must identify the occupied action')
assert(not keys:Set('Alt-Y'))
assert(not keys:Set('Shift-A'))
assert(keys:Get()=='Ctrl-Alt-C' and engine['Ctrl-Alt-C'])
assert(profile.UserKeyMap['Shift-Ctrl-X']=='attack' and profile.UserDebugKeyMap['Alt-Y']=='debug')
assert(keys:Set('Ctrl-K'))
assert(keys:Get()=='Ctrl-K' and engine['Ctrl-K'] and not engine['Ctrl-Alt-C'])
assert(engine['Alt-Z'].action=='foreign overlay')
failSave=true
assert(not keys:Set('Ctrl-Y'))
failSave=false
assert(keys:Get()=='Ctrl-K' and engine['Ctrl-K'] and not engine['Ctrl-Y'])
failAdd=true
assert(not keys:Set('Ctrl-Y'))
assert(keys:Get()=='Ctrl-K' and engine['Ctrl-K'] and not engine['Ctrl-Y'])
assert(keys:Set('') and keys:Get()=='' and not engine['Ctrl-K'])
keys:Destroy(); assert(not env.Open() and not keys:Set('Ctrl-K'))
local reload=env.Create(function() end)
reload:Initialize(); reload:Start()
assert(reload:Get()=='' and not engine['Ctrl-Alt-C'],'user-cleared binding must stay cleared after restart')
reload:Destroy()
-- A newly installed Core must not steal its suggested default from another action.
profile={UserKeyMap={['Alt-Ctrl-C']='other'},UserDebugKeyMap={}}
local occupied=env.Create(function() end)
occupied:Initialize(); occupied:Start()
assert(occupied:Get()=='' and profile.UserKeyMap['Alt-Ctrl-C']=='other')
occupied:Destroy()
print('PASS: native Claret action, default/reload, input normalization, user/debug/Hotbuild conflicts, scoped remap/clear, disk/engine rollback and session teardown')
