-- CargoSelection ownership and transition tests.
table.getn = function(value) return #value end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/CargoSelection.lua', 't', module))()
local a, b, c, d, outside = {}, {}, {}, {}, {}
local queued = { [b] = true }
local added, removed, refreshed = {}, {}, 0
local service = module.Create({
    add = function(unit) table.insert(added, unit) end,
    remove = function(unit) table.insert(removed, unit) end,
    isQueued = function(unit) return queued[unit] == true end,
    refresh = function() refreshed = refreshed + 1 end,
})

assert(service:SetCargo({ a, b, c, d }))
assert(service:IsSelected(2), 'queued unloads are reflected as selected')
assert(not service:Toggle(2), 'queued unload cannot be manually toggled')
assert(service:Toggle(1) and service:IsSelected(1))
assert(not service:SetCargo({ a, b, c, d }), 'same cargo keeps state without a spurious refresh')
assert(service:AddRange(3), 'range extends from the last manual toggle')
assert(service:IsSelected(1) and service:IsSelected(3), 'range adds its endpoints')
assert(service:IsSelected(2), 'queued unload remains represented by queue state')
assert(#added == 2 and added[1] == a and added[2] == c)
assert(service:Toggle(1) and not service:IsSelected(1), 'manual toggle removes owned unit')

service:SetCargo({ b, c, d })
assert(#removed == 1 and removed[1] == a, 'stale owned unit is removed on cargo refresh')
local appended, unit, index = service:AppendNext()
assert(appended and unit == d and index == 3, 'append skips queued and already selected cargo')
assert(not service:AppendNext(), 'append ends when no unselected cargo remains')

local preResetRemoved = #removed
assert(service:Reset(), 'reset changes owned selections')
assert(#removed == preResetRemoved + 2, 'reset removes only owned cargo')
local count = #removed
service:SetCargo({ outside })
assert(#removed == count, 'reset does not clear unrelated shared selections')
assert(refreshed >= 5, 'visual refresh callback runs after state changes')

service:Toggle(1)
service:Destroy()
assert(removed[#removed] == outside, 'destroy cleans its final owned unit')
count = #removed
service:Destroy()
assert(#removed == count, 'destroy is idempotent')
assert(not service:Toggle(1), 'destroyed state rejects changes')

local reOrdered = module.Create({ add = function() end, remove = function() end })
reOrdered:SetCargo({ a, b, c, d })
assert(reOrdered:Toggle(1))
assert(reOrdered:SetCargo({ b, a, c, d }), 'cargo reorder is observed')
assert(reOrdered:AddRange(4), 'anchor remains attached to the same unit after reorder')
local rangeSelection = reOrdered:GetSelection()
assert(#rangeSelection == 3 and rangeSelection[1] == a
    and rangeSelection[2] == c and rangeSelection[3] == d)

local failAdd, failRemove = true, false
local failureState = module.Create({
    add = function() if failAdd then error('add failed') end end,
    remove = function() if failRemove then error('remove failed') end end,
    refresh = function() error('refresh failure is isolated') end,
})
failureState:SetCargo({ a })
assert(not failureState:Toggle(1) and #failureState:GetSelection() == 0,
    'failed add is not recorded as owned')
failAdd = false
assert(failureState:Toggle(1) and #failureState:GetSelection() == 1,
    'successful add is recorded despite refresh callback failure')
failRemove = true
local changedOnFailure, cleanupOnFailure = failureState:Reset()
assert(not changedOnFailure and cleanupOnFailure == false and #failureState:GetSelection() == 1,
    'failed remove preserves ownership so cleanup can retry')
failRemove = false
local changedOnRetry, cleanupOnRetry = failureState:Reset()
assert(changedOnRetry and cleanupOnRetry == true and #failureState:GetSelection() == 0,
    'cleanup retries removal successfully')

local queueState = false
local queuedTransition = module.Create({ isQueued = function() return queueState end })
queuedTransition:SetCargo({ b })
queueState = true
assert(queuedTransition:SetCargo({ b }) and queuedTransition:IsSelected(1),
    'queue transition refreshes selected state')
queueState = false
assert(queuedTransition:SetCargo({ b }) and not queuedTransition:IsSelected(1),
    'queue removal refreshes selected state')

print('PASS: cargo selection toggles, range, append, queued unloads, stale cargo and owned cleanup')
