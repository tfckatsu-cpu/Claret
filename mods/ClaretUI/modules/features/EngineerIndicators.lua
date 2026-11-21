local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Group = import('/lua/maui/group.lua').Group
local Layout = import('/lua/maui/layouthelpers.lua')
local Game = import('/lua/ui/game/gamemain.lua')
local Commands = import('/lua/ui/game/commandmode.lua')
local World = import('/lua/ui/game/worldview.lua')
local Colors = import('/mods/ClaretCore/modules/Theme.lua').Colors

local DISCOVERY_INTERVAL = 2
local STATE_SWEEPS_PER_SECOND = 5
local NEW_CONTROLS_PER_FRAME = 24
local OPTIMIZED_MARKER_LIMIT = 128
local OPTIMIZED_SCAN_PER_FRAME = 60
local FADE_START_ZOOM = 0.55
local FADE_END_ZOOM = 0.65
local FADE_SECONDS = 0.15
local MARKER_SIZE = 18
local SYNC_KEY = 'ClaretUI.EngineerIndicators'
local textures = {
    '/mods/ClaretUI/textures/engineers/tier-1.png',
    '/mods/ClaretUI/textures/engineers/tier-2.png',
    '/mods/ClaretUI/textures/engineers/tier-3.png',
}
local floor = math.floor
local session

local function Release(owner, entry)
    local marker = entry.marker
    if not marker then return end
    if IsDestroyed(marker.control) then
        entry.marker = nil
        return
    end
    marker.control:Hide()
    table.insert(owner.pool, marker)
    entry.marker = nil
end

local function Forget(owner, entry)
    Release(owner, entry)
    local units, index = owner.units, entry.index
    local lastIndex = owner.count
    if index ~= lastIndex then
        local last = units[lastIndex]
        units[index], last.index = last, index
    end
    units[lastIndex], owner.byId[entry.id] = nil, nil
    owner.count = lastIndex - 1
end

local function Track(owner, unit, id)
    if owner.byId[id] or not unit or unit:IsDead() or unit:GetArmy() ~= owner.army then return end
    if not unit:IsInCategory('ENGINEER') or unit:IsInCategory('COMMAND')
        or unit:IsInCategory('SUBCOMMANDER') then return end
    local tier = unit:IsInCategory('TECH1') and 1
        or unit:IsInCategory('TECH2') and 2
        or unit:IsInCategory('TECH3') and 3
    if not tier then return end

    local index = owner.count + 1
    local entry = { id = id, unit = unit, tier = tier, index = index }
    owner.units[index], owner.byId[id], owner.count = entry, entry, index
end

local function SetArmy(owner, army)
    if owner.army == army then return end
    for i = 1, owner.count do Release(owner, owner.units[i]) end
    owner.army, owner.count = army, 0
    owner.units, owner.byId, owner.visible = {}, {}, {}
    owner.visibleCount = 0
    owner.nextDiscovery, owner.cursor, owner.sampleCredit = 0, 1, 0
end

local function SelectEngineers()
    UISelectionByCategory('ENGINEER', false, false, false, false)
    return GetSelectedUnits()
end

local function Prune(owner)
    for i = owner.count, 1, -1 do
        local entry = owner.units[i]
        if entry.unit:IsDead() or entry.unit:GetArmy() ~= owner.army then Forget(owner, entry) end
    end
end

local function Discover(owner)
    local previous = GetSelectedUnits()
    Game.SetIgnoreSelection(true)
    local ok, units = pcall(SelectEngineers)
    local restored, restoreError = pcall(SelectUnits, previous)
    Game.SetIgnoreSelection(false)
    if not ok or not restored then
        if not owner.discoveryFailed then
            WARN('[ClaretUI] Engineer discovery failed: ' .. tostring(not ok and units or restoreError))
        end
        owner.discoveryFailed = true
        return
    end
    owner.discoveryFailed = false

    Prune(owner)
    if units then
        for _, unit in ipairs(units) do Track(owner, unit, unit:GetEntityId()) end
    end
end

local function OnSync(owner, sync)
    SetArmy(owner, GetFocusArmy())
    if owner.army <= 0 then return end
    if sync.ArmyTransfer then
        Prune(owner)
        owner.nextDiscovery = 0
    end
    if sync.UnitData then
        for id, data in pairs(sync.UnitData) do
            if data and not owner.byId[id] then Track(owner, GetUnitById(id), id) end
        end
    end
    if sync.ReleaseIds then
        for id in pairs(sync.ReleaseIds) do
            local entry = owner.byId[id]
            if entry then Forget(owner, entry) end
        end
    end
end

local function NewMarker(owner)
    local control = Bitmap(owner.layer, nil, 'Claret Engineer Indicator')
    control:DisableHitTest()
    control.Depth:Set(owner.layer.Depth)
    control:Hide()
    return { control = control }
end

local function Project(entry, view, width, height, frame)
    local point = view:GetScreenPos(entry.unit)
    entry.projectionFrame = frame
    entry.onScreen = point and point.x >= 0 and point.x < width and point.y >= 0 and point.y < height
    if entry.onScreen then entry.x, entry.y = point.x, point.y end
    return entry.onScreen
end

local function UpdateStates(owner, view, width, height, delta)
    local count = owner.count
    local credit = owner.sampleCredit + delta * count * STATE_SWEEPS_PER_SECOND
    local budget = math.min(count, floor(credit))
    if owner.optimize or owner.idleOnly then budget = math.min(budget, OPTIMIZED_SCAN_PER_FRAME) end
    owner.sampleCredit = credit - floor(credit)
    for _ = 1, budget do
        if owner.cursor > owner.count then owner.cursor = 1 end
        local entry = owner.units[owner.cursor]
        if not entry then break end
        if (entry.marker or owner.optimize or owner.idleOnly) and entry.unit:IsDead() then
            Forget(owner, entry)
        else
            if owner.idleOnly then entry.idle = entry.unit:IsIdle() end
            if owner.optimize and not entry.marker then
                if not owner.idleOnly or entry.idle then
                    Project(entry, view, width, height, owner.frame)
                else
                    entry.onScreen = false
                end
            end
            if not owner.idleOnly and (entry.marker or (owner.optimize and entry.onScreen)) then
                entry.idle = entry.unit:IsIdle()
            end
            owner.cursor = owner.cursor + 1
        end
    end
end

local function LimitVisible(owner, count)
    local visible, quotas = owner.visible, owner.quotas
    for priority = 1, 4 do quotas[priority] = 0 end
    -- Keep existing markers within each idle/busy group.
    for i = 1, count do
        local entry = visible[i]
        -- In idle-only mode, leave room for existing markers to finish fading.
        local priority = ((owner.idleOnly or entry.idle) and 1 or 3) + (entry.marker and 0 or 1)
        entry.priority = priority
        quotas[priority] = quotas[priority] + 1
    end
    local remaining = OPTIMIZED_MARKER_LIMIT
    for priority = 1, 4 do
        quotas[priority] = math.min(quotas[priority], remaining)
        remaining = remaining - quotas[priority]
    end
    local kept = 0
    for i = 1, count do
        local entry = visible[i]
        local priority = entry.priority
        if quotas[priority] > 0 then
            quotas[priority] = quotas[priority] - 1
            kept = kept + 1
            visible[kept] = entry
        else
            Release(owner, entry)
        end
    end
    return kept
end

local function TrimPool(owner, reserved)
    local excess = table.getn(owner.pool) - (OPTIMIZED_MARKER_LIMIT - reserved)
    for _ = 1, math.min(excess, NEW_CONTROLS_PER_FRAME) do
        table.remove(owner.pool).control:Destroy()
    end
end

local function ApproachOpacity(previous, target, delta)
    local step = delta / FADE_SECONDS
    return math.min(previous + step, math.max(previous - step, target))
end

local function PaintMarker(marker, x, y, size, opacity, idleColor)
    local control = marker.control
    if marker.idleColor ~= idleColor then
        marker.idleColor = idleColor
        control:SetColorMask(idleColor and Colors.hudDamage or Colors.hudValue)
    end
    if marker.opacity ~= opacity then
        marker.opacity = opacity
        control:SetAlpha(opacity)
    end
    if marker.size ~= size then
        marker.size = size
        control.Width:Set(size)
        control.Height:Set(size)
    end
    if marker.x ~= x then
        marker.x = x
        control.Left:SetValue(x)
    end
    if marker.y ~= y then
        marker.y = y
        control.Top:SetValue(y)
    end
end

local function Draw(owner, view, delta)
    local left, top, width, height = view.Left(), view.Top(), view.Width(), view.Height()
    owner.frame = owner.frame + 1
    UpdateStates(owner, view, width, height, delta)
    local pixelScale = Layout.GetPixelScaleFactor()
    local size = math.max(1, floor(MARKER_SIZE * owner.scale * pixelScale + 0.5))
    local gap = math.max(1, floor(2 * pixelScale + 0.5))
    local opacity = owner.opacity
    local half = size * 0.5
    local visible, count = owner.visible, 0

    -- Return markers first, so a pan can reuse them on the same frame.
    for i = 1, owner.count do
        local entry = owner.units[i]
        local eligible = not owner.idleOnly or entry.idle or entry.marker
        if eligible and (not owner.optimize or entry.marker) then Project(entry, view, width, height, owner.frame) end
        if eligible and entry.onScreen then
            count = count + 1
            visible[count] = entry
        else
            Release(owner, entry)
        end
    end
    local projected = count
    if owner.optimize and count > OPTIMIZED_MARKER_LIMIT then count = LimitVisible(owner, count) end
    for i = count + 1, math.max(projected, owner.visibleCount) do visible[i] = nil end
    owner.visibleCount = count

    local remaining = NEW_CONTROLS_PER_FRAME
    local admissions = NEW_CONTROLS_PER_FRAME
    for i = 1, count do
        local entry = visible[i]
        local marker = entry.marker
        local acquired = not marker
        local canAcquire = acquired and (owner.pool[1] or remaining > 0)
        if canAcquire and owner.optimize then
            canAcquire = admissions > 0
            if canAcquire then
                admissions = admissions - 1
                -- A cached candidate may have left the view since its last scan.
                canAcquire = entry.projectionFrame == owner.frame
                    or Project(entry, view, width, height, owner.frame)
            end
        end
        if canAcquire and not entry.unit:IsDead() then
            entry.idle = entry.unit:IsIdle()
            if not owner.idleOnly or entry.idle then
                marker = table.remove(owner.pool)
                if not marker then
                    marker = NewMarker(owner)
                    remaining = remaining - 1
                end
                entry.marker = marker
                marker.statusOpacity = owner.idleOnly and 0 or 1
                if marker.tier ~= entry.tier then
                    marker.tier = entry.tier
                    marker.idleColor = nil
                    marker.control:SetTexture(textures[entry.tier], 0)
                end
            end
        end
        if marker then
            local target = (not owner.idleOnly or entry.idle) and 1 or 0
            if marker.statusOpacity ~= target then
                marker.statusOpacity = ApproachOpacity(marker.statusOpacity, target, delta)
            end
            if marker.statusOpacity == 0 then
                Release(owner, entry)
            else
                local x, y = floor(left + entry.x - half), floor(top + entry.y - size - gap)
                PaintMarker(marker, x, y, size, opacity * marker.statusOpacity, owner.idleOnly or entry.idle)
                if acquired then marker.control:Show() end
            end
        end
    end
    if owner.optimize then TrimPool(owner, count) end
end

local function ClearView(owner)
    if owner.layer and not IsDestroyed(owner.layer) then owner.layer:Destroy() end
    for i = 1, owner.count do
        local entry = owner.units[i]
        entry.marker, entry.onScreen = nil, false
    end
    owner.view, owner.layer, owner.camera, owner.opacity = nil, nil, nil, nil
    owner.pool, owner.visible, owner.visibleCount = {}, {}, 0
end

local function TargetOpacity(owner)
    if not owner.hideFar then return 1 end
    local camera = owner.camera
    if not camera or IsDestroyed(camera) then
        camera = GetCamera('WorldCamera')
        owner.camera = camera
    end
    if camera then
        local minimum, maximum = camera:GetMinZoom(), camera:GetMaxZoom()
        if maximum > minimum then
            local zoom = (camera:GetZoom() - minimum) / (maximum - minimum)
            local visible = math.min(1, math.max(0, (FADE_END_ZOOM - zoom) / (FADE_END_ZOOM - FADE_START_ZOOM)))
            return visible * visible * (3 - 2 * visible)
        end
    end
    return 1
end

local function Frame(owner, delta)
    local view = World.viewLeft
    if view and IsDestroyed(view) then view = nil end
    if owner.view and view ~= owner.view then ClearView(owner) end
    SetArmy(owner, GetFocusArmy())
    if owner.army <= 0 or not view or view:IsHidden() then return end

    owner.nextDiscovery = owner.nextDiscovery - delta
    -- Give FAF's startup selection and the first player commands time to settle.
    if owner.nextDiscovery <= 0 and GetGameTimeSeconds() >= 15
        and not Commands.GetCommandMode()[1] and not GetInputCapture() then
        owner.nextDiscovery = DISCOVERY_INTERVAL
        Discover(owner)
    end
    if not owner.layer then
        owner.view = view
        owner.layer = Group(view)
        Layout.FillParent(owner.layer, view)
        owner.layer:DisableHitTest()
        owner.layer.Depth:Set(function() return view.Depth() + 2 end)
    end

    local target, previous = TargetOpacity(owner), owner.opacity
    local opacity = target
    if previous then
        -- Keep the transition smooth even when the camera snaps to a different zoom.
        opacity = ApproachOpacity(previous, target, delta)
    end
    owner.opacity = opacity
    if opacity == 0 then
        if previous and previous > 0 then
            for i = 1, owner.count do
                local entry = owner.units[i]
                Release(owner, entry)
                entry.onScreen = false
            end
            owner.visible, owner.visibleCount = {}, 0
        end
        if owner.optimize then TrimPool(owner, 0) end
        return
    end
    Draw(owner, view, delta)
end

local function SetEnabled(owner, enabled)
    if owner.enabled == enabled then return end
    owner.enabled = enabled
    if enabled then
        AddOnSyncCallback(owner.onSync, SYNC_KEY)
    else
        RemoveOnSyncCallback(SYNC_KEY)
        ClearView(owner)
        SetArmy(owner, 0)
    end
    if not IsDestroyed(owner.driver) then owner.driver:SetNeedsFrameUpdate(enabled) end
end

local function ReadScale(value)
    if type(value) ~= 'number' or value ~= value or value < 50 or value > 200 then return 1 end
    return value * 0.01
end

function Start(self, scope, isReplay, options)
    local root = GetFrame(0)
    if not root then return end
    local driver = scope:Own(Group(root))
    driver:DisableHitTest()
    local hideFar = options.engineerIndicatorsHideFar
    local scale = options.engineerIndicatorsScale
    local optimize = options.engineerIndicatorsOptimize
    local idleOnly = options.engineerIndicatorsIdleOnly
    local owner = {
        driver = driver, enabled = false, army = 0, count = 0, units = {}, byId = {},
        pool = {}, visible = {}, visibleCount = 0, nextDiscovery = 0, cursor = 1, sampleCredit = 0,
        hideFar = hideFar:Get() ~= false,
        scale = ReadScale(scale:Get()),
        optimize = optimize:Get() == true, idleOnly = idleOnly:Get() == true, quotas = {}, frame = 0,
    }
    driver.OnFrame = function(_, delta) Frame(owner, delta) end
    owner.onSync = function(sync) OnSync(owner, sync) end
    session = owner
    scope:Bind(hideFar.OnChanged, function(_, value) owner.hideFar = value ~= false end)
    scope:Bind(scale.OnChanged, function(_, value) owner.scale = ReadScale(value) end)
    scope:Bind(optimize.OnChanged, function(_, value) owner.optimize = value == true end)
    scope:Bind(idleOnly.OnChanged, function(_, value) owner.idleOnly = value == true end)
    scope:Defer(function()
        SetEnabled(owner, false)
        session = nil
    end)
end

function SetVisible(self, visible)
    if session then SetEnabled(session, visible) end
end
