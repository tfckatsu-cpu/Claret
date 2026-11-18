local held=true
local running
local steps=0
local env=setmetatable({
    IsKeyDown=function(key) return key=='X' and held end,
    WaitSeconds=function(delay) assert(delay==0.3); coroutine.yield() end,
    ForkThread=function(fn,state)
        running=coroutine.create(function() fn(state) end)
        assert(coroutine.resume(running))
        return running
    end,
}, {__index=_G})
table.getn=function(t) return #t end
assert(loadfile('../mods/ClaretHotbuild/modules/EngineerHold.lua','t',env))()
assert(env.Start('X',function() steps=steps+1 end))
assert(steps==0 and env.Active('X'),'first step is performed by the caller')
assert(coroutine.resume(running) and steps==1,'held key repeats after 0.3 seconds')
assert(coroutine.resume(running) and steps==2,'holding continues to repeat')
held=false
assert(coroutine.resume(running) and steps==2 and not env.Active('X'),'release stops repeat')
print('PASS: engineer hold interval, repeated steps and release')
