-- Isolated tests for ContextUpgrade with mocked FAF UI APIs.
table.getn = function(value) return #value end
local selected = {}
local allUnits = {}
local rollover
local failIssue = false
local issued = {}
local nativeUpgrades = {}
local ignoreSelection = false
local command = { mode = 'build', data = { name = 'ueb1101' } }
local cached

local function unit(id, army, categories, upgrade, position)
    local value = { id = id, army = army, categories = categories, position = position or {0,0,0}, dead = false }
    function value:IsDead() return self.dead end
    function value:GetArmy() return self.army end
    function value:IsInCategory(category) return self.categories[category] == true end
    function value:GetBlueprint() return { BlueprintId = self.id, General = { UpgradesTo = upgrade } } end
    function value:GetPosition() return self.position end
    function value:GetFocus() return self.focus end
    return value
end

local target = unit('ueb1101', 1, { STRUCTURE=true }, 'ueb1201', {5,0,5})
local enemy = unit('ueb1102', 2, { STRUCTURE=true }, 'ueb1201', {5,0,5})
local mexA = unit('ueb1103', 1, { STRUCTURE=true, MASSEXTRACTION=true }, 'ueb1203', {10,0,10})
local mexB = unit('ueb1104', 1, { STRUCTURE=true, MASSEXTRACTION=true }, 'ueb1204', {30,0,10})
local mexC = unit('ueb1105', 1, { STRUCTURE=true, MASSEXTRACTION=true }, nil, {11,0,10})
local function focusedOn(id) return {GetBlueprint=function() return {BlueprintId=id} end} end
allUnits = {target, enemy, mexA, mexB, mexC}

function GetFocusArmy() return 1 end
function GetSelectedUnits() return selected end
function SelectUnits(units) selected = units end
function GetMouseWorldPos() return {10,0,10} end
function GetRolloverInfo() return rollover end
function GetUnitById(id) for _, item in ipairs(allUnits) do if item.id == id then return item end end end
function GetUnitCommandData(units)
    local buildable = {}
    local upgrade = units[1]:GetBlueprint().General.UpgradesTo
    if upgrade then buildable[upgrade] = true end
    return {}, {}, buildable
end
function EntityCategoryContains(category, id) return category[id] == true end
function UISelectionByCategory(category, _, onScreen)
    assert(onScreen == false, 'candidate scan must cover the whole map')
    local result = {}
    for _, item in ipairs(allUnits) do
        if category == 'STRUCTURE' and item:IsInCategory('STRUCTURE') then table.insert(result,item) end
        if category == 'MASSEXTRACTION STRUCTURE' and item:IsInCategory('MASSEXTRACTION') then table.insert(result,item) end
    end
    selected = result
end
function IssueBlueprintCommand(name, blueprint, count, clear)
    if failIssue then error('simulated issue failure') end
    table.insert(issued, {name=name, blueprint=blueprint, count=count, clear=clear, unit=selected[1]})
end

function IssueBlueprintCommandToUnit(unit, name, blueprint, count, clear)
    table.insert(issued, {unit=unit, name=name, blueprint=blueprint, count=count, clear=clear})
end

local commandModule = {
    GetCommandMode = function() return {command.mode, command.data} end,
    CacheAndClearCommandMode = function() cached = {command.mode, command.data}; command.mode=false; command.data=false end,
    RestoreCommandMode = function()
        if cached then command.mode, command.data = cached[1], cached[2]; cached=nil end
    end,
}
local gameMain = { SetIgnoreSelection = function(value) ignoreSelection=value end }
local worldView = { viewLeft = { CursorOverWorld=true } }
local nativeUpgrade = { UpgradeStructure=function(pause)
    local unit=rollover and rollover.userUnit
    table.insert(nativeUpgrades,{unit=unit,pause=pause})
    if failIssue then error('simulated issue failure') end
    if unit then table.insert(issued,{name='UNITCOMMAND_Upgrade',blueprint=unit:GetBlueprint().General.UpgradesTo,count=1,clear=false,unit=unit}) end
end }
function import(path)
    if path == '/lua/ui/game/commandmode.lua' then return commandModule end
    if path == '/lua/ui/game/gamemain.lua' then return gameMain end
    if path == '/lua/ui/game/worldview.lua' then return worldView end
    if path == '/lua/ui/game/hotkeys/upgrade-structure.lua' then return nativeUpgrade end
    error('unexpected import: '..path)
end

local env = setmetatable({}, {__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextUpgrade.lua','t',env))()
local action = 'upgrade_structure_under_cursor'
local context = {isReplay=false, focusArmy=1, selection={}, resolvedContext='cursor'}

-- Exact rollover picks only the rollover unit; a nearby candidate is irrelevant.
rollover = {userUnit=target}
assert(env.Available(action, context))
assert(env.CanUpgradeUnderCursor(context),'exported cursor eligibility accepts a live friendly rollover structure')
assert(env.Execute(action, context))
assert(issued[1].unit == target and issued[1].blueprint == 'ueb1201'
    and nativeUpgrades[1].unit==target and nativeUpgrades[1].pause==false)
assert(table.getn(selected) == 0 and command.mode == 'build' and not ignoreSelection,
    'temporary discovery/issue restores selection and command mode')

-- The rollover action also works with a building selected and restores it.
local selectedBuilding = unit('ueb1107', 1, { STRUCTURE=true }, 'ueb1207')
selected = {selectedBuilding}
context.selection = {selectedBuilding}
rollover = {userUnit=target}
assert(env.Available(action, context) and env.Execute(action, context))
assert(issued[table.getn(issued)].unit == target and selected[1] == selectedBuilding,
    'upgrade under cursor preserves a non-empty building selection')
selected = {}
context.selection = {}

-- Pause action delegates to FAF's native pause-after-upgrade routine.
local pauseAction='upgrade_structure_pause'
rollover={userUnit=target}
assert(env.Available(pauseAction,context) and env.CanUpgradeUnderCursor(context))
assert(env.Execute(pauseAction,context) and nativeUpgrades[table.getn(nativeUpgrades)].pause==true
    and nativeUpgrades[table.getn(nativeUpgrades)].unit==target and table.getn(selected)==0,
    'pause action uses FAF native semantics for the rollover structure and preserves selection')

-- A hostile rollover is rejected without issuing an upgrade or changing selection.
rollover = {userUnit=enemy}
local issueCount = table.getn(issued)
assert(not env.Available(action, context) and not env.Execute(action, context)
    and not env.CanUpgradeUnderCursor(context))
assert(table.getn(issued) == issueCount and table.getn(selected) == 0)

-- A live own structure already upgrading is ineligible under the cursor.
target.focus=focusedOn('ueb1201')
rollover={userUnit=target}
assert(not env.CanUpgradeUnderCursor(context) and not env.Available(action,context),
    'a structure with an active focus cannot be upgraded again')
target.focus=focusedOn('ueb9999')
assert(env.CanUpgradeUnderCursor(context),
    'an unrelated production focus does not block an otherwise valid upgrade')
target.focus=nil

-- The selected-extractor action upgrades all eligible members in place.
local batch = {mexA, mexB, mexC, target, enemy}
selected = batch
local batchContext = {selection=batch, focusArmy=1}
local before = #issued
assert(env.Execute('upgrade_mex', batchContext))
assert(#issued==before+2 and issued[before+1].unit==mexA and issued[before+1].blueprint=='ueb1203'
    and issued[before+2].unit==mexB and issued[before+2].blueprint=='ueb1204' and selected==batch,
    'the bind upgrades each eligible extractor to its own next tier and preserves selection')
mexA.focus=focusedOn('ueb1203')
selected={mexA,mexC}; batchContext.selection=selected
assert(not env.Execute('upgrade_mex', batchContext) and #issued==before+2,
    'extractors at max tier or already upgrading receive no command')
mexA.focus=nil

-- The cursor action upgrades the rollover extractor and selects the next eligible one.
selected={}
local mexAction = 'upgrade_mex_select_next'
local occupied = unit('ueb1106', 1, { STRUCTURE=true, MASSEXTRACTION=true }, 'ueb1206', {10,0,10})
occupied.focus=focusedOn('ueb1206'); table.insert(allUnits,occupied)
-- Legacy saved assignments without resolvedContext='cursor' retain selection based behavior.
context.resolvedContext=nil
rollover=nil
assert(env.Available(mexAction,context) and env.Execute(mexAction,context) and selected[1]==mexA,
    'legacy empty-selection assignment still selects nearest upgradeable extractor')
context.selection={mexA}
assert(env.Available(mexAction,context) and env.Execute(mexAction,context)
    and issued[table.getn(issued)].unit==mexA and selected[1]==mexB,
    'legacy selected-extractor assignment upgrades it and selects its successor')
selected={}; context.selection={}; context.resolvedContext='cursor'
rollover={userUnit=mexA}
assert(env.Available(mexAction, context))
assert(env.Execute(mexAction, context))
assert(issued[table.getn(issued)].unit == mexA and selected[1] == mexB
    and nativeUpgrades[table.getn(nativeUpgrades)].unit==mexA,
    'rollover extractor is upgraded and next eligible extractor is selected')
assert(command.mode == 'build' and not ignoreSelection)

-- An issue failure restores selection/mode and does not pick a successor.
selected = {mexA}
context.selection = {mexA}
rollover={userUnit=mexA}
failIssue = true
local ok = env.Execute(mexAction, context)
failIssue = false
assert(not ok and selected[1] == mexA and command.mode == 'build' and not ignoreSelection)
-- Even when the current selection was manually changed, never enqueue another
-- upgrade onto an extractor that is already upgrading.
mexA.focus=focusedOn('ueb1203')
selected={}; context.selection={}
assert(not env.Available(mexAction, context) and not env.Execute(mexAction, context))
mexA.focus=nil

-- Context snapshot races and replay cannot upgrade.
selected = {mexA}
context.selection = {}
assert(not env.Execute(mexAction, context))
context.isReplay = true
assert(not env.Available(mexAction, context) and not env.Execute(mexAction, context))

print('PASS: contextual upgrades use exact friendly rollover and restore selection/command mode')
