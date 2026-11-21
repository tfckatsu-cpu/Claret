local Game = import('/lua/ui/game/gamemain.lua')
local protocol = {
    channel = 'ClaretUI.InfoShare',
    legacyChannel = 'TIS',
    timeout = 12,
    maxRows = 64,
    maxEta = 36000,
    sequence = 0,
}
local categories = { smd = 'Smd', experimental = 'Experimental', acu = 'Acu', silo = 'Silo' }
local phases = { active = true, done = true, cancelled = true, interrupted = true }
local triggers = { started = 'active', completed = 'done', cancelled = 'cancelled' }
local commanders = { uef = 'uel0001', aeon = 'ual0001', cybran = 'url0001', seraphim = 'xsl0001' }
local lifetime = 1.5
local constructionIdleTime = 10
local listeners = {}

-- Called only for the two stock Notify payloads by the game UI hook.
function ReceiveNotify(sender, message)
    if listeners.stock and type(message) == 'table' then return listeners.stock(sender, message) end
end

-- With both mods active, the hook observes packets without replacing TIS's handler.
function ReceiveTis(sender, packet)
    if listeners.tis then listeners.tis(sender, packet) end
end

local function HasLocalTis()
    for _, mod in pairs(rawget(_G, '__active_mods') or {}) do
        if mod.uid == 'teaminfo-share-v11' then return true end
    end
    return false
end

local function SendTis(clients, data)
    SessionSendChatMessage(clients, { to = 'allies', TIS = true, text = data })
end

local function IsNumber(value, minimum, maximum)
    return type(value) == 'number' and value == value and value >= minimum and value <= maximum
end

local function Position(value, allowStrings)
    if type(value) ~= 'table' then return nil end
    local result = {}
    for index = 1, 3 do
        local coordinate = value[index]
        if allowStrings and type(coordinate) == 'string' then coordinate = tonumber(coordinate) end
        if not IsNumber(coordinate, -65536, 65536) then return nil end
        result[index] = coordinate
    end
    return result
end

local function TisId(value)
    if type(value) == 'string' and string.len(value) <= 64 and string.match(value, '^[%w_:%-.]+$') then return value end
    if IsNumber(value, 1, 9007199254740991) and value == math.floor(value) then return string.format('%.0f', value) end
end

local function TisFlag(value)
    return value == true or value == 'true' or value == 1 or value == '1'
end

local function SamePosition(first, second)
    return first and second and math.abs(first[1] - second[1]) <= 1 and math.abs(first[3] - second[3]) <= 1
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

local function MissileSilo(bp)
    local hash = bp and bp.CategoriesHash
    return hash and hash.STRUCTURE and hash.SILO and not hash.NAVAL
        and (hash.NUKE or hash.TECH3 and hash.ANTIMISSILE)
end

local function WorkName(kind, blueprint, enhancement, Text)
    if not IsId(blueprint) then return nil end
    local bp = __blueprints[blueprint]
    if kind == 'acu' then
        local item = bp and bp.CategoriesHash and bp.CategoriesHash.COMMAND
            and IsId(enhancement) and not string.find(enhancement, 'Remove', 1, true)
            and bp.Enhancements and bp.Enhancements[enhancement]
        if item then return LOC(item.Name or enhancement) end
    elseif kind == 'silo' and MissileSilo(bp) or BlueprintKind(bp) == kind then
        local general = bp.General or {}
        return LOC(general.UnitName or bp.Description or Text(kind))
    end
end

local function Percent(fraction)
    if IsNumber(fraction, 0, 1) then return math.floor(fraction * 100) end
end

local function IsConstruction(kind)
    return kind == 'experimental' or kind == 'smd'
end

local function Remaining(deadline, now)
    if deadline and deadline > now then return math.ceil(deadline - now) end
end

local function UpdateConstructionEta(work, fraction, now)
    local lastTime, lastFraction = work.sampledAt, work.fraction
    if lastTime and now <= lastTime then return end
    work.sampledAt, work.fraction = now, fraction
    if fraction and not work.progressSince then work.progressSince = now end
    local gain = fraction and lastFraction and fraction - lastFraction
    if gain and gain > 0 then
        local instant = gain / (now - lastTime)
        work.rate = work.rate and (0.75 * work.rate + 0.25 * instant) or instant
        work.advancedAt = now
        local eta = (1 - fraction) / work.rate
        work.deadline = eta <= protocol.maxEta and now + eta or nil
    elseif not gain or gain < 0 or work.advancedAt and now - work.advancedAt >= 2 then
        work.rate, work.deadline = nil, nil
    end
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

local function SortListRows(a, b)
    if a.phase == 'active' and b.phase == 'active' then
        local first, second = a.progress or -1, b.progress or -1
        if first ~= second then return first > second end
    end
    return SortRows(a, b)
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
    local tis, advertised = {}, {}
    local tisDiagnostics = {}
    local localTis = HasLocalTis()
    local tisSentAt, tisRecipients

    local function Text(key)
        return localization.Text('claretui.infoshare.' .. key)
    end

    local function DisplayName(work)
        if work.kind == 'experimental' and not work.blueprint then return Text('experimental') end
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
        work.deadline = nil
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

    local construction, upgrades, builders, production = {}, {}, {}, {}
    local experimentalSamples = 0

    local function Discover(unit)
        if not Owned(unit, own) then return end
        local id = unit:GetEntityId()
        if construction[id] then return true end
        local bp = unit:GetBlueprint()
        if not bp then return false end
        local hash = bp.CategoriesHash
        if hash and (hash.ENGINEER or hash.FACTORY or hash.COMMAND) then builders[id] = unit end
        if MissileSilo(bp) and not production[id] then
            production[id] = { unit = unit, blueprint = bp.BlueprintId }
        end
        local kind = BlueprintKind(bp)
        if kind then
            local progress = unit:GetFractionComplete()
            if IsNumber(progress, 0, 1) and progress < 1 then
                local work = NewWork(id, kind, bp.BlueprintId)
                work.unit = unit
                construction[id] = work
                return true
            end
            return production[id] ~= nil
        end
        return true
    end

    local function OnUnitData(data)
        if not OwnDataNeeded() or type(data) ~= 'table' then return end
        for key, value in pairs(data) do
            local id = tonumber(key)
            if value and id and not construction[id] and not production[id] and not pending[id] then pending[id] = 6 end
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

    local function SampleOwn(gameTime)
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
                local fraction = unit:GetFractionComplete()
                local progress = Percent(fraction)
                work.progress = progress
                UpdateConstructionEta(work, progress and fraction or nil, gameTime)
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
        for id, silo in pairs(production) do
            local unit, work = silo.unit, silo.work
            if not Owned(unit, own) then
                if work then
                    work.phase = 'interrupted'
                    localWork[work.key] = nil
                    sendAt = 0
                end
                production[id] = nil
            elseif work or unit:GetFractionComplete() == 1 then
                local missiles = unit:GetMissileInfo()
                local stock = missiles and (missiles.nukeSiloStorageCount or 0) + (missiles.tacticalSiloStorageCount or 0)
                local fraction = unit:GetWorkProgress()
                local progress = Percent(fraction)
                if progress and IsNumber(stock, 0, 10000) then
                    if not work then
                        work = NewWork(id, 'silo', silo.blueprint)
                        silo.work = work
                    end
                    if work.stock and stock > work.stock then
                        work.fraction, work.rate, work.deadline = nil, nil, nil
                    end
                    work.progress, work.stock = progress, stock
                    work.position = unit:GetPosition()
                    UpdateConstructionEta(work, fraction, gameTime)
                end
            end
        end
    end

    local function Publish(armies, now, gameTime)
        local enabled, rows, ordered = {}, {}, {}
        for kind in pairs(categories) do enabled[kind] = true end
        local clients = Recipients(armies, own)
        if table.getn(clients) > 0 then
            for _, work in pairs(localWork) do
                if enabled[work.kind] then table.insert(ordered, work) end
            end
            table.sort(ordered, SortRows)
            for index = 1, math.min(protocol.maxRows, table.getn(ordered)) do
                local work = ordered[index]
                table.insert(rows, {
                    key = work.key, kind = work.kind, blueprint = work.blueprint, enhancement = work.enhancement,
                    phase = work.phase, progress = work.progress,
                    position = Position(work.position),
                    eta = Remaining(work.deadline, gameTime),
                    fraction = IsConstruction(work.kind) and work.fraction or nil,
                    stock = work.stock,
                })
            end
            protocol.sequence = protocol.sequence + 1
            SessionSendChatMessage(clients, { Identifier = protocol.channel, version = 1, sequence = protocol.sequence,
                enabled = enabled, rows = rows })
        end
        sendAt = now + 2
    end

    local function PublishTis(armies, tick)
        if not next(advertised) and not next(production) then
            local hasExperimental = false
            for _, work in pairs(construction) do
                if work.kind == 'experimental' and work.fraction then
                    hasExperimental = true
                    break
                end
            end
            if not hasExperimental then return end
        end
        local clients = Recipients(armies, own)
        table.sort(clients)
        local recipients = table.concat(clients, ',')
        -- TIS drops overlays after ten simulation ticks without an update.
        local reset = recipients ~= tisRecipients or tisSentAt and tick > tisSentAt + 10
        for id, work in pairs(advertised) do
            if reset or work.phase ~= 'active' then
                if recipients ~= '' then
                    if work.phase == 'done' and not reset then
                        SendTis(clients, { exp = true, id = id, is_done = true, progress = 1, eta = -1 })
                    end
                    SendTis(clients, { exp = work.kind == 'experimental' or nil,
                        nuke = work.kind == 'silo' or nil, id = id, remove = true })
                end
                advertised[id] = nil
            end
        end
        tisSentAt, tisRecipients = tick, recipients
        if recipients == '' then return end
        local gameTime = GetGameTimeSeconds()
        local function Update(work)
            if not work or not work.fraction then return end
            local id = work.id
            local experimental = work.kind == 'experimental' or nil
            local silo = work.kind == 'silo' or nil
            if not advertised[id] then
                local position = Position(work.position)
                if position then
                    SendTis(clients, { exp = experimental, nuke = silo, id = id, init = true,
                        pos = position, blueprint = experimental and work.blueprint or nil })
                    advertised[id] = work
                end
            end
            if advertised[id] then
                SendTis(clients, { exp = experimental, nuke = silo, id = id,
                    progress = work.fraction, eta = Remaining(work.deadline, gameTime) or -1, silo = work.stock })
            end
        end
        for _, work in pairs(construction) do
            if work.kind == 'experimental' then Update(work) end
        end
        for _, silo in pairs(production) do Update(silo.work) end
    end

    local function OnShare(sender, packet)
        if not DisplayEnabled() or not options.infoShareAllies:Get() then return end
        if packet.version ~= 1 or not IsNumber(packet.sequence, 1, 1e9)
            or type(packet.enabled) ~= 'table' or type(packet.rows) ~= 'table'
            or table.getn(packet.rows) > protocol.maxRows then return end
        local army = Ally(sender, ArmyInfo())
        if not army then return end
        local old = remote[army]
        if old and packet.sequence <= old.sequence then return end
        local rows, enabled = {}, {}
        local gameTime = GetGameTimeSeconds()
        for kind in pairs(categories) do enabled[kind] = packet.enabled[kind] == true end
        for _, input in ipairs(packet.rows) do
            if type(input) == 'table' and IsId(input.key) and phases[input.phase] and enabled[input.kind]
                and WorkName(input.kind, input.blueprint, input.enhancement, Text) then
                local work = {
                    key = 'remote:' .. army .. ':' .. input.key, army = army, kind = input.kind,
                    blueprint = input.blueprint, enhancement = input.enhancement,
                    phase = input.phase, progress = IsNumber(input.progress, 0, 100) and math.floor(input.progress) or nil,
                    position = Position(input.position),
                    deadline = input.phase == 'active' and input.kind ~= 'acu'
                        and IsNumber(input.eta, 1, protocol.maxEta) and gameTime + input.eta or nil,
                    stock = input.kind == 'silo' and IsNumber(input.stock, 0, 10000) and math.floor(input.stock) or nil,
                }
                if work.phase == 'active' and IsConstruction(work.kind) then
                    local previous = old and old.rows[input.key]
                    local fraction = IsNumber(input.fraction, 0, 1) and input.fraction
                        or work.progress and work.progress / 100
                    if previous and previous.phase == 'active' and previous.kind == work.kind
                        and previous.blueprint == work.blueprint then
                        work.fraction = previous.fraction
                        work.progressSince = previous.progressSince
                        work.advancedAt = previous.advancedAt
                    end
                    if fraction then
                        work.progressSince = work.progressSince or gameTime
                        if work.fraction and fraction > work.fraction then work.advancedAt = gameTime end
                        work.fraction = fraction
                    end
                end
                rows[input.key] = work
            end
        end
        for key, row in pairs(stock) do
            if row.army == army and enabled[row.kind] then stock[key] = nil end
        end
        remote[army] = { sequence = packet.sequence, rows = rows, enabled = enabled,
            expires = GetSystemTimeSeconds() + protocol.timeout }
        renderDirty = true
    end

    local function LogTisOnce(message)
        if tisDiagnostics[message] then return end
        tisDiagnostics[message] = true
        LOG('[ClaretUI][InfoShare] TIS ' .. message)
    end

    local function IdentifyTisExperimental(row, id, blueprint)
        if row.blueprint or row.kind ~= 'experimental' then return end
        if IsId(blueprint) and BlueprintKind(__blueprints[blueprint]) == 'experimental' then
            row.blueprint = blueprint
            return
        end
        local entityId = tonumber(id)
        if not IsNumber(entityId, 1, 9007199254740991) or entityId ~= math.floor(entityId) then return end
        local unit = GetUnitById(entityId)
        if Owned(unit, row.army) and SamePosition(unit:GetPosition(), row.position) then
            local bp = unit:GetBlueprint()
            if BlueprintKind(bp) == 'experimental' and IsId(bp.BlueprintId) then row.blueprint = bp.BlueprintId end
        end
    end

    local function OnTis(sender, data)
        if type(data) ~= 'table' then
            LogTisOnce('ignored: payload type=' .. type(data))
            return
        end
        local id = TisId(data.id)
        if not id then
            LogTisOnce('ignored: invalid entity ID; type=' .. type(data.id))
            return
        end
        local kind
        local experimental, silo = TisFlag(data.exp), TisFlag(data.nuke)
        if experimental and not silo then
            kind = 'experimental'
        elseif not localTis and silo and not experimental then
            kind = 'silo'
        else
            LogTisOnce('ignored: unsupported work flags; exp=' .. type(data.exp) .. '; nuke=' .. type(data.nuke))
            return
        end
        local army = Ally(sender, ArmyInfo())
        if not army then
            LogTisOnce('ignored: sender did not match an active allied army; sender type=' .. type(sender)
                .. '; own focus=' .. tostring(OwnDataNeeded()))
            return
        end
        local rows = tis[army]
        local row = rows and rows[id]
        if row and row.kind ~= kind then return end
        local gameTime = GetGameTimeSeconds()
        if TisFlag(data.remove) or TisFlag(data.is_done) then
            if not row then return end
            rows[id] = nil
        elseif TisFlag(data.init) then
            local position = Position(data.pos, true)
            if not position then
                LogTisOnce('ignored: invalid position for ' .. kind .. '; position type=' .. type(data.pos))
                return
            end
            if not rows then
                rows = {}
                tis[army] = rows
            elseif not row then
                local count = 0
                for _ in pairs(rows) do count = count + 1 end
                if count >= protocol.maxRows then return end
            end
            row = row or { key = 'tis:' .. army .. ':' .. id, army = army,
                kind = kind, phase = 'active', startedAt = gameTime }
            row.position, row.expires = position, gameTime + protocol.timeout
            IdentifyTisExperimental(row, id, data.blueprint)
            rows[id] = row
            LogTisOnce('position received: ' .. kind)
        else
            local fraction = tonumber(data.progress)
            local eta = tonumber(data.eta)
            local progress = Percent(fraction)
            if not progress then
                LogTisOnce('ignored: invalid progress for ' .. kind .. '; progress type=' .. type(data.progress))
                return
            end
            if not row then
                LogTisOnce('progress arrived before position: ' .. kind)
                return
            end
            LogTisOnce('progress received: ' .. kind
                .. '; sender ETA=' .. tostring(IsNumber(eta, 0.001, protocol.maxEta)))
            local previousFraction = row.fraction
            if not previousFraction then IdentifyTisExperimental(row, id) end
            UpdateConstructionEta(row, fraction, gameTime)
            row.progress, row.expires = progress, gameTime + protocol.timeout
            if IsNumber(eta, 0.001, protocol.maxEta) then
                row.sharedDeadline = gameTime + eta
                row.sharedAt = gameTime
            elseif not row.sharedAt or gameTime - row.sharedAt >= 2
                or previousFraction and fraction < previousFraction then
                row.sharedDeadline = nil
            end
            local count = tonumber(data.silo)
            if kind == 'silo' and IsNumber(count, 0, 10000) then row.stock = math.floor(count) end
        end
        renderDirty = true
    end

    local function OnTisMessage(sender, packet)
        if type(packet) ~= 'table' or packet.to ~= 'allies' then return end
        LogTisOnce('chat packet received')
        OnTis(sender, packet.text)
    end

    local function OnStock(sender, packet)
        local data = packet.data
        if not DisplayEnabled() or type(data) ~= 'table' then return end
        local overlay = packet.NotifyOverlay == true
        local position = overlay and Position(data.pos)
        local replaceOverlay = position and not data.destroy and options.infoShareWorld:Get() and options.infoShareAcu:Get()
        local armies = ArmyInfo()
        if replaceOverlay and options.infoShareOwn:Get() and OwnDataNeeded()
            and armies[own] and sender == armies[own].nickname then
            local work = upgrades[data.id]
            return work and work.enhancement == data.source and work.position ~= nil
        end
        if not options.infoShareAllies:Get() then return end
        local army = Ally(sender, armies)
        if not army then return end
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
        if snapshot and snapshot.enabled[kind] then
            if replaceOverlay and kind == 'acu' and snapshot.expires > GetSystemTimeSeconds() then
                for _, work in pairs(snapshot.rows) do
                    if work.kind == kind and work.blueprint == bp and work.enhancement == enhancement
                        and work.phase == 'active' and SamePosition(work.position, position) then return true end
                end
            end
            return
        end
        local key = 'notify:' .. army .. ':' .. data.source
        local now = GetGameTimeSeconds()
        if overlay then
            if kind ~= 'acu' or not IsNumber(data.progress, 0, 100) then return end
            if not stock[key] and stock[key .. ':result'] then return end
            local row = stock[key] or { key = key, army = army, kind = kind, blueprint = bp,
                enhancement = enhancement, phase = 'active', expires = now + 1800 }
            if row.phase ~= 'active' then return end
            row.position = position
            row.overlayId = data.id
            row.progress = math.floor(data.progress)
            row.progressAt = now
            stock[key] = row
            renderDirty = true
            return replaceOverlay
        else
            local phase = triggers[data.trigger]
            if not phase then return end
            if type(packet.Id) == 'string' then
                if seenNotify[packet.Id] then return end
                seenNotify[packet.Id] = GetSystemTimeSeconds() + protocol.timeout
            end
            local active = stock[key]
            if phase == 'active' then
                if kind == 'experimental' and active then
                    active.count = active.count + 1
                    active.expires = now + 1800
                elseif not active then
                    stock[key] = { key = key, army = army, kind = kind, blueprint = bp,
                        enhancement = enhancement, phase = 'active', count = 1, startedAt = now, expires = now + 1800 }
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
        local rows, listRows, silos, legacyExperimentals = {}, {}, {}, {}
        local gameTime = GetGameTimeSeconds()
        local showWorld = options.infoShareWorld:Get()
        local showList = options.infoShareList:Get()
        local function HasSiloLabel(snapshot, position)
            if not snapshot then return false end
            for _, work in pairs(snapshot.rows) do
                local visible = work.kind == 'silo' or work.kind == 'smd' and options.infoShareSmd:Get()
                if visible and SamePosition(work.position, position) then return true end
            end
            return false
        end
        local function Add(work, matchedBlueprint, approximate)
            local army = armies[work.army]
            local silo = work.kind == 'silo'
            if not army or silo and not showWorld
                or not silo and not options['infoShare' .. categories[work.kind]]:Get() then return end
            local blueprint = work.blueprint or matchedBlueprint
            local name = matchedBlueprint and WorkName(work.kind, matchedBlueprint, nil, Text)
                or silo and not blueprint and Text('silo') or DisplayName(work)
            if not name then return end
            if work.count and work.count > 1 then name = name .. ' ×' .. work.count end
            local status = Text(work.phase)
            if work.phase == 'active' and work.progress then
                status = (approximate and '~' or '') .. tostring(work.progress) .. '%'
            end
            local row = {
                key = work.key, army = work.army, phase = work.phase,
                player = work.army == own and Text('me') or army.nickname,
                name = name, status = status, position = work.position,
                kind = work.kind, blueprint = blueprint, progress = work.progress, enhancement = work.enhancement,
                eta = work.phase == 'active' and (Remaining(work.sharedDeadline, gameTime)
                    or Remaining(work.deadline, gameTime)) or nil,
                stock = work.stock,
            }
            table.insert(silo and silos or rows, row)
            if showList and not silo then
                local lastIncrease = work.advancedAt or work.progressSince
                local stalled = work.phase == 'active' and IsConstruction(work.kind)
                    and lastIncrease and gameTime - lastIncrease >= constructionIdleTime
                if not stalled then table.insert(listRows, row) end
            end
        end
        local function NotifyBlueprint(army, works)
            local experimental
            for _, work in pairs(works) do
                if work.kind == 'experimental' then
                    if experimental then return end
                    experimental = work
                end
            end
            if not experimental or experimental.blueprint then return end
            local match
            for _, work in pairs(stock) do
                if work.army == army and work.kind == 'experimental' and work.phase == 'active' then
                    if match or work.count ~= 1 then return end
                    match = work
                end
            end
            if match and math.abs(match.startedAt - experimental.startedAt) <= 5 then return match.blueprint end
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
                for army, works in pairs(tis) do
                    local snapshot = remote[army]
                    if armies[army] and not armies[army].outOfGame and IsAlly(own, army) then
                        local experimentalFallback = not (snapshot and snapshot.enabled.experimental)
                            and NotifyBlueprint(army, works) or nil
                        for _, work in pairs(works) do
                            if work.kind == 'silo' then
                                if showWorld and not HasSiloLabel(snapshot, work.position) then Add(work) end
                            elseif not (snapshot and snapshot.enabled.experimental) then
                                legacyExperimentals[army] = true
                                Add(work, experimentalFallback, true)
                            end
                        end
                    end
                end
                for _, work in pairs(stock) do
                    local snapshot = remote[work.army]
                    local duplicate = work.kind == 'experimental' and work.phase == 'active' and legacyExperimentals[work.army]
                    if armies[work.army] and IsAlly(own, work.army)
                        and not duplicate and not (snapshot and snapshot.enabled[work.kind]) then Add(work) end
                end
            end
        end
        table.sort(rows, SortRows)
        table.sort(listRows, SortListRows)
        display:Render(rows, showList, showWorld, silos, listRows)
    end

    local function Beat()
        local now = GetSystemTimeSeconds()
        local sample = now >= sampleAt
        local tick = not localTis and (sample or next(advertised)) and GameTick()
        local publishTis = tick and (not tisSentAt or tick >= tisSentAt + 5)
        if not sample and not renderDirty then
            if publishTis then PublishTis(ArmyInfo(), tick) end
            return
        end
        if sample then sampleAt = now + 0.5 end
        local gameTime, armies = GetGameTimeSeconds(), ArmyInfo()
        if sample and OwnDataNeeded() then SampleOwn(gameTime) end
        for key, work in pairs(localWork) do
            if work.expires and work.expires <= gameTime then
                localWork[key] = nil
                sendAt = 0
            end
        end
        for army, snapshot in pairs(remote) do
            if snapshot.expires <= now then remote[army] = nil end
        end
        for _, works in pairs(tis) do
            for id, work in pairs(works) do
                if work.expires <= gameTime then works[id] = nil end
            end
        end
        for key, work in pairs(stock) do
            if work.expires <= gameTime then
                stock[key] = nil
            elseif work.progressAt and work.progressAt + protocol.timeout <= gameTime then
                work.progress, work.position, work.progressAt = nil, nil, nil
            end
        end
        for id, expires in pairs(seenNotify) do
            if expires <= now then seenNotify[id] = nil end
        end
        if GetFocusArmy() == own and now >= sendAt then Publish(armies, now, gameTime) end
        if publishTis and (next(advertised) or next(construction) or next(production)) then PublishTis(armies, tick) end
        Render(armies)
        renderDirty = false
    end

    local function StopTracking()
        if not running then return end
        running = false
        Game.RemoveBeatFunction(Beat)
        Game.ObserveSelection:AddObserver(nil, protocol.channel)
        RemoveOnSyncHashedCallback('UnitData', protocol.channel)
        RemoveOnSyncHashedCallback('EnhanceMessage', protocol.channel)
        if next(advertised) then
            local clients = Recipients(ArmyInfo(), own)
            if table.getn(clients) > 0 then
                for id, work in pairs(advertised) do
                    SendTis(clients, { exp = work.kind == 'experimental' or nil,
                        nuke = work.kind == 'silo' or nil, id = id, remove = true })
                end
            end
        end
        tis, advertised, tisSentAt, tisRecipients = {}, {}, nil, nil
        localWork, pending, construction, upgrades, builders, production = {}, {}, {}, {}, {}, {}
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
            Game.ObserveSelection:AddObserver(OnSelection, protocol.channel)
            AddOnSyncHashedCallback(OnUnitData, 'UnitData', protocol.channel)
            AddOnSyncHashedCallback(OnEnhancements, 'EnhanceMessage', protocol.channel)
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

    listeners.stock = OnStock
    if localTis then
        listeners.tis = OnTisMessage
    else
        Game.RegisterChatFunc(OnTisMessage, protocol.legacyChannel)
    end
    AddOnSyncHashedCallback(OnStockMessages, 'ChatMessages', protocol.channel)
    Game.RegisterChatFunc(OnShare, protocol.channel)
    AddOnSyncHashedCallback(Refresh, 'FocusArmyChanged', protocol.channel)
    scope:Defer(function()
        listeners.stock = nil
        listeners.tis = nil
        RemoveOnSyncHashedCallback('ChatMessages', protocol.channel)
        Game.RegisterChatFunc(nil, protocol.channel)
        if not localTis then Game.RegisterChatFunc(nil, protocol.legacyChannel) end
        RemoveOnSyncHashedCallback('FocusArmyChanged', protocol.channel)
        StopTracking()
    end)
    for _, key in ipairs({ 'List', 'World', 'Own', 'Allies', 'Smd', 'Experimental', 'Acu' }) do
        scope:Bind(options['infoShare' .. key].OnChanged, Refresh)
    end
    Refresh()
end
