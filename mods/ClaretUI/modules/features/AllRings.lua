local Data = import('/mods/ClaretUI/modules/features/AllRingsData.lua')
local viewModule = '/lua/ui/game/worldview.lua'
local getCommandMode = import('/lua/ui/game/commandmode.lua').GetCommandMode
local shapeId = 'ClaretUI.AllRings'
local builders = categories.REPAIR + categories.RECLAIM + categories.xrl0403
local reclaimers = categories.ENGINEER + categories.FACTORY
local empty = {}
local filters = {
    AllMilitary = 'ringsDirectFire', IndirectFire = 'ringsIndirectFire',
    AntiAir = 'ringsAntiAir', AntiNavy = 'ringsAntiNavy', Defense = 'ringsCountermeasure',
    Radar = 'ringsRadar', Sonar = 'ringsSonar', Omni = 'ringsOmni', CounterIntel = 'ringsCounterIntel',
}
local movement = { Move = true, AggressiveMove = true, Patrol = true, Teleport = true }
local buildOrders = { RULEUCC_Repair = true, RULEUCC_Reclaim = true, RULEUCC_Guard = true }
local session

local function QueuePosition(unit)
    if IsKeyDown('SHIFT') then
        local queue = unit:GetCommandQueue() or empty
        for index = table.getn(queue), 1, -1 do
            local order = queue[index]
            local pos = order.position
            if movement[order.type] and pos then
                return Vector(math.floor(pos[1]) + 0.5, pos[2], math.floor(pos[3]) + 0.5)
            end
        end
    end
    return unit:GetInterpolatedPosition()
end

local function TargetSize(mode, name)
    local target
    if mode == 'build' then
        target = __blueprints[name]
    elseif name == 'RULEUCC_Repair' or name == 'RULEUCC_Reclaim' then
        local info = GetRolloverInfo()
        if info and (name == 'RULEUCC_Reclaim'
            or (info.armyIndex and IsAlly(info.armyIndex + 1, GetFocusArmy()))) then
            target = __blueprints[info.blueprintId]
        end
    end
    if target then
        if name == 'RULEUCC_Reclaim' and target.Footprint then
            return math.max(target.Footprint.SizeX or 1, target.Footprint.SizeZ or 1)
        elseif target.Physics then
            return math.max(target.Physics.SkirtSizeX or 1, target.Physics.SkirtSizeZ or 1)
        end
    end
    return 1
end

local function BuildRing(selection, position, mode, name, actual)
    local largest, first = 0, nil
    local targetSize = actual and TargetSize(mode, name)
    for _, unit in ipairs(selection) do
        if EntityCategoryContains(builders, unit) then
            local bp = unit:GetBlueprint()
            if bp then
                local economy, footprint = bp.Economy or empty, bp.Footprint or empty
                local padding = actual and (math.max(footprint.SizeX or 1, footprint.SizeZ or 1) + targetSize) or 2
                largest = math.max(largest, (economy.MaxBuildDistance or 5) + padding)
                first = first or unit
            end
        end
    end
    if first then return position or QueuePosition(first), largest end
end

local function HoverRings(cache)
    local rollover = GetRolloverInfo()
    if not rollover or not rollover.blueprintId or rollover.blueprintId == 'unknown' then return empty end
    local unit = rollover.userUnit
    local blueprint = unit and unit:GetBlueprint() or __blueprints[rollover.blueprintId]
    return cache:Get(blueprint, unit)
end

local function UpdateSelection(state, selection, cache)
    local descriptors = state.selectionDescriptors
    local count = table.getn(selection)
    local changed = count ~= table.getn(descriptors)
    for index, unit in ipairs(selection) do
        local rings = cache:Get(unit:GetBlueprint(), unit)
        if descriptors[index] ~= rings then
            descriptors[index] = rings
            changed = true
        end
    end
    if not changed then return end
    for index = table.getn(descriptors), count + 1, -1 do descriptors[index] = nil end

    local combined, seen = {}, {}
    for _, rings in ipairs(descriptors) do
        if not seen[rings] then
            seen[rings] = true
            for _, ring in ipairs(rings) do
                local radii = seen[ring.kind]
                if not radii then
                    radii = {}
                    seen[ring.kind] = radii
                end
                if not radii[ring.radius] then
                    radii[ring.radius] = true
                    table.insert(combined, ring)
                end
            end
        end
    end
    state.selectionRings = combined
end

local function PreviewKey(key)
    return key == 'CONTROL' and 'CONTROL' or 'SHIFT'
end

local function Update(state, settings, cache)
    local command = getCommandMode()
    local mode, name = command[1], command[2] and command[2].name
    local atCursor = not mode or (mode == 'order' and name == 'RULEUCC_Move')
    local attackKey = PreviewKey(settings.ringSelectionKey)
    local hover = not mode and IsKeyDown(attackKey)
    local selected = atCursor and IsKeyDown(attackKey)
    local reclaim = atCursor and IsKeyDown(18)
    local build = atCursor and IsKeyDown(PreviewKey(settings.ringBuildKey))
    local anchored = not atCursor and (state.buildPosition or mode == 'build' or (mode == 'order' and buildOrders[name]))
    local selection = (selected or reclaim or build or anchored) and GetSelectedUnits() or empty
    local cursor = (hover or selected or reclaim or build) and GetMouseWorldPos()

    state.cursor = cursor
    state.hover = hover and cursor and HoverRings(cache) or empty
    state.showSelection = selected and cursor
    if state.showSelection then UpdateSelection(state, selection, cache) end

    state.buildPosition, state.buildRadius = nil, nil
    state.buildStyle = Data.Style('Miscellaneous')
    if reclaim and cursor then
        for _, unit in ipairs(selection) do
            if EntityCategoryContains(reclaimers, unit) then
                state.buildPosition, state.buildRadius = cursor, 28
                state.buildStyle = Data.Style('AllMilitary')
                break
            end
        end
    elseif (build and cursor) or anchored then
        state.buildPosition, state.buildRadius = BuildRing(
            selection, atCursor and cursor, mode, name, settings.ringsActualBuild)
    end
end

local function Draw(rings, position, settings)
    for _, ring in ipairs(rings) do
        if settings[filters[ring.kind]] then
            UI_DrawCircle(position, ring.radius, ring.color, ring.thickness)
        end
    end
end

function Install()
    ReUI.Core.Hook(viewModule, 'RegisterWorldView', function(original)
        return function(view)
            original(view)
            if session then session:Attach(view) end
        end
    end)
    ReUI.Core.Hook(viewModule, 'UnregisterWorldView', function(original)
        return function(view)
            if session then session:Detach(view, true) end
            original(view)
        end
    end)
end

function Start(self, scope, isReplay, options)
    local owner = { views = {}, enabled = false }
    local cache = Data.CreateCache()
    local settings = {}
    local function Observe(key)
        local option = options[key]
        settings[key] = option:Get()
        scope:Bind(option.OnChanged, function() settings[key] = option:Get() end)
    end
    for _, key in pairs(filters) do Observe(key) end
    for _, key in ipairs({ 'ringSelectionKey', 'ringBuildKey', 'ringsActualBuild', 'ringsMinimap' }) do
        Observe(key)
    end

    function owner:Attach(view)
        if not self.enabled or self.views[view] then return end
        local minimap = view._cameraName == 'MiniMap'
        local state = { selectionDescriptors = {}, selectionRings = {}, hover = empty }
        local originalCursor = view.OnUpdateCursor
        local onCursor = function(control)
            originalCursor(control)
            if self.enabled and control.CursorOverWorld and (not minimap or settings.ringsMinimap) then
                self.active = control
                Update(state, settings, cache)
            else
                state.buildPosition = nil
                if self.active == control then self.active = nil end
            end
        end
        local shape = { OnRender = true }
        function shape:Render()
            local active = owner.active
            if not owner.enabled or not active or not active.CursorOverWorld or active:IsHidden() then return end
            if minimap then
                if not settings.ringsMinimap then return end
            elseif active ~= view then
                return
            end
            local frame = owner.views[active].state
            if frame.cursor then
                Draw(frame.hover, frame.cursor, settings)
                if frame.showSelection then Draw(frame.selectionRings, frame.cursor, settings) end
            end
            if frame.buildPosition then
                local style = frame.buildStyle
                UI_DrawCircle(frame.buildPosition, frame.buildRadius, style.color, style.thickness)
            end
        end
        -- FAF's WorldView owns the registered shape in its trash bag.
        function shape:Destroy()
            self.OnRender = false
            self.Render = nil
        end
        self.views[view] = { state = state, original = originalCursor, cursor = onCursor, shape = shape }
        view.OnUpdateCursor = onCursor
        view:AddShape(shape, shapeId)
    end

    function owner:Detach(view, destroying)
        local entry = self.views[view]
        if not entry then return end
        self.views[view] = nil
        if self.active == view then self.active = nil end
        if not destroying and not IsDestroyed(view) then
            if view.OnUpdateCursor == entry.cursor then view.OnUpdateCursor = entry.original end
            view:RemoveShape(shapeId)
            entry.shape:Destroy()
        end
    end

    session = owner
    scope:Defer(function()
        session = nil
        owner.enabled = false
        for view in pairs(owner.views) do owner:Detach(view, false) end
    end)
end

function SetVisible(self, visible)
    if not session then return end
    session.enabled = visible
    if visible then
        for _, view in pairs(import(viewModule).GetWorldViews()) do session:Attach(view) end
    else
        session.active = nil
        for _, entry in pairs(session.views) do entry.state.buildPosition = nil end
    end
end
