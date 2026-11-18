-- Adapter protocol tests with command capture, not a simulation or FAF API test.
table.getn = table.getn or function(t) return #t end
local selected, focus, commands, modes = {}, 1, {}, {}
local refreshes, cleared = 0, 0
local selectionChanges, ignoreChanges, transaction = {}, {}, {}
local caches, restores, ignoreSelection = 0, 0, false
local issueThrows = false
local commandDataReads = 0
local module = setmetatable({}, { __index = _G })
module.GetSelectedUnits = function() return selected end
module.GetFocusArmy = function() return focus end
module.GetUnitCommandData = function(units)
    commandDataReads = commandDataReads + 1
    local buildable = {}
    local orderSet = {}
    local orders = {}
    for _, unit in ipairs(units) do
        for _, id in ipairs(unit.buildable or {}) do table.insert(buildable, id) end
        for _, order in ipairs(unit.orders or {}) do
            if not orderSet[order] then orderSet[order] = true; table.insert(orders, order) end
        end
    end
    return orders, {}, buildable
end
module.EntityCategoryGetUnitList = function(category) return category end
module.SelectUnits = function(units)
    table.insert(transaction, 'select')
    table.insert(selectionChanges, units)
    selected = units
end
module.IssueBlueprintCommand = function(kind, id, count)
    table.insert(transaction, 'issue')
    if issueThrows then error('command fault') end
    table.insert(commands, { units = selected, kind = kind, id = id, count = count })
end
module.ClearBuildTemplates = function() cleared = cleared + 1 end
module.import = function(path)
    if path == '/lua/ui/game/construction.lua' then
        return { RefreshUI = function() refreshes = refreshes + 1 end }
    end
    if path == '/lua/ui/game/commandmode.lua' then
        return {
            StartCommandMode = function(kind, data) table.insert(modes, {kind=kind,name=data.name}) end,
            CacheAndClearCommandMode = function() caches = caches + 1; table.insert(transaction, 'cache') end,
            RestoreCommandMode = function(force)
                assert(force == true)
                restores = restores + 1
                table.insert(transaction, 'restoreMode')
            end,
        }
    end
    if path == '/lua/ui/game/gamemain.lua' then
        return { SetIgnoreSelection = function(value)
            ignoreSelection = value
            table.insert(ignoreChanges, value)
            table.insert(transaction, value and 'ignoreOn' or 'ignoreOff')
        end }
    end
    error('Unexpected import: ' .. path)
end
assert(loadfile('../mods/ClaretHotbuild/modules/Adapter.lua', 't', module))()
local known = { uea0101 = true, ueb1103 = true }
local catalog = { Get = function(self, id) return known[id] and {id=id} or nil end }
local adapter = module.Create(catalog)
local function unit(categories, buildable, orders, creator, dead)
    return {
        buildable = buildable or {}, orders = orders or {},
        IsDead = function() return dead or false end,
        IsInCategory = function(self, category) return categories[category] or false end,
        GetCreator = function() return creator end,
    }
end

local factory = unit({FACTORY=true}, {'uea0101'}, {'RULEUCC_Move'})
local incapable = unit({FACTORY=true}, {'different'})
local dead = unit({FACTORY=true}, {'uea0101'}, nil, nil, true)
selected = {factory, incapable, dead}
local originalSelection = selected
local context = adapter:Context(false)
assert(#context.selection == 2 and context.orders.RULEUCC_Move)
assert(adapter:CanBuild('uea0101', context))
local readsAfterFirstCandidate = commandDataReads
assert(not adapter:CanBuild('ueb1103', context))
assert(commandDataReads == readsAfterFirstCandidate, 'priority entries must share capability reads within one press')
assert(adapter:Build('uea0101', context))
assert(#commands == 1 and #commands[1].units == 1 and commands[1].units[1] == factory)
assert(commands[1].kind == 'UNITCOMMAND_BuildFactory' and commands[1].id == 'uea0101' and commands[1].count == 1)
assert(refreshes == 1 and #modes == 0 and cleared == 0)
assert(selected == originalSelection and not ignoreSelection)
assert(caches == 1 and restores == 1 and #selectionChanges == 2)
assert(ignoreChanges[1] == true and ignoreChanges[2] == false)
assert(table.concat(transaction, ',') == 'cache,ignoreOn,select,issue,select,ignoreOff,restoreMode')
-- Every explicit press places exactly one concrete blueprint in each capable factory queue.
adapter:Build('uea0101', adapter:Context(false))
assert(#commands == 2 and commands[2].count == 1)
assert(not adapter:CanBuild('unknown', adapter:Context(false)))
assert(not adapter:Build('ueb1103', adapter:Context(false)))
assert(#commands == 2)

-- A complete capable factory selection uses the ordinary command without touching selection.
selected = {factory}
originalSelection = selected
local oldChanges, oldCaches, oldRestores, oldIgnores = #selectionChanges, caches, restores, #ignoreChanges
assert(adapter:Build('uea0101', adapter:Context(false)))
assert(#commands == 3 and commands[3].units == originalSelection and commands[3].count == 1)
assert(selected == originalSelection and #selectionChanges == oldChanges)
assert(caches == oldCaches and restores == oldRestores and #ignoreChanges == oldIgnores)

local engineer = unit({ENGINEER=true}, {'ueb1103'}, {'RULEUCC_Reclaim','RULEUCC_Guard','RULEUCC_Move'})
selected = {engineer}
assert(adapter:Build('ueb1103', adapter:Context(false)))
assert(cleared == 1 and #modes == 1 and modes[1].kind == 'build' and modes[1].name == 'ueb1103')
assert(#commands == 3, 'placement must not emit a factory queue command')

local creator = unit({FACTORY=true}, {'uea0101'})
local attachedA = unit({EXTERNALFACTORY=true}, {'uea0101'}, nil, creator)
local attachedB = unit({EXTERNALFACTORY=true}, {'uea0101'}, nil, creator)
selected = {attachedA, attachedB, creator}
originalSelection = selected
assert(adapter:Build('uea0101', adapter:Context(false)))
assert(#commands == 4 and #commands[4].units == 1 and commands[4].units[1] == creator)
assert(selected == originalSelection and not ignoreSelection)

-- Every restoration step must run even if issuing the subset command fails.
selected = {factory, incapable}
originalSelection = selected
oldRestores = restores
transaction = {}
issueThrows = true
local ok, err = pcall(adapter.Build, adapter, 'uea0101', adapter:Context(false))
issueThrows = false
assert(not ok and string.find(tostring(err), 'command fault'))
assert(selected == originalSelection and ignoreSelection == false and restores == oldRestores + 1)
assert(table.concat(transaction, ',') == 'cache,ignoreOn,select,issue,select,ignoreOff,restoreMode')
assert(#commands == 4)

selected = {factory}
assert(not adapter:Build('uea0101', adapter:Context(true)))
focus = -1
assert(not adapter:Build('uea0101', adapter:Context(false)))
focus = 1
selected = {}
assert(not adapter:Build('uea0101', adapter:Context(false)))
assert(#commands == 4, 'replay/observer/empty selection must emit no orders')

local registered = {}
module.RegisterActions({RegisterAction=function(self, definition) registered[definition.id] = definition; return true end})
selected = {engineer}
context = adapter:Context(false)
assert(registered['claret.order.reclaim'].available(context))
assert(registered['claret.order.assist'].available(context))
assert(registered['claret.order.move'].available(context))
assert(registered['claret.order.reclaim'].execute(context))
assert(modes[2].kind == 'order' and modes[2].name == 'RULEUCC_Reclaim')
selected = {factory}
assert(not registered['claret.order.reclaim'].available(adapter:Context(false)))
assert(registered['claret.order.move'].available(adapter:Context(false)))
assert(not registered['claret.order.move'].available(adapter:Context(true)))
focus = 0
assert(not registered['claret.order.move'].available(adapter:Context(false)))
print('PASS: Hotbuild adapter exact blueprint/count1, direct selection preservation, subset/external transactions, exception restoration, placement, replay guards, contextual actions')
