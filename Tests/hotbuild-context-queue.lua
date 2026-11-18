-- Transactional factory queue removal with mocked FAF APIs.
table.getn=function(value) return #value end
table.getsize=function(value) local n=0; for _ in pairs(value) do n=n+1 end; return n end

local queue, clearCount, refreshCount, decreaseCalls, shift, setQueueError, decreaseError = {}, 0, 0, {}, false, false, false
local factory={}
function factory:IsDead() return false end
function factory:IsInCategory(category) return category=='FACTORY' end
local construction={DecreaseBuildCountInQueue=function(index,count)
    decreaseCalls[#decreaseCalls+1]={index,count}
    if decreaseError then error('decrease failed') end
end, RefreshUI=function() refreshCount=refreshCount+1 end}
local environment=setmetatable({
 import=function(path) assert(path=='/lua/ui/game/construction.lua'); return construction end,
 SetCurrentFactoryForQueueDisplay=function(selected)
    assert(selected==factory)
    if setQueueError then error('queue read failed') end
    return queue
 end,
 ClearCurrentFactoryForQueueDisplay=function() clearCount=clearCount+1 end,
 IsKeyDown=function(key) assert(key=='Shift'); return shift end,
}, {__index=_G})
local module=setmetatable({}, {__index=environment})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextQueue.lua','t',module))()
local function context(selection) return {selection=selection or {factory}} end

queue={}; assert(module.Execute(context())==false and clearCount==1,'empty queue returns false and clears display')
queue={[1]={id='a'},[3]={id='c'}}; shift=false
assert(module.Execute(context())==true and clearCount==2)
assert(decreaseCalls[1][1]==2 and decreaseCalls[1][2]==1,'uses getsize and removes one')
assert(refreshCount==1,'successful removal refreshes after cleanup')
shift=true
assert(module.Execute(context())==true and clearCount==3)
assert(decreaseCalls[2][1]==2 and decreaseCalls[2][2]==5,'Shift removes five')
assert(refreshCount==2)

local before=#decreaseCalls
assert(module.Execute(context({}))==false and clearCount==3,'invalid selection does not clear display')
assert(module.Execute(context({factory,factory}))==false and clearCount==3,'multi-selection is rejected without cleanup')
local other={IsDead=function() return false end,IsInCategory=function() return false end}
assert(module.Execute(context({other}))==false and clearCount==3,'non-factory selection is rejected without cleanup')
assert(#decreaseCalls==before,'invalid selections do not alter queue')

setQueueError=true
local ok,err=pcall(module.Execute,context())
assert(not ok and tostring(err):find('queue read failed',1,true) and clearCount==4,'queue lookup error still clears display')
setQueueError=false; decreaseError=true
ok,err=pcall(module.Execute,context())
assert(not ok and tostring(err):find('decrease failed',1,true) and clearCount==5,'decrease error still clears display')
assert(refreshCount==2,'failed decrease does not refresh')
decreaseError=false

local clearFailure=false
environment.ClearCurrentFactoryForQueueDisplay=function()
    clearCount=clearCount+1
    if clearFailure then error('clear failed') end
end
clearFailure=true
ok,err=pcall(module.Execute,context())
assert(not ok and tostring(err):find('clear failed',1,true) and clearCount==6,'clear failure is reported')
assert(refreshCount==2,'refresh follows successful cleanup only')
print('PASS: empty queue, sparse size, Shift batch, invalid selection and cleanup on all error paths')
