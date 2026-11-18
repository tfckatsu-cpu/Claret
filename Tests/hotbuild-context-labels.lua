-- Context action labels and retired picker entries.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn = function(t) return #t end
-- Module lookup can resolve ReUI even when raw _G does not contain it.
local actions = setmetatable({ _G = {}, ReUI = ReUI }, { __index = _G })
assert(loadfile('../mods/ClaretHotbuild/modules/ContextActions.lua', 't', actions))()

local attack = actions.Get('attack')
assert(attack and attack.order == 'RULEUCC_Attack' and attack.label == 'Атака по площади',
    'all context entries backed by RULEUCC_Attack use the corrected label')
local patrol = actions.Get('patrol')
assert(patrol and patrol.label == 'Патруль', 'action label keys resolve through the registered RU table')
local cursor
for _, context in ipairs(actions.Contexts()) do if context.id == 'cursor' then cursor=context; break end end
assert(cursor and cursor.label == 'Под курсором', 'context label keys resolve through the registered RU table')

local cycleTypes = actions.Get('cycle_unit_types_in_sel')
assert(cycleTypes and cycleTypes.hidden and cycleTypes.obsolete,
    'the layer-cycle action is hidden from new assignments and marked obsolete')
assert(actions.Supports(cycleTypes.id, 'land') and actions.Supports(cycleTypes.id, 'air')
    and actions.Supports(cycleTypes.id, 'navy'), 'saved layer-cycle assignments remain executable')
assert(actions.Get(cycleTypes.id) == cycleTypes, 'the old action ID remains resolvable')
local hasLandContext = false
for _, context in ipairs(actions.Contexts()) do if context.id == 'land' then hasLandContext = true end end
assert(hasLandContext, 'the Land child context remains available')
print('PASS: context/action localization and retired layer-cycle picker action')
