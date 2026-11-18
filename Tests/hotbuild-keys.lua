-- FAF owns key assignments; Hotbuild registers UserKeyActions and prunes only its removed IDs.
table.getn = table.getn or function(t) return #t end
table.getsize = table.getsize or function(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local modelModule=setmetatable({}, {__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/Model.lua','t',modelModule))()
local registered, descriptions, writes = {}, {}, {}
local profile={
    UserKeyActions={
        ClaretHotbuild_OLD={category='Claret Hotbuild',action='old'},
        ForeignAction={category='orders',action='foreign'},
    },
    UserKeyMap={['Ctrl-O']='ClaretHotbuild_OLD',['Ctrl-F']='ForeignAction'},
    UserDebugKeyMap={['Alt-O']='ClaretHotbuild_OLD',['Alt-F']='ForeignAction'},
}
local mapper={
    SetUserKeyAction=function(id,definition)
        registered[id]=definition
        profile.UserKeyActions[id]=definition
    end,
}
local module=setmetatable({}, {__index=_G})
module.import=function(path)
    if path=='/lua/user/prefs.lua' then return {
        GetFromCurrentProfile=function(key) return profile[key] end,
        SetToCurrentProfile=function(key,value) writes[#writes+1]=key; profile[key]=value end,
    } end
    if path=='/lua/keymap/keymapper.lua' then return mapper end
    if path=='/lua/keymap/keydescriptions.lua' then return {keyDescriptions=descriptions} end
    error('unexpected import '..path)
end
assert(loadfile('../mods/ClaretHotbuild/modules/Keys.lua','t',module))()
local keys=module.Create()

local bindings={{id='x',name='Example',key='Ctrl-X'},{id='y_with_underscore',name='Second',key='Ctrl-X'}}
assert(keys:Validate(bindings),'key conflicts are resolved by FAF key assignment UI, not a shadow overlay')
assert(keys:Apply(bindings))
local idX='ClaretHotbuild_78'
local idY='ClaretHotbuild_795F776974685F756E64657273636F7265'
assert(registered[idX] and registered[idY],'each saved binding registers a FAF user action')
assert(registered[idX].category=='Claret Hotbuild')
assert(registered[idX].action=='UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").Execute("x")')
assert(descriptions[idX]=='Example' and descriptions[idY]=='Second')
profile.UserKeyMap['W']=idX
module.IsKeyDown=function(key) if key=='W' then error('Invalid enum value W') end return false end
assert(keys:HeldKey('x')==nil,'unsupported letter key must not prevent the action from executing')
profile.UserKeyMap['W']=nil
assert(profile.UserKeyActions.ClaretHotbuild_OLD==nil,'stale Claret action is removed')
assert(profile.UserKeyActions.ForeignAction.action=='foreign','other mod actions remain intact')
assert(profile.UserKeyMap['Ctrl-O']==nil and profile.UserDebugKeyMap['Alt-O']==nil,
    'only assignments to removed Claret actions are pruned')
assert(profile.UserKeyMap['Ctrl-F']=='ForeignAction' and profile.UserDebugKeyMap['Alt-F']=='ForeignAction')
assert(table.getsize(profile.UserKeyMap)==1 and table.getsize(profile.UserDebugKeyMap)==1,
    'FAF mappings keep unrelated assignments')

-- User-assigned keys are read as profile data and never overwritten by action registration.
profile.UserKeyMap['Ctrl-X']='ForeignAction'
profile.UserDebugKeyMap['Ctrl-X']='ForeignAction'
assert(keys:Apply({{id='x',name='Renamed',key='Ctrl-X'}}))
assert(profile.UserKeyMap['Ctrl-X']=='ForeignAction' and profile.UserDebugKeyMap['Ctrl-X']=='ForeignAction')
assert(profile.UserKeyActions.ClaretHotbuild_OLD==nil and profile.UserKeyActions.ForeignAction)
assert(descriptions[idX]=='Renamed' and not descriptions[idY])
assert(profile.UserKeyMap['Ctrl-F']=='ForeignAction' and profile.UserDebugKeyMap['Alt-F']=='ForeignAction')

-- Stop is intentionally inert: the registered action and assigned key belong to FAF's profile/keymap lifecycle.
local actionBefore=registered[idX]
keys:Stop()
assert(registered[idX]==actionBefore and profile.UserKeyMap['Ctrl-X']=='ForeignAction')
assert(#writes>=2)
print('PASS: FAF-owned user actions, stable encoded IDs, stale Claret cleanup, and preserved unrelated profile key assignments')
