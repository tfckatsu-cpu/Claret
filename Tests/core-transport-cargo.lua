-- Logic regression test for ClaretCore's isolated transport cargo staging service.
table.getn = function(value) return #value end

local selected, attachedByTransport = {}, {}
local sessionExtraSelectList = {'other-mod-entry'}
local clearCalls = 0
local failNextAdd = false
local sounds = {}
local game = {
    Sound=function(data) return data end,
    PlaySound=function(sound) table.insert(sounds,sound.Cue) end,
    categories = {TRANSPORTATION='TRANSPORTATION', MOBILE='MOBILE'},
    GetSelectedUnits = function() return selected end,
    GetAttachedUnitsList = function(transports)
        local result = {}
        for _, transport in ipairs(transports) do
            for _, unit in ipairs(attachedByTransport[transport] or {}) do
                table.insert(result, unit)
            end
        end
        return result
    end,
    EntityCategoryFilterDown = function(category, units)
        local result = {}
        for _, unit in ipairs(units or {}) do
            if unit.categories and unit.categories[category] then table.insert(result, unit) end
        end
        return result
    end,
    AddToSessionExtraSelectList = function(unit)
        if failNextAdd then
            failNextAdd = false
            error('simulated session-list failure')
        end
        table.insert(sessionExtraSelectList, unit)
    end,
    ClearSessionExtraSelectList = function()
        clearCalls = clearCalls + 1
        sessionExtraSelectList = {}
    end,
}
game._G=game
setmetatable(game, {__index=_G})
local module = setmetatable({}, {__index=game})
assert(loadfile('../mods/ClaretCore/modules/TransportCargo.lua', 't', module))()

local function unit(id, categoryList, dead, queued)
    local categories = {}
    for _, category in ipairs(categoryList or {}) do categories[category] = true end
    return {
        id=id, categories=categories, dead=dead or false, queued=queued or false,
        IsDead=function(self) return self.dead end,
        HasUnloadCommandQueuedUp=function(self) return self.queued end,
    }
end

local transportA=unit('transportA', {'TRANSPORTATION','MOBILE'})
local transportB=unit('transportB', {'TRANSPORTATION','MOBILE'})
local engineer=unit('engineer', {'MOBILE'})
local cargo1=unit('cargo1', {'MOBILE'}, false, true)
local cargo2=unit('cargo2', {'MOBILE'})
local cargo3=unit('cargo3', {'MOBILE'})
local cargo4=unit('cargo4', {'MOBILE'})
local deadCargo=unit('deadCargo', {'MOBILE'}, true)
attachedByTransport[transportA]={cargo1,cargo2,cargo3,deadCargo}
attachedByTransport[transportB]={cargo4}

local service=module.Create(false)
selected={transportA}
assert(not service:Append({transportB}) and #sessionExtraSelectList==1,
    'mismatched requested selection is rejected')
assert(not service:Append({transportA,engineer}) and #sessionExtraSelectList==1,
    'mixed transport and non-transport selection is rejected')

local ok, staged, index=service:Append(selected)
assert(ok and staged==cargo2 and index==2,
    'initial cursor skips cargo already queued for unload and dead cargo')
assert(sounds[#sounds]=='UI_MFD_Click','successful staging plays feedback')
ok, staged, index=service:Append(selected)
assert(ok and staged==cargo3 and index==3,'subsequent calls preserve cargo order')
assert(not service:Append(selected),'append stops after the final eligible cargo')
assert(sounds[#sounds]=='UI_Menu_Error_01','exhausted cargo plays error feedback')

cargo2.queued=true
service:Reset()
ok, staged, index=service:Append(selected)
assert(ok and staged==cargo3 and index==3,'Reset reinitializes at the first not-queued cargo')

-- Changing membership invalidates the cursor and initializes against the new cargo set.
attachedByTransport[transportA]={cargo4,cargo3}
ok, staged, index=service:Append(selected)
assert(ok and staged==cargo4 and index==1,'cargo membership change resets cursor and follows current order')

-- Changing the selected transport set also creates a fresh cursor.
selected={transportA,transportB}
ok, staged, index=service:Append(selected)
assert(ok and staged==cargo4 and index==1,'transport selection change resets the cursor')

-- A failed append must leave the same cargo at the cursor for a later retry.
attachedByTransport[transportA]={cargo2}
cargo2.queued=false
selected={transportA}
service:Reset()
local beforeRetry=#sessionExtraSelectList
failNextAdd=true
assert(not service:Append(selected) and #sessionExtraSelectList==beforeRetry,
    'a failed extra-select append does not report success or add cargo')
ok, staged, index=service:Append(selected)
assert(ok and staged==cargo2 and index==1,
    'a failed extra-select append retries the same cargo on the next call')

-- With an unchanged cargo set, a cancelled queued unload must become eligible.
attachedByTransport[transportA]={cargo2,cargo3}
cargo2.queued=true
cargo3.queued=true
service:Reset()
local beforeAllQueued=#sessionExtraSelectList
assert(not service:Append(selected) and #sessionExtraSelectList==beforeAllQueued,
    'all cargo with queued unloads leaves the cursor uninitialized')
cargo3.queued=false
ok, staged, index=service:Append(selected)
assert(ok and staged==cargo3 and index==2,
    'cancelled queued unload is staged without a cargo membership change')

local deadTransport=unit('deadTransport', {'TRANSPORTATION','MOBILE'}, true)
selected={deadTransport}
assert(not service:Append(selected),'dead transports are rejected safely')
selected={}
assert(not service:Append(nil),'nil/empty selection is handled safely')

local replay=module.Create(true)
selected={transportA}
assert(not replay:Append(selected),'replay service never stages cargo')
replay:Destroy()
assert(not replay:Append(selected),'destroyed service never stages cargo')

assert(sessionExtraSelectList[1]=='other-mod-entry' and clearCalls==0,
    'staging preserves shared session selection state and never clears it')
service:Destroy()
assert(sessionExtraSelectList[1]=='other-mod-entry' and clearCalls==0,
    'Destroy resets only internal cursor state')
print('PASS: transport cargo snapshot validation, ordering, queued cargo, membership resets, replay and shared state')
