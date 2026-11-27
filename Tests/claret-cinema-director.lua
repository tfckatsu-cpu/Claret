table.getn = table.getn or function(t) return #t end
local warnings = {}
local env = setmetatable({WARN = function(message) table.insert(warnings, message) end}, {__index = _G})
assert(loadfile('../mods/ClaretCinema/modules/Director.lua', 't', env))()

local function Pose(x, y, z)
    return {Focus = {x = x, y = y, z = z}, Heading = 0.6, Pitch = 0.2, Zoom = 45}
end
local camera = {pose = Pose(10, 4, 20), holds = 0, calls = {}}
local timers, commands, statuses = {}, {}, {}
local frame, now, failStart, failSchedule = nil, 0, false, false
function camera:SaveSettings() table.insert(self.calls, 'save'); return self.pose end
function camera:RestoreSettings(pose) table.insert(self.calls, 'restore'); self.pose = pose end
function camera:HoldRotation() table.insert(self.calls, 'hold'); self.holds = self.holds + 1 end
function camera:MoveTo(focus, rotation, zoom, seconds) table.insert(self.calls, 'move'); self.move = {focus, rotation, zoom, seconds}; self.started = self.pose end
function camera:SnapTo(focus, rotation, zoom)
    table.insert(self.calls, 'snap')
    if self.failSnap then error('simulated camera error') end
    self.frozen = {focus, rotation, zoom}
    self.pose = {Focus = {x = focus.x or focus[1], y = focus.y or focus[2], z = focus.z or focus[3]},
        Heading = rotation[1], Pitch = rotation[2], Zoom = zoom}
end
function camera:Spin(heading, zoom) table.insert(self.calls, 'spin'); self.spin = {heading, zoom} end

local director = env.Create(function() return camera end,
    function(seconds, done)
        if failSchedule then error('simulated schedule error') end
        table.insert(timers, {seconds, done})
    end,
    function(command) table.insert(commands, command) end,
    function(callback)
        if failStart then error('simulated frame setup error') end
        frame = callback
    end,
    function() return now end)
director.Listen(function(status) table.insert(statuses, status or 'idle') end)
assert(not director.Play('move', false) and not director.ToggleOrigin('pan'),
    'require captured poses only for the operations that need them')
assert(director.Capture('move', 'origin'), 'capture a starting camera pose')
camera.pose = Pose(30, 6, 50)
assert(director.Capture('move', 'target'), 'capture a destination camera pose')
local afterCapture = Pose(5, 9, 15)
camera.pose = afterCapture
assert(director.Set('move', env.Motion.move[1], 3) and director.Play('move', true),
    'start a timed preview from the chosen position')
assert(camera.pose.Focus.x == 10 and director.IsActive(),
    'start the preview at the saved origin')
now = 3
assert(frame() and camera.pose.Focus.x == 30, 'preview reaches the target on completion')
assert(not frame() and camera.pose.Focus.x == afterCapture.Focus.x
    and statuses[1] == 'cinema.previewing' and statuses[2] == 'idle',
    'completed previews restore the pre-preview view and clear status')
assert(director.Play('move', true), 'start a preview for endpoint cancellation')
now = 6
assert(frame() and camera.pose.Focus.x == 30 and director.Stop(),
    'stop after the endpoint cancels the pending preview return')
local endCalls = table.getn(camera.calls)
assert(not frame() and table.getn(camera.calls) == endCalls and camera.pose.Focus.x == 30,
    'cancelled preview does not restore its previous pose')
camera.pose = afterCapture
assert(director.Play('move', true), 'start a preview for restore failure')
now = 9
assert(frame() and camera.pose.Focus.x == 30, 'preview reaches endpoint before restore failure')
camera.failSnap = true
assert(not frame() and not director.IsActive(), 'failed preview return stops frame processing')
camera.failSnap = false
camera.pose = afterCapture
failStart = true
local beforeOriginFailure = table.getn(camera.calls)
assert(not director.Play('move', false) and table.getn(camera.calls) == beforeOriginFailure + 1,
    'failed frame setup does not apply the captured origin')
failStart = false
camera.failSnap = true
local previousFrame = frame
assert(not director.Play('move', false) and not director.IsActive(),
    'failed origin snap invalidates the registered frame callback')
camera.failSnap = false
local afterOriginFailure = table.getn(camera.calls)
assert(frame ~= previousFrame and not frame() and table.getn(camera.calls) == afterOriginFailure,
    'a callback registered before origin failure cannot write later')

assert(director.Capture('pan', 'origin') and director.Set('pan', env.Motion.pan[1], 1.25)
    and director.Set('pan', env.Motion.pan[2], -0.5) and director.Set('pan', env.Motion.pan[3], 4)
    and director.Play('pan', true), 'start a pan with independent signed axes and adjustable time')
assert(camera.move[1][1] == 10 and camera.move[1][2] == 9 and camera.move[1][3] == 13 and camera.move[4] == 4,
    'apply pan rates over the actual duration without changing the camera height')
assert(director.Jump('move', 'target') and camera.frozen and camera.pose.Focus.x == 30,
    'jump interrupts the previous movement and restores the selected pose')
timers[1][2]()
assert(camera.pose.Focus.x == 30, 'a cancelled preview cannot unexpectedly restore its old camera later')

assert(director.Play('spin', true) and timers[2][1] == 5 and camera.spin[1] == 0.1,
    'preview spin uses the reference duration and initial rates')
assert(director.Play('spin', false) and director.IsActive() and not timers[3],
    'continuous spin has no preview timer')
local beforeSpinStop = camera.pose.Focus.x
assert(director.Stop() and camera.spin[1] == 0 and camera.spin[2] == 0 and not director.IsActive(),
    'stop deactivates continuous rotation')
assert(camera.pose.Focus.x == beforeSpinStop, 'stop preserves coordinates from keyed engine vectors')

camera.pose = {Focus = {x = 0, y = 0, z = 0}, Heading = 3, Pitch = 0, Zoom = 10}
assert(director.Capture('move', 'target') and director.ToggleOrigin('move'),
    'capture the flight target and disable the saved start')
camera.pose = {Focus = {x = 10, y = 20, z = 30}, Heading = -3, Pitch = 1, Zoom = 20}
now = 10
assert(director.Set('move', env.Motion.move[1], 4) and director.Play('move', false),
    'start the frame-driven flight from the current pose')
local oldTarget = director.Get('move', 'target')
oldTarget.Focus.x = 99
director.Set('move', env.Motion.move[1], 10)
now = 11
assert(frame() and math.abs(camera.pose.Focus.x - 8.4375) < 0.00001
    and math.abs(camera.pose.Heading - (-3 + (-2 * math.pi + 6) * 0.15625)) < 0.00001,
    'quarter progress uses smoothstep and the shortest heading arc, with frozen inputs')
now = 15
assert(not frame() and not director.IsActive() and camera.pose.Focus.x == 0
    and camera.pose.Heading == 3 and camera.pose.Zoom == 10,
    'a delayed frame reaches the original exact target')
assert(director.Play('move', true), 'start a preview that can be stopped')
local oldFrame = frame
assert(director.Stop(), 'stop the frame-driven preview')
local afterStop = table.getn(camera.calls)
assert(not oldFrame() and table.getn(camera.calls) == afterStop,
    'stop cancels all frame writes and preview restoration')
failStart = true
local beforeFailure = table.getn(camera.calls)
assert(not director.Play('move', false) and not director.IsActive()
    and table.getn(camera.calls) == beforeFailure + 1,
    'failed frame setup does not write the camera or leave an active run')
failStart = false
assert(director.Play('move', false), 'start a flight before a simulated camera failure')
camera.failSnap = true
local warningsBeforeFrame = table.getn(warnings)
assert(not frame() and not director.IsActive() and table.getn(warnings) == warningsBeforeFrame + 1
    and statuses[table.getn(statuses)] == 'cinema.camera_unavailable',
    'camera failure stops recurring frame writes')
camera.failSnap = false
assert(director.Play('move', false), 'start a flight before replacement')
oldFrame = frame
assert(director.Play('spin', false), 'replace the flight with a spin')
local beforeStale = table.getn(camera.calls)
assert(not oldFrame() and table.getn(camera.calls) == beforeStale and director.IsActive(),
    'stale frame cannot write the camera or clear the replacement')
assert(director.Stop(), 'stop the replacement spin')
assert(director.SetVisual(env.Visual[1], 65) and commands[1] == 'cam_NearFOV 65', 'apply a visual slider through its fixed engine command')
assert(not director.SetVisual(env.Visual[1], 200) and not commands[2], 'reject out-of-range slider values')
assert(director.ResetVisual() and commands[2] == 'cam_NearFOV 80' and not commands[3],
    'reset only the visual settings Cinema adjusted')
assert(director.Play('move', false), 'start a flight before teardown')
oldFrame = frame
director.Destroy()
local afterDestroy = table.getn(camera.calls)
assert(not oldFrame() and table.getn(camera.calls) == afterDestroy and not director.IsActive(),
    'frame callback cannot modify the camera after teardown')
print('PASS: Cinema camera poses, eased flight, preview, pan timing, spin, stop, and visual controls')
