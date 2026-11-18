local function setup(gate, primary, fallback, cfunctionClock, strictPrimary)
    local logs,warnings={},{}
    local inherited={GetSystemTimeSecondsOnlyForProfileUse=primary,GetSystemTimeSeconds=fallback}
    local env=setmetatable({LOG=function(s) table.insert(logs,s) end,WARN=function(s) table.insert(warnings,s) end,
        type=function(value) if cfunctionClock and value==fallback then return 'cfunction' end; return type(value) end},
        {__index=function(_,key) if strictPrimary and key=='GetSystemTimeSecondsOnlyForProfileUse' then error('strict global') end; return inherited[key] or _G[key] end})
    assert(loadfile('../mods/ClaretHotbuild/modules/OpenPerf.lua','t',env))()
    local enabled=gate
    local reui={Options={Mods={ClaretCore={probeEnabled={Get=function() return enabled end}}}}}
    return env,reui,logs,warnings,function(value) enabled=value end
end
local calls=0
local function clock() calls=calls+1; return calls/1000 end
local env,reui,logs,warnings,enable=setup(false,clock,nil)
assert(env.Start(reui)==nil and calls==0)
assert(logs[1]=='[Claret][perf] init gate=false timer=GetSystemTimeSecondsOnlyForProfileUse')
enable(true)
local perf=assert(env.Start(reui)); local start=perf:Now(); perf:Add('test',start); perf:Emit('test')
assert(#logs==2 and logs[2]:find('stage=test ms=',1,true))
assert(#warnings==0)
enable(false); local previous=calls; assert(perf:Now()==nil and calls==previous)
local constant=function() return 5 end
env,reui,logs,warnings=setup(true,nil,constant,true,true)
perf=assert(env.Start(reui))
assert(logs[1]=='[Claret][perf] init gate=true timer=GetSystemTimeSeconds')
local same=perf:Now(); perf:Add('constant',same); perf:Emit('constant')
assert(logs[2]=='[Claret][perf] stage=constant ms=0' and #warnings==0)
local bad=function() error('clock failure') end
env,reui,logs,warnings=setup(true,bad,clock)
perf=assert(env.Start(reui))
assert(#warnings==1 and warnings[1]:find('clock failure',1,true))
assert(logs[1]=='[Claret][perf] init gate=true timer=GetSystemTimeSeconds')
assert(env.Start(reui) and #warnings==1 and #logs==1)
env,reui,logs,warnings=setup(true,nil,nil)
assert(env.Start(reui)==nil and logs[1]=='[Claret][perf] init gate=true timer=none')
local count=0
local failingLater=function() count=count+1; if count>1 then error('later failure') end; return 1 end
env,reui,logs,warnings=setup(true,failingLater,nil)
perf=assert(env.Start(reui)); assert(perf:Now()==nil); perf:Add('test',perf.entry); perf:Emit('test')
assert(#warnings==1 and #logs==1)
print('PASS: optional timing, inherited clocks, fallback and diagnostics')
