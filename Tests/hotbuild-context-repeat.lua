table.getn=function(value) return #value end
local selected, now, executions={},0,{}
local function unit(id)
    return {GetEntityId=function() return id end, IsDead=function() return false end}
end
local a,b=unit(1),unit(2)
local env=setmetatable({GetSelectedUnits=function() return selected end,
    GetSystemTimeSeconds=function() return now end}, {__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextRepeat.lua','t',env))()
local actions={Execute=function(action,context,id)
    executions[#executions+1]={action.id,context.isRepeat,id,context.resolvedContext,context.legacyUnits}
    if action.continuation=='accumulate' then selected={a,b} end
    return true
end}
local state=env.Create(actions)
local double={id='double',continuation='double'}
local add={id='add',continuation='accumulate'}
local context={focusArmy=1,selection={a},isReplay=false}
selected={a}; state:Remember('key1',double,context); now=0.3
local handled,result=state:Continue('key1',context)
assert(handled and result and executions[1][2] and executions[1][3]=='key1','double resumes same binding')
assert(not state:Continue('key1',context),'double is consumed')
state:Remember('key1',double,context); now=1
assert(not state:Continue('key1',context),'late double does not intercept')
state:Remember('key1',double,context)
assert(not state:Continue('key2',context),'another key invalidates continuation')
state:Remember('key1',double,context)
assert(not state:Continue('key1',{focusArmy=1,selection={b}}),'changed selection invalidates continuation')
state:Remember('key1',double,context)
assert(not state:Continue('key1',{focusArmy=2,selection={a}}),'army change invalidates continuation')
selected={a}; state:Remember('key1',add,context); now=100
handled,result=state:Continue('key1',context)
assert(handled and result,'accumulation is not time limited')
handled,result=state:Continue('key1',{focusArmy=1,selection={b,a}})
assert(handled and result,'accumulation continues with the selection it produced')
state:Clear(); assert(not state:Continue('key1',context),'cleanup clears pending state')
local quick={id='quick'}
now=0; selected={}; context.selection={}
state:RememberQuick('key1',quick,context,1.5)
local before=#executions
handled,result=state:ContinueQuick('key1',context)
assert(handled and not result and #executions==before,'holding does not execute a quick repeat')
state:ReleaseQuick('key1'); now=1.5
handled,result=state:ContinueQuick('key1',context)
assert(handled and result and executions[#executions][1]=='quick','empty selection and boundary are supported')
assert(not state:ContinueQuick('key1',context),'quick repeat does not rearm')
context.resolvedContext='builder'
context.legacyUnits=true
state:RememberQuick('key1',quick,context,1.5); state:ReleaseQuick('key1')
context.resolvedContext='units'
context.legacyUnits=false
handled,result=state:ContinueQuick('key1',context)
assert(handled and result and executions[#executions][4]=='builder' and executions[#executions][5]==true
    and context.resolvedContext=='units' and context.legacyUnits==false,
    'quick repeat keeps the originating context for capability checks and restores the caller')
context.resolvedContext=nil
context.legacyUnits=nil
state:RememberQuick('key1',quick,context,1.5); state:ReleaseQuick('key1'); now=3.1
assert(not state:ContinueQuick('key1',context),'expired repeat')
state:RememberQuick('key1',quick,context,1.5); state:ReleaseQuick('key1')
assert(not state:ContinueQuick('key2',context),'different key breaks repeat')
state:RememberQuick('key1',quick,context,1.5); state:ReleaseQuick('key1')
state:TouchQuick('key2')
assert(not state:ContinueQuick('key1',context),'even an unavailable different action breaks repeat')
state:RememberQuick('key1',quick,context,1.5); state:ReleaseQuick('key1')
state:SelectionChangedQuick({a}); state:SelectionChangedQuick({})
assert(not state:ContinueQuick('key1',context),'selection change and restoration breaks repeat')
state:RememberQuick('key1',quick,context,1.5); state:ReleaseQuick('key1')
assert(not state:ContinueQuick('key1',{focusArmy=2,selection={}}),'army changes break repeat')
state:RememberQuick('key1',quick,context,0/0)
assert(not state:ContinueQuick('key1',context),'invalid window is rejected')
state:RememberQuick('key1',quick,context,1/0)
assert(not state:ContinueQuick('key1',context),'infinite window is rejected')
print('PASS: continuation ownership, timing, selection and army guards, accumulation and cleanup')
