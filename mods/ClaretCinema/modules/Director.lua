Visual = {
    {id = 'nearFov', label = 'cinema.near_fov', command = 'cam_NearFOV', min = 10, max = 180, step = 1, initial = 80},
    {id = 'farFov', label = 'cinema.far_fov', command = 'cam_FarFOV', min = 10, max = 180, step = 1, initial = 80},
    {id = 'nearPitch', label = 'cinema.near_pitch', command = 'cam_NearPitch', min = 10, max = 180, step = 1, initial = 45},
    {id = 'farPitch', label = 'cinema.far_pitch', command = 'cam_FarPitch', min = 10, max = 180, step = 1, initial = 90},
    {id = 'shadowLod', label = 'cinema.shadow_lod', command = 'ren_ShadowLOD', min = 100, max = 1000, step = 10, initial = 500},
    {id = 'shadowSize', label = 'cinema.shadow_size', command = 'ren_ShadowSize', min = 100, max = 4096, step = 1, initial = 1024},
}

Motion = {
    move = {
        {id = 'seconds', label = 'cinema.duration', min = 1, max = 20, step = 0.5, initial = 2},
    },
    pan = {
        {id = 'x', label = 'cinema.pan_x', min = -2, max = 2, step = 0.05, initial = 0},
        {id = 'z', label = 'cinema.pan_z', min = -2, max = 2, step = 0.05, initial = 0},
        {id = 'seconds', label = 'cinema.duration', min = 1, max = 30, step = 0.5, initial = 10},
    },
    spin = {
        {id = 'heading', label = 'cinema.spin_heading', min = -0.2, max = 0.2, step = 0.005, initial = 0.1},
        {id = 'zoom', label = 'cinema.spin_zoom', min = -3, max = 3, step = 0.1, initial = 0.4},
    },
}

local function Validate(spec, value)
    return type(value) == 'number' and value == value and value >= spec.min and value <= spec.max
end

local function Restore(camera, pose)
    camera:RestoreSettings(pose)
    camera:HoldRotation()
end

local function CopyPose(pose)
    return {
        Focus = {x = pose.Focus.x, y = pose.Focus.y, z = pose.Focus.z},
        Heading = pose.Heading, Pitch = pose.Pitch, Zoom = pose.Zoom,
    }
end

local function Snap(camera, pose)
    camera:SnapTo({pose.Focus.x, pose.Focus.y, pose.Focus.z},
        {pose.Heading, pose.Pitch, 0}, pose.Zoom)
end

function Create(cameraFor, schedule, execute, startFrames, clock)
    local service = {}
    local tabs = {move = {}, pan = {}, spin = {}}
    local visual, touched = {}, {}
    local active, listener, closed
    for _, spec in ipairs(Visual) do visual[spec.id] = spec.initial end
    for name, specs in pairs(Motion) do
        for _, spec in ipairs(specs) do tabs[name][spec.id] = spec.initial end
    end

    local function Notify(problem)
        if listener then listener(problem or active and active.preview and 'cinema.previewing'
            or active and 'cinema.motion_running' or nil) end
    end

    local function Guard(action)
        if closed then return false, 'cinema.camera_unavailable' end
        local ok, message = pcall(action)
        if not ok then
            WARN('[ClaretCinema] Camera: ' .. tostring(message))
            return false, 'cinema.camera_unavailable'
        end
        return true
    end

    local function Freeze(camera, kind)
        local pose = camera:SaveSettings()
        if kind == 'spin' then camera:Spin(0, 0) end
        camera:SnapTo(pose.Focus, {pose.Heading, pose.Pitch, 0}, pose.Zoom)
        camera:HoldRotation()
    end

    function service.Listen(callback) listener = callback end
    function service.GetVisual(id) return visual[id] end
    function service.Get(tab, id) return tabs[tab][id] end
    function service.IsActive() return active ~= nil end

    function service.SetVisual(spec, value)
        if not Validate(spec, value) then return false end
        if visual[spec.id] == value then return true end
        local ok, message = Guard(function()
            execute(spec.command .. ' ' .. string.format('%.5g', value))
        end)
        if ok then visual[spec.id] = value; touched[spec.id] = true end
        return ok, message
    end

    function service.ResetVisual()
        for _, spec in ipairs(Visual) do
            if touched[spec.id] then
                local ok, message = service.SetVisual(spec, spec.initial)
                if not ok then return false, message end
                touched[spec.id] = nil
            end
        end
        return true
    end

    function service.Set(tab, spec, value)
        if not Validate(spec, value) then return false end
        tabs[tab][spec.id] = value
        return true
    end

    function service.Capture(tab, slot)
        return Guard(function()
            tabs[tab][slot] = cameraFor():SaveSettings()
            if slot == 'origin' then tabs[tab].useOrigin = true end
        end)
    end

    function service.ToggleOrigin(tab)
        local entry = tabs[tab]
        if not entry.origin then return false, 'cinema.no_origin' end
        entry.useOrigin = not entry.useOrigin
        return true
    end

    function service.Stop()
        if not active then return true end
        local run = active
        if run.kind == 'move' then
            active = nil
            Notify()
            return true
        end
        local ok, message = Guard(function() Freeze(run.camera, run.kind) end)
        if ok then active = nil; Notify() end
        return ok, message
    end

    function service.Jump(tab, slot)
        local pose = tabs[tab][slot]
        if not pose then return false, slot == 'origin' and 'cinema.no_origin' or 'cinema.no_target' end
        local ok, message = service.Stop()
        if not ok then return false, message end
        return Guard(function() Restore(cameraFor(), pose) end)
    end

    function service.Play(tab, preview)
        local entry = tabs[tab]
        if tab == 'move' and not entry.target then return false, 'cinema.no_target' end
        local stopped, stopError = service.Stop()
        if not stopped then return false, stopError end
        local run = {kind = tab, preview = preview}
        if tab == 'move' then
            local ok, message = Guard(function()
                run.camera = cameraFor()
                run.previous = CopyPose(run.camera:SaveSettings())
                run.start = CopyPose(entry.useOrigin and entry.origin or run.previous)
                run.target = CopyPose(entry.target)
                run.duration = entry.seconds
                run.started = clock()
                run.heading = math.mod(run.target.Heading - run.start.Heading, 2 * math.pi)
                if run.heading > math.pi then run.heading = run.heading - 2 * math.pi end
                if run.heading < -math.pi then run.heading = run.heading + 2 * math.pi end
            end)
            if not ok then return false, message end
            active = run
            local setupOk, setupError = Guard(function()
                startFrames(function()
                    if active ~= run then return false end
                    local done = false
                    local frameOk = Guard(function()
                        if run.returnNext then
                            Snap(run.camera, run.previous)
                            done = true
                            return
                        end
                        local progress = math.max(0, math.min(1, (clock() - run.started) / run.duration))
                        local t = progress * progress * (3 - 2 * progress)
                        local a, b = run.start, run.target
                        local pose = progress >= 1 and b or {
                            Focus = {x = a.Focus.x + (b.Focus.x - a.Focus.x) * t,
                                y = a.Focus.y + (b.Focus.y - a.Focus.y) * t,
                                z = a.Focus.z + (b.Focus.z - a.Focus.z) * t},
                            Heading = a.Heading + run.heading * t,
                            Pitch = a.Pitch + (b.Pitch - a.Pitch) * t,
                            Zoom = a.Zoom + (b.Zoom - a.Zoom) * t,
                        }
                        Snap(run.camera, pose)
                        if progress >= 1 then
                            if run.preview then run.returnNext = true else done = true end
                        end
                    end)
                    if not frameOk or done then
                        active = nil
                        Notify(not frameOk and 'cinema.camera_unavailable' or nil)
                        return false
                    end
                    return true
                end)
                if entry.useOrigin and entry.origin then Snap(run.camera, run.start) end
            end)
            if not setupOk then active = nil; return false, setupError end
            Notify()
            return true
        end
        local ok, message = Guard(function()
            local camera = cameraFor()
            local previous = camera:SaveSettings()
            local start = entry.useOrigin and entry.origin or previous
            if start ~= previous then Restore(camera, start) end
            run.camera, run.previous = camera, previous
            if tab == 'pan' then
                local focus = start.Focus
                camera:MoveTo({focus.x + entry.x * entry.seconds, focus.y, focus.z + entry.z * entry.seconds},
                    {start.Heading, start.Pitch, 0}, start.Zoom, entry.seconds)
            else
                camera:Spin(entry.heading, entry.zoom)
            end
        end)
        if not ok then return false, message end
        active = run
        local duration = tab ~= 'spin' and entry.seconds or preview and 5 or nil
        if duration then
            schedule(duration, function()
                if active ~= run then return end
                if preview then
                    Guard(function()
                        if tab == 'spin' then run.camera:Spin(0, 0) end
                        Restore(run.camera, run.previous)
                    end)
                end
                active = nil
                Notify()
            end)
        end
        Notify()
        return true
    end

    function service.Destroy()
        listener = nil
        service.Stop()
        active = nil
        closed = true
    end

    return service
end
