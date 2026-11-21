-- Individual actions for the context binding editor. IDs are saved in profiles.
-- Contexts describe unit types used to prioritize mixed selections.
local function T(key, first, second, third)
    local core = ReUI and ReUI.ClaretCore
    local localization = core and core.Localization
    if localization and type(localization.Text) == 'function' then return localization.Text(key, first, second, third) end
    return key
end

local function LocalizedFields(item)
    setmetatable(item, {__index=function(self, field)
        if field == 'label' then
            if self.labelFormatter then return self.labelFormatter() end
            if self.labelKey then return T(self.labelKey) end
        elseif field == 'description' and self.descriptionKey then
            return T(self.descriptionKey)
        end
    end})
    return item
end

local contexts = {
    {id='cursor', labelKey='hotbuild.context.cursor'},
    {id='units', labelKey='hotbuild.context.units'},
    {id='land', labelKey='hotbuild.context.land'},
    {id='air', labelKey='hotbuild.context.air'},
    {id='fighter', labelKey='hotbuild.context.fighter'},
    {id='bomber', labelKey='hotbuild.context.bomber'},
    {id='gunship', labelKey='hotbuild.context.gunship'},
    {id='navy', labelKey='hotbuild.context.navy'},
    {id='builder', labelKey='hotbuild.context.builder'},
    {id='empty', labelKey='hotbuild.context.empty'},
    {id='acu', labelKey='hotbuild.context.acu'},
    {id='sacu', labelKey='hotbuild.context.sacu'},
    {id='engineer', labelKey='hotbuild.context.engineer'},
    {id='factory', labelKey='hotbuild.context.factory'},
    {id='missiles', labelKey='hotbuild.context.missiles'},
    {id='transport', labelKey='hotbuild.context.transport'},
    {id='silo_tactical', labelKey='hotbuild.context.silo_tactical'},
    {id='silo_nuclear', labelKey='hotbuild.context.silo_nuclear'},
    {id='mex', labelKey='hotbuild.context.mex'},
    {id='scout', labelKey='hotbuild.context.scout'},
    {id='other', labelKey='hotbuild.context.other'},
}
local priority = {'empty','land','air','fighter','bomber','gunship','navy','acu','sacu','engineer','factory','silo_tactical','silo_nuclear','transport','mex','scout','other'}
function Priority() return priority end

local combatAirContexts = {air=true, fighter=true, bomber=true, gunship=true}
function IsArmyContext(kind)
    return kind=='land' or kind=='navy' or combatAirContexts[kind]==true
end

local definitions = {
    {id='select_acu', labelKey='hotbuild.action.select_acu.label', contexts={'empty'}, select='UI_SelectByCategory +nearest +goto COMMAND', selectionPolicy='exclusive'},
    {id='select_acu_only', labelKey='hotbuild.action.select_acu_only.label', contexts={'empty'}, select='UI_SelectByCategory +nearest COMMAND', selectionPolicy='exclusive'},
    {id='select_acu_double', labelKey='hotbuild.action.select_acu_double.label', descriptionKey='hotbuild.action.select_acu_double.description', contexts={'empty','acu'}, select='UI_SelectByCategory +nearest COMMAND', doubleSelect='UI_SelectByCategory +nearest +goto COMMAND', selectionPolicy='double', continuation='double', hidden=true},
    {id='goto_acu', labelKey='hotbuild.action.goto_acu.label', contexts={'empty'}, select='UI_SelectByCategory +nearest +goto COMMAND', selectionPolicy='exclusive', hidden=true},
    {id='select_engineer', labelKey='hotbuild.action.select_engineer.label', contexts={'empty'}, select='UI_SelectByCategory +inview +nearest +idle ENGINEER TECH1', selectionPolicy='exclusive'},
    {id='select_engineers', labelKey='hotbuild.action.select_engineers.label', contexts={'empty'}, select='UI_SelectByCategory +inview +idle ENGINEER TECH1,ENGINEER TECH2,ENGINEER TECH3', selectionPolicy='exclusive'},
    {id='select_scout', labelKey='hotbuild.action.select_scout.label', contexts={'empty'}, select='UI_SelectByCategory +nearest AIR INTELLIGENCE', selectionPolicy='exclusive'},
    {id='select_transport', labelKey='hotbuild.action.select_transport.label', contexts={'empty'}, select='UI_SelectByCategory +nearest +idle AIR TRANSPORTATION', selectionPolicy='accumulate'},
    {id='select_transport_nearest', labelKey='hotbuild.action.select_transport_nearest.label', contexts={'empty'}, select='UI_SelectByCategory +nearest +idle AIR TRANSPORTATION', selectionPolicy='accumulate'},
    {id='select_transports_accumulate', labelKey='hotbuild.action.select_transports_accumulate.label', descriptionKey='hotbuild.action.select_transports_accumulate.description', contexts={'empty','transport'}, special='next_idle_transport', selectionPolicy='accumulate', continuation='accumulate'},
    {id='select_all_idle_transports', labelKey='hotbuild.action.select_all_idle_transports.label', descriptionKey='hotbuild.action.select_all_idle_transports.description', contexts={'empty','land','air','navy','engineer','transport','acu','sacu','other'}, special='select_all_idle_transports', selectionPolicy='accumulate'},
    {id='select_transport_double', labelKey='hotbuild.action.select_transport_double.label', descriptionKey='hotbuild.action.select_transport_double.description', contexts={'empty','transport'}, select='UI_SelectByCategory +nearest +idle AIR TRANSPORTATION', doubleSelect='UI_SelectByCategory AIR TRANSPORTATION', selectionPolicy='double', continuation='double', hidden=true},
    {id='select_radars', labelKey='hotbuild.action.select_radars.label', contexts={'empty'}, select='UI_SelectByCategory INTELLIGENCE STRUCTURE RADAR,INTELLIGENCE STRUCTURE OMNI', selectionPolicy='exclusive'},
    {id='select_sensors', labelKey='hotbuild.action.select_sensors.label', contexts={'empty'}, select='UI_SelectByCategory INTELLIGENCE STRUCTURE RADAR,INTELLIGENCE STRUCTURE OMNI,INTELLIGENCE SONAR NAVAL', selectionPolicy='exclusive'},
    {id='select_all_scouts', labelKey='hotbuild.action.select_all_scouts.label', contexts={'empty','scout'}, select='UI_SelectByCategory AIR INTELLIGENCE', selectionPolicy='exclusive'},
    {id='select_bombers', labelKey='hotbuild.action.select_bombers.label', contexts={'empty'}, select='UI_SelectByCategory AIR BOMBER', selectionPolicy='exclusive'},
    {id='select_fighters', labelKey='hotbuild.action.select_fighters.label', contexts={'empty'}, special='smart_fighters', selectionPolicy='exclusive'},
    {id='build_storage_nearest', labelKey='hotbuild.action.build_storage_nearest.label', descriptionKey='hotbuild.action.build_storage_nearest.description', contexts={'engineer'}, special='build_storage_nearest'},
    {id='build_fabs_nearest', labelKey='hotbuild.action.build_fabs_nearest.label', descriptionKey='hotbuild.action.build_fabs_nearest.description', contexts={'engineer'}, special='build_fabs_nearest'},
    {id='select_gunships', labelKey='hotbuild.action.select_gunships.label', contexts={'empty'}, select='UI_SelectByCategory AIR GROUNDATTACK', selectionPolicy='exclusive'},
    {id='select_land_army_screen', labelKey='hotbuild.action.select_land_army_screen.label', contexts={'empty'}, special='select_land_army_screen', selectionPolicy='exclusive'},
    {id='select_land_army_map', labelKey='hotbuild.action.select_land_army_map.label', contexts={'empty'}, special='select_land_army_map', selectionPolicy='exclusive'},
    {id='select_naval_army_screen', labelKey='hotbuild.action.select_naval_army_screen.label', contexts={'empty'}, select='UI_SelectByCategory +inview MOBILE NAVAL', selectionPolicy='exclusive'},
    {id='select_naval_army_map', labelKey='hotbuild.action.select_naval_army_map.label', contexts={'empty'}, select='UI_SelectByCategory MOBILE NAVAL', selectionPolicy='exclusive'},
    {id='select_experimentals', labelKey='hotbuild.action.select_experimentals.label', contexts={'empty'}, special='select_mobile_land_experimentals', selectionPolicy='exclusive'},
    {id='select_satellites', labelKey='hotbuild.action.select_satellites.label', contexts={'empty'}, special='select_satellites', selectionPolicy='exclusive'},
    {id='select_land_experimentals', labelKey='hotbuild.action.select_land_experimentals.label', contexts={'empty'}, select='UI_SelectByCategory EXPERIMENTAL LAND', selectionPolicy='exclusive'},
    {id='select_air_experimentals', labelKey='hotbuild.action.select_air_experimentals.label', contexts={'empty'}, special='select_air_experimentals', selectionPolicy='exclusive'},
    {id='select_transport_screen', labelKey='hotbuild.action.select_transport_screen.label', contexts={'empty'}, select='UI_SelectByCategory +inview AIR TRANSPORTATION', selectionPolicy='exclusive'},
    {id='select_transport_map', labelKey='hotbuild.action.select_transport_map.label', contexts={'empty'}, select='UI_SelectByCategory AIR TRANSPORTATION', selectionPolicy='exclusive'},
    {id='select_engineers_t1', labelKey='hotbuild.action.select_engineers_t1.label', contexts={'empty','engineer'}, special='next_engineer_t1', selectionPolicy='accumulate', continuation='accumulate'},
    {id='select_engineers_t2', labelKey='hotbuild.action.select_engineers_t2.label', contexts={'empty','engineer'}, special='next_engineer_t2', selectionPolicy='accumulate', continuation='accumulate'},
    {id='select_engineers_t3', labelKey='hotbuild.action.select_engineers_t3.label', contexts={'empty','engineer'}, special='next_engineer_t3', selectionPolicy='accumulate', continuation='accumulate'},
    {id='select_engineers_all', labelKey='hotbuild.action.select_engineers_all.label', contexts={'empty','engineer'}, special='next_engineer_all', selectionPolicy='accumulate', continuation='accumulate'},
    {id='select_t3_artillery', labelKey='hotbuild.action.select_t3_artillery.label', contexts={'empty'}, select='UI_SelectByCategory +inview MOBILE TECH3 ARTILLERY', selectionPolicy='exclusive'},
    {id='select_t3_shields', labelKey='hotbuild.action.select_t3_shields.label', contexts={'empty'}, special='select_mobile_shields', selectionPolicy='exclusive'},
    {id='select_t3_stealth', labelKey='hotbuild.action.select_t3_stealth.label', contexts={'empty'}, select='UI_SelectByCategory +inview LAND MOBILE STEALTHFIELD CYBRAN TECH2', selectionPolicy='exclusive'},
    {id='select_t3_mml', labelKey='hotbuild.action.select_t3_mml.label', contexts={'empty'}, select='UI_SelectByCategory +inview +excludeengineers MOBILE LAND SILO', selectionPolicy='exclusive'},
    {id='select_tactical_silos', labelKey='hotbuild.action.select_tactical_silos.label', contexts={'empty'}, select='UI_SelectByCategory STRUCTURE SILO TACTICALMISSILEPLATFORM', selectionPolicy='exclusive'},
    {id='select_nuclear_silos', labelKey='hotbuild.action.select_nuclear_silos.label', contexts={'empty'}, select='UI_SelectByCategory STRUCTURE SILO NUKE', selectionPolicy='exclusive'},
    {id='select_land_factories_screen', labelKey='hotbuild.action.select_land_factories_screen.label', contexts={'empty'}, select='UI_SelectByCategory +inview STRUCTURE FACTORY LAND TECH1,STRUCTURE FACTORY LAND TECH2,STRUCTURE FACTORY LAND TECH3', selectionPolicy='exclusive'},
    {id='select_land_factories_map', labelKey='hotbuild.action.select_land_factories_map.label', contexts={'empty'}, select='UI_SelectByCategory STRUCTURE FACTORY LAND TECH1,STRUCTURE FACTORY LAND TECH2,STRUCTURE FACTORY LAND TECH3', selectionPolicy='exclusive'},
    {id='select_naval_factories_screen', labelKey='hotbuild.action.select_naval_factories_screen.label', contexts={'empty'}, select='UI_SelectByCategory +inview STRUCTURE FACTORY NAVAL TECH1,STRUCTURE FACTORY NAVAL TECH2,STRUCTURE FACTORY NAVAL TECH3', selectionPolicy='exclusive'},
    {id='select_naval_factories_map', labelKey='hotbuild.action.select_naval_factories_map.label', contexts={'empty'}, select='UI_SelectByCategory STRUCTURE FACTORY NAVAL TECH1,STRUCTURE FACTORY NAVAL TECH2,STRUCTURE FACTORY NAVAL TECH3', selectionPolicy='exclusive'},
    {id='select_air_factories_screen', labelKey='hotbuild.action.select_air_factories_screen.label', contexts={'empty'}, select='UI_SelectByCategory +inview STRUCTURE FACTORY AIR TECH1,STRUCTURE FACTORY AIR TECH2,STRUCTURE FACTORY AIR TECH3', selectionPolicy='exclusive'},
    {id='select_air_factories_map', labelKey='hotbuild.action.select_air_factories_map.label', contexts={'empty'}, select='UI_SelectByCategory STRUCTURE FACTORY AIR TECH1,STRUCTURE FACTORY AIR TECH2,STRUCTURE FACTORY AIR TECH3', selectionPolicy='exclusive'},
    {id='cycle_idle_factories', labelKey='hotbuild.action.cycle_idle_factories.label', contexts={'empty'}, select='UI_Lua import("/lua/keymap/misckeyactions.lua").CycleIdleFactories()', selectionPolicy='exclusive', continuation='cycle'},
    {id='patrol', labelKey='hotbuild.action.patrol.label', contexts={'land','air','navy'}, order='RULEUCC_Patrol'},
    {id='mode', labelKey='hotbuild.action.mode.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/orders.lua").CycleRetaliateStateUp()'},
    {id='set_target_priority', labelKey='hotbuild.action.set_target_priority.label', contexts={'land','air','navy'}, select='UI_LUA import("/lua/keymap/misckeyactions.lua").SetWeaponPrioritiesToUnitType()'},
    {id='set_default_target_priority', labelKey='hotbuild.action.set_default_target_priority.label', contexts={'land','air','navy'}, select='UI_LUA import("/lua/keymap/misckeyactions.lua").SetDefaultWeaponPriorities()'},
    {id='spreadattack', labelKey='hotbuild.action.spreadattack.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/hotkeys/distribute-queue.lua").DistributeOrders(true)'},
    {id='copy_orders', labelKey='hotbuild.action.copy_orders.label', contexts={'land','air','navy'}, select='UI_LUA import("/lua/ui/game/hotkeys/copy-queue.lua").CopyOrders()'},
    {id='load_transports', labelKey='hotbuild.action.load_transports.label', contexts={'land','air','navy','acu','sacu','engineer'}, select='UI_Lua import("/lua/ui/game/hotkeys/load-in-transport.lua").LoadIntoTransports(false)'},
    {id='split_layer', labelKey='hotbuild.action.split_layer.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/selection.lua").SplitLayer()'},
    {id='split_tech', labelKey='hotbuild.action.split_tech.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/selection.lua").SplitTech()'},
    {id='split_into_groups_1', labelKey='hotbuild.action.split_into_groups_1.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(1)'},
    {id='split_into_groups_2', labelKey='hotbuild.action.split_into_groups_2.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(2)'},
    {id='split_into_groups_4', labelKey='hotbuild.action.split_into_groups_4.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(4)'},
    {id='split_into_groups_8', labelKey='hotbuild.action.split_into_groups_8.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(8)'},
    {id='split_into_groups_16', labelKey='hotbuild.action.split_into_groups_16.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(16)'},
    {id='split_next', labelKey='hotbuild.action.split_next.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/ui/game/selection.lua").SplitNext()'},
    {id='cycle_unit_types_in_sel', labelKey='hotbuild.action.cycle_unit_types_in_sel.label', contexts={'land','air','navy'}, select='UI_Lua import("/lua/keymap/misckeyactions.lua").CycleUnitTypesInSel()'},
    {id='suicide', labelKey='hotbuild.action.suicide.label', contexts={'land','air','navy','other'}, select='UI_Lua import("/lua/ui/game/confirmunitdestroy.lua").ConfirmUnitDestruction(false)'},
    {id='kill_selected_units', labelKey='hotbuild.action.kill_selected_units.label', contexts={'land','air','navy','acu','sacu','engineer','factory','silo_tactical','silo_nuclear','transport','mex','scout','other'},
        select='UI_Lua import("/lua/ui/game/confirmunitdestroy.lua").ConfirmUnitDestruction(true)'},
    {id='discharge', labelKey='hotbuild.action.discharge.label', contexts={'land'}, toggle='RULEUTC_ShieldToggle', select='UI_Lua import("/lua/keymap/misckeyactions.lua").DischargeShields()'},
    {id='dock', labelKey='hotbuild.action.dock.label', contexts={'air','transport','scout'}, select='UI_Lua import("/lua/ui/game/orders.lua").Dock(true)'},
    {id='ferry', labelKey='hotbuild.action.ferry.label', contexts={'transport'}, order='RULEUCC_Ferry'},
    {id='dock_damaged', labelKey='hotbuild.action.dock_damaged.label', contexts={'air'}, select='UI_Lua import("/lua/ui/game/hotkeys/dock-damaged.lua").DockDamaged(0.9, true)'},
    {id='dive', labelKey='hotbuild.action.dive.label', contexts={'navy'}, select='UI_Lua import("/lua/ui/game/orders.lua").ToggleDiveOrder()'},
    {id='dive_all', labelKey='hotbuild.action.dive_all.label', contexts={'navy'}, select='UI_Lua import("/lua/keymap/misckeyactions.lua").DiveAll()'},
    {id='undive_all', labelKey='hotbuild.action.undive_all.label', contexts={'navy'}, select='UI_Lua import("/lua/keymap/misckeyactions.lua").SurfaceAll()'},
    {id='repair', labelKey='hotbuild.action.repair.label', contexts={'acu','sacu','engineer'}, order='RULEUCC_Repair'},
    {id='capture', labelKey='hotbuild.action.capture.label', contexts={'acu','sacu','engineer'}, order='RULEUCC_Capture'},
    {id='cap', labelKey='hotbuild.action.cap.label', contexts={'acu','sacu','engineer'}, select='UI_LUA import("/lua/ui/game/hotkeys/capping.lua").HotkeyToCap(true, true)'},
    {id='abort_navigation', labelKey='hotbuild.action.abort_navigation.label', contexts={'acu','sacu','engineer'}, select='UI_Lua import("/lua/keymap/misckeyactions.lua").AbortNavigation()'},
    {id='pause_unit', labelKey='hotbuild.action.pause_unit.label', contexts={'acu','sacu','engineer','silo_tactical','silo_nuclear'}, select='UI_Lua import("/lua/ui/game/construction.lua").ToggleUnitPause()'},
    {id='teleport', labelKey='hotbuild.action.teleport.label', contexts={'acu'}, order='RULEUCC_Teleport'},
    {id='filter_highest_engineer_and_assist', labelKey='hotbuild.action.filter_highest_engineer_and_assist.label', contexts={'engineer'}, select='UI_Lua import("/lua/ui/game/hotkeys/filter-engineers.lua").SelectHighestEngineerAndAssist()'},
    {id='build_templates', labelKey='hotbuild.action.build_templates.label', descriptionKey='hotbuild.action.build_templates.description', contexts={'acu','sacu','engineer'}, select='UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Templates")'},
    {id='upgrade_structure', labelKey='hotbuild.action.upgrade_structure.label', contexts={'factory'}, select='UI_LUA import("/lua/ui/game/hotkeys/upgrade-structure.lua").UpgradeStructure()'},
    {id='upgrade_structure_pause', labelKey='hotbuild.action.upgrade_structure_pause.label', contexts={'factory','mex','other'}, select='UI_LUA import("/lua/ui/game/hotkeys/upgrade-structure.lua").UpgradeStructure(true)'},
    {id='create_template_factory', labelKey='hotbuild.action.create_template_factory.label', contexts={'factory'}, select='UI_Lua import("/lua/keymap/misckeyactions.lua").CreateTemplateFactory()'},
    {id='fire_beetle_detonate', labelKey='hotbuild.action.fire_beetle_detonate.label', contexts={'other'}, special='fire_beetle'},
    {id='pause_unit_all', labelKey='hotbuild.action.pause_unit_all.label', contexts={'other'}, select='UI_Lua import("/lua/ui/game/construction.lua").ToggleUnitPauseAll()'},
    {id='unpause_unit_all', labelKey='hotbuild.action.unpause_unit_all.label', contexts={'other'}, select='UI_Lua import("/lua/ui/game/construction.lua").ToggleUnitUnpauseAll()'},
    {id='toggle_production', labelKey='hotbuild.action.toggle_production.label', contexts={'other'}, toggle='RULEUTC_ProductionToggle', select='UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Production")', special='unit_toggle'},
    {id='toggle_intel', labelKey='hotbuild.action.toggle_intel.label', contexts={'other'}, toggle='RULEUTC_IntelToggle', select='UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Intel")', special='unit_toggle'},
    {id='toggle_jamming', labelKey='hotbuild.action.toggle_jamming.label', contexts={'other'}, toggle='RULEUTC_JammingToggle', select='UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Jamming")', special='unit_toggle'},
    {id='toggle_cloak', labelKey='hotbuild.action.toggle_cloak.label', contexts={'other'}, toggle='RULEUTC_CloakToggle', select='UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Cloak")', special='unit_toggle'},
    {id='toggle_all', labelKey='hotbuild.action.toggle_all.label', contexts={'acu','sacu','engineer','factory','silo_tactical','silo_nuclear','transport','mex','scout','other'}, select='UI_Lua import("/lua/keymap/misckeyactions.lua").toggleAllScript()'},
    {id='cycle_mex_screen', labelKey='hotbuild.action.cycle_mex_screen.label', contexts={'empty','mex'}, special='cycle_mex_screen', legacy=true},
    {id='cycle_mex_map', labelKey='hotbuild.action.cycle_mex_map.label', contexts={'empty','mex'}, special='cycle_mex_map', legacy=true},
    {id='upgrade_structure_under_cursor', labelKey='hotbuild.action.upgrade_structure_under_cursor.label', contexts={'empty'}, special='context_upgrade'},
    {id='upgrade_mex_select_next', labelKey='hotbuild.action.upgrade_mex_select_next.label', contexts={'mex'}, special='context_upgrade', selectionPolicy='exclusive', continuation='accumulate'},
    {id='upgrade_mex', labelKey='hotbuild.action.upgrade_mex.label', contexts={'mex'}, special='upgrade_mex'},
    {id='overcharge', labelKey='hotbuild.action.overcharge.label', contexts={'acu','sacu'}, order='RULEUCC_Overcharge', special='overcharge'},
    {id='acu_tech', labelKey='hotbuild.action.acu_tech.label', contexts={'acu'}, special='enhancement'},
    {id='acu_ras', labelKey='hotbuild.action.acu_ras.label', contexts={'acu'}, special='enhancement'},
    {id='acu_tele', labelKey='hotbuild.action.acu_tele.label', contexts={'acu'}, special='enhancement'},
    {id='acu_gun', labelKey='hotbuild.action.acu_gun.label', contexts={'acu'}, special='enhancement'},
    {id='acu_nano', labelKey='hotbuild.action.acu_nano.label', contexts={'acu'}, special='enhancement'},
    {id='acu_special', labelKey='hotbuild.action.acu_special.label', contexts={'acu'}, special='enhancement'},
    {id='sacu_tech', labelKey='hotbuild.action.sacu_tech.label', contexts={'sacu'}, special='enhancement'},
    {id='transport_order', labelKey='hotbuild.action.transport_order.label', contexts={'transport','other'}, order='RULEUCC_Transport'},
    {id='append_transport_cargo', labelKey='hotbuild.action.append_transport_cargo.label', descriptionKey='hotbuild.action.append_transport_cargo.description', contexts={'transport'}, special='append_transport_cargo'},
    {id='claret_strategic_rings_create', labelKey='hotbuild.action.claret_strategic_rings_create.label', descriptionKey='hotbuild.action.claret_strategic_rings_create.description', contexts={'empty'}, special='create_strategic_rings'},
    {id='claret_strategic_rings_vision', labelKey='hotbuild.action.claret_strategic_rings_vision.label', descriptionKey='hotbuild.action.claret_strategic_rings_vision.description', contexts={'empty'}, special='create_vision_ring'},
    {id='reclaim', labelKey='hotbuild.action.reclaim.label', contexts={'acu','sacu','engineer','other'}, order='RULEUCC_Reclaim'},
    {id='assist', labelKey='hotbuild.action.assist.label', contexts={'acu','sacu','engineer','other'}, order='RULEUCC_Guard'},
    {id='move', labelKey='hotbuild.action.move.label', contexts={'acu','sacu','engineer','transport','scout','other'}, order='RULEUCC_Move'},
    {id='attack', labelKey='hotbuild.action.attack.label', contexts={'acu','sacu','engineer','transport','scout','other'}, order='RULEUCC_Attack'},
    {id='attack_move', labelKey='hotbuild.action.attack_move.label', contexts={'acu','sacu','engineer','transport','scout','other'}, special='attack_move'},
    {id='smart_missile', labelKey='hotbuild.action.smart_missile.label', contexts={'acu','sacu','silo_tactical','silo_nuclear'}, special='smart_missile'},
    {id='nuke', labelKey='hotbuild.action.nuke.label', contexts={'silo_nuclear'}, order='RULEUCC_Nuke'},
    {id='tactical', labelKey='hotbuild.action.tactical.label', contexts={'silo_tactical'}, order='RULEUCC_Tactical'},
    {id='repeat_queue', labelKey='hotbuild.action.repeat_queue.label', contexts={'factory'}, special='repeat_queue'},
    {id='pause', labelKey='hotbuild.action.pause.label', contexts={'factory','mex','other'}, special='pause'},
    {id='shield', labelKey='hotbuild.action.shield.label', contexts={'acu','sacu','engineer','factory','other'}, toggle='RULEUTC_ShieldToggle', special='shield'},
    {id='stealth', labelKey='hotbuild.action.stealth.label', contexts={'acu','sacu','engineer','other'}, toggle='RULEUTC_StealthToggle', special='stealth'},
    {id='stop', labelKey='hotbuild.action.stop.label', contexts={'acu','sacu','engineer','factory','transport','silo_tactical','silo_nuclear','mex','scout','other'}, special='stop'},
    {id='soft_stop', labelKey='hotbuild.action.soft_stop.label', contexts={'acu','sacu','engineer','factory','transport','scout','other'}, special='soft_stop'},
    {id='remove_queue', labelKey='hotbuild.action.remove_queue.label', contexts={}, special='remove_queue'},
}

-- Map communication is independent of the selection and belongs in the keyboard picker.
for _, ping in ipairs({'marker','alert','move','attack'}) do
    local id = 'ping_' .. ping
    table.insert(definitions, {
        id=id, labelKey='hotbuild.action.' .. id .. '.label', contexts={}, global=true,
        select='UI_Lua import("/lua/ui/game/ping.lua").DoPing("' .. ping .. '")',
    })
end

-- Keep the old combined on-screen selectors executable for existing assignments.
for _, action in ipairs(definitions) do
    if string.find(action.id, '^select_.*_factories_screen$') then action.hidden=true end
end
for _, domain in ipairs({
    {id='land', category='LAND', labelKey='hotbuild.domain.land'},
    {id='naval', category='NAVAL', labelKey='hotbuild.domain.naval'},
    {id='air', category='AIR', labelKey='hotbuild.domain.air'},
}) do
    for level=1,3 do
        local levelValue=level
        local domainLabelKey=domain.labelKey
        for _, area in ipairs({{id='screen',labelKey='hotbuild.area.screen',prefix='+inview '},{id='map',labelKey='hotbuild.area.map',prefix=''}}) do
            local areaLabelKey=area.labelKey
            table.insert(definitions,{
                id='select_'..domain.id..'_factories_t'..level..'_'..area.id,
                labelFormatter=function()
                    return T('hotbuild.action.select_factory_level.label',
                        T(domainLabelKey), levelValue, T(areaLabelKey))
                end,
                searchKeys={domainLabelKey,areaLabelKey},
                contexts={'empty'},
                select='UI_SelectByCategory '..area.prefix..'STRUCTURE FACTORY '..domain.category..' TECH'..level,
                selectionPolicy='exclusive',
            })
        end
    end
end

-- The parent builder action is limited to commands valid for all three child types.
local builderActions = {reclaim=true, assist=true, move=true, attack=true, attack_move=true,
    patrol=true, repair=true, capture=true, shield=true, stealth=true, toggle_all=true, stop=true, soft_stop=true,
    spreadattack=true, copy_orders=true, abort_navigation=true, pause_unit=true, kill_selected_units=true}

local byId = {}
for _, context in ipairs(contexts) do LocalizedFields(context) end
for _, action in ipairs(definitions) do LocalizedFields(action) end
for _, action in ipairs(definitions) do byId[action.id]=action end
local unitActions = {move=true,attack=true,attack_move=true,stop=true,patrol=true,mode=true,
    set_target_priority=true,set_default_target_priority=true,spreadattack=true,copy_orders=true,
    toggle_all=true,load_transports=true,split_layer=true,split_tech=true,split_into_groups_2=true,
    split_into_groups_1=true,split_into_groups_4=true,split_into_groups_8=true,split_into_groups_16=true,split_next=true,
    cycle_unit_types_in_sel=true,suicide=true,kill_selected_units=true}
local individualToggles={shield=true,stealth=true,toggle_production=true,toggle_intel=true,toggle_jamming=true,toggle_cloak=true}
for _, action in ipairs(definitions) do
    if individualToggles[action.id] then action.hidden=true end
    local removed={suicide=true,mode=true,dock=true,set_default_target_priority=true,upgrade_structure=true,cap=true,
        create_template_factory=true,
        nuke=true,tactical=true,cycle_unit_types_in_sel=true,attack_move=true,select_transport=true}
    local cursorOnly={upgrade_structure_under_cursor=true,upgrade_structure_pause=true,upgrade_mex_select_next=true}
    if removed[action.id] then action.hidden=true; action.obsolete=true end
    if cursorOnly[action.id] then action.hidden=true; action.compositeOnly=true end
    if action.id=='patrol' or action.id=='spreadattack' or action.id=='copy_orders' then
        for _, kind in ipairs({'acu','sacu','engineer'}) do table.insert(action.contexts,kind) end
    end
    if action.id=='spreadattack' then
        for _, kind in ipairs({'transport','scout','silo_tactical','silo_nuclear'}) do
            table.insert(action.contexts,kind)
        end
    end
    if action.id=='patrol' then table.insert(action.contexts,'factory') end
    if action.id=='patrol' then table.insert(action.contexts,'scout') end
    if unitActions[action.id] then
        for _, kind in ipairs({'land','air','navy'}) do
            local found=false
            for _, existing in ipairs(action.contexts) do if existing==kind then found=true; break end end
            if not found then table.insert(action.contexts,kind) end
        end
    end
    if action.id=='shield' or action.id=='stealth' then
        table.insert(action.contexts,'land'); table.insert(action.contexts,'navy')
    end
    if action.id=='move' then table.insert(action.contexts,'factory') end
end

local function Contains(list, value)
    for _, item in ipairs(list or {}) do if item==value then return true end end
    return false
end

-- Only actions that already contain a continuation reserve another context.
function ContinuationTargets(action)
    if not action or action.continuation=='double' then return {} end
    local id=action.id or ''
    if id=='cycle_idle_factories' then return {'factory'} end
    if string.find(id,'^select_engineers_') then return {'engineer'} end
    if action.continuation~='accumulate' then return {} end
    local result={}
    for _,context in ipairs(action.contexts or {}) do
        if context~='empty' then table.insert(result,context) end
    end
    return result
end

function Contexts() return contexts end
function List()
    local result={}
    for _,action in ipairs(definitions) do if not action.legacy then table.insert(result,action) end end
    return result
end
function Get(id) return byId[id] end
function IsSelection(id)
    local action=byId[id]
    return action and (action.id=='cycle_idle_factories' or (action.select and string.find(action.select, '^UI_SelectByCategory ') ~= nil) or (action.special and
        (string.find(action.special,'^select_') or string.find(action.special,'^next_engineer_') or action.special=='next_idle_transport' or action.special=='smart_fighters'))) and true or false
end
function StartsTargetOrder(action)
    return action and (action.order~=nil or action.special=='smart_missile'
        or action.special=='attack_move' or action.special=='overcharge')
end

function Supports(id, context)
    if context=='builder' then return builderActions[id] == true end
    if context=='units' then return unitActions[id] == true end
    if context=='missiles' then return id=='stop' or id=='pause_unit' or id=='smart_missile' or id=='toggle_all' or id=='kill_selected_units' end
    if context=='cursor' then return id=='upgrade_structure_under_cursor' or id=='upgrade_structure_pause' or id=='upgrade_mex_select_next' end
    local action=byId[id]
    if not action then return false end
    if Contains(action.contexts,context) then return true end
    if combatAirContexts[context] or context=='transport' or context=='scout' then
        return Contains(action.contexts,'air')
    end
    return false
end

local function UnitContext(unit)
    local blueprint=type(unit.GetBlueprint)=='function' and unit:GetBlueprint() or nil
    if unit:IsInCategory('DRONE') or unit:IsInCategory('STATIONASSISTPOD') then return 'other' end
    if blueprint and blueprint.BlueprintId=='xsb2401' then return 'silo_nuclear' end
    if unit:IsInCategory('COMMAND') then return 'acu' end
    if unit:IsInCategory('SUBCOMMANDER') then return 'sacu' end
    if unit:IsInCategory('ENGINEER') then return 'engineer' end
    local mobileFactory=(unit:IsInCategory('FACTORY') or unit:IsInCategory('EXTERNALFACTORY')) and unit:IsInCategory('MOBILE')
    if mobileFactory then
        if unit:IsInCategory('AIR') then return 'air' end
        if unit:IsInCategory('NAVAL') then return 'navy' end
        if unit:IsInCategory('LAND') then return 'land' end
        return 'other'
    end
    if (unit:IsInCategory('FACTORY') or unit:IsInCategory('EXTERNALFACTORY')) and not mobileFactory then return 'factory' end
    if unit:IsInCategory('SILO') then
        if unit:IsInCategory('TACTICALMISSILEPLATFORM') then return 'silo_tactical' end
        if unit:IsInCategory('NUKE') then return 'silo_nuclear' end
        -- SILO is also present on ordinary missile vehicles, ships and SMD.
    end
    if unit:IsInCategory('MASSEXTRACTION') then return 'mex' end
    if unit:IsInCategory('TRANSPORTATION') and not mobileFactory then return 'transport' end
    if unit:IsInCategory('AIR') and unit:IsInCategory('INTELLIGENCE') then return 'scout' end
    if unit:IsInCategory('MOBILE') or mobileFactory or (blueprint and blueprint.BlueprintId=='xea0002') then
        if unit:IsInCategory('AIR') then
            if unit:IsInCategory('BOMBER') then return 'bomber' end
            if unit:IsInCategory('GROUNDATTACK') then return 'gunship' end
            if unit:IsInCategory('ANTIAIR') and unit:IsInCategory('HIGHALTAIR') then return 'fighter' end
            return 'air'
        end
        if unit:IsInCategory('NAVAL') then return 'navy' end
        if unit:IsInCategory('LAND') then return 'land' end
    end
    return 'other'
end

local function IsBuilder(unit)
    return unit:IsInCategory('COMMAND') or unit:IsInCategory('SUBCOMMANDER')
        or unit:IsInCategory('ENGINEER') or unit:IsInCategory('FACTORY')
        or unit:IsInCategory('EXTERNALFACTORY')
end

function HasOrdinaryBuilder(selection)
    if not selection then return false end
    for _,unit in ipairs(selection) do if IsBuilder(unit) then return true end end
    return false
end

function OrdinaryBuilders(selection)
    local result={}
    for _,unit in ipairs(selection or {}) do if IsBuilder(unit) then table.insert(result,unit) end end
    return result
end

function HasMobileFactory(selection)
    if not selection then return false end
    for _,unit in ipairs(selection) do
        if unit:IsInCategory('FACTORY') or unit:IsInCategory('EXTERNALFACTORY') then
            if unit:IsInCategory('MOBILE') or unit:IsInCategory('COMMAND') or unit:IsInCategory('SUBCOMMANDER') then return true end
        end
    end
    return false
end

function PresentContexts(selection)
    local present={}
    for _,unit in ipairs(selection or {}) do present[UnitContext(unit)]=true end
    return present
end

function Classify(selection)
    if not selection or table.getn(selection)==0 then return 'empty' end
    local present=PresentContexts(selection)
    for _,kind in ipairs(priority) do
        if present[kind] then return kind end
    end
    return 'other'
end

function HasContext(selection, wanted)
    if not selection then return false end
    for _,unit in ipairs(selection) do
        local kind=UnitContext(unit)
        if kind==wanted or (wanted=='air' and combatAirContexts[kind]) then return true end
    end
    return false
end

function MatchesContext(selection, wanted)
    if wanted=='builder' then return HasContext(selection,'acu') or HasContext(selection,'sacu') or HasContext(selection,'engineer') end
    if wanted=='units' then return HasContext(selection,'land') or HasContext(selection,'air') or HasContext(selection,'navy') end
    if wanted=='missiles' then return HasContext(selection,'silo_tactical') or HasContext(selection,'silo_nuclear') end
    if wanted=='empty' then return not selection or table.getn(selection)==0 end
    return HasContext(selection,wanted)
end

local function SelectionGroupAllows(groupKind, unitKind, resolved)
    if groupKind=='units' or IsArmyContext(groupKind) then
        return IsArmyContext(unitKind) or (resolved and (unitKind=='transport' or unitKind=='scout'))
    end
    if resolved and (groupKind=='transport' or groupKind=='scout') then
        return combatAirContexts[unitKind] or unitKind=='transport' or unitKind=='scout'
    end
    if groupKind=='builder' or groupKind=='acu' or groupKind=='sacu' or groupKind=='engineer' then
        return unitKind=='acu' or unitKind=='sacu' or unitKind=='engineer'
    end
    if groupKind=='factory' then return unitKind=='factory' end
    return groupKind==unitKind
end

local function HasEligibleUnitCapability(action, context, capability, value)
    local selection=context.selection or {}
    local groupKind=context.resolvedContext
    local legacyUnitsFallback=context.legacyUnits and Contains(action.contexts,'other')
        and MatchesContext(selection,'units')
    if legacyUnitsFallback then groupKind='units' end
    if not groupKind then
        for _, kind in ipairs(priority) do
            if Contains(action.contexts,kind) and MatchesContext(selection,kind) then
                groupKind=kind
                break
            end
        end
    end
    if not groupKind then return false end
    local resolved=context.resolvedContext~=nil
    for _, unit in ipairs(selection) do
        local kind=UnitContext(unit)
        if SelectionGroupAllows(groupKind,kind,resolved)
            and (Contains(action.contexts,kind) or (combatAirContexts[kind] and Contains(action.contexts,'air'))
                or (resolved and Supports(action.id,kind)) or legacyUnitsFallback) then
            local orders, toggles = GetUnitCommandData({unit})
            if Contains(capability == 'order' and orders or toggles, value) then return true end
        end
    end
    return false
end

local scriptToggles={
    RULEUTC_ShieldToggle=true, RULEUTC_WeaponToggle=true, RULEUTC_JammingToggle=true,
    RULEUTC_IntelToggle=true, RULEUTC_ProductionToggle=true, RULEUTC_StealthToggle=true,
    RULEUTC_GenericToggle=true, RULEUTC_SpecialToggle=true, RULEUTC_CloakToggle=true,
}

local function KeyboardPauseSelection(selection)
    local eligible = {}
    for _, unit in ipairs(selection or {}) do
        if not unit:IsDead() and Contains(GetUnitCommandData({unit}), 'RULEUCC_Pause') then
            table.insert(eligible, unit)
        end
    end
    return eligible
end

local function IsKeyboardPause(action, context)
    return context.keyboardAction and (action.id == 'pause_unit' or action.id == 'pause')
end

function Available(action, context)
    if not action or not context or context.isReplay or context.focusArmy < 1 then return false end
    if IsKeyboardPause(action, context) then
        return table.getn(KeyboardPauseSelection(context.selection)) > 0
    end
    if action.global then return true end
    if action.id=='toggle_all' then
        for _, unit in ipairs(context.selection or {}) do
            local _, toggles=GetUnitCommandData({unit})
            for _, toggle in ipairs(toggles or {}) do
                if scriptToggles[toggle] then return true end
            end
        end
        return false
    end
    if action.id=='load_transports' then
        local hasTransport, hasCargo = false, false
        for _, unit in ipairs(context.selection or {}) do
            if unit:IsInCategory('TRANSPORTATION') then
                hasTransport = true
            elseif unit:IsInCategory('MOBILE') and not unit:IsInCategory('AIR') then
                hasCargo = true
            end
        end
        return hasTransport and hasCargo
    end
    if action.id=='spreadattack' then
        local eligible=false
        for _, unit in ipairs(context.selection or {}) do
            if not unit:IsInCategory('FACTORY') and not unit:IsInCategory('EXTERNALFACTORY') then
                eligible=true
                break
            end
        end
        if not eligible then return false end
    end
    local supported=false
    -- This action targets the rollover unit and preserves the current selection,
    -- so its availability is independent of the selected unit context.
    local resolved=context.resolvedContext
    if resolved=='cursor' and Supports(action.id,'cursor') then supported=true end
    if (resolved=='transport' or resolved=='scout') and Supports(action.id,resolved)
        and HasContext(context.selection,resolved) then supported=true end
    if action.id == 'upgrade_structure_under_cursor' then supported=true end
    if context.absolute and Contains(action.contexts,'empty') then supported=true end
    if context.isRepeat and action.id=='cycle_idle_factories' and MatchesContext(context.selection,'factory') then supported=true end
    if context.legacyUnits and Contains(action.contexts,'other') and MatchesContext(context.selection,'units') then supported=true end
    if not supported then
        if action.continuation=='accumulate' and action.special
            and (string.find(action.special,'^next_engineer_') or action.special=='next_idle_transport') then supported=true end
        for _,kind in ipairs(action.contexts or {}) do
            if MatchesContext(context.selection,kind) then supported=true; break end
        end
    end
    -- A transport can also be a mobile factory, which has a higher general
    -- classification priority. Its pending second press is still a transport.
    if not supported and context.isRepeat and action.id=='select_transport_double'
        and table.getn(context.selection or {})==1
        and context.selection[1]:IsInCategory('TRANSPORTATION') then supported=true end
    if not supported then return false end
    if context.resolvedContext=='cursor' and Supports(action.id,'cursor') then
        return import('/mods/ClaretHotbuild/modules/ContextUpgrade.lua').Available(action.id,context)
    end
    if action.special=='context_upgrade' or action.special=='upgrade_mex' then
        return import('/mods/ClaretHotbuild/modules/ContextUpgrade.lua').Available(action.id,context)
    end
    if action.id=='patrol' or action.id=='repair' or action.id=='capture' or action.id=='teleport' or action.id=='ferry' then
        return HasEligibleUnitCapability(action,context,'order',action.order)
    elseif action.id=='dive' or action.id=='dive_all' or action.id=='undive_all' then
        return HasEligibleUnitCapability(action,context,'order','RULEUCC_Dive')
    elseif action.id=='discharge' then
        return HasEligibleUnitCapability(action,context,'toggle',action.toggle)
    end
    if action.order and not context.orders[action.order] then return false end
    if action.special == 'enhancement' then
        return import('/mods/ClaretHotbuild/modules/ContextEnhancements.lua').Available(action.id,context)
    end
    if action.special == 'append_transport_cargo' then
        for _,unit in ipairs(context.selection or {}) do
            if UnitContext(unit)~='transport' then return false end
        end
        local reui = rawget(_G, 'ReUI')
        if type(reui) ~= 'table' or type(reui.ClaretCore) ~= 'table'
            or type(reui.ClaretCore.AppendTransportCargo) ~= 'function' then return false end
    end
    if action.special == 'fire_beetle' then
        if not context.selection or table.getn(context.selection)==0 then return false end
        for _, unit in ipairs(context.selection) do
            local blueprint=type(unit.GetBlueprint)=='function' and unit:GetBlueprint() or nil
            if not blueprint or blueprint.BlueprintId~='xrl0302' then return false end
        end
    end
    if action.toggle then
        return HasEligibleUnitCapability(action,context,'toggle',action.toggle)
    end
    return true
end

local currentMex

local function SelectNextUnit(category,idleOnly,accumulate)
    local preserveSelection = accumulate ~= false
    local mouse = GetMouseWorldPos()
    if not mouse or type(mouse[1])~='number' or type(mouse[3])~='number' then return false end
    local original = GetSelectedUnits() or {}
    local gameMain = import('/lua/ui/game/gamemain.lua')
    -- Candidate discovery must not notify the UI about the entire category.
    -- SetIgnoreSelection also protects command mode in FAF3840. Restore the
    -- original selection while ignored, then publish only the final addition.
    gameMain.SetIgnoreSelection(true)
    local ok, result = pcall(function()
        local selectedIds = {}
        local nextUnit, bestDistance, bestId
        if preserveSelection then
            for _, unit in ipairs(original) do selectedIds[unit:GetEntityId()] = true end
        end
        local selectionCategory = string.find(category, '^ENGINEER') and ('MOBILE ' .. category) or category
        UISelectionByCategory(selectionCategory, false, false, false, false)
        for _, unit in ipairs(GetSelectedUnits() or {}) do
            local id = unit:GetEntityId()
            local queue = idleOnly and unit:GetCommandQueue() or nil
            local isIdle = not idleOnly or (type(queue)=='table' and table.getn(queue)==0)
            local isMobileEngineer = not string.find(category, '^ENGINEER')
                or (unit:IsInCategory('ENGINEER') and unit:IsInCategory('MOBILE'))
            if isIdle and isMobileEngineer and (not preserveSelection or not selectedIds[id]) and not unit:IsInCategory('COMMAND')
                and not unit:IsInCategory('SUBCOMMANDER') then
                local position = unit:GetPosition()
                if position and type(position[1])=='number' and type(position[3])=='number' then
                    local dx, dz = position[1]-mouse[1], position[3]-mouse[3]
                    local distance = dx*dx + dz*dz
                    if not bestDistance or distance<bestDistance or (distance==bestDistance and id<bestId) then
                        nextUnit, bestDistance, bestId = unit, distance, id
                    end
                end
            end
        end
        if not nextUnit then return false end
        local resultSelection = {}
        if preserveSelection then
            for _, unit in ipairs(original) do table.insert(resultSelection, unit) end
        end
        table.insert(resultSelection, nextUnit)
        return resultSelection
    end)
    local restored, restoreError = pcall(SelectUnits, original)
    local reset, resetError = pcall(gameMain.SetIgnoreSelection, false)
    if not ok then error(result) end
    if not restored then error(restoreError) end
    if not reset then error(resetError) end
    if not result then return false end
    SelectUnits(result)
    return true
end

local function SelectAllIdleTransports()
    local original=GetSelectedUnits() or {}
    local gameMain=import('/lua/ui/game/gamemain.lua')
    gameMain.SetIgnoreSelection(true)
    local ok, idleTransports=pcall(function()
        local result, seen={},{}
        UISelectionByCategory('AIR TRANSPORTATION',false,false,false,false)
        for _,unit in ipairs(GetSelectedUnits() or {}) do
            local queue=unit:GetCommandQueue()
            if type(queue)=='table' and table.getn(queue)==0 then
                local id=unit:GetEntityId()
                if not seen[id] then seen[id]=true; table.insert(result,unit) end
            end
        end
        return result
    end)
    local restored,restoreError=pcall(SelectUnits,original)
    local reset,resetError=pcall(gameMain.SetIgnoreSelection,false)
    if not ok then error(idleTransports) end
    if not restored then error(restoreError) end
    if not reset then error(resetError) end
    if table.getn(idleTransports)==0 then return false end

    local result,seen={},{}
    for _,unit in ipairs(original) do
        local isTransport=unit:IsInCategory('AIR') and unit:IsInCategory('TRANSPORTATION')
        local queue=isTransport and unit:GetCommandQueue() or nil
        local keep=not isTransport or (type(queue)=='table' and table.getn(queue)==0)
        local id=unit:GetEntityId()
        if keep and not seen[id] then seen[id]=true; table.insert(result,unit) end
    end
    for _,unit in ipairs(idleTransports) do
        local id=unit:GetEntityId()
        if not seen[id] then seen[id]=true; table.insert(result,unit) end
    end
    SelectUnits(result)
    return true
end

local function CycleMexes(onScreen)
    local originalSelection=GetSelectedUnits() or {}
    local ok, selected=pcall(function()
        local candidates, seen = {}, {}
        for _, tech in ipairs({'TECH1', 'TECH2'}) do
            UISelectionByCategory('MASSEXTRACTION STRUCTURE ' .. tech, false, onScreen, false, true)
            for _, mex in ipairs(GetSelectedUnits() or {}) do
                if mex:IsInCategory('MASSEXTRACTION') and mex:IsInCategory(tech) then
                    local id=mex:GetEntityId()
                    if not seen[id] then seen[id]=true; table.insert(candidates,mex) end
                end
            end
        end
        table.sort(candidates, function(a, b) return a:GetEntityId() < b:GetEntityId() end)
        local candidate
        for _, mex in ipairs(candidates) do
            if not currentMex or currentMex:IsDead() or mex:GetEntityId() > currentMex:GetEntityId() then
                candidate=mex
                break
            end
        end
        candidate=candidate or candidates[1]
        if candidate then SelectUnits({candidate}) end
        return candidate
    end)
    if not ok then
        pcall(SelectUnits,originalSelection)
        error(selected)
    end
    if not selected then
        local restored, restoreError=pcall(SelectUnits,originalSelection)
        if not restored then error(restoreError) end
        currentMex=nil
        return false
    end
    currentMex=selected
    return true
end

local function SelectFiltered(category,onScreen,predicate)
    local original=GetSelectedUnits() or {}
    local gameMain=import('/lua/ui/game/gamemain.lua')
    gameMain.SetIgnoreSelection(true)
    local ok, satellites=pcall(function()
        UISelectionByCategory(category, false, onScreen, false, false)
        local result={}
        for _,unit in ipairs(GetSelectedUnits() or {}) do
            if predicate(unit) then table.insert(result,unit) end
        end
        return result
    end)
    local restored, restoreError=pcall(SelectUnits,original)
    local reset, resetError=pcall(gameMain.SetIgnoreSelection,false)
    if not ok then error(satellites) end
    if not restored then error(restoreError) end
    if not reset then error(resetError) end
    if table.getn(satellites)==0 then return false end
    SelectUnits(satellites)
    return true
end

local function BlueprintId(unit)
    local blueprint=type(unit.GetBlueprint)=='function' and unit:GetBlueprint() or nil
    return blueprint and blueprint.BlueprintId
end

local function SelectSatellites()
    return SelectFiltered('EXPERIMENTAL',false,function(unit) return BlueprintId(unit)=='xea0002' end)
end

local function SelectLandArmy(onScreen)
    return SelectFiltered('LAND MOBILE',onScreen,function(unit)
        return not unit:IsInCategory('ENGINEER') and BlueprintId(unit)~='xrl0403'
    end)
end

local function SelectMobileLandExperimentals()
    return SelectFiltered('EXPERIMENTAL MOBILE LAND',false,function(unit)
        local id=BlueprintId(unit)
        return id~='xrl0403' and id~='xea0002'
    end)
end

local function SelectAirExperimentals()
    return SelectFiltered('EXPERIMENTAL AIR',false,function(unit) return BlueprintId(unit)~='xea0002' end)
end

local shieldBlueprints={uel0307=true, ual0307=true, xsl0307=true}
local function SelectMobileShields()
    return SelectFiltered('MOBILE SHIELD',true,function(unit)
        return shieldBlueprints[BlueprintId(unit)]==true
    end)
end

local transportSelectors = {
    select_transport=true, select_transport_nearest=true, select_transport_double=true,
    select_transports_accumulate=true, select_all_idle_transports=true,
    select_transport_screen=true, select_transport_map=true,
}

local function WithTransportSelection(callback)
    for _, mod in ipairs(rawget(_G, '__active_mods') or {}) do
        if mod.uid=='advanced-selection-extension-v03' then
            local ok, ase = pcall(import, '/mods/ASE/modules/Main.lua')
            if ok and ase and type(ase.GetIgnored)=='function' and type(ase.SetIgnored)=='function' then
                -- ASE may schedule another selection from its selection hook.
                -- Suspend its filters for discovery and final selection only.
                local previous = ase.GetIgnored()
                ase.SetIgnored(true)
                local called, result = pcall(callback)
                ase.SetIgnored(previous)
                if not called then error(result) end
                return result
            end
            break
        end
    end
    return callback()
end

function Execute(action, context, bindingId)
    if action and context and not context.isReplay and context.focusArmy >= 1
        and IsKeyboardPause(action, context) then
        local selection = KeyboardPauseSelection(context.selection)
        if table.getn(selection) == 0 then return false end
        local paused = not GetIsPaused(selection)
        SetPaused(selection, paused)
        for _, unit in ipairs(selection) do
            if (unit:IsInCategory('EXTERNALFACTORY') or unit:IsInCategory('EXTERNALFACTORYUNIT'))
                and unit:GetFractionComplete() == 1 then
                local creator = unit:GetCreator()
                if creator and not creator:IsDead() then
                    creator:ProcessInfo('SetPaused', tostring(paused))
                end
            end
        end
        return true
    end
    if not Available(action,context) then return false end
    if context.resolvedContext=='cursor' and Supports(action.id,'cursor') then
        return import('/mods/ClaretHotbuild/modules/ContextUpgrade.lua').Execute(action.id,context)
    end
    if action.select then
        -- Empty-selection actions can race a selection change between key dispatch and here.
        if not action.global and not context.absolute and Classify(context.selection)=='empty' and Classify(GetSelectedUnits() or {}) ~= 'empty' then return false end
        if (action.id=='select_transport' or action.id=='select_transport_nearest'
            or action.id=='select_transport_double') and not context.isRepeat then
            return WithTransportSelection(function() return SelectNextUnit('AIR TRANSPORTATION',true,true) end)
        end
        if action.id=='select_acu' then
            if context.absolute then SelectUnits({}) end
            ConExecute('UI_SelectByCategory +inview +nearest COMMAND')
            if table.getn(GetSelectedUnits() or {})==0 then
                ConExecute(action.select)
            end
            return true
        end
        local command = action.selectionPolicy == 'double' and context.isRepeat and action.doubleSelect or action.select
        if transportSelectors[action.id] then
            return WithTransportSelection(function() ConExecute(command); return true end)
        end
        ConExecute(command)
        return true
    end
    local special=action.special
    if special=='context_upgrade' then return import('/mods/ClaretHotbuild/modules/ContextUpgrade.lua').Execute(action.id,context)
    elseif special=='smart_missile' then
        local missileOrder
        for _,unit in ipairs(context.selection or {}) do
            local kind=UnitContext(unit)
            if kind~='acu' and kind~='sacu' and kind~='silo_tactical' and kind~='silo_nuclear' then return false end
            local orders=GetUnitCommandData({unit}) or {}
            local tactical=Contains(orders,'RULEUCC_Tactical')
            local nuclear=Contains(orders,'RULEUCC_Nuke')
            if tactical==nuclear then return false end
            local candidate=tactical and 'RULEUCC_Tactical' or 'RULEUCC_Nuke'
            if missileOrder and missileOrder~=candidate then return false end
            missileOrder=candidate
        end
        if not missileOrder then return false end
        import('/lua/ui/game/commandmode.lua').StartCommandMode('order',{name=missileOrder})
    elseif special=='smart_fighters' then
        import('/lua/keymap/smartselection.lua').smartSelect('AIR HIGHALTAIR ANTIAIR -BOMBER -EXPERIMENTAL')
    elseif special=='select_satellites' then return SelectSatellites()
    elseif special=='select_land_army_screen' then return SelectLandArmy(true)
    elseif special=='select_land_army_map' then return SelectLandArmy(false)
    elseif special=='select_mobile_land_experimentals' then return SelectMobileLandExperimentals()
    elseif special=='select_air_experimentals' then return SelectAirExperimentals()
    elseif special=='select_mobile_shields' then return SelectMobileShields()
    elseif special=='next_engineer_t1' then return SelectNextUnit('ENGINEER TECH1')
    elseif special=='next_engineer_t2' then return SelectNextUnit('ENGINEER TECH2')
    elseif special=='next_engineer_t3' then return SelectNextUnit('ENGINEER TECH3')
    elseif special=='next_engineer_all' then return SelectNextUnit('ENGINEER')
    elseif special=='next_idle_transport' then
        return WithTransportSelection(function() return SelectNextUnit('AIR TRANSPORTATION',true) end)
    elseif special=='select_all_idle_transports' then return WithTransportSelection(SelectAllIdleTransports)
    elseif special=='build_storage_nearest' then
        return import('/mods/ClaretHotbuild/modules/StorageFabs.lua').buildStorageNearest()
    elseif special=='build_fabs_nearest' then
        return import('/mods/ClaretHotbuild/modules/StorageFabs.lua').buildFabsNearest()
    elseif special=='enhancement' then return import('/mods/ClaretHotbuild/modules/ContextEnhancements.lua').Execute(action.id,context)
    elseif special=='append_transport_cargo' then
        local reui = rawget(_G, 'ReUI')
        if type(reui) ~= 'table' or type(reui.ClaretCore) ~= 'table'
            or type(reui.ClaretCore.AppendTransportCargo) ~= 'function' then
            return false
        end
        return reui.ClaretCore.AppendTransportCargo(context.selection)
    elseif special=='create_strategic_rings' or special=='create_vision_ring' then
        local reui = rawget(_G, 'ReUI')
        if type(reui) ~= 'table' or type(reui.ClaretCore) ~= 'table'
            or type(reui.ClaretCore.CreateStrategicRing) ~= 'function' then return false end
        return reui.ClaretCore.CreateStrategicRing(special == 'create_vision_ring')
    elseif special=='fire_beetle' then import('/lua/keymap/misckeyactions.lua').toggleScript('Production')
    elseif special=='overcharge' then import('/lua/ui/game/orders.lua').EnterOverchargeMode()
    elseif special=='attack_move' then
        import('/lua/ui/game/commandmode.lua').StartCommandMode('order',
            {name='RULEUCC_Script',AbilityName='AttackMove',TaskName='AttackMove',Cursor='ATTACK_MOVE'})
    elseif special=='repeat_queue' then
        local all=true
        for _,unit in ipairs(context.selection) do if not unit:IsRepeatQueue() then all=false end end
        for _,unit in ipairs(context.selection) do
            unit:ProcessInfo('SetRepeatQueue',all and 'false' or 'true')
            if unit:IsInCategory('EXTERNALFACTORY') then
                local creator=unit:GetCreator(); if creator and not creator:IsDead() then creator:ProcessInfo('SetRepeatQueue',all and 'false' or 'true') end
            end
        end
    elseif special=='pause' then
        local paused = not GetIsPaused(context.selection)
        SetPaused(context.selection, paused)
        local state = paused and 'true' or 'false'
        for _, unit in ipairs(context.selection) do
            if unit:IsInCategory('EXTERNALFACTORY') then
                local creator = unit:GetCreator()
                if creator and not creator:IsDead() then creator:ProcessInfo('SetPaused', state) end
            end
        end
    elseif special=='cycle_mex_screen' then return CycleMexes(true)
    elseif special=='cycle_mex_map' then return CycleMexes(false)
    elseif special=='upgrade_mex' then
        return import('/mods/ClaretHotbuild/modules/ContextUpgrade.lua').Execute(action.id,context)
    elseif special=='shield' or special=='stealth' then
        import('/lua/keymap/misckeyactions.lua').toggleScript(special=='shield' and 'Shield' or 'Stealth')
    elseif special=='stop' then import('/lua/ui/game/orders.lua').Stop(context.selection)
    elseif special=='soft_stop' then import('/lua/ui/game/orders.lua').SoftStop(context.selection)
    elseif special=='remove_queue' then
        return import('/mods/ClaretHotbuild/modules/ContextQueue.lua').Execute(context)
    elseif action.order then import('/lua/ui/game/commandmode.lua').StartCommandMode('order',{name=action.order})
    else return false end
    return true
end

local function TargetMatches(action, unit)
    if action.id=='cycle_idle_factories' then
        return unit:IsInCategory('FACTORY') or unit:IsInCategory('EXTERNALFACTORY')
    end
    local special=action.special
    local category=action.select and string.gsub(action.select, '^UI_SelectByCategory%s+', '')
    if special=='smart_fighters' then category='AIR HIGHALTAIR ANTIAIR -BOMBER -EXPERIMENTAL'
    elseif special=='select_satellites' then return BlueprintId(unit)=='xea0002'
    elseif special=='select_land_army_screen' or special=='select_land_army_map' then
        category='LAND MOBILE -ENGINEER'; if BlueprintId(unit)=='xrl0403' then return false end
    elseif special=='select_mobile_land_experimentals' then
        category='EXPERIMENTAL MOBILE LAND'; if BlueprintId(unit)=='xrl0403' or BlueprintId(unit)=='xea0002' then return false end
    elseif special=='select_air_experimentals' then
        category='EXPERIMENTAL AIR'; if BlueprintId(unit)=='xea0002' then return false end
    elseif special=='select_mobile_shields' then return shieldBlueprints[BlueprintId(unit)]==true
    elseif special and string.find(special,'^next_engineer_') then
        category='MOBILE ENGINEER'; local _,_,tech=string.find(special,'^next_engineer_(t%d)$')
        if tech then category=category..' TECH'..string.sub(tech,2) end
    elseif special=='next_idle_transport' then category='AIR TRANSPORTATION'
    elseif special=='select_all_idle_transports' then category='AIR TRANSPORTATION'
    end
    if not category then return false end
    local start=1
    while start<=string.len(category) do
        local comma=string.find(category,',',start,true)
        local alternative=string.sub(category,start,comma and comma-1 or string.len(category))
        local matches=true
        local position=1
        while true do
            local first,last=string.find(alternative,'%S+',position)
            if not first then break end
            local token=string.sub(alternative,first,last)
            local prefix=string.sub(token,1,1)
            if token=='+excludeengineers' and unit:IsInCategory('ENGINEER') then
                matches=false; break
            elseif prefix~='+' then
                local name=prefix=='-' and string.sub(token,2) or token
                local has=unit:IsInCategory(name)
                if (prefix=='-' and has) or (prefix~='-' and not has) then matches=false; break end
            end
            position=last+1
        end
        if matches then return true end
        if not comma then break end
        start=comma+1
    end
    return false
end

function SelectionMatches(action, selection)
    if table.getn(selection or {})==0 then return false end
    for _,unit in ipairs(selection) do
        if not TargetMatches(action,unit) then return false end
    end
    return true
end

function ExecuteWithOutcome(action, context, bindingId)
    if not Available(action,context) then return false,'unavailable' end
    if action.select and not context.absolute and Classify(context.selection)=='empty' then
        local current=GetSelectedUnits() or {}
        if Classify(current)~='empty' then
            -- A selection action may have raced with another selection update.
            -- Preserve that update, but treat an already selected target as found.
            for _,unit in ipairs(current) do
                if TargetMatches(action,unit) then return true,'executed' end
            end
            return false,'unavailable'
        end
    end
    local result=Execute(action,context,bindingId)
    if action.special=='next_idle_transport' then return result,result and 'executed' or 'unavailable' end
    if not IsSelection(action.id) then return result,result and 'executed' or 'unavailable' end
    for _,unit in ipairs(GetSelectedUnits() or {}) do
        if TargetMatches(action,unit) then return result or true,'executed' end
    end
    return result,'not_found'
end

