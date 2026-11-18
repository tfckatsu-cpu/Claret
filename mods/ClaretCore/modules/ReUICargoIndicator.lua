-- Optional bridge to the installed ReUI.Construction passenger indicator.
-- ReUI keeps the rendered mark in its private TransportCargo context; this
-- updates that context for a passenger Core has already staged in the session.

local function Failure(reason, fallbackAllowed)
    return false, reason, fallbackAllowed == true
end

local function Read(object, key)
    local ok, value = pcall(function() return object[key] end)
    if not ok then return false, value end
    return true, value
end

local function Invoke(object, method, argument)
    local okMethod, callback = Read(object, method)
    if not okMethod then return false, callback end
    if type(callback) ~= 'function' then return false, 'method unavailable: ' .. method end
    if argument ~= nil then return pcall(callback, object, argument) end
    return pcall(callback, object)
end

local function IsObject(value)
    local valueType = type(value)
    return valueType == 'table' or valueType == 'userdata'
end

function Mark(unit, cargoUnits)
    if unit == nil then return Failure('passenger unit is required') end

    local reui = rawget(_G, 'ReUI')
    if type(reui) ~= 'table' then
        return Failure('ReUI global panel registry is unavailable')
    end
    local okUI, ui = Read(reui, 'UI')
    if not okUI or not IsObject(ui) then return Failure('ReUI UI namespace is unavailable') end
    local okGlobal, global = Read(ui, 'Global')
    if not okGlobal or not IsObject(global) then return Failure('ReUI global panel registry is unavailable') end
    local okPanel, panel = Read(global, 'Construction')
    if not okPanel then return Failure('ReUI construction panel lookup failed') end
    if panel == nil then return Failure('ReUI construction panel is unavailable') end
    local okDestroyed, destroyed = pcall(function() return IsDestroyed(panel) end)
    if not okDestroyed then return Failure('ReUI panel destruction check failed') end
    if destroyed then return Failure('ReUI construction panel is destroyed') end

    local okHandler, handler = Invoke(panel, 'GetHandler', 'TransportCargo')
    if not okHandler or not IsObject(handler) then return Failure('ReUI TransportCargo handler is unavailable') end

    local okContext, context = Read(handler, '_context')
    if not okContext or not IsObject(context) then return Failure('ReUI cargo context is unavailable') end
    local okActiveMethod, isActive = Read(context, 'IsActive')
    if not okActiveMethod or type(isActive) ~= 'function' then return Failure('ReUI cargo context IsActive API is unavailable') end
    local okActive, active = pcall(isActive, context)
    if not okActive then return Failure('ReUI cargo context activation check failed') end
    if active ~= true then return Failure('ReUI cargo context is inactive') end

    if cargoUnits ~= nil then
        if type(cargoUnits) ~= 'table' then return Failure('cargo unit list is invalid') end
        local okSetCargo, setCargo = Read(context, 'SetCargo')
        if not okSetCargo or type(setCargo) ~= 'function' then
            return Failure('ReUI cargo context SetCargo API is unavailable')
        end
        local okSet, setError = pcall(setCargo, context, cargoUnits)
        if not okSet then return Failure('ReUI cargo list refresh failed: ' .. tostring(setError)) end
    end

    local okCargo, cargo = Read(context, 'cargoUnits')
    if not okCargo or type(cargo) ~= 'table' then return Failure('ReUI cargo unit list is unavailable') end
    local found = false
    for _, candidate in ipairs(cargo) do
        if candidate == unit then found = true; break end
    end
    if not found then return Failure('passenger is not in ReUI cargo context') end
    local okMarkMethod, markUnit = Read(context, 'MarkUnit')
    if not okMarkMethod or type(markUnit) ~= 'function' then return Failure('ReUI cargo context MarkUnit API is unavailable') end
    local okMark, markError = pcall(markUnit, context, unit)
    if not okMark then return Failure('ReUI passenger mark failed: ' .. tostring(markError)) end

    local okRefresh, refreshError = Invoke(panel, 'Refresh')
    if not okRefresh then return Failure('ReUI panel refresh failed: ' .. tostring(refreshError)) end
    return true
end

-- Mirror ReUI.Construction's registered transport action: use its handler API,
-- then refresh the same panel in the same call so the passenger mark renders now.
function AppendNext()
    local reui = rawget(_G, 'ReUI')
    if type(reui) ~= 'table' then return Failure('ReUI global panel registry is unavailable', true) end
    local okUI, ui = Read(reui, 'UI')
    if not okUI or not IsObject(ui) then return Failure('ReUI UI namespace is unavailable', true) end
    local okGlobal, global = Read(ui, 'Global')
    if not okGlobal or not IsObject(global) then return Failure('ReUI global panel registry is unavailable', true) end
    local okPanel, panel = Read(global, 'Construction')
    if not okPanel or panel == nil then return Failure('ReUI construction panel is unavailable', true) end
    local okDestroyed, destroyed = pcall(function() return IsDestroyed(panel) end)
    if not okDestroyed then return Failure('ReUI panel destruction check failed', true) end
    if destroyed then return Failure('ReUI construction panel is destroyed', true) end

    -- Hotbuild may invoke the action before ReUI processed the latest selection.
    -- Prime the cargo handler before asking it to append the next passenger.
    local okPrime, primeError = Invoke(panel, 'Refresh')
    if not okPrime then return Failure('ReUI panel pre-refresh failed: ' .. tostring(primeError), true) end

    local okHandler, handler = Invoke(panel, 'GetHandler', 'TransportCargo')
    if not okHandler or not IsObject(handler) then return Failure('ReUI TransportCargo handler is unavailable', true) end
    local okAppend, append = Read(handler, 'AppendNextUnitForDrop')
    if not okAppend or type(append) ~= 'function' then
        return Failure('ReUI TransportCargo append API is unavailable', true)
    end
    local okResult, appended = pcall(append, handler)
    if not okResult then return Failure('ReUI passenger append failed: ' .. tostring(appended)) end
    if appended ~= true then return Failure('ReUI TransportCargo handler is inactive', true) end

    local okRefresh, refreshError = Invoke(panel, 'Refresh')
    if not okRefresh then return true, true, 'ReUI panel refresh failed: ' .. tostring(refreshError) end
    return true, true
end
