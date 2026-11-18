-- Bindable strategic range rings. The implementation is owned by Claret Core;
-- the public entry points are called by Claret Hotbuild actions.
local RangeOverlayParams = import('/lua/ui/game/rangeoverlayparams.lua').RangeOverlayParams
local WorldView = import('/lua/ui/game/worldview.lua')

local function Axis(position, index, name)
    return position and (position[index] or position[name])
end

local function IsPosition(position)
    return Axis(position, 1, 'x') ~= nil and Axis(position, 3, 'z') ~= nil
end

local function IsStructure(blueprint)
    return blueprint and blueprint.BlueprintId
        and EntityCategoryContains(categories.STRUCTURE, blueprint.BlueprintId)
end

local function IsRangedWeapon(weapon)
    return weapon and weapon.MaxRadius and weapon.MaxRadius > 0 and weapon.MaxRadius <= 4000
        and weapon.Label ~= 'DeathWeapon' and weapon.WeaponCategory ~= 'Death'
        and weapon.DamageType ~= 'DeathExplosion'
end

local function IsDeathWeapon(weapon)
    return weapon and (weapon.Label == 'DeathWeapon' or weapon.WeaponCategory == 'Death'
        or weapon.DamageType == 'DeathExplosion')
end

local weaponRangeTypes = {
    UWRC_DirectFire = 'AllMilitary', UWRC_IndirectFire = 'IndirectFire',
    UWRC_AntiAir = 'AntiAir', UWRC_Countermeasure = 'Defense', UWRC_AntiNavy = 'AntiNavy',
}
local shieldCenterOffsets = {
    uab4202 = -1.625, uab4301 = -3, ueb4202 = -1.75, ueb4301 = -4.75,
    urb4202 = -0.5, urb4204 = -0.5, urb4205 = -1.5, urb4206 = -2.5,
    urb4207 = -3.5, xsb4202 = -1.5, xsb4301 = -4.75,
}

local function RangeColor(rangeType)
    local params = RangeOverlayParams[rangeType] or RangeOverlayParams.AllMilitary
    if not params then return 'fff2f029', 0.04 end
    local color = params.RolloverColor or params.SelectColor or params.NormalColor or 'fff2f029'
    return 'ff' .. string.sub(color, 3), params.Outer[1] / params.Type
end

local function MakeGroupId(blueprintId, position)
    return string.lower(blueprintId) .. ':' .. tostring(math.floor(Axis(position, 1, 'x') * 10 + 0.5))
        .. ':' .. tostring(math.floor(Axis(position, 3, 'z') * 10 + 0.5))
end

local FULL_CIRCLE = math.pi * 2

local function Angle(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 then return math.atan(y / x) - math.pi end
    if y > 0 then return math.pi * 0.5 end
    if y < 0 then return -math.pi * 0.5 end
    return 0
end

local function NormalizeAngle(value)
    value = math.mod(value, FULL_CIRCLE)
    if value < 0 then value = value + FULL_CIRCLE end
    return value
end

local function AddCoveredArc(intervals, startAngle, endAngle)
    startAngle = NormalizeAngle(startAngle)
    endAngle = NormalizeAngle(endAngle)
    if startAngle <= endAngle then table.insert(intervals, {startAngle, endAngle})
    else
        table.insert(intervals, {0, endAngle})
        table.insert(intervals, {startAngle, FULL_CIRCLE})
    end
end

local function VisibleArcs(ring, index, rings)
    if not ring.merge then return {{0, FULL_CIRCLE}} end
    local covered, centerX, centerZ = {}, Axis(ring.position, 1, 'x'), Axis(ring.position, 3, 'z')
    for otherIndex, other in ipairs(rings) do
        if otherIndex ~= index and other.merge and other.shape == 'Circle'
            and other.mergeKey == ring.mergeKey and other.minimum == ring.minimum
            and other.colorKey == ring.colorKey then
            local dx = Axis(other.position, 1, 'x') - centerX
            local dz = Axis(other.position, 3, 'z') - centerZ
            local distance = math.sqrt(dx * dx + dz * dz)
            if distance < 0.0001 then
                if other.radius > ring.radius or (other.radius == ring.radius and otherIndex < index) then
                    return {}
                end
            elseif distance + ring.radius <= other.radius then
                return {}
            elseif distance < ring.radius + other.radius and distance + other.radius > ring.radius then
                local cosine = (ring.radius * ring.radius + distance * distance - other.radius * other.radius)
                    / (2 * ring.radius * distance)
                cosine = math.max(-1, math.min(1, cosine))
                local half = math.acos(cosine)
                local direction = Angle(dz, dx)
                AddCoveredArc(covered, direction - half, direction + half)
            end
        end
    end
    if table.getn(covered) == 0 then return {{0, FULL_CIRCLE}} end
    table.sort(covered, function(a, b) return a[1] < b[1] end)
    local merged = {}
    for _, interval in ipairs(covered) do
        local last = merged[table.getn(merged)]
        if last and interval[1] <= last[2] then last[2] = math.max(last[2], interval[2])
        else table.insert(merged, {interval[1], interval[2]}) end
    end
    local visible, cursor = {}, 0
    for _, interval in ipairs(merged) do
        if interval[1] > cursor then table.insert(visible, {cursor, interval[1]}) end
        cursor = math.max(cursor, interval[2])
    end
    if cursor < FULL_CIRCLE then table.insert(visible, {cursor, FULL_CIRCLE}) end
    return visible
end

local function DistanceToSegment(x, z, first, second)
    local ax, az = Axis(first, 1, 'x'), Axis(first, 3, 'z')
    local bx, bz = Axis(second, 1, 'x'), Axis(second, 3, 'z')
    local dx, dz = bx - ax, bz - az
    local length = dx * dx + dz * dz
    if length <= 0 then
        dx, dz = x - ax, z - az
        return math.sqrt(dx * dx + dz * dz)
    end
    local t = math.max(0, math.min(1, ((x - ax) * dx + (z - az) * dz) / length))
    dx, dz = x - (ax + t * dx), z - (az + t * dz)
    return math.sqrt(dx * dx + dz * dz)
end

local function RolloverPosition(info, blueprint)
    local unit = info.userUnit
    if not unit and info.entityId and GetUnitById then
        local ok, result = pcall(GetUnitById, info.entityId)
        if ok then unit = result end
    end
    if unit then
        local ok, position = pcall(function() return unit:GetPosition() end)
        if ok and IsPosition(position) then return position end
        ok, position = pcall(function() return unit:GetInterpolatedPosition() end)
        if ok and IsPosition(position) then return position end
    end
    for _, field in ipairs({'position', 'Position', 'pos', 'Pos', 'location', 'Location'}) do
        if IsPosition(info[field]) then return info[field] end
    end
    local mouse = GetMouseWorldPos()
    if IsPosition(mouse) then
        local sizeX = blueprint.Footprint and blueprint.Footprint.SizeX or 1
        local sizeZ = blueprint.Footprint and blueprint.Footprint.SizeZ or 1
        local x, z = Axis(mouse, 1, 'x'), Axis(mouse, 3, 'z')
        local function snap(value, size)
            if math.mod(math.floor(size + 0.5), 2) == 0 then return math.floor(value + 0.5) end
            return math.floor(value) + 0.5
        end
        return Vector(snap(x, sizeX), Axis(mouse, 2, 'y') or GetTerrainHeight(x, z), snap(z, sizeZ))
    end
end

function Create()
    local rings = {}
    local renderer
    local disposed = false
    local geometryDirty = true
    local service = {}

    local function EnsureGeometry()
        if not geometryDirty then return end
        geometryDirty = false
        for index, ring in ipairs(rings) do
            ring.arcs = ring.shape == 'Circle' and VisibleArcs(ring, index, rings) or {{0, FULL_CIRCLE}}
            ring.full = table.getn(ring.arcs) == 1 and ring.arcs[1][1] == 0
                and ring.arcs[1][2] == FULL_CIRCLE
            ring.segments = {}
            if not ring.full then
                for _, arc in ipairs(ring.arcs) do
                    local count = math.max(1, math.ceil((arc[2] - arc[1]) * 48 / FULL_CIRCLE))
                    local previous
                    for step = 0, count do
                        local angle = arc[1] + (arc[2] - arc[1]) * step / count
                        local current = Vector(Axis(ring.position, 1, 'x') + ring.radius * math.cos(angle),
                            Axis(ring.position, 2, 'y'), Axis(ring.position, 3, 'z') + ring.radius * math.sin(angle))
                        if previous then table.insert(ring.segments, {previous, current}) end
                        previous = current
                    end
                end
            end
        end
    end

    local function AttachRenderer()
        local view = WorldView.viewLeft
        if not view or not view.AddShape then return false end
        if renderer and renderer.worldview == view and view.Shapes and view.Shapes.ClaretStrategicRings == renderer then
            return true
        end
        if renderer and renderer.worldview and renderer.worldview.RemoveShape then
            renderer.worldview:RemoveShape('ClaretStrategicRings')
        end
        renderer = {worldview = view, OnRender = true}
        local function point(ring, vertical, azimuth)
            local horizontal = ring.radius * math.cos(vertical)
            return Vector(Axis(ring.position, 1, 'x') + math.cos(azimuth) * horizontal,
                Axis(ring.position, 2, 'y') + ring.centerOffset + math.sin(vertical) * ring.radius,
                Axis(ring.position, 3, 'z') + math.sin(azimuth) * horizontal)
        end
        local function line(a, b, ring)
            if UI_DrawLine then UI_DrawLine(a, b, ring.color, ring.thickness) end
        end
        local function drawSphere(ring, slice)
            if slice and not UI_DrawLine then
                UI_DrawCircle(ring.position, ring.radius, ring.color, ring.thickness)
                return
            end
            if not slice then
                UI_DrawCircle(Vector(Axis(ring.position, 1, 'x'), Axis(ring.position, 2, 'y') + ring.centerOffset,
                    Axis(ring.position, 3, 'z')), ring.radius, ring.color, ring.thickness)
                for band = 1, 3 do
                    local vertical = math.pi * 0.5 * band / 4
                    local radius = ring.radius * math.cos(vertical)
                    local y = Axis(ring.position, 2, 'y') + ring.centerOffset + ring.radius * math.sin(vertical)
                    UI_DrawCircle(Vector(Axis(ring.position, 1, 'x'), y, Axis(ring.position, 3, 'z')),
                        radius, ring.color, ring.thickness)
                    y = Axis(ring.position, 2, 'y') + ring.centerOffset - ring.radius * math.sin(vertical)
                    UI_DrawCircle(Vector(Axis(ring.position, 1, 'x'), y, Axis(ring.position, 3, 'z')),
                        radius, ring.color, ring.thickness)
                end
            end
            local startAngle = slice and ring.angle - math.pi / 8 or 0
            local endAngle = slice and ring.angle + math.pi / 8 or math.pi * 2
            local meridians = slice and 5 or 6
            for meridian = 0, meridians - 1 do
                local azimuth = startAngle + (endAngle - startAngle) * meridian / meridians
                local previous
                for step = 0, 20 do
                    local current = point(ring, -math.pi / 2 + math.pi * step / 20, azimuth)
                    if previous then line(previous, current, ring) end
                    previous = current
                end
            end
            if slice then
                for band = 0, 6 do
                    local vertical = -math.pi / 2 + math.pi * band / 6
                    local previous
                    for step = 0, 10 do
                        local current = point(ring, vertical, startAngle + (endAngle - startAngle) * step / 10)
                        if previous then line(previous, current, ring) end
                        previous = current
                    end
                end
            end
        end
        function renderer:Render()
            EnsureGeometry()
            for _, ring in ipairs(rings) do
                if not ring.destroyed then
                    if ring.shape == 'Sphere' then drawSphere(ring, false)
                    elseif ring.shape == 'SphereSlice' then drawSphere(ring, true)
                    elseif ring.full then UI_DrawCircle(ring.position, ring.radius, ring.color, ring.thickness)
                    elseif UI_DrawLine then
                        for _, segment in ipairs(ring.segments) do
                            UI_DrawLine(segment[1], segment[2], ring.color, ring.thickness * 2)
                        end
                    end
                end
            end
        end
        function renderer:Destroy()
            renderer = nil
        end
        view:AddShape(renderer, 'ClaretStrategicRings')
        return true
    end

    local function Add(groupId, position, radius, rangeType, minimum, twoStage, colorOverride,
        centerOffset, mergeKey, merge)
        if not radius or radius <= 0 then return false end
        for _, existing in ipairs(rings) do
            if existing.group == groupId and existing.radius == radius and existing.rangeType == rangeType
                and existing.minimum == (minimum == true) and existing.twoStage == (twoStage == true)
                and existing.colorKey == (colorOverride or rangeType)
                and existing.mergeKey == (mergeKey or rangeType) and existing.merge == (merge ~= false) then
                if twoStage then
                    if existing.shape == 'Circle' then existing.shape = 'Sphere'
                    elseif existing.shape == 'Sphere' then existing.shape = 'SphereSlice'
                    else
                        local mouse = GetMouseWorldPos()
                        if IsPosition(mouse) then
                            local dx = Axis(mouse, 1, 'x') - Axis(existing.position, 1, 'x')
                            local dz = Axis(mouse, 3, 'z') - Axis(existing.position, 3, 'z')
                            if math.atan2 then existing.angle = math.atan2(dz, dx)
                            elseif dx ~= 0 then existing.angle = math.atan(dz / dx)
                            else existing.angle = dz >= 0 and math.pi / 2 or -math.pi / 2 end
                        end
                    end
                    geometryDirty = true
                    return true
                end
                return true
            end
        end
        local color, thickness = RangeColor(rangeType)
        if colorOverride then color = 'ff' .. colorOverride end
        local p = Vector(Axis(position, 1, 'x'), Axis(position, 2, 'y') or 0, Axis(position, 3, 'z'))
        table.insert(rings, {group = groupId, position = p, radius = radius,
            color = color, thickness = thickness, rangeType = rangeType, minimum = minimum == true,
            colorKey = colorOverride or rangeType, twoStage = twoStage == true,
            shape = 'Circle', angle = 0, centerOffset = centerOffset or 0, mergeKey = mergeKey or rangeType,
            merge = merge ~= false})
        geometryDirty = true
        return true
    end

    local function AddWeaponRanges(blueprint, groupId, position)
        local weapons = blueprint.Weapon or {}
        local longest, longestType, longestMin = 0, 'AllMilitary', nil
        local shortest, shortestMin = 0, nil
        local deathRadius = 0
        for _, weapon in ipairs(weapons) do
            if IsRangedWeapon(weapon) then
                local rangeType = weaponRangeTypes[weapon.RangeCategory] or 'AllMilitary'
                if weapon.MaxRadius > longest then
                    longest, longestType = weapon.MaxRadius, rangeType
                    longestMin = weapon.MinRadius
                end
                if shortest == 0 or weapon.MaxRadius < shortest then
                    shortest, shortestMin = weapon.MaxRadius, weapon.MinRadius
                end
            elseif IsDeathWeapon(weapon) then
                deathRadius = math.max(deathRadius, weapon.DamageRadius or 0,
                    weapon.NukeInnerRingRadius or 0, weapon.NukeOuterRingRadius or 0)
            end
        end
        local created = false
        local id = string.lower(blueprint.BlueprintId)
        if IsStructure(blueprint) and EntityCategoryContains(categories.SILO * categories.ANTIMISSILE, id) then
            created = Add(groupId, position, longest, 'Defense', false, false, nil, nil, 'SMD') or created
            if longestMin and longestMin > 0 and longestMin < longest then
                created = Add(groupId, position, longestMin, 'Defense', true, false, nil, nil, 'SMD') or created
            end
        end
        if IsStructure(blueprint) and EntityCategoryContains(categories.ANTIMISSILE, id) then
            created = Add(groupId, position, shortest, 'Defense', false, false, nil, nil, 'TMD') or created
            if shortestMin and shortestMin > 0 and shortestMin < shortest then
                created = Add(groupId, position, shortestMin, 'Defense', true, false, nil, nil, 'TMD') or created
            end
        end
        if IsStructure(blueprint) and EntityCategoryContains(categories.SILO * categories.TACTICALMISSILEPLATFORM, id) then
            created = Add(groupId, position, longest, 'IndirectFire') or created
            if longestMin and longestMin > 0 and longestMin < longest then
                created = Add(groupId, position, longestMin, 'IndirectFire', true) or created
            end
        end
        if (IsStructure(blueprint) and EntityCategoryContains(categories.ANTIAIR + categories.ANTINAVY
            + categories.DIRECTFIRE + categories.INDIRECTFIRE, id)) or id == 'url0401' then
            created = Add(groupId, position, longest, longestType) or created
            if longestMin and longestMin > 0 and longestMin < longest then
                created = Add(groupId, position, longestMin, longestType, true) or created
            end
        end
        if IsStructure(blueprint) and deathRadius > 0 then
            created = Add(groupId, position, deathRadius, 'AllMilitary', false, true, 'FF6363', nil, 'DeathSplash') or created
        end
        return created
    end

    function service:CreateHover(includeVision)
        if disposed then return false, 'Strategic rings are unavailable' end
        local info = GetRolloverInfo()
        if not info or not info.blueprintId or info.blueprintId == 'unknown' then
            return false, 'No unit under cursor'
        end
        local blueprint = __blueprints[info.blueprintId]
        if not blueprint then return false, 'Hovered unit blueprint is unavailable' end
        local position = RolloverPosition(info, blueprint)
        if not position then return false, 'Hovered unit position is unavailable' end
        if not AttachRenderer() then return false, 'World view renderer is unavailable' end
        local groupId = MakeGroupId(info.blueprintId, position)
        local intel = blueprint.Intel or {}
        local created = false
        local structure = IsStructure(blueprint)
        if includeVision then
            if structure then
                local vision = math.max(intel.VisionRadius or 0, intel.MaxVisionRadius or 0)
                created = Add(groupId, position, vision, 'Miscellaneous', false, false, 'C9A700', nil, 'Vision') or created
            end
        else
            if structure then
                if EntityCategoryContains(categories.INTELLIGENCE, info.blueprintId) then
                    created = Add(groupId, position, intel.OmniRadius, 'Omni') or created
                    created = Add(groupId, position, intel.RadarRadius, 'Radar') or created
                end
                created = Add(groupId, position, intel.SonarRadius, 'Sonar') or created
                local stealth = intel.RadarStealthFieldRadius or 0
                stealth = math.max(stealth, intel.SonarStealthFieldRadius or 0)
                created = Add(groupId, position, stealth, 'Miscellaneous', false, false, '9D4EDD', nil, 'StealthField') or created
                created = Add(groupId, position, intel.CloakFieldRadius, 'Miscellaneous', false, false, 'C77DFF', nil, 'CloakField') or created
            end
            local shield = structure and blueprint.Defense and blueprint.Defense.Shield
            if shield and shield.ShieldSize and shield.ShieldSize > 0 then
                local blueprintId = string.lower(blueprint.BlueprintId)
                local offset = shieldCenterOffsets[blueprintId]
                if offset == nil then offset = (shield.ShieldVerticalOffset or -1) + 2 end
                created = Add(groupId, position, shield.ShieldSize / 2, 'Defense', false, true,
                    'FFA963', offset, 'Shield', false) or created
            end
            created = AddWeaponRanges(blueprint, groupId, position) or created
        end
        if not created then return false, 'Hovered unit has no matching ranges' end
        return true
    end

    function service:DeleteAtBrush(position, brushRadius)
        if disposed or not IsPosition(position) or type(brushRadius) ~= 'number' or brushRadius <= 0 then return 0 end
        EnsureGeometry()
        local groups = {}
        for _, ring in ipairs(rings) do
            local x, z = Axis(position, 1, 'x'), Axis(position, 3, 'z')
            local dx = x - Axis(ring.position, 1, 'x')
            local dz = z - Axis(ring.position, 3, 'z')
            local hit = ring.full and math.abs(math.sqrt(dx * dx + dz * dz) - ring.radius) < brushRadius
            if not hit then
                for _, segment in ipairs(ring.segments or {}) do
                    if DistanceToSegment(x, z, segment[1], segment[2]) < brushRadius then hit = true; break end
                end
            end
            if hit then
                groups[ring.group] = true
            end
        end
        local kept, deleted = {}, 0
        for _, ring in ipairs(rings) do
            if groups[ring.group] then ring.destroyed = true; deleted = deleted + 1
            else table.insert(kept, ring) end
        end
        rings = kept
        geometryDirty = true
        return deleted
    end

    function service:Destroy()
        if disposed then return end
        disposed = true
        rings = {}
        if renderer and renderer.worldview and renderer.worldview.RemoveShape then
            renderer.worldview:RemoveShape('ClaretStrategicRings')
        end
        renderer = nil
    end

    return service
end

