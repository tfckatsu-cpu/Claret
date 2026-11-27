Choices = {
    {id = 'mode', label = 'cinema.toggle'},
    {id = 'hud', label = 'cinema.hud'},
    {id = 'free', label = 'cinema.free'},
    {id = 'reset', label = 'cinema.reset'},
    {id = 'ease', label = 'cinema.ease'},
    {id = 'decals', label = 'cinema.decals'},
    {id = 'boxes', label = 'cinema.boxes'},
    {id = 'move_origin', label = 'cinema.bind_move_origin', group = 'move'},
    {id = 'move_target', label = 'cinema.bind_move_target', group = 'move'},
    {id = 'move_jump_origin', label = 'cinema.bind_move_jump_origin', group = 'move'},
    {id = 'move_jump_target', label = 'cinema.bind_move_jump_target', group = 'move'},
    {id = 'move_play', label = 'cinema.bind_move_play', group = 'move'},
    {id = 'pan_origin', label = 'cinema.bind_pan_origin', group = 'pan'},
    {id = 'pan_play', label = 'cinema.bind_pan_play', group = 'pan'},
    {id = 'spin_origin', label = 'cinema.bind_spin_origin', group = 'spin'},
    {id = 'spin_play', label = 'cinema.bind_spin_play', group = 'spin'},
    {id = 'motion_stop', label = 'cinema.bind_motion_stop', group = 'motion'},
}

local console = {free = 'cam_Free', decals = 'ren_IgnoreDecalLOD', boxes = 'ren_SelectBoxes'}

function Create()
    local changed = {}
    local controls = {}

    local function Run(id)
        if id == 'hud' then
            ConExecute(changed.hud and 'ren_UI true' or 'ren_UI false')
        elseif id == 'reset' then
            local camera = GetCamera('WorldCamera')
            camera:Reset()
            camera:RevertRotation()
            return
        elseif id == 'ease' then
            local camera = GetCamera('WorldCamera')
            if changed.ease then camera:EnableEaseInOut() else camera:DisableEaseInOut() end
        elseif console[id] then
            ConExecute(console[id])
        else
            return
        end
        changed[id] = not changed[id]
    end

    function controls.Run(id)
        local ok, message = pcall(Run, id)
        if not ok then WARN('[ClaretCinema] Command ' .. id .. ' failed: ' .. tostring(message)) end
        return ok, not ok and 'cinema.camera_unavailable' or nil
    end

    function controls.Restore()
        for _, choice in ipairs(Choices) do
            if changed[choice.id] then controls.Run(choice.id) end
        end
    end

    return controls
end
