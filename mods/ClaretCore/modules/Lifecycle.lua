-- Original Claret implementation. State management is independent of ReUI.
-- Own/Every operate on game controls; Guard/Bind accept two callback arguments.

---@param start fun(scope:table)
---@param report fun(message:string)
---@return table
function Create(start, report)
    local active = false
    local disposed = false
    local busy = false
    local cleanups = {}
    local scope
    local failure
    local startingFailure
    local state = 'disabled'
    local controller = {}

    -- A fresh scope per start prevents callbacks from older runs being reused.
    local function NewScope()
        local current = { closed = false }
        function current:Defer(callback)
            assert(not self.closed, 'scope is closed')
            assert(type(callback) == 'function', 'cleanup must be a function')
            table.insert(cleanups, callback)
        end
        function current:Own(control)
            self:Defer(function()
                if not IsDestroyed(control) then control:Destroy() end
            end)
            return control
        end
        function current:Guard(callback)
            return function(sender, value)
                if self.closed then return end
                local ok, err = pcall(callback, sender, value)
                if not ok then controller:Fail(tostring(err)) end
            end
        end
        function current:Bind(event, callback)
            local guarded = self:Guard(callback)
            self:Defer(function() event:Remove(guarded) end)
            event:Add(guarded)
        end
        -- For an exclusively owned control. No catch-up work after a slow frame.
        function current:Every(control, interval, callback)
            assert(interval > 0, 'interval must be positive')
            local elapsed = 0
            local guarded = self:Guard(callback)
            self:Defer(function()
                if not IsDestroyed(control) then
                    control:SetNeedsFrameUpdate(false)
                    control.OnFrame = function() end
                end
            end)
            control.OnFrame = function(self, delta)
                if current.closed then return end
                elapsed = elapsed + delta
                if elapsed >= interval then
                    elapsed = 0
                    guarded()
                end
            end
            control:SetNeedsFrameUpdate(true)
        end
        return current
    end

    local function Clean()
        if scope then scope.closed = true end
        for i = table.getn(cleanups), 1, -1 do
            local callback = cleanups[i]
            cleanups[i] = nil
            local ok, err = pcall(callback)
            if not ok then
                report('cleanup failed: ' .. tostring(err))
            end
        end
    end

    function controller:Fail(message)
        if disposed then return end
        if busy then
            startingFailure = tostring(message)
            return
        end
        if not active then return end
        busy = true
        active = false
        failure = tostring(message)
        state = 'error'
        Clean()
        busy = false
        report('feature failed: ' .. failure)
    end

    ---@param enabled boolean
    ---@return boolean
    function controller:SetEnabled(enabled)
        if disposed or busy then return false end
        enabled = enabled and true or false
        if active == enabled then
            if not enabled then state = 'disabled'; failure = nil end
            return true
        end
        busy = true
        if enabled then
            scope = NewScope()
            startingFailure = nil
            failure = nil
            local ok, err = pcall(start, scope)
            if ok and not startingFailure then
                active = true
                state = 'running'
            else
                failure = startingFailure or tostring(err)
                state = 'error'
                Clean()
                report('start failed: ' .. failure)
            end
        else
            active = false
            state = 'disabled'
            failure = nil
            Clean()
        end
        busy = false
        return active == enabled
    end

    ---@return boolean
    function controller:IsActive()
        return active
    end

    function controller:GetState()
        return state, failure
    end

    function controller:Destroy()
        if disposed then return end
        self:SetEnabled(false)
        disposed = true
        state = 'disposed'
    end

    return controller
end
