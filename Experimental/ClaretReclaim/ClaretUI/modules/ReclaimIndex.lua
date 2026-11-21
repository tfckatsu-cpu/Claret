local floor = math.floor
local LEAF_SIZE = 16

local function Heavier(a, b)
    if a.mass ~= b.mass then return a.mass > b.mass end
    if type(a.id) == type(b.id) then return a.id < b.id end
    return type(a.id) == 'number'
end

local function Write(heap, slot, item)
    heap.items[slot] = item
    if heap.slots then heap.slots[item] = slot end
end

local function Up(heap, slot, item)
    local items, before = heap.items, heap.before
    while slot > 1 do
        local parent = floor(slot / 2)
        if not before(item, items[parent]) then break end
        Write(heap, slot, items[parent])
        slot = parent
    end
    Write(heap, slot, item)
end

local function Push(heap, item)
    heap.count = heap.count + 1
    Up(heap, heap.count, item)
end

local function Remove(heap, slot)
    local items, before = heap.items, heap.before
    local item, last = items[slot], items[heap.count]
    items[heap.count] = nil
    heap.count = heap.count - 1
    if heap.slots then heap.slots[item] = nil end
    if slot > heap.count then return item end
    if slot > 1 and before(last, items[floor(slot / 2)]) then
        Up(heap, slot, last)
    else
        local child = slot * 2
        while child <= heap.count do
            if child < heap.count and before(items[child + 1], items[child]) then child = child + 1 end
            if not before(items[child], last) then break end
            Write(heap, slot, items[child])
            slot, child = child, child * 2
        end
        Write(heap, slot, last)
    end
    return item
end

local function Node(x, z, size)
    local node = { x = x, z = z, size = size, mass = 0, count = 0 }
    if size <= LEAF_SIZE then
        node.heap = { items = {}, slots = {}, count = 0, before = Heavier }
    else
        node.children = {}
    end
    return node
end

local function Change(node, old, entry)
    node.mass = node.mass + (entry and entry.mass or 0) - (old and old.mass or 0)
    node.count = node.count + (entry and 1 or 0) - (old and 1 or 0)
    if node.count == 0 then node.mass = 0 end

    local heap = node.heap
    if heap then
        if old then Remove(heap, heap.slots[old]) end
        if entry then Push(heap, entry) end
        node.best = heap.items[1]
        return
    end

    local pos = (entry or old).position
    local size = node.size * 0.5
    local dx = pos[1] >= node.x + size and 1 or 0
    local dz = pos[3] >= node.z + size and 1 or 0
    local slot = 1 + dx + 2 * dz
    local children = node.children
    local child = children[slot]
    if not child then child = Node(node.x + dx * size, node.z + dz * size, size) end
    Change(child, old, entry)
    children[slot] = child.count > 0 and child or nil
    local best
    for i = 1, 4 do
        local other = children[i]
        if other and (not best or Heavier(other.best, best)) then best = other.best end
    end
    node.best = best
end

function Create(width, height)
    local size = LEAF_SIZE
    while size < width or size < height do size = size * 2 end
    return { root = Node(0, 0, size), entries = {} }
end

function Update(index, id, entry)
    local old = index.entries[id]
    if old == entry then return false end
    index.entries[id] = entry
    if old and entry and old.position[1] == entry.position[1] and old.position[3] == entry.position[3] then
        Change(index.root, old, entry)
    else
        if old then Change(index.root, old) end
        if entry then Change(index.root, nil, entry) end
    end
    return true
end

local function NearOrder(a, b)
    return Heavier(a.entry, b.entry)
end

local function FarOrder(a, b)
    if a.mass ~= b.mass then return a.mass > b.mass end
    if a.node.size ~= b.node.size then return a.node.size > b.node.size end
    if a.node.x ~= b.node.x then return a.node.x < b.node.x end
    return a.node.z < b.node.z
end

local function QueueNode(search, node)
    local b = search.bounds
    if not node.best or node.x > b.right or node.x + node.size < b.left
        or node.z > b.bottom or node.z + node.size < b.top then return end
    if search.size then
        Push(search.heap, { node = node, mass = node.mass })
    else
        Push(search.heap, { node = node, entry = node.best })
    end
end

local function QueueLeaf(search, leaf, slot)
    local entry = leaf.items[slot]
    if entry then Push(search.heap, { leaf = leaf, slot = slot, entry = entry }) end
end

function Search(index, bounds, size)
    local heap = { items = {}, count = 0, before = size and FarOrder or NearOrder }
    local search = { index = index, bounds = bounds, size = size, heap = heap }
    QueueNode(search, index.root)
    return search
end

-- Each step examines one heap item. The caller controls both work and projection budgets.
function Step(search)
    local heap = search.heap
    if heap.count == 0 then return nil, true end
    local item = Remove(heap, 1)
    local node = item.node
    if node then
        if node.count == 0 then return end
        if search.size and node.size <= search.size then return node end
        if node.children then
            for i = 1, 4 do
                local child = node.children[i]
                if child then QueueNode(search, child) end
            end
        else
            QueueLeaf(search, node.heap, 1)
        end
    else
        local slot, leaf = item.slot, item.leaf
        QueueLeaf(search, leaf, slot * 2)
        QueueLeaf(search, leaf, slot * 2 + 1)
        if search.index.entries[item.entry.id] == item.entry then return item.entry end
    end
end

function CellSize(index, desired, previous)
    if previous and desired >= previous * 0.68 and desired < previous * 1.46 then return previous end
    local size = LEAF_SIZE
    while size < index.root.size and size * 1.41 < desired do size = size * 2 end
    return size
end
