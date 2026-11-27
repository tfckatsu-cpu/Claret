local root = '../mods/ClaretCinema/'
local keys = {}
local hud, failAction = true, nil
local menuAction = 'UI_Lua import("/mods/ClaretCore/modules/MenuKey.lua").Open()'
local function Normalize(key) return string.lower(key) end
local function Clear() keys = {} end
local function Add(batch)
    for key, definition in pairs(batch) do
        keys[Normalize(key)] = definition.action
        if definition.action == failAction then
            failAction = nil
            error('injected failure after native write')
        end
    end
end
local function Remove(batch)
    for key in pairs(batch) do keys[Normalize(key)] = nil end
end
local input = setmetatable({}, {__index = _G})
assert(loadfile(root .. 'modules/InputMode.lua', 't', input))()
local layout = setmetatable({}, {__index = _G})
assert(loadfile(root .. 'modules/KeyboardLayout.lua', 't', layout))()
local native = setmetatable({}, {__index = _G})
assert(loadfile(root .. 'modules/NativeActions.lua', 't', native))()
local director = setmetatable({WARN = function(message) error(message) end}, {__index = _G})
assert(loadfile(root .. 'modules/Director.lua', 't', director))()
local nativeDefinitions = {
    ['lock_zoom'] = {action = 'native lock zoom', category = 'camera', repeatable = true},
    ['pause'] = {action = 'native pause', category = 'ui'},
    ['decrease_game_speed'] = {action = 'native slower', category = 'game'},
    ['increase_game_speed'] = {action = 'native faster', category = 'game'},
    ['reset_game_speed'] = {action = 'native speed reset', category = 'game'},
    ['toggle_lifebars'] = {action = 'native unit bars', category = 'ui'},
    ['Render_Unit_Bars'] = {action = 'native unit bars', category = 'ui'},
    ['debug_bones'] = {action = 'native bone names', category = 'debug'},
    ['debug_collision'] = {action = 'native collision', category = 'debug'},
    ['show_fps'] = {action = 'native fps', category = 'debug'},
}
local multiplayer = false
local settings, writes, failSave = {}, 0, false
local console, camera = {}, {}
local free, freeCameraWrites = false, 0
local function ConExecute(command)
    table.insert(console, command)
    if command == 'ren_UI true' or command == 'ren_UI false' then hud = command == 'ren_UI true' end
    if command == 'cam_Free' then free = not free end
end
local commandEnv = setmetatable({
    ConExecute = ConExecute,
    GetCamera = function()
        return {
            SaveSettings = function() freeCameraWrites = freeCameraWrites + 1; return {} end,
            RestoreSettings = function() freeCameraWrites = freeCameraWrites + 1 end,
            Reset = function() table.insert(camera, 'reset') end,
            RevertRotation = function() table.insert(camera, 'rotation') end,
            DisableEaseInOut = function() table.insert(camera, 'disable ease') end,
            EnableEaseInOut = function() table.insert(camera, 'enable ease') end,
        }
    end,
    WARN = function(message) error(message) end,
}, {__index = _G})
assert(loadfile(root .. 'modules/Commands.lua', 't', commandEnv))()
local prefs = {
    GetFromCurrentProfile = function(key) return settings[key] end,
    SetToCurrentProfile = function(key, value) settings[key] = value end,
}
local events = {}
local env = setmetatable({
    IN_ClearKeyMap = Clear,
    IN_AddKeyMapTable = Add,
    IN_RemoveKeyMapTable = Remove,
    LOG = function(message) table.insert(events, message) end,
    WARN = function(message) table.insert(events, message) end,
    DebugFacilitiesEnabled = function() return false end,
    SessionIsMultiplayer = function() return multiplayer end,
    SavePreferences = function()
        if failSave then error('injected preference save failure') end
        writes = writes + 1
    end,
    import = function(path)
        if path == '/lua/user/prefs.lua' then return prefs end
        if path == '/mods/ClaretCinema/modules/Commands.lua' then return commandEnv end
        if path == '/mods/ClaretCinema/modules/NativeActions.lua' then return native end
        if path == '/mods/ClaretCinema/modules/Director.lua' then return director end
        if path == '/mods/ClaretCinema/modules/KeyboardLayout.lua' then return layout end
        if path == '/lua/keymap/keymapper.lua' then
            return {
                NormalizeKeyBinding = Normalize,
                GetCurrentKeyMap = function() return {A = 'FAF'} end,
                GetActionName = function(id) return id .. ' action' end,
                GetKeyActions = function() return nativeDefinitions end,
            }
        end
        assert(path == '/mods/ClaretCinema/modules/InputMode.lua', 'unexpected runtime import')
        return input
    end,
}, {__index = _G})
env._G = env
assert(loadfile(root .. 'modules/Runtime.lua', 't', env))()
Add({P = {action = 'preexisting'}})
local dispose = env.Start()
assert(env.GetChord('move_origin') == 'Ctrl-Q' and env.GetChord('move_target') == 'Ctrl-W'
    and env.GetChord('move_jump_origin') == 'Ctrl-A' and env.GetChord('move_jump_target') == 'Ctrl-S'
    and env.GetChord('move_play') == 'Ctrl-Z', 'install the requested default flight shortcuts')
writes = 0
env.IN_AddKeyMapTable({A = {action = 'late'}})
env.Toggle()
assert(keys.p == 'preexisting' and keys.a == 'late' and not keys['ctrl-alt-f9'],
    'never replace a partially observed native map')

env.IN_ClearKeyMap()
env.IN_AddKeyMapTable({
    A = {action = 'FAF'}, ['Ctrl-Alt-F9'] = {action = 'foreign'},
    ['Ctrl-Alt-X'] = {action = menuAction}, ['Ctrl-Alt-C'] = {action = 'ordinary command'},
})
local shifted = {action = 'Hotbuild override'}
env.IN_AddKeyMapTable({A = shifted, B = {action = 'mod'}})
shifted.action = 'mutated caller table'
assert(keys['ctrl-alt-f9'] == 'foreign' and keys['ctrl-alt-f8']:find('Toggle', 1, true),
    'reserve a free alternate chord without stealing a normal binding')
local action, known = env.GetNormalAction('A')
assert(known and action == 'FAF action', 'show the ordinary mapped action for a switched chord')
action, known = env.GetNormalAction('B')
assert(known and not action, 'identify a runtime-only assignment without leaking its command string')
assert(not env.Assign('hud', 'Ctrl-Alt-F8') and not env.Assign('hud', 'Esc') and writes == 0,
    'reserve the return key and Escape without writing preferences')
assert(not env.Assign('hud', 'Ctrl-Alt-X'), 'do not let a Cinema command claim the Claret menu chord')
env.Toggle()
assert(not keys.a and not keys.b and not keys['ctrl-alt-f9'] and keys.h and keys['ctrl-alt-f8'],
    'remove all ordinary bindings including keys not assigned to Cinema')
assert(keys['ctrl-alt-x'] == menuAction and not keys['ctrl-alt-c'],
    'pass through the actual menu action, not the default Claret chord or other bindings')
assert(not env.Assign('hud', 'G') and writes == 0, 'leave the active isolated layout unchanged while editing')
env.Perform('hud')
assert(not hud, 'hide the HUD with the Cinema action')
env.Toggle()
assert(hud and keys.a == 'Hotbuild override' and keys.b == 'mod' and keys['ctrl-alt-f9'] == 'foreign',
    'restore the HUD and native override order using the original batch contents')

env.Toggle()
env.IN_ClearKeyMap()
env.IN_AddKeyMapTable({C = {action = 'rebuilt'}, D = {action = 'remove me'}})
env.IN_RemoveKeyMapTable({D = true})
assert(not keys.c and not keys.d and keys.h and keys['ctrl-alt-f8'],
    'a normal-map rebuild cannot leak game bindings into the active Cinema map')
assert(not keys['ctrl-alt-x'], 'a rebuild drops a menu chord no longer present in the normal map')
env.Toggle()
assert(keys.c == 'rebuilt' and not keys.a and not keys.d and not keys.h and keys['ctrl-alt-f9'],
    'apply the latest rebuilt normal map and its removals on exit')

failAction = keys['ctrl-alt-f9']
env.Toggle()
assert(keys.c == 'rebuilt' and not keys.h and keys['ctrl-alt-f9'],
    'undo a partially applied Cinema map when entering fails')
env.Toggle()
failAction = 'rebuilt'
env.Toggle()
assert(not keys.c and keys.h and keys['ctrl-alt-f9'],
    'preserve the working Cinema map when restoring the normal map fails')
env.Perform('hud')
dispose()
assert(hud and keys.c == 'rebuilt' and not keys.h and not keys['ctrl-alt-f9'],
    'teardown restores the normal map and removes the temporary toggle')
assert(env.IN_ClearKeyMap == Clear and env.IN_AddKeyMapTable == Add and env.IN_RemoveKeyMapTable == Remove,
    'teardown releases the native map hooks')

dispose = env.Start()
env.IN_ClearKeyMap()
env.IN_AddKeyMapTable({G = {action = 'normal G'}})
assert(env.Assign('hud', 'G') and settings.ClaretCinemaBindings.actions.hud == 'G' and writes == 1,
    'allow deliberate overlap and save only the Cinema assignment')
failSave = true
assert(not env.Assign('hud', 'Shift-H') and settings.ClaretCinemaBindings.actions.hud == 'G' and writes == 1,
    'failed saves roll back the preference and pending Cinema layout')
failSave = false
env.Toggle()
assert(not keys.h and not keys['shift-h'] and keys.g:find('Perform("hud")', 1, true),
    'the selected HUD chord replaces H only in Cinema mode')
env.Toggle()
assert(keys.g == 'normal G', 'editing a Cinema chord must not overwrite an ordinary assignment')
assert(env.Clear('G') and writes == 2, 'clearing an assignment persists an explicit unbound state')
dispose()
dispose = env.Start()
env.IN_ClearKeyMap()
env.IN_AddKeyMapTable({G = {action = 'normal G'}})
env.Toggle()
assert(not keys.g and not keys.h and keys['ctrl-alt-f9'], 'an explicit unbound value survives reload')
env.Toggle()
assert(not env.Assign('mode', 'G') and keys.g == 'normal G', 'never steal the switch chord from an ordinary action')
assert(env.Assign('mode', 'Ctrl-J') and not keys['ctrl-alt-f9'] and keys['ctrl-j'], 'move the mode key without leaving the old chord active')
failSave = true
assert(not env.Assign('mode', 'Ctrl-K') and keys['ctrl-j'] and not keys['ctrl-k'],
    'restore the previous switch if the preference cannot be saved')
failSave = false
assert(env.Assign('free', 'F6') and not env.Assign('boxes', 'F6'), 'do not overwrite another Cinema command')
assert(env.Assign('faf:lock_zoom', 'F5'), 'native camera actions can use an isolated Cinema chord')
assert(not env.Assign('faf:Render_Unit_Bars', 'F4'), 'duplicate aliases cannot be installed')
assert(env.Assign('faf:pause', 'Shift-F5') and env.Assign('faf:decrease_game_speed', 'Shift-F6')
    and env.Assign('faf:increase_game_speed', 'Shift-F7') and env.Assign('faf:reset_game_speed', 'Shift-F8'),
    'all four game and replay controls can be assigned in a match')
assert(env.Toggle() and keys['ctrl-j'] and keys.f6:find('Perform("free")', 1, true),
    'the new switch stays available in both layouts')
assert(keys.f5 == 'native lock zoom', 'install the unchanged native action instead of a copy of the engine command')
assert(keys['shift-f5'] == 'native pause' and keys['shift-f6'] == 'native slower'
    and keys['shift-f7'] == 'native faster' and keys['shift-f8'] == 'native speed reset',
    'use the same native controls in an active Cinema layout during a match')
console, camera = {}, {}
for _, id in ipairs({'free', 'decals', 'boxes', 'reset', 'ease'}) do env.Perform(id) end
env.Toggle()
assert(table.concat(console, ',') == 'cam_Free,ren_IgnoreDecalLOD,ren_SelectBoxes,cam_Free,ren_IgnoreDecalLOD,ren_SelectBoxes',
    'dispatch and undo the technical console toggles on exit')
assert(table.concat(camera, ',') == 'reset,rotation,disable ease,enable ease', 'dispatch reset and restore easing on exit')
env.IN_AddKeyMapTable({['Ctrl-J'] = {action = 'now occupied'}})
assert(keys['ctrl-j'] == 'now occupied' and keys['ctrl-alt-f9'], 'fall back when the preferred switch becomes occupied')
env.IN_RemoveKeyMapTable({['Ctrl-J'] = true})
assert(keys['ctrl-j'] and not keys['ctrl-alt-f9'], 'restore the preferred switch when it is free again')
dispose()
dispose = env.Start()
env.IN_ClearKeyMap()
env.IN_AddKeyMapTable({G = {action = 'normal G'}})
assert(keys['ctrl-j'] and env.Toggle() and keys.f6, 'reload the saved switch and technical bindings together')
env.IN_AddKeyMapTable({F6 = {action = menuAction}})
assert(keys.f6 == menuAction and keys['ctrl-j'], 'prioritize a moved menu shortcut over a Cinema command')
env.IN_RemoveKeyMapTable({F6 = true})
env.IN_AddKeyMapTable({['Ctrl-Alt-Y'] = {action = menuAction}})
assert(keys.f6:find('Perform("free")', 1, true) and keys['ctrl-alt-y'] == menuAction,
    'track menu reassignment during Cinema and restore the formerly shadowed Cinema command')
env.Toggle()
assert(env.Clear('Ctrl-J') and keys['ctrl-alt-f9'] and not keys['ctrl-j'], 'clearing the switch restores automatic selection')
assert(env.Assign('faf:debug_bones', 'F4') and not env.Assign('faf:debug_collision', 'F3'),
    'client visuals can be bound offline without enabling debug, but dbg tools require debug facilities')
dispose()
multiplayer = true
dispose = env.Start(false)
env.IN_ClearKeyMap()
env.IN_AddKeyMapTable({G = {action = 'normal G'}})
assert(env.Toggle() and not keys.f4 and settings.ClaretCinemaBindings.actions['faf:debug_bones'] == 'F4',
    'skip an unavailable saved diagnostic without deleting its preference')
dispose()
dispose = env.Start(true)
env.IN_ClearKeyMap()
env.IN_AddKeyMapTable({G = {action = 'normal G'}})
assert(env.Toggle() and keys.f4 == 'native bone names', 'reuse the saved bone binding in a replay')
dispose()

local poses, flights, snaps, spins = 0, 0, 0, {}
local threads, time = {}, 0
local cameraStub = {
    SaveSettings = function()
        poses = poses + 1
        return {Focus = {x = poses, y = 0, z = 0}, Heading = 0, Pitch = 0, Zoom = 1}
    end,
    RestoreSettings = function() end,
    HoldRotation = function() end,
    MoveTo = function() flights = flights + 1 end,
    Spin = function(self, heading, zoom) table.insert(spins, {heading, zoom}) end,
    SnapTo = function() snaps = snaps + 1 end,
}
env.GetCamera = function() return cameraStub end
env.ForkThread = function(callback) table.insert(threads, coroutine.create(callback)) end
env.WaitFrames = function() coroutine.yield() end
env.GetSystemTimeSeconds = function() return time end
dispose = env.Start(true)
env.IN_ClearKeyMap()
env.IN_AddKeyMapTable({G = {action = 'normal G'}})
assert(env.Assign('move_origin', 'F1') and env.Assign('move_target', 'F2') and env.Assign('move_play', 'F3'))
assert(env.Assign('pan_origin', 'Shift-F1') and env.Assign('pan_play', 'Shift-F2')
    and env.Assign('spin_origin', 'Shift-F3') and env.Assign('spin_play', 'Shift-F4')
    and env.Assign('motion_stop', 'Shift-F9'))
assert(env.GetChord('move_origin') == 'F1')
env.Perform('move_origin')
assert(poses == 0, 'shortcuts do not execute outside Cinema mode')
assert(env.Toggle() and keys.f1:find('Perform("move_origin")', 1, true)
    and keys.f2:find('Perform("move_target")', 1, true) and keys.f3:find('Perform("move_play")', 1, true))
env.Perform('move_origin')
env.Perform('move_target')
assert(env.RunDrawer('move_jump_origin') and env.RunDrawer('move_jump_target'), 'jump to each captured flight pose')
env.Perform('move_play')
assert(poses == 3 and flights == 0 and snaps == 1,
    'shortcuts capture two poses and start the SnapTo flight from the saved origin')
assert(coroutine.resume(threads[1]), 'the flight thread waits for its first UI frame')
time = 1
assert(coroutine.resume(threads[1]) and snaps == 2,
    'the shortcut drives a frame of SnapTo flight with the runtime clock')
env.Perform('pan_origin')
env.Perform('pan_play')
env.Perform('motion_stop')
env.Perform('spin_origin')
env.Perform('spin_play')
env.Perform('motion_stop')
assert(flights == 1, 'pan and spin commands use the existing director and shared stop')
assert(spins[1] and spins[2] and not spins[3] and spins[1][1] ~= 0 and spins[2][1] == 0 and spins[2][2] == 0,
    'spin starts and the shared stop cancels rotation')
local changedCount = 0
env.Subscribe('conflict-test', function() changedCount = changedCount + 1 end)
env.IN_AddKeyMapTable({F1 = {action = menuAction}})
local chord, blocked = env.GetChord('move_origin')
assert(chord == 'F1' and blocked and changedCount > 0, 'report a menu conflict without losing the assignment')
env.IN_RemoveKeyMapTable({F1 = true})
chord, blocked = env.GetChord('move_origin')
assert(chord == 'F1' and not blocked, 'clear the conflict when the menu moves away')
env.Unsubscribe('conflict-test')
env.Toggle()
dispose()
dispose = env.Start(true)
assert(env.GetChord('move_origin') == 'F1' and env.GetChord('move_target') == 'F2'
    and env.GetChord('move_play') == 'F3', 'new assignments survive reload')
assert(env.Clear('Ctrl-A'), 'allow clearing a default jump shortcut')
dispose()
dispose = env.Start(true)
assert(not env.GetChord('move_jump_origin'), 'explicitly cleared defaults stay unbound on reload')
dispose()
local preserved = settings.ClaretCinemaBindings
settings.ClaretCinemaBindings = {actions = {hud = 'G', move_origin = 'F1'}}
dispose = env.Start(true)
assert(env.GetChord('move_origin') == 'F1' and not env.GetChord('move_target')
    and not env.GetChord('move_play'), 'existing profiles never acquire missing defaults')
dispose()
settings.ClaretCinemaBindings = preserved

local function Catalogue(isReplay, isMultiplayer, debugAllowed)
    local result = {}
    local mockMapper = {
        GetKeyActions = function() return nativeDefinitions end,
        GetActionName = function(id) return id end,
    }
    for _, choice in ipairs(native.Build(commandEnv.Choices, mockMapper, isReplay, isMultiplayer, debugAllowed)) do
        assert(not result[choice.id], 'catalogue entries have stable unique IDs')
        result[choice.id] = choice
    end
    return result
end
local live = Catalogue(false, true, false)
local replay = Catalogue(true, false, false)
local offlineDebug = Catalogue(false, false, true)
assert(live['faf:debug_bones'].reason == 'cinema.needs_local_view'
    and replay['faf:debug_bones'].definition.action == 'native bone names'
    and not replay['faf:debug_bones'].reason and not live['faf:show_fps'].reason,
    'distinguish replay/offline rendering diagnostics from client FPS')
assert(replay['faf:debug_collision'].reason == 'cinema.needs_offline_debug'
    and not offlineDebug['faf:debug_collision'].reason, 'only install dbg visualization in an offline debug session')
assert(not live['faf:pause'].reason and not replay['faf:pause'].reason,
    'Cinema does not add a context restriction to the native pause action')
assert(replay['faf:lock_zoom'].definition.repeatable and not replay['faf:cam_free'] and not replay['faf:Render_Unit_Bars'],
    'preserve native flags and omit aliases of existing actions')

local freeCamera = commandEnv.Create()
assert(freeCamera.Run('free') and free and freeCameraWrites == 0, 'use only the native command on free-camera entry')
assert(freeCamera.Run('free') and not free and freeCameraWrites == 0,
    'never capture or restore a pose during the native free-camera transition')

print('PASS: Cinema isolates input, preserves ordinary bindings, and saves only its own settings')
