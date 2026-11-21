local Group = import('/lua/maui/group.lua').Group
local Text = import('/lua/maui/text.lua').Text
local Layout = import('/lua/maui/layouthelpers.lua')
local World = import('/lua/ui/game/worldview.lua')
local Native = import('/lua/ui/game/reclaim.lua')
local Theme = import('/mods/ClaretCore/modules/Theme.lua')
local Feed = import('/mods/ClaretUI/modules/ReclaimFeed.lua')
local Index = import('/mods/ClaretUI/modules/ReclaimIndex.lua')

local LABEL_LIMIT = 128
local PROJECTION_BUDGET = 32
local CREATION_BUDGET = 8
local SEARCH_BUDGET = 256
local CHANGE_BUDGET = 128
local SAMPLE_INTERVAL = 0.10
local floor = math.floor
local session

local function Read(value, low, high, default)
    if type(value) == 'number' and value >= low and value <= high then return value end
    return default
end

local function Excluded(owner, entry)
    if not entry or entry.mass < owner.minimum then return 'mass' end
    local x, z = entry.position[1], entry.position[3]
    if x < 0 or x >= owner.width or z < 0 or z >= owner.height then return 'map' end
    local area = owner.feed.area
    if area and (x <= area[1] or x >= area[3] or z <= area[2] or z >= area[4]) then return 'area' end
end

local function Inside(bounds, x, z)
    return x >= bounds.left and x <= bounds.right and z >= bounds.top and z <= bounds.bottom
end

local function CellCenter(owner, x, z, size)
    return 0.5 * (x + math.min(x + size, owner.width)), 0.5 * (z + math.min(z + size, owner.height))
end

local function AffectsView(owner, entry)
    if not entry then return false end
    local bounds = owner.queryBounds
    if not bounds then return true end
    local x, z = entry.position[1], entry.position[3]
    local size = owner.far and owner.farSize
    if size then
        x, z = CellCenter(owner, floor(x / size) * size, floor(z / size) * size, size)
    end
    return Inside(bounds, x, z)
end

local function UpdateIndex(owner, id, entry, exclusions)
    local reason = Excluded(owner, entry)
    if reason then
        if exclusions then exclusions[reason] = exclusions[reason] + 1 end
        entry = nil
    end
    local before = owner.index.entries[id]
    if Index.Update(owner.index, id, entry) and (AffectsView(owner, before) or AffectsView(owner, entry)) then
        owner.queryDirty = true
    end
end

local function Queue(owner, id)
    if not owner.enabled or owner.queued[id] then return end
    if owner.tail == 0 then owner.driver:SetNeedsFrameUpdate(true) end
    owner.tail = owner.tail + 1
    owner.queue[owner.tail], owner.queued[id] = id, true
end

local function ApplyChanges(owner)
    local stop = math.min(owner.tail, owner.head + CHANGE_BUDGET - 1)
    for i = owner.head, stop do
        local id = owner.queue[i]
        owner.queue[i], owner.queued[id] = nil, nil
        UpdateIndex(owner, id, Feed.Get(id))
    end
    if stop == owner.tail then
        owner.head, owner.tail = 1, 0
    else
        owner.head = stop + 1
    end

    local cursor = owner.buildCursor
    if not cursor then return end
    local count = owner.feed.count
    stop = math.min(count, cursor + CHANGE_BUDGET - 1)
    for i = cursor, stop do
        local entry = owner.feed.records[i]
        UpdateIndex(owner, entry.id, entry, owner.exclusions)
    end
    -- The feed queues records moved by swap-removal, even if the cursor passed their new slot.
    owner.buildCursor = stop < count and stop + 1 or nil
    if not owner.buildCursor then
        local excluded, area = owner.exclusions, owner.feed.area
        local areaText = area and string.format('%s,%s,%s,%s',
            tostring(area[1]), tostring(area[2]), tostring(area[3]), tostring(area[4])) or 'none'
        owner.queryDirty = true
        LOG(string.format('[ClaretUI][reclaim] index complete: feed=%d indexed=%d minimum=%s map=%sx%s area=%s rejected mass=%d map=%d area=%d',
            count, owner.index.root.count, tostring(owner.minimum), tostring(owner.width), tostring(owner.height),
            areaText, excluded.mass, excluded.map, excluded.area))
    end
end

local function Release(owner, marker)
    if marker.generation == owner.generation then owner.accepted = owner.accepted - 1 end
    local shown, slot = owner.shown, marker.slot
    local count = table.getn(shown)
    local last = shown[count]
    shown[slot], last.slot = last, slot
    shown[count], owner.byTarget[marker.key] = nil, nil
    marker.control:Hide()
    table.insert(owner.free, marker)
end

local function ClearSearch(owner)
    owner.search, owner.deferred, owner.queryDirty = nil, nil, true
    owner.queryBounds = nil
end

local function ClearShown(owner)
    for i = table.getn(owner.shown), 1, -1 do Release(owner, owner.shown[i]) end
    ClearSearch(owner)
end

local function ClearView(owner)
    if owner.layer and not IsDestroyed(owner.layer) then owner.layer:Destroy() end
    owner.view, owner.layer, owner.camera, owner.measure = nil, nil, nil, nil
    owner.bounds, owner.farSize, owner.sampleIn, owner.pixel = nil, nil, 0, nil
    owner.pose = {}
    owner.shown, owner.byTarget, owner.free = {}, {}, {}
    owner.accepted = 0
    ClearSearch(owner)
end

local function Rebuild(owner)
    owner.index = Index.Create(owner.width, owner.height)
    owner.buildCursor = 1
    owner.exclusions = { mass = 0, map = 0, area = 0 }
    owner.loggedSettledSearch = false
    owner.queue, owner.queued, owner.head, owner.tail = {}, {}, 1, 0
    ClearShown(owner)
    owner.driver:SetNeedsFrameUpdate(true)
end

local function Attach(owner, view)
    owner.view, owner.camera = view, GetCamera('WorldCamera')
    owner.layer = Group(view)
    Layout.FillParent(owner.layer, view)
    owner.layer:DisableHitTest()
    owner.layer.Depth:Set(function() return view.Depth() + 2 end)
    owner.measure = Text(owner.layer)
    Layout.AtLeftTopIn(owner.measure, owner.layer)
    owner.measure:DisableHitTest()
    owner.measure:Hide()
    owner.created = owner.created + 2
end

local function SetFont(owner, control)
    control:SetFont(Theme.Fonts.body, Theme.Metrics.caption * owner.scale)
end

local function Box(owner, mass, far, marker)
    local rounded = floor(mass + 0.5)
    if marker and marker.rounded == rounded and marker.far == far and marker.font == owner.font then
        return marker.text, marker.halfWidth, marker.halfHeight, rounded
    end
    local text = (far and 'Σ ' or '') .. tostring(rounded)
    return text, 0.5 * owner.measure:GetStringAdvance(text) + 2 * owner.pixel,
        0.5 * owner.measure.Height() + owner.pixel, rounded
end

local function Paint(owner, marker, x, y, text, halfWidth, halfHeight, rounded)
    local control = marker.control
    if marker.font ~= owner.font then
        SetFont(owner, control)
        marker.font = owner.font
    end
    if marker.text ~= text then control:SetText(text) end
    marker.x, marker.y, marker.text, marker.rounded = x, y, text, rounded
    marker.halfWidth, marker.halfHeight, marker.far = halfWidth, halfHeight, owner.far
    local left = floor(x - halfWidth + 2 * owner.pixel + 0.5)
    local top = floor(y - halfHeight + owner.pixel + 0.5)
    if marker.left ~= left then control.Left:SetValue(left) end
    if marker.top ~= top then control.Top:SetValue(top) end
    marker.left, marker.top = left, top
end

local function Position(owner, target)
    if not owner.far then return target.position end
    if not target.position then
        local x, z = CellCenter(owner, target.x, target.z, target.size)
        -- The UI receives prop elevations through Sync. Keep the cell anchor stable after creation.
        target.position = Vector(x, target.best.position[2], z)
    end
    return target.position
end

local function Project(owner, position)
    local point = owner.view:Project(position)
    if not point then return end
    local x, y = point.x, point.y
    local view = owner.viewport
    if x >= view.left and x < view.right and y >= view.top and y < view.bottom then return x, y end
end

local function TrackShown(owner)
    for i = table.getn(owner.shown), 1, -1 do
        local marker = owner.shown[i]
        local target = owner.far and marker.key or Feed.Get(marker.key)
        local valid = owner.far and target.count > 0 or not owner.far and not Excluded(owner, target)
        local position = valid and Position(owner, target)
        local x, y = marker.x, marker.y
        local moved = owner.reproject or marker.position ~= position
        if not valid then
            x = nil
        elseif moved then
            x, y = Project(owner, position)
        end
        if x then
            if moved or marker.rounded ~= floor(target.mass + 0.5) or marker.font ~= owner.font then
                Paint(owner, marker, x, y, Box(owner, target.mass, owner.far, marker))
            end
            marker.position = position
        else
            Release(owner, marker)
            owner.queryDirty = true
        end
    end
end

local function Overlap(marker, x, y, halfWidth, halfHeight)
    return math.abs(marker.x - x) < marker.halfWidth + halfWidth
        and math.abs(marker.y - y) < marker.halfHeight + halfHeight
end

local function Acquire(owner, key)
    local marker = table.remove(owner.free)
    if not marker then
        local control = Text(owner.layer)
        control.Left:Set(0)
        control.Top:Set(0)
        control:SetDropShadow(true)
        control:SetColor(Theme.Colors.hudMass)
        control:DisableHitTest()
        marker = { control = control }
        owner.created = owner.created + 1
    end
    marker.key, marker.slot, marker.generation = key, table.getn(owner.shown) + 1, nil
    owner.shown[marker.slot], owner.byTarget[key] = marker, marker
    return marker
end

local function Place(owner, target, marker, x, y)
    local text, halfWidth, halfHeight, rounded = Box(owner, target.mass, owner.far, marker)
    local shown, generation = owner.shown, owner.generation
    local replace
    for i = 1, table.getn(shown) do
        local other = shown[i]
        if other ~= marker then
            local overlap = not owner.far and Overlap(other, x, y, halfWidth, halfHeight)
            if other.generation == generation then
                if overlap then return end
            elseif not replace or overlap then
                replace = other
            end
        end
    end

    if not marker and table.getn(shown) >= LABEL_LIMIT and replace then Release(owner, replace) end
    -- Free overlapping slots from the previous selection while publishing this one.
    if not owner.far then
        for i = table.getn(shown), 1, -1 do
            local other = shown[i]
            if other ~= marker and other.generation ~= generation and Overlap(other, x, y, halfWidth, halfHeight) then
                Release(owner, other)
            end
        end
    end
    if not marker then
        if table.getn(owner.free) == 0 and owner.created >= CREATION_BUDGET then return false end
        marker = Acquire(owner, owner.far and target or target.id)
        marker.position = Position(owner, target)
        Paint(owner, marker, x, y, text, halfWidth, halfHeight, rounded)
        marker.control:Show()
    end
    marker.generation = generation
    owner.accepted = owner.accepted + 1
end

local function EndSearch(owner)
    for i = table.getn(owner.shown), 1, -1 do
        local marker = owner.shown[i]
        if marker.generation ~= owner.generation then Release(owner, marker) end
    end
    owner.search, owner.deferred = nil, nil
    local hasLabels = owner.accepted > 0
    local settled = not owner.buildCursor
    if not owner.loggedSearch or settled and not owner.loggedSettledSearch or hasLabels and not owner.loggedLabels then
        LOG(string.format('[ClaretUI][reclaim] feed=%d indexed=%d shown=%d projected=%d inView=%d far=%s indexing=%s',
            owner.feed.count, owner.index.root.count, owner.accepted, owner.searchProjections, owner.searchHits,
            tostring(owner.far), tostring(not settled)))
        owner.loggedSearch = true
        if settled then owner.loggedSettledSearch = true end
        if hasLabels then owner.loggedLabels = true end
    end
end

local function FindLabels(owner)
    local projections = 0
    for _ = 1, SEARCH_BUDGET do
        if owner.accepted >= LABEL_LIMIT then EndSearch(owner); return end
        local target, finished = owner.deferred, false
        if not target then target, finished = Index.Step(owner.search) end
        owner.deferred = nil
        if finished then EndSearch(owner); return end
        if target and (owner.far and target.count > 0 or not owner.far and Feed.Get(target.id) == target) then
            local marker = owner.byTarget[owner.far and target or target.id]
            if not marker or marker.generation ~= owner.generation then
                local x, y
                if marker then
                    x, y = marker.x, marker.y
                else
                    local wx, wz
                    if owner.far then
                        wx, wz = CellCenter(owner, target.x, target.z, target.size)
                    else
                        wx, wz = target.position[1], target.position[3]
                    end
                    if Inside(owner.search.bounds, wx, wz) then
                        x, y = Project(owner, Position(owner, target))
                        projections = projections + 1
                        owner.searchProjections = owner.searchProjections + 1
                        if x then owner.searchHits = owner.searchHits + 1 end
                    end
                end
                if x and Place(owner, target, marker, x, y) == false then
                    owner.deferred = target
                    return
                end
                if projections >= PROJECTION_BUDGET then return end
            end
        end
    end
end

local function Sample(owner)
    local view, v = owner.view, owner.viewport
    local a = UnProject(view, Vector2(v.left, v.top))
    local b = UnProject(view, Vector2(v.right, v.top))
    local c = UnProject(view, Vector2(v.right, v.bottom))
    local d = UnProject(view, Vector2(v.left, v.bottom))
    if not (a and b and c and d) then
        return { left = 0, top = 0, right = owner.width, bottom = owner.height }
    end
    local left, right = math.min(a[1], b[1], c[1], d[1]), math.max(a[1], b[1], c[1], d[1])
    local top, bottom = math.min(a[3], b[3], c[3], d[3]), math.max(a[3], b[3], c[3], d[3])
    return { left = left, top = top, right = right, bottom = bottom }
end

local function Offset(a, b)
    return math.max(math.abs(a.left - b.left), math.abs(a.right - b.right),
        math.abs(a.top - b.top), math.abs(a.bottom - b.bottom))
end

local function SampleView(owner, delta)
    local view = owner.view
    local left, top, right, bottom = view.Left(), view.Top(), view.Right(), view.Bottom()
    local v = owner.viewport
    owner.reproject = false
    if v.left ~= left or v.top ~= top or v.right ~= right or v.bottom ~= bottom then
        v.left, v.top, v.right, v.bottom = left, top, right, bottom
        owner.sampleIn = 0
        owner.reproject = true
        ClearSearch(owner)
    end
    if right <= left or bottom <= top then return false end

    local pixel = Layout.GetPixelScaleFactor()
    if owner.pixel ~= pixel then
        owner.pixel = pixel
        owner.font = owner.font + 1
        SetFont(owner, owner.measure)
        ClearSearch(owner)
    end
    local camera = owner.camera
    local zoom, focus, settings = camera:GetZoom(), camera:GetFocusPosition(), camera:SaveSettings()
    local pose = owner.pose
    if zoom ~= pose.zoom or focus[1] ~= pose.x or focus[2] ~= pose.y or focus[3] ~= pose.z
        or settings.Pitch ~= pose.pitch or settings.Heading ~= pose.heading or settings.Roll ~= pose.roll then
        pose.zoom, pose.x, pose.y, pose.z = zoom, focus[1], focus[2], focus[3]
        pose.pitch, pose.heading, pose.roll = settings.Pitch, settings.Heading, settings.Roll
        owner.reproject = true
    end
    local far = zoom >= 150 or owner.far and zoom >= 140
    if far ~= owner.far then
        owner.far, owner.sampleIn = far, 0
        ClearShown(owner)
    end
    owner.sampleIn = owner.sampleIn - delta
    if owner.sampleIn > 0 then return true end
    owner.sampleIn = SAMPLE_INTERVAL

    local bounds = Sample(owner)
    local width, height = bounds.right - bounds.left, bounds.bottom - bounds.top
    if not owner.bounds or Offset(owner.bounds, bounds) > 0.01 then
        owner.bounds = bounds
        owner.queryDirty = true
        owner.reproject = true
    end
    if owner.search and owner.queryOrigin and Offset(owner.queryOrigin, bounds) > math.min(width, height) * 0.2 then
        ClearSearch(owner)
    end
    if far then
        local desired = 96 * pixel * math.max(width / (right - left), height / (bottom - top))
        local size = Index.CellSize(owner.index, desired, owner.farSize)
        if size ~= owner.farSize then
            owner.farSize = size
            ClearShown(owner)
        end
    end
    return true
end

local function BeginSearch(owner)
    local bounds = owner.bounds
    local xPad = math.max(16, (bounds.right - bounds.left) * 0.12)
    local zPad = math.max(16, (bounds.bottom - bounds.top) * 0.12)
    local queryBounds = {
        left = bounds.left - xPad, right = bounds.right + xPad,
        top = bounds.top - zPad, bottom = bounds.bottom + zPad,
    }
    owner.search = Index.Search(owner.index, queryBounds, owner.far and owner.farSize or nil)
    owner.queryBounds = queryBounds
    owner.queryOrigin, owner.queryDirty = bounds, false
    owner.generation, owner.accepted = owner.generation + 1, 0
    owner.searchProjections, owner.searchHits = 0, 0
end

local function Frame(owner, delta)
    ApplyChanges(owner)
    local showing = owner.pinned or owner.feed.graph and IsKeyDown('Control')
    if not showing then
        if owner.layer and not owner.layer:IsHidden() then
            ClearShown(owner)
            owner.layer:Hide()
            owner.sampleIn = 0
        end
        if not owner.feed.graph and not owner.buildCursor and owner.tail == 0 then
            owner.driver:SetNeedsFrameUpdate(false)
        end
        return
    end
    local view = World.viewLeft
    if owner.view and owner.view ~= view then ClearView(owner) end
    if not view or IsDestroyed(view) or view:IsHidden() then return end
    owner.created = 0
    if not owner.layer then Attach(owner, view) end
    if not owner.camera or IsDestroyed(owner.camera) then owner.camera = GetCamera('WorldCamera') end
    if not owner.camera or not SampleView(owner, delta) then return end
    if owner.layer:IsHidden() then owner.layer:Show() end
    TrackShown(owner)
    if owner.queryDirty and not owner.search then BeginSearch(owner) end
    if owner.search then FindLabels(owner) end
end

local function SetEnabled(owner, enabled, restore)
    if owner.enabled == enabled then return end
    local view = World.viewLeft
    owner.enabled = enabled
    if enabled then
        owner.pinned = view and view.ShowingReclaim == true and not owner.feed.graph
        if view and not IsDestroyed(view) then Native.ClaretReleaseNativeReclaim() end
        Rebuild(owner)
        LOG(string.format('[ClaretUI][reclaim] enabled; buffered=%d', owner.feed.count))
    else
        local pinned = owner.pinned
        owner.pinned = false
        owner.index, owner.buildCursor = nil, nil
        owner.queue, owner.queued, owner.head, owner.tail = {}, {}, 1, 0
        ClearView(owner)
        owner.driver:SetNeedsFrameUpdate(false)
        if restore and view and not IsDestroyed(view) then Native.ClaretRestoreNativeReclaim(pinned) end
    end
end

function Start(self, scope, isReplay, options)
    if Feed.Conflicts() then return end
    local root = GetFrame(0)
    if not root then return end
    local driver = scope:Own(Group(root))
    Layout.FillParent(driver, root)
    driver:DisableHitTest()
    local size = SessionGetScenarioInfo().size
    local minimum, scale = options.reclaimMinimumMass, options.reclaimLabelScale
    local owner = {
        driver = driver, feed = Feed.State(), width = size[1], height = size[2],
        enabled = false, pinned = false, far = false, sampleIn = 0,
        minimum = Read(minimum:Get(), 10, 500, 10), scale = Read(scale:Get(), 50, 200, 100) * 0.01,
        viewport = {}, pose = {}, shown = {}, free = {}, byTarget = {}, generation = 0, accepted = 0, font = 0,
    }
    driver.OnFrame = function(_, delta) Frame(owner, delta) end
    Feed.Listen({
        update = function(id, moved)
            Queue(owner, id)
            if moved and moved ~= id and owner.buildCursor then Queue(owner, moved) end
        end,
        area = function()
            if owner.enabled then Rebuild(owner) end
        end,
        toggle = function()
            if not owner.enabled then return false end
            owner.pinned = not owner.pinned
            owner.driver:SetNeedsFrameUpdate(true)
            return true
        end,
        graph = function()
            if not owner.enabled then return false end
            owner.driver:SetNeedsFrameUpdate(true)
            return true
        end,
    })
    scope:Bind(minimum.OnChanged, function(_, value)
        owner.minimum = Read(value, 10, 500, 10)
        if owner.enabled then Rebuild(owner) end
    end)
    scope:Bind(scale.OnChanged, function(_, value)
        owner.scale = Read(value, 50, 200, 100) * 0.01
        owner.pixel = nil
    end)
    scope:Defer(function()
        Feed.Listen(nil)
        SetEnabled(owner, false, true)
        session = nil
    end)
    session = owner
end

function SetVisible(self, visible)
    if session then SetEnabled(session, visible, true) end
end
