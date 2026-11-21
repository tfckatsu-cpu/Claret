-- Loaded from the native reclaim module before UserSync caches its handlers.
local records, slots = {}, {}
local state = { records = records, count = 0, graph = false }
local receiver

function Conflicts()
    local mods = rawget(_G, '__active_mods') or {}
    for _, mod in ipairs(mods) do
        if mod.name == 'ReUI.Reclaim' then return true end
    end
    return false
end

local function Finite(value)
    -- FAF LuaPlus does not provide math.huge. A finite number minus itself is zero.
    return type(value) == 'number' and value - value == 0
end

function State()
    return state
end

function Listen(listener)
    receiver = listener
end

function Receive(points)
    for id, point in pairs(points) do
        local slot = slots[id]
        if point == false and slot then
            local last = records[state.count]
            records[slot], slots[last.id] = last, slot
            records[state.count], slots[id] = nil, nil
            state.count = state.count - 1
            if receiver then receiver.update(id, last.id) end
        elseif point and type(point) == 'table' and Finite(point.mass) and point.mass >= 10 then
            local pos = point.position
            if pos and Finite(pos[1]) and Finite(pos[2]) and Finite(pos[3]) then
                if not slot then
                    state.count = state.count + 1
                    slot = state.count
                    slots[id] = slot
                end
                local entry = { id = id, mass = point.mass, position = { pos[1], pos[2], pos[3] } }
                records[slot] = entry
                if receiver then receiver.update(id) end
            end
        end
    end
end

function Get(id)
    return records[slots[id]]
end

function SetArea(rect)
    state.area = { rect[1], rect[2], rect[3], rect[4] }
    if receiver then receiver.area() end
end

function Toggle()
    return receiver and receiver.toggle()
end

function CommandGraph(shown)
    state.graph = shown
    return receiver and receiver.graph()
end
