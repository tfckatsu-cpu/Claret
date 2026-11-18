-- Per-session diagnostics and optional per-open UI timing.
local initialized=false
local warned=false
local function WarnTimer(name,err)
    if warned then return end
    warned=true
    WARN('[Claret][perf] timer='..name..' error='..tostring(err))
end
local function FindClock(getter)
    local ok,clock=pcall(getter)
    if ok and (type(clock)=='function' or type(clock)=='cfunction') then return clock end
end
local function ReadClock(clock,name)
    local ok,value=pcall(clock)
    if not ok then WarnTimer(name,value); return nil end
    if type(value)~='number' then WarnTimer(name,'non-numeric result: '..tostring(value)); return nil end
    return value
end
function Start(reui)
    local options=reui and reui.Options and reui.Options.Mods and reui.Options.Mods['ClaretCore']
    local probe=options and options.probeEnabled
    local gate=probe and probe:Get() or false
    -- Resolve through the module environment, including its inherited game globals.
    local primary=FindClock(function() return GetSystemTimeSecondsOnlyForProfileUse end)
    local fallback=FindClock(function() return GetSystemTimeSeconds end)
    local clock,name=primary,'GetSystemTimeSecondsOnlyForProfileUse'
    if not clock then clock,name=fallback,'GetSystemTimeSeconds' end
    local value
    if gate and clock then
        value=ReadClock(clock,name)
        if not value and clock~=fallback and fallback then
            clock,name=fallback,'GetSystemTimeSeconds'
            value=ReadClock(clock,name)
        end
        if not value then clock=nil end
    end
    if not clock then name='none' end
    if not initialized then
        initialized=true
        LOG('[Claret][perf] init gate='..tostring(gate)..' timer='..name)
    end
    if not gate or not clock then return nil end
    local perf={clock=clock,entry=value,totals={},valid=true}
    function perf:Enabled() return self.valid and probe:Get() end
    function perf:Now()
        if not self:Enabled() then return nil end
        local now=ReadClock(self.clock,name)
        if not now then self.valid=false end
        return now
    end
    function perf:Add(stage,start)
        if not start then return end
        local now=self:Now()
        if now then self.totals[stage]=(self.totals[stage] or 0)+(now-start)*1000 end
    end
    function perf:Emit(stage)
        if self:Enabled() and self.totals[stage] then LOG('[Claret][perf] stage='..stage..' ms='..tostring(self.totals[stage])) end
    end
    return perf
end
