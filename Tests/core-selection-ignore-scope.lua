-- Mock-only lifecycle tests for the ownership-aware selection ignore wrapper.
local env = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/SelectionIgnoreScope.lua', 't', env))()

local values = {}
local underlying = false
local function createSetter(options)
    options = options or {}
    return function(value)
        table.insert(values, value)
        if options.throwOn == value then error('mock setter failure') end
        if options.rejectOn == value then return false end
        underlying = value
    end
end

-- Nested leases hold true until the last owned scope releases.
values, underlying = {}, false
local manager = assert(env.Create(createSetter(), false))
local first = assert(manager.AcquireIgnoreSelectionScope())
local second = assert(manager.AcquireIgnoreSelectionScope())
assert(underlying and #values == 1 and values[1] == true,
    'nested scopes set the underlying flag only when the effective state changes')
assert(manager.ReleaseIgnoreSelectionScope(second))
assert(underlying and #values == 1, 'releasing an inner scope retains the outer lease')
assert(manager.ReleaseIgnoreSelectionScope(first))
assert(not underlying and #values == 2 and values[2] == false,
    'last lease restores the known external state')
assert(not manager.ReleaseIgnoreSelectionScope(first), 'duplicate scope release fails without changing state')

-- External requests during a lease are retained independently of the effective flag.
values, underlying = {}, false
manager = assert(env.Create(createSetter(), false))
local lease = assert(manager.AcquireIgnoreSelectionScope())
assert(manager.SetIgnoreSelection(false))
assert(underlying and manager.GetState().externalRequested == false,
    'external false request is remembered while the owned scope keeps effective true')
assert(manager.ReleaseIgnoreSelectionScope(lease))
assert(not underlying and values[#values] == false, 'release applies the latest external request')
assert(manager.SetIgnoreSelection(true))
lease = assert(manager.AcquireIgnoreSelectionScope())
assert(manager.ReleaseIgnoreSelectionScope(lease) and underlying,
    'external true request survives scope release')
assert(manager.SetIgnoreSelection(false) and not underlying,
    'later external false request turns the effective state off')

-- Initial external true is preserved and does not require duplicate underlying calls.
values, underlying = {}, true
manager = assert(env.Create(createSetter(), true))
lease = assert(manager.AcquireIgnoreSelectionScope())
assert(manager.ReleaseIgnoreSelectionScope(lease) and underlying and #values == 0,
    'scope does not clear a pre-existing external true request')
assert(manager.SetIgnoreSelection(false) and not underlying and values[1] == false,
    'wrapped setter can turn off the external request after lease release')

-- Failed setter calls do not drop leases or report successful state transitions.
values, underlying = {}, false
local rejectFalse = true
manager = assert(env.Create(function(value)
    table.insert(values, value)
    if value == false and rejectFalse then return false end
    underlying = value
end, false))
lease = assert(manager.AcquireIgnoreSelectionScope())
assert(not manager.ReleaseIgnoreSelectionScope(lease)
    and manager.GetState().leaseCount == 1 and not manager.GetState().synchronized,
    'failed release retains token and reports uncertain underlying synchronization')
rejectFalse = false
assert(manager.ReleaseIgnoreSelectionScope(lease) and manager.GetState().leaseCount == 0
    and not underlying and manager.GetState().synchronized,
    'release retry first resynchronizes then commits token release')

-- Exception failures can be retried without fabricating an acquired token.
values, underlying = {}, false
local throwTrue = true
manager = assert(env.Create(function(value)
    table.insert(values, value)
    if value == true and throwTrue then error('mock exception') end
    underlying = value
end, false))
local failedToken = manager.AcquireIgnoreSelectionScope()
assert(failedToken == nil and manager.GetState().leaseCount == 0
    and not manager.GetState().synchronized, 'failed acquisition returns no lease token')
throwTrue = false
lease = assert(manager.AcquireIgnoreSelectionScope())
assert(underlying and manager.Destroy() and not underlying,
    'destroy restores external state and invalidates outstanding tokens')
assert(not manager.ReleaseIgnoreSelectionScope(lease), 'destroyed manager rejects stale scope tokens')
assert(not manager.SetIgnoreSelection(true), 'destroyed manager rejects external setter calls')
assert(not manager.Destroy(), 'destroy is not reported successful twice')

-- Unknown initial state fails closed before touching the supplied setter.
values = {}
local missing, missingError = env.Create(createSetter(), nil)
assert(missing == nil and missingError and #values == 0,
    'manager refuses to guess when initial external state is unknown')
missing, missingError = env.Create(nil, false)
assert(missing == nil and missingError, 'manager requires the original setter callback')

print('PASS: selection ignore scope nesting, external updates, failures and teardown')
