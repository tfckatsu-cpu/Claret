-- Mock-only tests for the explicit setter-table adapter.
local scopeEnv = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/SelectionIgnoreScope.lua', 't', scopeEnv))()
local adapterEnv = setmetatable({
    import = function(path)
        assert(path == '/mods/ClaretCore/modules/SelectionIgnoreScope.lua')
        return scopeEnv
    end,
}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/SelectionIgnoreHook.lua', 't', adapterEnv))()

local underlying, setterCalls, preWrapperCalls = false, {}, 0
local function originalSetter(value)
    underlying = value
    table.insert(setterCalls, value)
end
local function makeModule(setter)
    return { SetIgnoreSelection = setter }
end

-- A pre-existing wrapper is retained as the scope manager's original callback.
local preexisting = function(value)
    preWrapperCalls = preWrapperCalls + 1
    return originalSetter(value)
end
local module = makeModule(preexisting)
local adapter = assert(adapterEnv.Create(module, false))
local ownedWrapper = module.SetIgnoreSelection
assert(ownedWrapper ~= preexisting, 'adapter replaces setter only after scope manager creation succeeds')
local duplicate, duplicateError = adapterEnv.Create(module, false)
assert(duplicate == nil and duplicateError and module.SetIgnoreSelection == ownedWrapper,
    'duplicate install fails without replacing the owned wrapper')

assert(module.SetIgnoreSelection(true) and underlying)
assert(module.SetIgnoreSelection(false) and not underlying)
local outer = assert(adapter.AcquireIgnoreSelectionScope())
local inner = assert(adapter.AcquireIgnoreSelectionScope())
assert(underlying)
assert(adapter.ReleaseIgnoreSelectionScope(inner) and underlying)
assert(adapter.ReleaseIgnoreSelectionScope(outer) and not underlying,
    'external setter calls and nested leases share the real manager state')
assert(module.SetIgnoreSelection(true) and underlying)
assert(adapter.Destroy() and module.SetIgnoreSelection == preexisting and underlying,
    'teardown restores the exact pre-existing wrapper and its requested external state')
assert(preWrapperCalls == #setterCalls, 'all manager writes preserved the captured pre-existing wrapper')

-- Unknown/malformed states are rejected without changing the module.
module = makeModule(preexisting)
local missing, missingError = adapterEnv.Create(module, nil)
assert(missing == nil and missingError and module.SetIgnoreSelection == preexisting,
    'unknown initial state fails closed')
missing, missingError = adapterEnv.Create({}, false)
assert(missing == nil and missingError, 'a module without the setter is rejected')
missing, missingError = adapterEnv.Create(false, false)
assert(missing == nil and missingError, 'non-table module input is rejected')

-- Failed scoped cleanup keeps the wrapper installed so the caller can retry safely.
local rejectFalse = true
module = makeModule(function(value)
    if value == false and rejectFalse then error('mock original setter failure') end
    originalSetter(value)
end)
underlying = false
local failingOriginal = module.SetIgnoreSelection
adapter = assert(adapterEnv.Create(module, false))
outer = assert(adapter.AcquireIgnoreSelectionScope())
assert(underlying)
assert(not adapter.Destroy() and module.SetIgnoreSelection ~= nil
    and adapter.GetState().leaseCount == 1,
    'failed cleanup does not detach the wrapper or lose active scope state')
rejectFalse = false
assert(adapter.Destroy() and module.SetIgnoreSelection == failingOriginal
    and not underlying, 'cleanup can be retried and restores the external baseline')

-- Original setter failures surface through the installed wrapper without false success.
local rejectTrue = true
module = makeModule(function(value)
    if value == true and rejectTrue then error('mock setter exception') end
    originalSetter(value)
end)
underlying = false
adapter = assert(adapterEnv.Create(module, false))
local okSet = module.SetIgnoreSelection(true)
assert(not okSet and not adapter.GetState().externalRequested and not adapter.GetState().synchronized,
    'setter exceptions are reported and not recorded as successful external changes')
rejectTrue = false
assert(module.SetIgnoreSelection(false) and adapter.GetState().synchronized and not underlying,
    'later setter call resynchronizes the original state before accepting changes')
assert(adapter.Destroy())

-- Takeover or wrapping by another mod is never overwritten by Destroy.
underlying = false
module = makeModule(originalSetter)
adapter = assert(adapterEnv.Create(module, false))
outer = assert(adapter.AcquireIgnoreSelectionScope())
local ownedBeforeTakeover = module.SetIgnoreSelection
local takeoverCalls = {}
local takeover = function(value)
    table.insert(takeoverCalls, value)
    return ownedBeforeTakeover(value)
end
module.SetIgnoreSelection = takeover
assert(takeover(false) and underlying,
    'a newer wrapper can continue forwarding external requests through the captured adapter')
local beforeTakeoverDestroy = #setterCalls
local detached, detachError = adapter.Destroy()
assert(not detached and detachError and module.SetIgnoreSelection == takeover
    and underlying and #setterCalls == beforeTakeoverDestroy,
    'takeover is preserved and cleanup refuses to alter state through a stale setter')
assert(not adapter.ReleaseIgnoreSelectionScope(outer),
    'owned scopes fail closed after setter takeover')

print('PASS: selection ignore setter adapter preserves ownership, wrappers and safe teardown')
