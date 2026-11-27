-- Explicit allowlist: engine actions keep their native definitions, including
-- repeat behaviour. Never accept a command string or a new action ID from prefs.
local camera = {
    'lock_zoom', 'zoom_pop', 'RestorePreviousCameraPosition',
    'next_cam_position', 'add_cam_position', 'rem_cam_position',
    'zoom_in', 'zoom_out', 'zoom_in_fast', 'zoom_out_fast',
    'track_unit', 'track_unit_minimap', 'track_unit_second_mon', 'reset_camera',
}
local presentation = {
    'toggle_lifebars', 'Render_SelectionSet_Names', 'Render_Custom_Names',
    'Render_Icons', 'Always_Render_Strategic_Icons', 'show_enemy_life',
    'military_overlay', 'intel_overlay', 'tog_military', 'tog_defense', 'tog_econ',
    'toggle_reclaim_labels', 'split_screen_enable', 'split_screen_disable',
    'toggle_score_screen', 'cap_frame',
}
local replay = {'pause', 'decrease_game_speed', 'increase_game_speed', 'reset_game_speed'}
local debugClient = {
    'show_fps', 'debug_show_frame_stats', 'show_network_stats',
    'debug_graphics_fidelity_0', 'debug_graphics_fidelity_2',
}
local debugLocal = {
    'debug_skeletons', 'debug_bones', 'debug_render_wireframe', 'toggle_profiler', 'toggle_profiler_window',
}
local debugSimulationView = {'debug_collision', 'debug_navpath', 'debug_grid', 'debug_weapons'}
local labels = {
    reset_camera = 'cinema.wide_view',
    debug_skeletons = 'cinema.skeletons',
    debug_bones = 'cinema.bone_names',
    debug_render_wireframe = 'cinema.wireframe',
    debug_collision = 'cinema.collision',
    debug_navpath = 'cinema.navpath',
    show_fps = 'cinema.fps',
    toggle_profiler = 'cinema.profiler',
    toggle_profiler_window = 'cinema.profiler_window',
}

local function Append(output, group, ids, definitions, actionName, reason)
    for _, id in ipairs(ids) do
        local definition = definitions[id]
        local valid = type(definition) == 'table' and type(definition.action) == 'string' and definition.action ~= ''
        table.insert(output, {
            id = 'faf:' .. id,
            group = group,
            label = labels[id],
            name = not labels[id] and (actionName(id) or id) or nil,
            definition = valid and definition or nil,
            reason = reason or not valid and 'cinema.native_missing' or nil,
        })
    end
end

function Build(custom, mapper, isReplay, multiplayer, debugAllowed)
    local output = {}
    for _, choice in ipairs(custom) do table.insert(output, choice) end
    local definitions = mapper.GetKeyActions()
    local cameraIds = {}
    for _, id in ipairs(camera) do table.insert(cameraIds, id) end
    for index = 1, 10 do
        local slot = math.mod(index, 10)
        table.insert(cameraIds, 'SaveCameraPosition' .. slot)
        table.insert(cameraIds, 'RestoreCameraPosition' .. slot)
    end
    Append(output, 'camera', cameraIds, definitions, mapper.GetActionName)
    Append(output, 'presentation', presentation, definitions, mapper.GetActionName)
    Append(output, 'replay', replay, definitions, mapper.GetActionName)
    Append(output, 'debug', debugClient, definitions, mapper.GetActionName)
    Append(output, 'debug', debugLocal, definitions, mapper.GetActionName,
        not isReplay and multiplayer ~= false and 'cinema.needs_local_view' or nil)
    Append(output, 'debug', debugSimulationView, definitions, mapper.GetActionName,
        (isReplay or multiplayer ~= false or not debugAllowed) and 'cinema.needs_offline_debug' or nil)
    return output
end
