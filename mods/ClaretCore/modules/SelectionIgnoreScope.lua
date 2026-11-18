-- Original scoped wrapper around FAF's SetIgnoreSelection setter.
-- Install this manager before UI selection callbacks begin, then route every
-- subsequent external SetIgnoreSelection call through manager.SetIgnoreSelection.
--
-- Create(originalSetter, knownInitialExternalValue) returns a manager exposing:
-- SetIgnoreSelection(value), AcquireIgnoreSelectionScope(),
-- ReleaseIgnoreSelectionScope(token), GetState(), and Destroy().
-- The effective FAF value is external request OR at least one active lease.

function Create(originalSetter, knownInitialExternalValue)
    if type(originalSetter) ~= 'function' then
        return nil, 'original SetIgnoreSelection callback is required'
    end
    if type(knownInitialExternalValue) ~= 'boolean' then
        return nil, 'known initial external ignore state is required'
    end

    local owner = {}
    local tokens = {}
    local nextTokenId = 0
    local externalRequested = knownInitialExternalValue
    local effective = knownInitialExternalValue
    local synchronized = true
    local destroyed = false

    local function LeaseCount()
        local count = 0
        for _ in pairs(tokens) do count = count + 1 end
        return count
    end

    local function Desired(externalValue, leaseCount)
        return externalValue or leaseCount > 0
    end

    local function SetUnderlying(value)
        local ok, result = pcall(originalSetter, value)
        if not ok then
            synchronized = false
            return false, result
        end
        if result == false then
            synchronized = false
            return false, 'original setter rejected the state change'
        end
        synchronized = true
        effective = value
        return true
    end

    local function EnsureSynchronized()
        if synchronized then return true end
        return SetUnderlying(Desired(externalRequested, LeaseCount()))
    end

    local manager = {}

    function manager.SetIgnoreSelection(value)
        if destroyed then return false, 'ignore scope manager is destroyed' end
        if type(value) ~= 'boolean' then return false, 'ignore state must be boolean' end
        local ok, err = EnsureSynchronized()
        if not ok then return false, err end
        local desired = Desired(value, LeaseCount())
        if desired ~= effective then
            ok, err = SetUnderlying(desired)
            if not ok then return false, err end
        end
        externalRequested = value
        return true
    end

    function manager.AcquireIgnoreSelectionScope()
        if destroyed then return nil, 'ignore scope manager is destroyed' end
        local ok, err = EnsureSynchronized()
        if not ok then return nil, err end
        local desired = true
        if desired ~= effective then
            ok, err = SetUnderlying(desired)
            if not ok then return nil, err end
        end
        nextTokenId = nextTokenId + 1
        local token = { owner = owner, id = nextTokenId }
        tokens[token] = true
        return token
    end

    function manager.ReleaseIgnoreSelectionScope(token)
        if destroyed then return false, 'ignore scope manager is destroyed' end
        if type(token) ~= 'table' or token.owner ~= owner or tokens[token] ~= true then
            return false, 'ignore scope token is invalid or already released'
        end
        local ok, err = EnsureSynchronized()
        if not ok then return false, err end
        local desired = Desired(externalRequested, LeaseCount() - 1)
        if desired ~= effective then
            ok, err = SetUnderlying(desired)
            if not ok then return false, err end
        end
        tokens[token] = nil
        token.released = true
        return true
    end

    function manager.GetState()
        return {
            knownInitialState = true,
            externalRequested = externalRequested,
            effective = effective,
            leaseCount = LeaseCount(),
            synchronized = synchronized,
            destroyed = destroyed,
        }
    end

    function manager.Destroy()
        if destroyed then return false, 'ignore scope manager is already destroyed' end
        local desired = externalRequested
        if not synchronized or desired ~= effective then
            local ok, err = SetUnderlying(desired)
            if not ok then return false, err end
        end
        for token in pairs(tokens) do
            tokens[token] = nil
            token.released = true
        end
        effective = desired
        destroyed = true
        return true
    end

    return manager
end
