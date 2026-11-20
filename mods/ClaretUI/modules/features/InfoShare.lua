local Game = import('/lua/ui/game/gamemain.lua')
local channel = 'ClaretUI.InfoShare'
local categories = { smd = 'Smd', experimental = 'Experimental', acu = 'Acu' }
local phases = { active = true, done = true, cancelled = true, interrupted = true }
local triggers = { started = 'active', completed = 'done', cancelled = 'cancelled' }
local commanders = { uef = 'uel0001', aeon = 'ual0001', cybran = 'url0001', seraphim = 'xsl0001' }
local lifetime, timeout, limit = 1.5, 12, 64
local sequence = 0
local stockListener

-- Called only for the two stock Notify payloads by the game UI hook.
function ReceiveNotify(sender, message)
    if stockListener then stockListener(sender, message) end
end

local function IsNumber(value, minimum, maximum)
    return type(value) == 'number' and value == value and value >= minimum and value <= maximum
end

local function Position(value)
    if type(value) ~= 'table' then return nil end
    for index = 1, 3 do
        if not IsNumber(value[index], -65536, 65536) then return nil end
    end
    return { value[1], value[2], value[3] }
end

local function IsId(value)
    return type(value) == 'string' and string.len(value) <= 64 and string.match(value, '^[%w_]+$')
end

local function BlueprintKind(bp)
    local hash = bp and bp.CategoriesHash
    if not hash then return nil end
    if hash.STRUCTURE and hash.TECH3 and hash.ANTIMISSILE and hash.SILO then return 'smd' end
    if bp.TechCategory == 'EXPERIMENTAL' then return 'experimental' end
end

local function WorkName(kind, blueprint, enhancement, Text)
    if not IsId(blueprint) then return nil end
    local bp = __blueprints[blueprint]
    if kind == 'acu' then
        local item = bp and bp.CategoriesHash and bp.CategoriesHash.COMMAND
            and IsId(enhancement) and not string.find(enhancement, 'Remove', 1, true)
            and bp.Enhancements and bp.Enhancements[enhancement]
        if item then return LOC(item.Name or enhancement) end
    elseif BlueprintKind(bp) == kind then
        local general = bp.General or {}
        return LOC(general.UnitName or bp.Description or Text(kind))
    end
end

local function Percent(fraction)
    if IsNumber(fraction, 0, 1) then return math.floor(fraction * 100) end
end

local function Owned(unit, army)
    return unit and not unit:IsDead() and unit:GetArmy() == army
end

local function SortRows(a, b)
    if a.phase ~= b.phase and (a.phase == 'active' or b.phase == 'active') then
        return a.phase == 'active'
    end
    if a.army ~= b.army then return a.army < b.army end
    return a.key < b.key
end

-- Match clients to allied human command sources. FindClients() also includes observers.
local function Recipients(armies, own)
    local sources, result = {}, {}
    for index, army in pairs(armies) do
        if index ~= own and army.human and not army.outOfGame and IsAlly(own, index) then
            for _, source in pairs(army.authorizedCommandSources or {}) do sources[source] = true end
        end
    end
    for index, client in pairs(GetSessionClients() or {}) do
        if client.connected then
            for _, source in pairs(client.authorizedCommandSources or {}) do
                if sources[source] then
                    table.insert(result, index)
                    break
                end
            end
        end
    end
    return result
end

function Start(self, scope, isReplay, options)
    local own = Game.OriginalFocusArmy
    if isReplay or type(own) ~= 'number' or own < 1 then return end
    local localization = ReUI.ClaretCore.Localization
    local display
    local localWork, remote, stock, pending = {}, {}, {}, {}
    local seenNotify = {}
    local workIndex = 0
    local running = false
    local sampleAt, sendAt = 0, 0
    local renderDirty = true

    local function Text(key)
        return localization.Text('claretui.infoshare.' .. key)
    end

    local function DisplayName(work)
        if work.kind == 'acu' then
            local prefix = 'claretui.notifications.upgrade.'
            local key = prefix .. work.blueprint .. '.' .. work.enhancement
            local message = localization.Text(key)
            if message == key then
                key = prefix .. work.enhancement
                message = localization.Text(key)
            end
            if message and message ~= key then
                return string.match(message, '^(.-) — ') or string.match(message, '^(.-) ready%.$') or message
            end
        end
        return WorkName(work.kind, work.blueprint, work.enhancement, Text)
    end

    local function DisplayEnabled()
        return options.infoShareList:Get() or options.infoShareWorld:Get()
    end

    local function OwnDataNeeded()
        return GetFocusArmy() == own
    end

    local function ArmyInfo()
        return GetArmiesTable().armiesTable
    end

    local function Ally(sender, armies)
        if GetFocusArmy() ~= own or type(sender) ~= 'string' then return nil end
        for index, army in pairs(armies) do
            if army.nickname == sender then
                if index ~= own and army.human and not army.outOfGame and IsAlly(own, index) then return index end
                return nil
            end
        end
    end

    local function Finish(work, phase)
        work.phase = phase
        work.expires = GetGameTimeSeconds() + lifetime
        if phase == 'done' then work.progress = 100 end
        renderDirty = true
        sendAt = 0
    end

    local function NewWork(id, kind, blueprint, enhancement)
        workIndex = workIndex + 1
        local work = {
            key = tostring(workIndex), army = own, id = id, kind = kind,
            blueprint = blueprint, enhancement = enhancement, phase = 'active',
        }
        localWork[work.key] = work
        renderDirty = true
        sendAt = 0
        return work
    end

    local construction, upgrades, builders = {}, {}, {}
    local experimentalSamples = 0

    local function Discover(unit)
        if not Owned(unit, own) then return end
        local id = unit:GetEntityId()
        if construction[id] then return true end
        local bp = unit:GetBlueprint()
        if not bp then return false end
        local hash = bp.CategoriesHash
        if hash and (hash.ENGINEER or hash.FACTORY or hash.COMMAND) then builders[id] = unit end
        local kind = BlueprintKind(bp)
        if kind then
            local progress = unit:GetFractionComplete()
            if IsNumber(progress, 0, 1) and progress < 1 then
                local work = NewWork(id, kind, bp.BlueprintId)
                work.unit = unit
                construction[id] = work
                return true
            end
            return false
        end
        return true
    end

    local function OnUnitData(data)
        if not OwnDataNeeded() or type(data) ~= 'table' then return end
        for key, value in pairs(data) do
            local id = tonumber(key)
            if value and id and not construction[id] and not pending[id] then pending[id] = 6 end
        end
    end

    local function OnSelection(info)
        if not OwnDataNeeded() then return end
        for _, unit in ipairs(info.newSelection or {}) do
            if Owned(unit, own) then
                Discover(unit)
                local target = unit:GetFocus()
                if target then Discover(target) end
            end
        end
    end

    local function OnEnhancements(events)
        if not OwnDataNeeded() then return end
        for _, event in ipairs(events) do
            local phase = triggers[event.trigger]
            if event.army == own and event.category == 'experimentals' and phase == 'active' then
                experimentalSamples = 10
                OnUnitData(UnitData)
            elseif event.army == own and phase and event.id and IsId(event.source) then
                local work = upgrades[event.id]
                if phase == 'active' then
                    local unit = GetUnitById(event.id)
                    local blueprint = Owned(unit, own) and unit:GetBlueprint().BlueprintId or commanders[event.category]
                    if WorkName('acu', blueprint, event.source, Text) then
                        if work then Finish(work, 'interrupted') end
                        work = NewWork(event.id, 'acu', blueprint, event.source)
                        work.unit = unit or nil
                        upgrades[event.id] = work
                    end
                elseif work and work.enhancement == event.source then
                    Finish(work, phase)
                    upgrades[event.id] = nil
                elseif not work then
                    local blueprint = commanders[event.category]
                    if WorkName('acu', blueprint, event.source, Text) then
                        Finish(NewWork(event.id, 'acu', blueprint, event.source), phase)
                    end
                end
            end
        end
    end

    local function SampleOwn()
        for id, attempts in pairs(pending) do
            local unit = GetUnitById(id)
            if Discover(unit) then
                pending[id] = nil
            else
                pending[id] = attempts > 1 and attempts - 1 or nil
            end
        end
        if experimentalSamples > 0 then
            experimentalSamples = experimentalSamples - 1
            for id, builder in pairs(builders) do
                if Owned(builder, own) then
                    Discover(builder:GetFocus())
                else
                    builders[id] = nil
                end
            end
        end
        for id, work in pairs(construction) do
            local unit = work.unit
            if Owned(unit, own) then
                local progress = Percent(unit:GetFractionComplete())
                work.progress = progress
                work.position = unit:GetPosition()
                if progress == 100 then
                    Finish(work, 'done')
                    construction[id] = nil
                end
            else
                Finish(work, 'interrupted')
                construction[id] = nil
            end
        end
        for id, work in pairs(upgrades) do
            local unit = work.unit or GetUnitById(id)
            if Owned(unit, own) then
                work.unit = unit
                work.progress = Percent(unit:GetWorkProgress())
                work.position = unit:GetPosition()
            elseif work.missing then
                Finish(work, 'interrupted')
                upgrades[id] = nil
            else
                work.missing = true
            end
        end
    end

    local function Publish(armies, now)
        local enabled, rows, ordered = {}, {}, {}
        for kind in pairs(categories) do enabled[kind] = true end
        local clients = Recipients(armies, own)
        if table.getn(clients) > 0 then
            for _, work in pairs(localWork) do
                if enabled[work.kind] then table.insert(ordered, work) end
            end
            table.sort(ordered, SortRows)
            for index = 1, math.min(limit, table.getn(ordered)) do
                local work = ordered[index]
                table.insert(rows, {
                    key = work.key, kind = work.kind, blueprint = work.blueprint, enhancement = work.enhancement,
                    phase = work.phase, progress = work.progress,
                    position = Position(work.position),
                })
            end
            sequence = sequence + 1
            SessionSendChatMessage(clients, { Identifier = channel, version = 1, sequence = sequence,
                enabled = enabled, rows = rows })
        end
        sendAt = now + 2
    end

    local function OnShare(sender, packet)
        if not DisplayEnabled() or not options.infoShareAllies:Get() then return end
        if packet.version ~= 1 or not IsNumber(packet.sequence, 1, 1e9)
            or type(packet.enabled) ~= 'table' or type(packet.rows) ~= 'table' or table.getn(packet.rows) > limit then return end
        local army = Ally(sender, ArmyInfo())
        if not army then return end
        local old = remote[army]
        if old and packet.sequence <= old.sequence then return end
        local rows, enabled = {}, {}
        for kind in pairs(categories) do enabled[kind] = packet.enabled[kind] == true end
        for _, input in ipairs(packet.rows) do
            if type(input) == 'table' and IsId(input.key) and phases[input.phase] and enabled[input.kind]
                and WorkName(input.kind, input.blueprint, input.enhancement, Text) then
                rows[input.key] = {
                    key = 'remote:' .. army .. ':' .. input.key, army = army, kind = input.kind,
                    blueprint = input.blueprint, enhancement = input.enhancement,
                    phase = input.phase, progress = IsNumber(input.progress, 0, 100) and math.floor(input.progress) or nil,
                    position = Position(input.position),
                }
            end
        end
        for key, row in pairs(stock) do
            if row.army == army and enabled[row.kind] then stock[key] = nil end
        end
        remote[army] = { sequence = packet.sequence, rows = rows, enabled = enabled, expires = GetSystemTimeSeconds() + timeout }
        renderDirty = true
    end

    local function OnStock(sender, packet)
        if not DisplayEnabled() or not options.infoShareAllies:Get() then return end
        local army = Ally(sender, ArmyInfo())
        local data = packet.data
        if not army or type(data) ~= 'table' then return end
        local overlay = packet.NotifyOverlay == true
        if overlay and data.destroy == true then
            for _, row in pairs(stock) do
                if row.army == army and row.overlayId and row.overlayId == data.id then
                    row.position, row.progress, row.progressAt, row.overlayId = nil, nil, nil, nil
                    renderDirty = true
                end
            end
            return
        end
        if not overlay and packet.notifyFrom ~= army then return end
        local kind = data.category == 'experimentals' and 'experimental' or 'acu'
        local bp = kind == 'experimental' and data.source or commanders[data.category]
        local enhancement = kind == 'acu' and data.source or nil
        if not WorkName(kind, bp, enhancement, Text) then return end

        local snapshot = remote[army]
        if snapshot and snapshot.enabled[kind] then return end
        local key = 'notify:' .. army .. ':' .. data.source
        local now = GetGameTimeSeconds()
        if overlay then
            if kind ~= 'acu' or not IsNumber(data.progress, 0, 100) then return end
            if not stock[key] and stock[key .. ':result'] then return end
            local row = stock[key] or { key = key, army = army, kind = kind, blueprint = bp,
                enhancement = enhancement, phase = 'active', expires = now + 1800 }
            if row.phase ~= 'active' then return end
            row.position = Position(data.pos)
            row.overlayId = data.id
            row.progress = math.floor(data.progress)
            row.progressAt = now
            stock[key] = row
        else
            local phase = triggers[data.trigger]
            if not phase then return end
            if type(packet.Id) == 'string' then
                if seenNotify[packet.Id] then return end
                seenNotify[packet.Id] = GetSystemTimeSeconds() + timeout
            end
            local active = stock[key]
            if phase == 'active' then
                if kind == 'experimental' and active then
                    active.count = active.count + 1
                    active.expires = now + 1800
                elseif not active then
                    stock[key] = { key = key, army = army, kind = kind, blueprint = bp,
                        enhancement = enhancement, phase = 'active', count = 1, expires = now + 1800 }
                end
            else
                if active and (active.count or 1) > 1 then active.count = active.count - 1
                else stock[key] = nil end
                local resultKey = key .. ':result'
                stock[resultKey] = { key = resultKey, army = army, kind = kind, blueprint = bp,
                    enhancement = enhancement, phase = phase, expires = now + lifetime }
            end
        end
        renderDirty = true
    end

    local function Render(armies)
        if not DisplayEnabled() then
            if display then display:Render({}, false, false) end
            return
        end
        if not display then display = import('/mods/ClaretUI/modules/InfoShareDisplay.lua').Create(scope, options) end
        local rows = {}
        local function Add(work)
            local army = armies[work.army]
            if not army or not options['infoShare' .. categories[work.kind]]:Get() then return end
            local name = DisplayName(work)
            if not name then return end
            if work.count and work.count > 1 then name = name .. ' ×' .. work.count end
            local status = Text(work.phase)
            if work.phase == 'active' and work.progress then status = tostring(work.progress) .. '%' end
            table.insert(rows, {
                key = work.key, army = work.army, phase = work.phase,
                player = work.army == own and Text('me') or army.nickname,
                name = name, status = status, position = work.position,
                kind = work.kind, blueprint = work.blueprint, progress = work.progress, enhancement = work.enhancement,
            })
        end
        if GetFocusArmy() == own then
            if options.infoShareOwn:Get() then
                for _, work in pairs(localWork) do Add(work) end
            end
            if options.infoShareAllies:Get() then
                for army, snapshot in pairs(remote) do
                    if armies[army] and IsAlly(own, army) then
                        for _, work in pairs(snapshot.rows) do Add(work) end
                    end
                end
                for _, work in pairs(stock) do
                    local snapshot = remote[work.army]
                    if armies[work.army] and IsAlly(own, work.army)
                        and not (snapshot and snapshot.enabled[work.kind]) then Add(work) end
                end
            end
        end
        table.sort(rows, SortRows)
        display:Render(rows, options.infoShareList:Get(), options.infoShareWorld:Get())
    end

    local function Beat()
        local now = GetSystemTimeSeconds()
        local sample = now >= sampleAt
        if not sample and not renderDirty then return end
        if sample then sampleAt = now + 0.5 end
        local gameTime, armies = GetGameTimeSeconds(), ArmyInfo()
        if sample and OwnDataNeeded() then SampleOwn() end
        for key, work in pairs(localWork) do
            if work.expires and work.expires <= gameTime then
                localWork[key] = nil
                sendAt = 0
            end
        end
        for army, snapshot in pairs(remote) do
            if snapshot.expires <= now then remote[army] = nil end
        end
        for key, work in pairs(stock) do
            if work.expires <= gameTime then
                stock[key] = nil
            elseif work.progressAt and work.progressAt + timeout <= gameTime then
                work.progress, work.position, work.progressAt = nil, nil, nil
            end
        end
        for id, expires in pairs(seenNotify) do
            if expires <= now then seenNotify[id] = nil end
        end
        if GetFocusArmy() == own and now >= sendAt then Publish(armies, now) end
        Render(armies)
        renderDirty = false
    end

    local function StopTracking()
        if not running then return end
        running = false
        Game.RemoveBeatFunction(Beat)
        Game.ObserveSelection:AddObserver(nil, channel)
        RemoveOnSyncHashedCallback('UnitData', channel)
        RemoveOnSyncHashedCallback('EnhanceMessage', channel)
        localWork, pending, construction, upgrades, builders = {}, {}, {}, {}, {}
        experimentalSamples = 0
        remote, stock, seenNotify = {}, {}, {}
    end

    local function Refresh()
        sampleAt, sendAt, renderDirty = 0, 0, true
        if GetFocusArmy() ~= own then
            StopTracking()
            Render(ArmyInfo())
            return
        end
        if not running then
            running = true
            Game.AddBeatFunction(Beat, true)
            Game.ObserveSelection:AddObserver(OnSelection, channel)
            AddOnSyncHashedCallback(OnUnitData, 'UnitData', channel)
            AddOnSyncHashedCallback(OnEnhancements, 'EnhanceMessage', channel)
        end
        OnUnitData(UnitData)
        OnSelection({ newSelection = GetSelectedUnits() })
        Beat()
    end

    local function OnStockMessages(messages)
        if not DisplayEnabled() or not options.infoShareAllies:Get() then return end
        local armies = ArmyInfo()
        for _, message in ipairs(messages) do
            if type(message) == 'table' and message.to == 'notify' and message.From then
                local army = armies[message.From]
                if army then OnStock(army.nickname, message) end
            end
        end
    end

    stockListener = OnStock
    AddOnSyncHashedCallback(OnStockMessages, 'ChatMessages', channel)
    Game.RegisterChatFunc(OnShare, channel)
    AddOnSyncHashedCallback(Refresh, 'FocusArmyChanged', channel)
    scope:Defer(function()
        stockListener = nil
        RemoveOnSyncHashedCallback('ChatMessages', channel)
        Game.RegisterChatFunc(nil, channel)
        RemoveOnSyncHashedCallback('FocusArmyChanged', channel)
        StopTracking()
    end)
    for _, key in ipairs({ 'List', 'World', 'Own', 'Allies', 'Smd', 'Experimental', 'Acu' }) do
        scope:Bind(options['infoShare' .. key].OnChanged, Refresh)
    end
    Refresh()
end
