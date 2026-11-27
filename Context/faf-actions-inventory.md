# FAF native key actions

Source: FAF3840 installed snapshot `C:/ProgramData/FAForever/gamedata/lua.nx2`, extracted from `lua/keymap/keyactions.lua`; descriptions from `lua/keymap/keydescriptions.lua`. Checked 2026-11-13. `in_claret` means a semantically corresponding action exists in `../mods/ClaretHotbuild/modules/ContextActions.lua`; it does not imply identical behavior.

## Visual debug actions used by Cinema

Checked the installed archive on 2026-11-27. `lua/keymap/keymapper.lua:194–217` merges `debugKeyActions.lua` into `GetKeyActions()` without enabling debug. In `debugKeyActions.lua`, FPS and network stats are at lines 40–45, frame stats and wireframe at 148–153, skeletons and bone names at 176–181, and collision at 208–209. Collision, navigation, grid, and weapon arcs use `dbg` commands; exposing their definitions does not confirm that the engine accepts them. Cinema's allowlist and session restrictions are owned by `../mods/ClaretCinema/modules/NativeActions.lua`.

## Not in Claret

377 actions: `lock_zoom`, `zoom_pop`, `cam_free`, `RestorePreviousCameraPosition`, `SaveCameraPosition1`, `SaveCameraPosition2`, `SaveCameraPosition3`, `SaveCameraPosition4`, `SaveCameraPosition5`, `SaveCameraPosition6`, `SaveCameraPosition7`, `SaveCameraPosition8`, `SaveCameraPosition9`, `SaveCameraPosition0`, `RestoreCameraPosition1`, `RestoreCameraPosition2`, `RestoreCameraPosition3`, `RestoreCameraPosition4`, `RestoreCameraPosition5`, `RestoreCameraPosition6`, `RestoreCameraPosition7`, `RestoreCameraPosition8`, `RestoreCameraPosition9`, `RestoreCameraPosition0`, `next_cam_position`, `add_cam_position`, `rem_cam_position`, `zoom_in`, `zoom_out`, `zoom_in_fast`, `zoom_out_fast`, `track_unit`, `track_unit_minimap`, `track_unit_second_mon`, `reset_camera`, `cycle_idle_factories`, `cycle_unit_types_in_sel`, `create_template_factory`, `toggle_mdf_panel`, `toggle_tab_display`, `split_next`, `split_major_axis`, `split_minor_axis`, `split_mouse_axis`, `split_mouse_axis_orthogonal`, `split_engineer_tech`, `split_tech`, `split_layer`, `split_into_groups_1`, `split_into_groups_2`, `split_into_groups_4`, `split_into_groups_8`, `split_into_groups_16`, `revert_selection_set`, `group1`, `group2`, `group3`, `group4`, `group5`, `group6`, `group7`, `group8`, `group9`, `group0`, `set_group1`, `set_group2`, `set_group3`, `set_group4`, `set_group5`, `set_group6`, `set_group7`, `set_group8`, `set_group9`, `set_group0`, `append_group1`, `append_group2`, `append_group3`, `append_group4`, `append_group5`, `append_group6`, `append_group7`, `append_group8`, `append_group9`, `append_group0`, `add_selection_to_selection_set1`, `add_selection_to_selection_set2`, `add_selection_to_selection_set3`, `add_selection_to_selection_set4`, `add_selection_to_selection_set5`, `add_selection_to_selection_set6`, `add_selection_to_selection_set7`, `add_selection_to_selection_set8`, `add_selection_to_selection_set9`, `add_selection_to_selection_set0`, `combine_and_select_with_selection_set1`, `combine_and_select_with_selection_set2`, `combine_and_select_with_selection_set3`, `combine_and_select_with_selection_set4`, `combine_and_select_with_selection_set5`, `combine_and_select_with_selection_set6`, `combine_and_select_with_selection_set7`, `combine_and_select_with_selection_set8`, `combine_and_select_with_selection_set9`, `combine_and_select_with_selection_set0`, `fac_group1`, `fac_group2`, `fac_group3`, `fac_group4`, `fac_group5`, `fac_group6`, `fac_group7`, `fac_group8`, `fac_group9`, `fac_group0`, `builders`, `sensors`, `shields`, `tmd`, `xp`, `mobilearty`, `mass`, `massfab`, `pgen`, `templates`, `cycle_templates`, `engystation`, `mml`, `mobileshield`, `fieldengy`, `defense`, `aa`, `torpedo`, `arties`, `tml`, `upgrades`, `alt_builders`, `alt_radars`, `alt_shields`, `alt_tmd`, `alt_xp`, `alt_sonars`, `alt_mass`, `alt_stealth`, `alt_pgen`, `alt_templates`, `alt_engystation`, `alt_defense`, `alt_aa`, `alt_torpedo`, `alt_arties`, `alt_tml`, `land_factory`, `air_factory`, `naval_factory`, `quantum_gateway`, `power_generator`, `hydrocarbon_power_plant`, `mass_extractor`, `mass_fabricator`, `energy_storage`, `mass_storage`, `point_defense`, `anti_air`, `tactical_missile_launcher`, `torpedo_launcher`, `heavy_artillery_installation`, `artillery_installation`, `strategic_missile_launcher`, `radar_system`, `sonar_system`, `omni_sensor`, `tactical_missile_defense`, `shield_generator`, `stealth_field_generator`, `heavy_shield_generator`, `strategic_missile_defense`, `wall_section`, `aeon_quantum_gate_beacon`, `air_staging`, `sonar_platform`, `rapid_fire_artillery_installation`, `quantum_optics_facility`, `engineering_station`, `heavy_point_defense`, `torpedo_ambushing_system`, `perimeter_monitoring_system`, `t2_guided_missile`, `t3_shield_disruptor`, `t2_fighter/bomber`, `t2_gatling_bot`, `t2_rocket_bot`, `t1_air_scout`, `t1_interceptor`, `t1_attack_bomber`, `t2_air_transport`, `t1_light_air_transport`, `t2_gunship`, `t2_torpedo_bomber`, `t3_spy_plane`, `t3_air_superiority_fighter`, `t3_strategic_bomber`, `t1_land_scout`, `t1_mobile_light_artillery`, `t1_mobile_anti_air_gun`, `t1_engineer`, `t1_light_assault_bot`, `t2_mobile_missile_launcher`, `t1_tank`, `t2_heavy_tank`, `t2_mobile_aa_flak_artillery`, `t2_engineer`, `t3_tank`, `t3_mobile_heavy_artillery`, `t2_mobile_shield_generator`, `t3_engineer`, `t1_attack_boat`, `t1_frigate`, `t2_destroyer`, `t2_cruiser`, `t1_attack_submarine`, `t3_battleship`, `t3_aircraft_carrier`, `t3_strategic_missile_submarine`, `t3_heavy_gunship`, `t2_amphibious_tank`, `t1_assault_bot`, `t3_siege_assault_bot`, `t2_mobile_stealth_field_system`, `t2_combat_fighter`, `t3_aa_gunship`, `t3_torpedo_bomber`, `t2_assault_tank`, `t3_sniper_bot`, `t2_submarine_hunter`, `t3_missile_ship`, `t3_heavy_air_transport`, `t2_field_engineer`, `t3_armored_assault_bot`, `t3_mobile_missile_platform`, `t2_torpedo_boat`, `t2_shield_boat`, `t3_battlecruiser`, `t1_light_gunship`, `t2_mobile_bomb`, `t2_submarine_killer`, `t2_counter_intelligence_boat`, `t1_combat_scout`, `t2_assault_bot`, `t2_hover_tank`, `t2_mobile_anti_air_cannon`, `t3_siege_tank`, `t3_mobile_shield_generator`, `t3_submarine_hunter`, `t3_mobile_aa`, `t2_support_factory`, `t2_support_land_factory`, `t2_support_air_factory`, `t2_support_naval_factory`, `t3_support_factory`, `t3_support_land_factory`, `t3_support_air_factory`, `t3_support_naval_factory`, `repair`, `patrol`, `capture`, `stop`, `soft_stop`, `dive`, `dive_all`, `undive_all`, `shift_dive_all`, `shift_undive_all`, `ferry`, `move_hard`, `shift_repair`, `shift_patrol`, `shift_capture`, `shift_stop`, `shift_dive`, `shift_ferry`, `toggle_build_mode`, `pause_unit`, `pause_unit_all`, `unpause_unit_all`, `mode`, `suicide`, `set_default_target_priority`, `toggle_shield`, `toggle_weapon`, `toggle_jamming`, `toggle_intel`, `toggle_production`, `toggle_stealth`, `toggle_generic`, `toggle_special`, `toggle_cloak`, `toggle_all`, `teleport`, `toggle_cloakjammingstealth`, `toggle_intelshield`, `Kill_Selected_Units`, `dock`, `dock_damaged`, `shift_dock`, `shift_dock_damaged`, `load_transports`, `load_transports_clear`, `shift_load_transports`, `shift_load_transports_clear`, `filter_highest_engineer_and_assist`, `shift_filter_highest_engineer_and_assist`, `abort_navigation`, `shift_abort_navigation`, `discharge`, `shift_discharge`, `spreadattack`, `shift_spreadattack`, `spreadattack_context`, `shift_spreadattack_context`, `copy_orders`, `shift_copy_orders`, `cycle_context_based_templates`, `shift_cycle_context_based_templates`, `set_target_priority`, `shift_set_target_priority`, `cap`, `shift_cap`, `upgrade_structure_pause`, `shift_upgrade_structure_pause`, `toggle_lifebars`, `tog_military`, `tog_defense`, `tog_econ`, `switch_layout_up`, `switch_layout_down`, `switch_skin_down`, `switch_skin_up`, `escape`, `pause`, `Render_SelectionSet_Names`, `Render_Custom_Names`, `Render_Unit_Bars`, `Render_Icons`, `Always_Render_Strategic_Icons`, `Show_Bandwidth_Usage`, `Execute_Paste_Buffer`, `decrease_game_speed`, `increase_game_speed`, `reset_game_speed`, `quick_save`, `quick_load`, `toggle_key_bindings`, `create_build_template`, `cap_frame`, `military_overlay`, `intel_overlay`, `show_enemy_life`, `chat_page_up`, `chat_page_down`, `chat_line_up`, `chat_line_down`, `rename`, `split_screen_enable`, `split_screen_disable`, `toggle_notify_customiser`, `toggle_score_screen`, `toggle_mass_fabricator_panel`, `toggle_voting_panel`, `toggle_diplomacy_screen`, `ping_alert`, `ping_move`, `ping_attack`, `ping_marker`, `toggle_main_menu`, `toggle_disconnect_screen`, `toggle_reclaim_labels`, `show_objective_screen`

## Camera (`camera`)

- `lock_zoom` | Lock the zoom to current level | `UI_Lua import("/lua/keymap/misckeyactions.lua").lockZoom()` | in_claret=no
- `zoom_pop` | One-key zoom-pop | `UI_Lua import('/lua/ui/game/zoompopper.lua').ToggleZoomPop()` | in_claret=no
- `cam_free` | Toggles camera free mode | `Cam_Free` | in_claret=no
- `RestorePreviousCameraPosition` | Restore Previous Camera Position | `UI_Lua import("/lua/usercamera.lua").RestorePreviousCameraPosition()` | in_claret=no
- `SaveCameraPosition1` | Save Camera Position1 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(1)` | in_claret=no
- `SaveCameraPosition2` | Save Camera Position2 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(2)` | in_claret=no
- `SaveCameraPosition3` | Save Camera Position3 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(3)` | in_claret=no
- `SaveCameraPosition4` | Save Camera Position4 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(4)` | in_claret=no
- `SaveCameraPosition5` | Save Camera Position5 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(5)` | in_claret=no
- `SaveCameraPosition6` | Save Camera Position6 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(6)` | in_claret=no
- `SaveCameraPosition7` | Save Camera Position7 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(7)` | in_claret=no
- `SaveCameraPosition8` | Save Camera Position8 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(8)` | in_claret=no
- `SaveCameraPosition9` | Save Camera Position9 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(9)` | in_claret=no
- `SaveCameraPosition0` | Save Camera Position0 | `UI_Lua import("/lua/usercamera.lua").SaveCameraPosition(0)` | in_claret=no
- `RestoreCameraPosition1` | Restore Camera Position1 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(1)` | in_claret=no
- `RestoreCameraPosition2` | Restore Camera Position2 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(2)` | in_claret=no
- `RestoreCameraPosition3` | Restore Camera Position3 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(3)` | in_claret=no
- `RestoreCameraPosition4` | Restore Camera Position4 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(4)` | in_claret=no
- `RestoreCameraPosition5` | Restore Camera Position5 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(5)` | in_claret=no
- `RestoreCameraPosition6` | Restore Camera Position6 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(6)` | in_claret=no
- `RestoreCameraPosition7` | Restore Camera Position7 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(7)` | in_claret=no
- `RestoreCameraPosition8` | Restore Camera Position8 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(8)` | in_claret=no
- `RestoreCameraPosition9` | Restore Camera Position9 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(9)` | in_claret=no
- `RestoreCameraPosition0` | Restore Camera Position0 | `UI_Lua import("/lua/usercamera.lua").RestoreCameraPosition(0)` | in_claret=no
- `next_cam_position` | Go to the next saved Camera Position | `UI_Lua import("/lua/ui/game/zoomslider.lua").RecallCameraPos()` | in_claret=no
- `add_cam_position` | Save a Camera Position | `UI_Lua import("/lua/ui/game/zoomslider.lua").SaveCameraPos()` | in_claret=no
- `rem_cam_position` | Delete current Camera Position | `UI_Lua import("/lua/ui/game/zoomslider.lua").RemoveCamPos()` | in_claret=no
- `zoom_in` | Zoom your View in | `UI_Lua import("/lua/ui/game/zoomslider.lua").ZoomIn(.02)` | in_claret=no
- `zoom_out` | Zoom your View out | `UI_Lua import("/lua/ui/game/zoomslider.lua").ZoomOut(.02)` | in_claret=no
- `zoom_in_fast` | Zoom your View in fast | `UI_Lua import("/lua/ui/game/zoomslider.lua").ZoomIn(.08)` | in_claret=no
- `zoom_out_fast` | Zoom your View out fast | `UI_Lua import("/lua/ui/game/zoomslider.lua").ZoomOut(.08)` | in_claret=no
- `track_unit` | Track a unit in the Primary view | `UI_TrackUnit WorldCamera` | in_claret=no
- `track_unit_minimap` | Track a unit in the Strategic view | `UI_TrackUnit MiniMap` | in_claret=no
- `track_unit_second_mon` | Track a unit on the Second Monitor | `UI_TrackUnit CameraHead2` | in_claret=no
- `reset_camera` | Reset the Camera | `UI_Lua import("/lua/ui/game/zoomslider.lua").ToggleWideView()` | in_claret=no

## Selection (`selection`)

- `cycle_idle_factories` | Cycle through idle factories | `UI_Lua import("/lua/keymap/misckeyactions.lua").CycleIdleFactories()` | in_claret=no
- `cycle_unit_types_in_sel` | Cycle through unit types in selection (Land, Sea, Air) | `UI_Lua import("/lua/keymap/misckeyactions.lua").CycleUnitTypesInSel()` | in_claret=no
- `create_template_factory` | Create a factory build queue template based on the currently selected factory | `UI_Lua import("/lua/keymap/misckeyactions.lua").CreateTemplateFactory()` | in_claret=no
- `select_upgrading_extractors` | Select all extractors that are upgrading | `UI_Lua import("/lua/keymap/misckeyactions.lua").SelectAllUpgradingExtractors()` | in_claret=yes
- `select_air` | Select all Air units | `UI_SelectByCategory +excludeengineers AIR MOBILE` | in_claret=yes
- `select_naval` | Select all Naval units | `UI_SelectByCategory +excludeengineers NAVAL MOBILE` | in_claret=yes
- `select_naval_no_mobile_sonar` | Select all Naval units without sonar platforms | `UI_Lua import("/lua/keymap/smartselection.lua").smartSelect("NAVAL MOBILE -MOBIL…` | in_claret=yes
- `select_land` | Select all Land units | `UI_SelectByCategory +excludeengineers LAND MOBILE` | in_claret=yes
- `select_all_units_of_same_type` | Select all units similar to those selected | `UI_ExpandCurrentSelection` | in_claret=yes
- `select_engineers` | Select all Engineers | `UI_SelectByCategory ENGINEER` | in_claret=yes
- `goto_engineer` | Go to the nearest idle Engineer | `UI_SelectByCategory +nearest +idle +goto ENGINEER` | in_claret=yes
- `select_idle_engineer` | Select the nearest idle Engineer | `UI_SelectByCategory +nearest +idle ENGINEER` | in_claret=yes
- `select_idle_t1_engineer` | Select the nearest idle tech 1 Engineer | `UI_SelectByCategory +nearest +idle ENGINEER TECH1` | in_claret=yes
- `cycle_engineers` | Cycle through all Engineers | `UI_Lua import("/lua/ui/game/avatars.lua").GetEngineerGeneric()` | in_claret=yes
- `goto_commander` | Go to your ACU | `UI_Lua import("/lua/keymap/misckeyactions.lua").SelectCommander(true)` | in_claret=yes
- `select_commander` | Select your ACU | `UI_Lua import("/lua/keymap/misckeyactions.lua").SelectCommander(false)` | in_claret=yes
- `select_all` | Select all units | `UI_SelectByCategory ALLUNITS` | in_claret=yes
- `select_all_onscreen` | Select all units on the screen | `UI_SelectByCategory +inview ALLUNITS` | in_claret=yes
- `select_all_eng_onscreen` | Select all Engineers on the screen | `UI_SelectByCategory +inview ENGINEER` | in_claret=yes
- `select_all_factory_onscreen` | Select all Factories on the screen | `UI_SelectByCategory +inview FACTORY` | in_claret=yes
- `select_nearest_factory` | Select the nearest Factory | `UI_SelectByCategory +nearest FACTORY` | in_claret=yes
- `select_all_mobile_factory_onscreen` | Select all Mobile Factories on the screen | `UI_SelectByCategory +inview EXTERNALFACTORYUNIT` | in_claret=yes
- `select_nearest_mobile_factory` | Select the nearest Mobile Factory | `UI_SelectByCategory +nearest EXTERNALFACTORYUNIT` | in_claret=yes
- `select_nearest_land_factory` | Select the nearest Land Factory | `UI_SelectByCategory +nearest LAND FACTORY` | in_claret=yes
- `select_nearest_air_factory` | Select the nearest Air Factory | `UI_SelectByCategory +nearest AIR FACTORY` | in_claret=yes
- `select_nearest_naval_factory` | Select the nearest Naval Factory | `UI_SelectByCategory +nearest NAVAL FACTORY` | in_claret=yes
- `select_all_radars` | Select all radars | `UI_SelectByCategory INTELLIGENCE STRUCTURE RADAR, INTELLIGENCE STRUCTURE OMNI` | in_claret=yes
- `select_all_idle_eng_onscreen` | Select idle engineers on screen | `UI_SelectByCategory +inview +idle ENGINEER` | in_claret=yes
- `select_all_building_eng` | Select all engineers that are requesting resources | `UI_Lua import("/lua/keymap/misckeyactions.lua").SelectAllBuildingEngineers()` | in_claret=yes
- `select_all_building_eng_onscreen` | Select all engineers that are requesting resources on screen | `UI_Lua import("/lua/keymap/misckeyactions.lua").SelectAllBuildingEngineers(true)` | in_claret=yes
- `select_all_resource_consumers` | Select all units that are requesting resources | `UI_Lua import("/lua/keymap/misckeyactions.lua").SelectAllResourceConsumers()` | in_claret=yes
- `select_all_resource_consumers_onscreen` | Select all units that are requesting resources on screen | `UI_Lua import("/lua/keymap/misckeyactions.lua").SelectAllResourceConsumers(true)` | in_claret=yes
- `select_all_land_units_onscreen` | Select land units on screen | `UI_SelectByCategory +inview +excludeengineers MOBILE LAND` | in_claret=yes
- `select_all_air_units_onscreen` | Select air units on screen | `UI_SelectByCategory +inview MOBILE AIR` | in_claret=yes
- `select_all_naval_units_onscreen` | Select naval units on screen | `UI_SelectByCategory +inview MOBILE NAVAL` | in_claret=yes
- `select_all_similar_units` | Select all similarly upgraded units | `UI_Lua import("/lua/keymap/misckeyactions.lua").GetSimilarUnits()` | in_claret=yes
- `select_next_land_factory` | Select next land factory | `UI_Lua import("/lua/keymap/misckeyactions.lua").GetNextLandFactory()` | in_claret=yes
- `select_next_air_factory` | Select next air factory | `UI_Lua import("/lua/keymap/misckeyactions.lua").GetNextAirFactory()` | in_claret=yes
- `select_next_naval_factory` | Select next naval factory | `UI_Lua import("/lua/keymap/misckeyactions.lua").GetNextNavalFactory()` | in_claret=yes
- `select_inview_idle_mex` | Select onscreen idle mass extractors. | `UI_SelectByCategory +inview +idle MASSEXTRACTION` | in_claret=yes
- `select_all_mex` | Select all mass extractors. | `UI_SelectByCategory MASSEXTRACTION` | in_claret=yes
- `select_nearest_idle_lt_mex` | Select nearest onscreen lowest tech idle mass extractor. | `UI_Lua import("/lua/keymap/misckeyactions.lua").GetNearestIdleLTMex()` | in_claret=yes
- `acu_select_cg` | Select ACU (double tap to zoom) | `UI_Lua import("/lua/keymap/misckeyactions.lua").ACUSelectCG()` | in_claret=yes
- `acu_append_cg` | Append ACU to selection (double tap to zoom) | `UI_Lua import("/lua/keymap/misckeyactions.lua").ACUAppendCG()` | in_claret=yes
- `select_nearest_idle_eng_not_acu` | Select nearest idle engineer (not ACU) | `UI_Lua import("/lua/keymap/misckeyactions.lua").GetNearestIdleEngineerNotACU()` | in_claret=yes
- `add_nearest_idle_engineers_seq` | Select/Add nearest idle engineers | `UI_Lua import("/lua/keymap/misckeyactions.lua").AddNearestIdleEngineersSeq()` | in_claret=yes
- `select_gunships` | Select all Gunships | `UI_SelectByCategory AIR GROUNDATTACK` | in_claret=yes
- `select_bombers` | Select all Bombers | `UI_SelectByCategory AIR BOMBER` | in_claret=yes
- `select_surface_bombers` | Select all Bombers (Normal) | `UI_Lua import("/lua/keymap/smartselection.lua").smartSelect("AIR BOMBER -ANTINAV…` | in_claret=yes
- `select_torpedo_bombers` | Select all Bombers (Torpedo) | `UI_SelectByCategory AIR BOMBER ANTINAVY` | in_claret=yes
- `select_anti_air_fighters` | Select all Air Fighters | `UI_Lua import("/lua/keymap/smartselection.lua").smartSelect("AIR HIGHALTAIR ANTI…` | in_claret=yes
- `select_nearest_idle_airscout` | Select nearest idle Air Scout | `UI_SelectByCategory AIR INTELLIGENCE +nearest +idle` | in_claret=yes
- `select_all_idle_airscouts` | Select all idle Air Scouts | `UI_SelectByCategory AIR INTELLIGENCE +idle` | in_claret=yes
- `select_all_tml` | Select all TML | `UI_SelectByCategory STRUCTURE TACTICALMISSILEPLATFORM` | in_claret=yes
- `select_all_stationdrones` | Select all Drones | `UI_SelectByCategory AIR STATIONASSISTPOD` | in_claret=yes
- `select_all_t2_podstations` | Select all T2 Engineering Podstations | `UI_SelectByCategory STRUCTURE PODSTAGINGPLATFORM TECH2` | in_claret=yes
- `select_all_air_exp` | Select all Air Experimentals | `UI_SelectByCategory AIR EXPERIMENTAL` | in_claret=yes
- `select_all_antinavy_subs` | Select all anti-Navy Submarines | `UI_SelectByCategory SUBMERSIBLE OVERLAYANTINAVY` | in_claret=yes
- `select_all_land_exp` | Select all Land Experimentals | `UI_SelectByCategory LAND MOBILE OVERLAYDIRECTFIRE EXPERIMENTAL` | in_claret=yes
- `select_all_land_indirectfire` | Select all Land Indirect-Fire units | `UI_SelectByCategory LAND OVERLAYINDIRECTFIRE` | in_claret=yes
- `select_all_land_directfire` | Select all Land Direct-Fire units | `UI_SelectByCategory +excludeengineers LAND OVERLAYDIRECTFIRE` | in_claret=yes
- `select_all_air_factories` | Select all Air Factories | `UI_SelectByCategory STRUCTURE FACTORY AIR` | in_claret=yes
- `select_all_land_factories` | Select all Land Factories | `UI_SelectByCategory STRUCTURE FACTORY LAND` | in_claret=yes
- `select_all_naval_factories` | Select all Naval Factories | `UI_SelectByCategory STRUCTURE FACTORY NAVAL` | in_claret=yes
- `select_all_t1_engineers` | Select all T1 Engineers | `UI_SelectByCategory LAND TECH1 ENGINEER` | in_claret=yes
- `select_all_battleships` | Select all Battleships | `UI_SelectByCategory NAVAL BATTLESHIP` | in_claret=yes
- `select_air_no_transport` | Select air but no transports | `UI_Lua import("/lua/keymap/misckeyactions.lua").airNoTransports()` | in_claret=yes
- `select_air_transport` | Select only transports | `UI_Lua import("/lua/keymap/misckeyactions.lua").airTransports()` | in_claret=yes
- `create_build_template` | Create a build template based on the current selection | `UI_Lua import("/lua/ui/game/build_templates.lua").CreateBuildTemplate()` | in_claret=no

## Selection subgroups (`selectionSubgroups`)

- `split_next` | Select the next subgroup, or the original selection if there is no next subgroup | `UI_Lua import("/lua/ui/game/selection.lua").SplitNext()` | in_claret=no
- `split_major_axis` | Divides a selection over the major axis of the selected units | `UI_Lua import("/lua/ui/game/selection.lua").SplitMajorAxis()` | in_claret=no
- `split_minor_axis` | Divides a selection over the minor axis of the selected units | `UI_Lua import("/lua/ui/game/selection.lua").SplitMinorAxis()` | in_claret=no
- `split_mouse_axis` | Divides a selection by the line through your mouse position and the center of the selection | `UI_Lua import("/lua/ui/game/selection.lua").SplitMouseAxis()` | in_claret=no
- `split_mouse_axis_orthogonal` | Divides a selection orthogonally to the line from your mouse position to the center of the selection | `UI_Lua import("/lua/ui/game/selection.lua").SplitMouseOrthogonalAxis()` | in_claret=no
- `split_engineer_tech` | Divides a selection over SACUs, tech 3, tech 2 and tech 1 engineers | `UI_Lua import("/lua/ui/game/selection.lua").SplitEngineerTech()` | in_claret=no
- `split_tech` | Divides a selection over experimentals, SACUs, tech 3, tech 2 and tech 1 units | `UI_Lua import("/lua/ui/game/selection.lua").SplitTech()` | in_claret=no
- `split_layer` | Divides a selection over land, naval and air units | `UI_Lua import("/lua/ui/game/selection.lua").SplitLayer()` | in_claret=no
- `split_into_groups_1` | Divides a selection over subgroups of 1 unit | `UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(1)` | in_claret=no
- `split_into_groups_2` | Divides a selection over subgroups of 2 units | `UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(2)` | in_claret=no
- `split_into_groups_4` | Divides a selection over subgroups of 4 units | `UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(4)` | in_claret=no
- `split_into_groups_8` | Divides a selection over subgroups of 8 units | `UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(8)` | in_claret=no
- `split_into_groups_16` | Divides a selection over subgroups of 16 units | `UI_Lua import("/lua/ui/game/selection.lua").SplitIntoGroups(16)` | in_claret=no

## Selection control groups (`selectionControlGroups`)

- `revert_selection_set` | Restore selection to the one before recalling a control group | `UI_Lua import("/lua/ui/game/selection.lua").RevertSelectionSet()` | in_claret=no
- `group1` | Recall Group 1 | `UI_ApplySelectionSet 1` | in_claret=no
- `group2` | Recall Group 2 | `UI_ApplySelectionSet 2` | in_claret=no
- `group3` | Recall Group 3 | `UI_ApplySelectionSet 3` | in_claret=no
- `group4` | Recall Group 4 | `UI_ApplySelectionSet 4` | in_claret=no
- `group5` | Recall Group 5 | `UI_ApplySelectionSet 5` | in_claret=no
- `group6` | Recall Group 6 | `UI_ApplySelectionSet 6` | in_claret=no
- `group7` | Recall Group 7 | `UI_ApplySelectionSet 7` | in_claret=no
- `group8` | Recall Group 8 | `UI_ApplySelectionSet 8` | in_claret=no
- `group9` | Recall Group 9 | `UI_ApplySelectionSet 9` | in_claret=no
- `group0` | Recall Group 10 | `UI_ApplySelectionSet 0` | in_claret=no
- `set_group1` | Set Group 1 | `UI_MakeSelectionSet 1` | in_claret=no
- `set_group2` | Set Group 2 | `UI_MakeSelectionSet 2` | in_claret=no
- `set_group3` | Set Group 3 | `UI_MakeSelectionSet 3` | in_claret=no
- `set_group4` | Set Group 4 | `UI_MakeSelectionSet 4` | in_claret=no
- `set_group5` | Set Group 5 | `UI_MakeSelectionSet 5` | in_claret=no
- `set_group6` | Set Group 6 | `UI_MakeSelectionSet 6` | in_claret=no
- `set_group7` | Set Group 7 | `UI_MakeSelectionSet 7` | in_claret=no
- `set_group8` | Set Group 8 | `UI_MakeSelectionSet 8` | in_claret=no
- `set_group9` | Set Group 9 | `UI_MakeSelectionSet 9` | in_claret=no
- `set_group0` | Set Group 10 | `UI_MakeSelectionSet 0` | in_claret=no
- `append_group1` | Append control group 1 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(1)` | in_claret=no
- `append_group2` | Append control group 2 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(2)` | in_claret=no
- `append_group3` | Append control group 3 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(3)` | in_claret=no
- `append_group4` | Append control group 4 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(4)` | in_claret=no
- `append_group5` | Append control group 5 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(5)` | in_claret=no
- `append_group6` | Append control group 6 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(6)` | in_claret=no
- `append_group7` | Append control group 7 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(7)` | in_claret=no
- `append_group8` | Append control group 8 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(8)` | in_claret=no
- `append_group9` | Append control group 9 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(9)` | in_claret=no
- `append_group0` | Append control group 10 to current selection | `UI_Lua import("/lua/ui/game/selection.lua").AppendSetToSelection(0)` | in_claret=no
- `add_selection_to_selection_set1` | Append the current selection to control group 1 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(1)` | in_claret=no
- `add_selection_to_selection_set2` | Append the current selection to control group 2 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(2)` | in_claret=no
- `add_selection_to_selection_set3` | Append the current selection to control group 3 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(3)` | in_claret=no
- `add_selection_to_selection_set4` | Append the current selection to control group 4 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(4)` | in_claret=no
- `add_selection_to_selection_set5` | Append the current selection to control group 5 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(5)` | in_claret=no
- `add_selection_to_selection_set6` | Append the current selection to control group 6 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(6)` | in_claret=no
- `add_selection_to_selection_set7` | Append the current selection to control group 7 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(7)` | in_claret=no
- `add_selection_to_selection_set8` | Append the current selection to control group 8 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(8)` | in_claret=no
- `add_selection_to_selection_set9` | Append the current selection to control group 9 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(9)` | in_claret=no
- `add_selection_to_selection_set0` | Append the current selection to control group 0 | `UI_Lua import("/lua/ui/game/selection.lua").AppendSelectionToSet(0)` | in_claret=no
- `combine_and_select_with_selection_set1` | Combine selection and control group 1 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(1)` | in_claret=no
- `combine_and_select_with_selection_set2` | Combine selection and control group 2 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(2)` | in_claret=no
- `combine_and_select_with_selection_set3` | Combine selection and control group 3 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(3)` | in_claret=no
- `combine_and_select_with_selection_set4` | Combine selection and control group 4 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(4)` | in_claret=no
- `combine_and_select_with_selection_set5` | Combine selection and control group 5 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(5)` | in_claret=no
- `combine_and_select_with_selection_set6` | Combine selection and control group 6 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(6)` | in_claret=no
- `combine_and_select_with_selection_set7` | Combine selection and control group 7 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(7)` | in_claret=no
- `combine_and_select_with_selection_set8` | Combine selection and control group 8 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(8)` | in_claret=no
- `combine_and_select_with_selection_set9` | Combine selection and control group 9 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(9)` | in_claret=no
- `combine_and_select_with_selection_set0` | Combine selection and control group 0 and select the control group | `UI_Lua import("/lua/ui/game/selection.lua").CombineSelectionAndSet(0)` | in_claret=no
- `fac_group1` | Select only factories from Group 1 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(1)` | in_claret=no
- `fac_group2` | Select only factories from Group 2 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(2)` | in_claret=no
- `fac_group3` | Select only factories from Group 3 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(3)` | in_claret=no
- `fac_group4` | Select only factories from Group 4 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(4)` | in_claret=no
- `fac_group5` | Select only factories from Group 5 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(5)` | in_claret=no
- `fac_group6` | Select only factories from Group 6 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(6)` | in_claret=no
- `fac_group7` | Select only factories from Group 7 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(7)` | in_claret=no
- `fac_group8` | Select only factories from Group 8 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(8)` | in_claret=no
- `fac_group9` | Select only factories from Group 9 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(9)` | in_claret=no
- `fac_group0` | Select only factories from Group 10 | `UI_Lua import("/lua/ui/game/selection.lua").FactorySelection(0)` | in_claret=no

## Hotbuilding (`hotbuilding`)

- `builders` | build builders (factories, Quantum Gate & T1 engineers) | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Builders")` | in_claret=no
- `sensors` | build sensors + T1 sub marines | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Sensors")` | in_claret=no
- `shields` | build shields/steath fields + LAB + Interceptors + Frigates | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Shields")` | in_claret=no
- `tmd` | build Tactical Missiles Defense + T1 Tanks + T1 Bombers + Attack boat | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("TMD")` | in_claret=no
- `xp` | build experimentals + mobile T1 AA + T1 light Transports | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("XP")` | in_claret=no
- `mobilearty` | build T1 artilleries + T1 light gunship | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Mobilearty")` | in_claret=no
- `mass` | build mass extractors + T2 Engineers | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Mass")` | in_claret=no
- `massfab` | build mass fabricators + T2 Bots + T2 air fighters + T2 subs | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("MassFab")` | in_claret=no
- `pgen` | build power generators + T2 Tanks + T2 Torpedo Bombers + T2 Destroyers | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Pgen")` | in_claret=no
- `templates` | cycle user templates & build T2 Hover Tanks + T2 Gunships + T2 Cruisers | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Templates")` | in_claret=no
- `cycle_templates` | cycle context templates & build T2 Hover Tanks + T2 Gunships + T2 Cruisers | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Cycle_Templates")` | in_claret=no
- `engystation` | build engineers stations + T2 Mobile AA + T2 Air Transports + T2 Boats | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("EngyStation")` | in_claret=no
- `mml` | build Mobile Missiles launchers + T2 Air Guided Missile (mercy) | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("MML")` | in_claret=no
- `mobileshield` | build T2 Mobiles Shields and mobile Stealth fields | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("MobileShield")` | in_claret=no
- `fieldengy` | build UEF T2 Field Engineer | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("FieldEngy")` | in_claret=no
- `defense` | build Point Defenses + walls + T3 Engineers | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Defense")` | in_claret=no
- `aa` | build Anti Air + Air Staging Facilities + T3 Assault bots + Snipers + T3 Air scouts + T3 Subs | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("AA")` | in_claret=no
- `torpedo` | build Torpedo defenses + T3 Heavy bots + ASF + Battleships | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Torpedo")` | in_claret=no
- `arties` | build Artilleries defenses + T3 Strategic Bombers + Aircraft Carriers + Battlecruiser | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Arties")` | in_claret=no
- `tml` | build Tactical Missile Launchers + Shield disruptors + T3 mobile shields + T3 gunships + Missile Ship | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("TML")` | in_claret=no
- `upgrades` | build Upgrades + T3 Mobile Anti Air + T3 Air Transport + T3 torpedo bomber | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Upgrades")` | in_claret=no

## Hotbuilding (extra) (`hotbuildingExtra`)

- `land_factory` | build Land Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Land_Factory")` | in_claret=no
- `air_factory` | build Air Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Air_Factory")` | in_claret=no
- `naval_factory` | build Naval Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Naval_Factory")` | in_claret=no
- `quantum_gateway` | build Quantum Gateway | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Quantum_Gateway")` | in_claret=no
- `power_generator` | build Power Generator | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Power_Generator")` | in_claret=no
- `hydrocarbon_power_plant` | build Hydrocarbon Power Plant | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Hydrocarbon_Power_Plant")` | in_claret=no
- `mass_extractor` | build Mass Extractor | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Mass_Extractor")` | in_claret=no
- `mass_fabricator` | build Mass Fabricator | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Mass_Fabricator")` | in_claret=no
- `energy_storage` | build Energy Storage | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Energy_Storage")` | in_claret=no
- `mass_storage` | build Mass Storage | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Mass_Storage")` | in_claret=no
- `point_defense` | build Point Defense | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Point_Defense")` | in_claret=no
- `anti_air` | build Anti Air | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Anti_Air")` | in_claret=no
- `tactical_missile_launcher` | build Tactical Missile Launcher | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Tactical_Missile_Launcher")` | in_claret=no
- `torpedo_launcher` | build Torpedo Launcher | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Torpedo_Launcher")` | in_claret=no
- `heavy_artillery_installation` | build Heavy Artillery Installation | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Heavy_Artillery_Installat…` | in_claret=no
- `artillery_installation` | build Artillery Installation | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Artillery_Installation")` | in_claret=no
- `strategic_missile_launcher` | build Strategic Missile Launcher | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Strategic_Missile_Launcher")` | in_claret=no
- `radar_system` | build Radar System | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Radar_System")` | in_claret=no
- `sonar_system` | build Sonar System | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Sonar_System")` | in_claret=no
- `omni_sensor` | build Omni Sensor | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Omni_Sensor")` | in_claret=no
- `tactical_missile_defense` | build Tactical Missile Defense | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Tactical_Missile_Defense")` | in_claret=no
- `shield_generator` | build Shield Generator | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Shield_Generator")` | in_claret=no
- `stealth_field_generator` | build Stealth Field Generator | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Stealth_Field_Generator")` | in_claret=no
- `heavy_shield_generator` | build Heavy Shield Generator | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Heavy_Shield_Generator")` | in_claret=no
- `strategic_missile_defense` | build Strategic Missile Defense | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Strategic_Missile_Defense")` | in_claret=no
- `wall_section` | build Wall Section | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Wall_Section")` | in_claret=no
- `aeon_quantum_gate_beacon` | build Aeon Quantum Gate Beacon | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Aeon_Quantum_Gate_Beacon")` | in_claret=no
- `air_staging` | build Air Staging | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Air_Staging")` | in_claret=no
- `sonar_platform` | build Sonar Platform | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Sonar_Platform")` | in_claret=no
- `rapid_fire_artillery_installation` | build Rapid Fire Artillery Installation | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Rapid_Fire_Artillery_Inst…` | in_claret=no
- `quantum_optics_facility` | build Quantum Optics Facility | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Quantum_Optics_Facility")` | in_claret=no
- `engineering_station` | build Engineering Station | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Engineering_Station")` | in_claret=no
- `heavy_point_defense` | build Heavy Point Defense | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Heavy_Point_Defense")` | in_claret=no
- `torpedo_ambushing_system` | build Torpedo Ambushing System | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Torpedo_Ambushing_System")` | in_claret=no
- `perimeter_monitoring_system` | build Perimeter Monitoring System | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("Perimeter_Monitoring_System")` | in_claret=no
- `t2_guided_missile` | build T2 Guided Missile | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Guided_Missile")` | in_claret=no
- `t3_shield_disruptor` | build T3 Shield Disruptor | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Shield_Disruptor")` | in_claret=no
- `t2_fighter/bomber` | build T2 Fighter/Bomber | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Fighter/Bomber")` | in_claret=no
- `t2_gatling_bot` | build T2 Gatling Bot | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Gatling_Bot")` | in_claret=no
- `t2_rocket_bot` | build T2 Rocket Bot | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Rocket_Bot")` | in_claret=no
- `t1_air_scout` | build T1 Air Scout | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Air_Scout")` | in_claret=no
- `t1_interceptor` | build T1 Interceptor | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Interceptor")` | in_claret=no
- `t1_attack_bomber` | build T1 Attack Bomber | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Attack_Bomber")` | in_claret=no
- `t2_air_transport` | build T2 Air Transport | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Air_Transport")` | in_claret=no
- `t1_light_air_transport` | build T1 Light Air Transport | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Light_Air_Transport")` | in_claret=no
- `t2_gunship` | build T2 Gunship | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Gunship")` | in_claret=no
- `t2_torpedo_bomber` | build T2 Torpedo Bomber | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Torpedo_Bomber")` | in_claret=no
- `t3_spy_plane` | build T3 Spy Plane | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Spy_Plane")` | in_claret=no
- `t3_air_superiority_fighter` | build T3 Air Superiority Fighter | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Air_Superiority_Fighter")` | in_claret=no
- `t3_strategic_bomber` | build T3 Strategic Bomber | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Strategic_Bomber")` | in_claret=no
- `t1_land_scout` | build T1 Land Scout | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Land_Scout")` | in_claret=no
- `t1_mobile_light_artillery` | build T1 Mobile Light Artillery | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Mobile_Light_Artillery")` | in_claret=no
- `t1_mobile_anti_air_gun` | build T1 Mobile Anti Air Gun | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Mobile_Anti_Air_Gun")` | in_claret=no
- `t1_engineer` | build T1 Engineer | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Engineer")` | in_claret=no
- `t1_light_assault_bot` | build T1 Light Assault Bot | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Light_Assault_Bot")` | in_claret=no
- `t2_mobile_missile_launcher` | build T2 Mobile Missile Launcher | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Mobile_Missile_Launcher")` | in_claret=no
- `t1_tank` | build T1 Tank | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Tank")` | in_claret=no
- `t2_heavy_tank` | build T2 Heavy Tank | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Heavy_Tank")` | in_claret=no
- `t2_mobile_aa_flak_artillery` | build T2 Mobile AA Flak Artillery | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Mobile_AA_Flak_Artillery")` | in_claret=no
- `t2_engineer` | build T2 Engineer | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Engineer")` | in_claret=no
- `t3_tank` | build T3 Tank | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Tank")` | in_claret=no
- `t3_mobile_heavy_artillery` | build T3 Mobile Heavy Artillery | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Mobile_Heavy_Artillery")` | in_claret=no
- `t2_mobile_shield_generator` | build T2 Mobile Shield Generator | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Mobile_Shield_Generator")` | in_claret=no
- `t3_engineer` | build T3 Engineer | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Engineer")` | in_claret=no
- `t1_attack_boat` | build T1 Attack Boat | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Attack_Boat")` | in_claret=no
- `t1_frigate` | build T1 Frigate | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Frigate")` | in_claret=no
- `t2_destroyer` | build T2 Destroyer | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Destroyer")` | in_claret=no
- `t2_cruiser` | build T2 Cruiser | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Cruiser")` | in_claret=no
- `t1_attack_submarine` | build T1 Attack Submarine | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Attack_Submarine")` | in_claret=no
- `t3_battleship` | build T3 Battleship | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Battleship")` | in_claret=no
- `t3_aircraft_carrier` | build T3 Aircraft Carrier | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Aircraft_Carrier")` | in_claret=no
- `t3_strategic_missile_submarine` | build T3 Strategic Missile Submarine | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Strategic_Missile_Subm…` | in_claret=no
- `t3_heavy_gunship` | build T3 Heavy Gunship | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Heavy_Gunship")` | in_claret=no
- `t2_amphibious_tank` | build T2 Amphibious Tank | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Amphibious_Tank")` | in_claret=no
- `t1_assault_bot` | build T1 Assault Bot | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Assault_Bot")` | in_claret=no
- `t3_siege_assault_bot` | build T3 Siege Assault Bot | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Siege_Assault_Bot")` | in_claret=no
- `t2_mobile_stealth_field_system` | build T2 Mobile Stealth Field System | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Mobile_Stealth_Field_S…` | in_claret=no
- `t2_combat_fighter` | build T2 Combat Fighter | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Combat_Fighter")` | in_claret=no
- `t3_aa_gunship` | build T3 AA Gunship | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_AA_Gunship")` | in_claret=no
- `t3_torpedo_bomber` | build T3 Torpedo Bomber | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Torpedo_Bomber")` | in_claret=no
- `t2_assault_tank` | build T2 Assault Tank | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Assault_Tank")` | in_claret=no
- `t3_sniper_bot` | build T3 Sniper Bot | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Sniper_Bot")` | in_claret=no
- `t2_submarine_hunter` | build T2 Submarine Hunter | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Submarine_Hunter")` | in_claret=no
- `t3_missile_ship` | build T3 Missile Ship | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Missile_Ship")` | in_claret=no
- `t3_heavy_air_transport` | build T3 Heavy Air Transport | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Heavy_Air_Transport")` | in_claret=no
- `t2_field_engineer` | build T2 Field Engineer | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Field_Engineer")` | in_claret=no
- `t3_armored_assault_bot` | build T3 Armored Assault Bot | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Armored_Assault_Bot")` | in_claret=no
- `t3_mobile_missile_platform` | build T3 Mobile Missile Platform | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Mobile_Missile_Platform")` | in_claret=no
- `t2_torpedo_boat` | build T2 Torpedo Boat | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Torpedo_Boat")` | in_claret=no
- `t2_shield_boat` | build T2 Shield Boat | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Shield_Boat")` | in_claret=no
- `t3_battlecruiser` | build T3 Battlecruiser | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Battlecruiser")` | in_claret=no
- `t1_light_gunship` | build T1 Light Gunship | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Light_Gunship")` | in_claret=no
- `t2_mobile_bomb` | build T2 Mobile Bomb | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Mobile_Bomb")` | in_claret=no
- `t2_submarine_killer` | build T2 Submarine Killer | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Submarine_Killer")` | in_claret=no
- `t2_counter_intelligence_boat` | build T2 Counter Intelligence Boat | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Counter_Intelligence_B…` | in_claret=no
- `t1_combat_scout` | build T1 Combat Scout | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T1_Combat_Scout")` | in_claret=no
- `t2_assault_bot` | build T2 Assault Bot | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Assault_Bot")` | in_claret=no
- `t2_hover_tank` | build T2 Hover Tank | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Hover_Tank")` | in_claret=no
- `t2_mobile_anti_air_cannon` | build T2 Mobile Anti Air Cannon | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Mobile_Anti_Air_Cannon")` | in_claret=no
- `t3_siege_tank` | build T3 Siege Tank | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Siege_Tank")` | in_claret=no
- `t3_mobile_shield_generator` | build T3 Mobile Shield Generator | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Mobile_Shield_Generator")` | in_claret=no
- `t3_submarine_hunter` | build T3 Submarine Hunter | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Submarine_Hunter")` | in_claret=no
- `t3_mobile_aa` | build T3 Mobile Anti Air | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Mobile_AA")` | in_claret=no
- `t2_support_factory` | build T2 Support Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Support_Factory")` | in_claret=no
- `t2_support_land_factory` | build T2 Support Land Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Support_Land_Factory")` | in_claret=no
- `t2_support_air_factory` | build T2 Support Air Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Support_Air_Factory")` | in_claret=no
- `t2_support_naval_factory` | build T2 Support Naval Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T2_Support_Naval_Factory")` | in_claret=no
- `t3_support_factory` | build T3 Support Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Support_Factory")` | in_claret=no
- `t3_support_land_factory` | build T3 Support Land Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Support_Land_Factory")` | in_claret=no
- `t3_support_air_factory` | build T3 Support Air Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Support_Air_Factory")` | in_claret=no
- `t3_support_naval_factory` | build T3 Support Naval Factory | `UI_Lua import("/lua/keymap/hotbuild.lua").buildAction("T3_Support_Naval_Factory")` | in_claret=no

## Orders (`orders`)

- `repair` | Repair | `StartCommandMode order RULEUCC_Repair` | in_claret=no
- `reclaim` | Reclaim | `StartCommandMode order RULEUCC_Reclaim` | in_claret=yes
- `patrol` | Patrol | `StartCommandMode order RULEUCC_Patrol` | in_claret=no
- `attack` | Attack | `StartCommandMode order RULEUCC_Attack` | in_claret=yes
- `capture` | Capture | `StartCommandMode order RULEUCC_Capture` | in_claret=no
- `stop` | Stop and cancel all Orders | `UI_Lua import("/lua/ui/game/orders.lua").Stop()` | in_claret=no
- `soft_stop` | Stop and cancel all factory orders except the current one | `UI_Lua import("/lua/ui/game/orders.lua").SoftStop()` | in_claret=no
- `dive` | Dive | `UI_Lua import("/lua/ui/game/orders.lua").ToggleDiveOrder()` | in_claret=no
- `dive_all` | Submerge all units in the selection | `UI_Lua import("/lua/keymap/misckeyactions.lua").DiveAll()` | in_claret=no
- `undive_all` | Surface all units in the selection | `UI_Lua import("/lua/keymap/misckeyactions.lua").SurfaceAll()` | in_claret=no
- `shift_dive_all` | Submerge all units in the selection | `UI_Lua import("/lua/keymap/misckeyactions.lua").DiveAll()` | in_claret=no
- `shift_undive_all` | Surface all units in the selection | `UI_Lua import("/lua/keymap/misckeyactions.lua").SurfaceAll()` | in_claret=no
- `ferry` | Ferry | `StartCommandMode order RULEUCC_Ferry` | in_claret=no
- `guard` | Assist | `StartCommandMode order RULEUCC_Guard` | in_claret=yes
- `transport` | Transport | `StartCommandMode order RULEUCC_Transport` | in_claret=yes
- `launch_tactical` | Launch a Tactical Missile | `StartCommandMode order RULEUCC_Tactical` | in_claret=yes
- `overcharge` | Overcharge | `UI_Lua import("/lua/ui/game/orders.lua").EnterOverchargeMode()` | in_claret=yes
- `move` | Move | `StartCommandMode order RULEUCC_Move` | in_claret=yes
- `move_hard` | Move order that you can consistently issue without queueing | `UI_Lua import("/lua/keymap/misckeyactions.lua").ToggleHardMove()` | in_claret=no
- `nuke` | Nuke | `StartCommandMode order RULEUCC_Nuke` | in_claret=yes
- `shift_repair` | Repair | `StartCommandMode order RULEUCC_Repair` | in_claret=no
- `shift_reclaim` | Reclaim | `StartCommandMode order RULEUCC_Reclaim` | in_claret=yes
- `shift_patrol` | Patrol | `StartCommandMode order RULEUCC_Patrol` | in_claret=no
- `shift_attack` | Attack | `StartCommandMode order RULEUCC_Attack` | in_claret=yes
- `shift_capture` | Capture | `StartCommandMode order RULEUCC_Capture` | in_claret=no
- `shift_stop` | Stop and cancel all Orders | `UI_Lua import("/lua/ui/game/orders.lua").Stop()` | in_claret=no
- `shift_dive` | Dive | `UI_Lua import("/lua/ui/game/orders.lua").ToggleDiveOrder()` | in_claret=no
- `shift_ferry` | Ferry | `StartCommandMode order RULEUCC_Ferry` | in_claret=no
- `shift_guard` | Assist | `StartCommandMode order RULEUCC_Guard` | in_claret=yes
- `shift_transport` | Transport | `StartCommandMode order RULEUCC_Transport` | in_claret=yes
- `shift_launch_tactical` | Launch a Tactical Missile | `StartCommandMode order RULEUCC_Tactical` | in_claret=yes
- `shift_overcharge` | Overcharge | `UI_Lua import("/lua/ui/game/orders.lua").EnterOverchargeMode()` | in_claret=yes
- `shift_move` | Move | `StartCommandMode order RULEUCC_Move` | in_claret=yes
- `shift_nuke` | Nuke | `StartCommandMode order RULEUCC_Nuke` | in_claret=yes
- `toggle_build_mode` | Toggles keyboard build command mode on and off | `UI_Lua import("/lua/ui/game/buildmode.lua").ToggleBuildMode()` | in_claret=no
- `pause_unit` | Pause | `UI_Lua import("/lua/ui/game/construction.lua").ToggleUnitPause()` | in_claret=no
- `pause_unit_all` | Pause all units in the selection | `UI_Lua import("/lua/ui/game/construction.lua").ToggleUnitPauseAll()` | in_claret=no
- `unpause_unit_all` | Unpause all units in the selection | `UI_Lua import("/lua/ui/game/construction.lua").ToggleUnitUnpauseAll()` | in_claret=no
- `mode` | Cycle through all of the available fire states. | `UI_Lua import("/lua/ui/game/orders.lua").CycleRetaliateStateUp()` | in_claret=no
- `suicide` | Self-Destruct | `UI_Lua import("/lua/ui/game/confirmunitdestroy.lua").ConfirmUnitDestruction(false)` | in_claret=no
- `set_default_target_priority` | Set weapon target priorities of selected units to their defaults | `UI_LUA import("/lua/keymap/misckeyactions.lua").SetDefaultWeaponPriorities()` | in_claret=no
- `toggle_shield` | Toggle unit shield | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Shield")` | in_claret=no
- `toggle_weapon` | Toggle unit weapon | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Weapon")` | in_claret=no
- `toggle_jamming` | Toggle unit jamming | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Jamming")` | in_claret=no
- `toggle_intel` | Toggle unit intel | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Intel")` | in_claret=no
- `toggle_production` | Toggle unit production | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Production")` | in_claret=no
- `toggle_stealth` | Toggle unit stealth | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Stealth")` | in_claret=no
- `toggle_generic` | Toggle unit generic | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Generic")` | in_claret=no
- `toggle_special` | Toggle unit special | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Special")` | in_claret=no
- `toggle_cloak` | Toggle unit cloak | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Cloak")` | in_claret=no
- `toggle_all` | Toggle all unit abilities | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleAllScript()` | in_claret=no
- `teleport` | Teleport | `StartCommandMode order RULEUCC_Teleport` | in_claret=no
- `toggle_repeat_build` | Toggle factory repeat build | `UI_Lua import("/lua/keymap/misckeyactions.lua").ToggleRepeatBuild()` | in_claret=yes
- `toggle_cloakjammingstealth` | Toggle all counter-intelligence abilities | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleCloakJammingStealthScript()` | in_claret=no
- `toggle_intelshield` | Toggle intel and shield | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleIntelShieldScript()` | in_claret=no
- `Kill_Selected_Units` | Immediately kill selected units | `UI_Lua import("/lua/ui/game/confirmunitdestroy.lua").ConfirmUnitDestruction(true)` | in_claret=no
- `dock` | Dock | `UI_Lua import("/lua/ui/game/orders.lua").Dock(true)` | in_claret=no
- `dock_damaged` | Dock damaged units | `UI_Lua import("/lua/ui/game/hotkeys/dock-damaged.lua").DockDamaged(0.9, true)` | in_claret=no
- `shift_dock` | Dock | `UI_Lua import("/lua/ui/game/orders.lua").Dock(false)` | in_claret=no
- `shift_dock_damaged` | Dock damaged units | `UI_Lua import("/lua/ui/game/hotkeys/dock-damaged.lua").DockDamaged(0.9, false)` | in_claret=no

## Advanced orders (`ordersAdvanced`)

- `load_transports` | Load into transports | `UI_Lua import("/lua/ui/game/hotkeys/load-in-transport.lua").LoadIntoTransports(f…` | in_claret=no
- `load_transports_clear` | Load into transports. Applies immediately | `UI_Lua import("/lua/ui/game/hotkeys/load-in-transport.lua").LoadIntoTransports(true)` | in_claret=no
- `shift_load_transports` | Load into transports | `UI_Lua import("/lua/ui/game/hotkeys/load-in-transport.lua").LoadIntoTransports(f…` | in_claret=no
- `shift_load_transports_clear` | Load into transports. Applies immediately | `UI_Lua import("/lua/ui/game/hotkeys/load-in-transport.lua").LoadIntoTransports(true)` | in_claret=no
- `filter_highest_engineer_and_assist` | Filter engineers by tech level and majority faction | `UI_Lua import("/lua/ui/game/hotkeys/filter-engineers.lua").SelectHighestEngineer…` | in_claret=no
- `shift_filter_highest_engineer_and_assist` | Filter engineers by tech level and majority faction | `UI_Lua import("/lua/ui/game/hotkeys/filter-engineers.lua").SelectHighestEngineer…` | in_claret=no
- `abort_navigation` | Interrupt pathfinding of engineers | `UI_Lua import("/lua/keymap/misckeyactions.lua").AbortNavigation()` | in_claret=no
- `shift_abort_navigation` | Interrupt pathfinding of engineers | `UI_Lua import("/lua/keymap/misckeyactions.lua").AbortNavigation()` | in_claret=no
- `discharge` | Discharge shields | `UI_Lua import("/lua/keymap/misckeyactions.lua").DischargeShields()` | in_claret=no
- `shift_discharge` | Discharge shields | `UI_Lua import("/lua/keymap/misckeyactions.lua").DischargeShields()` | in_claret=no

## Queue based orders (`ordersQueueBased`)

- `spreadattack` | Distribute orders | `UI_Lua import("/lua/ui/game/hotkeys/distribute-queue.lua").DistributeOrders(true)` | in_claret=no
- `shift_spreadattack` | Distribute orders | `UI_Lua import("/lua/ui/game/hotkeys/distribute-queue.lua").DistributeOrders(true)` | in_claret=no
- `spreadattack_context` | Distribute orders from the unit beneath the mouse cursor | `UI_Lua import("/lua/ui/game/hotkeys/distribute-queue.lua").DistributeOrdersOfMou…` | in_claret=no
- `shift_spreadattack_context` | Distribute orders from the unit beneath the mouse cursor | `UI_Lua import("/lua/ui/game/hotkeys/distribute-queue.lua").DistributeOrdersOfMou…` | in_claret=no
- `copy_orders` | Copy orders of the unit the mouse is on top of | `UI_LUA import("/lua/ui/game/hotkeys/copy-queue.lua").CopyOrders()` | in_claret=no
- `shift_copy_orders` | Copy orders of the unit the mouse is on top of | `UI_LUA import("/lua/ui/game/hotkeys/copy-queue.lua").CopyOrders()` | in_claret=no

## Context based orders (`ordersContextBased`)

- `cycle_context_based_templates` | Cycle context templates | `UI_Lua import("/lua/ui/game/hotkeys/context-based-templates.lua").Cycle()` | in_claret=no
- `shift_cycle_context_based_templates` | Cycle context templates | `UI_Lua import("/lua/ui/game/hotkeys/context-based-templates.lua").Cycle()` | in_claret=no
- `set_target_priority` | Prioritize unit type | `UI_LUA import("/lua/keymap/misckeyactions.lua").SetWeaponPrioritiesToUnitType()` | in_claret=no
- `shift_set_target_priority` | Prioritize unit type | `UI_LUA import("/lua/keymap/misckeyactions.lua").SetWeaponPrioritiesToUnitType()` | in_claret=no
- `cap` | Cap a structure. Clears the command queue | `UI_LUA import("/lua/ui/game/hotkeys/capping.lua").HotkeyToCap(true, true)` | in_claret=no
- `shift_cap` | Cap a structure | `UI_LUA import("/lua/ui/game/hotkeys/capping.lua").HotkeyToCap(true, false)` | in_claret=no
- `upgrade_structure` | Upgrade a structure | `UI_LUA import("/lua/ui/game/hotkeys/upgrade-structure.lua").UpgradeStructure()` | in_claret=yes
- `shift_upgrade_structure` | Upgrade a structure | `UI_LUA import("/lua/ui/game/hotkeys/upgrade-structure.lua").UpgradeStructure()` | in_claret=yes
- `upgrade_structure_pause` | Upgrade a structure and pause it | `UI_LUA import("/lua/ui/game/hotkeys/upgrade-structure.lua").UpgradeStructure(true)` | in_claret=no
- `shift_upgrade_structure_pause` | Upgrade a structure and pause it | `UI_LUA import("/lua/ui/game/hotkeys/upgrade-structure.lua").UpgradeStructure(true)` | in_claret=no

## UI (`ui`)

- `toggle_mdf_panel` | Toggle MFD panel | `UI_Lua import("/lua/ui/game/multifunction.lua").ToggleMFDPanel()` | in_claret=no
- `toggle_tab_display` | Toggle options tab | `UI_Lua import("/lua/ui/game/tabs.lua").ToggleTabDisplay()` | in_claret=no
- `toggle_lifebars` | Toggle life bars | `UI_RenderUnitBars` | in_claret=no
- `tog_military` | Toggle Military Overlay | `UI_Lua import("/lua/ui/game/multifunction.lua").ToggleMilitary()` | in_claret=no
- `tog_defense` | Toggle Unit Color | `UI_Lua import("/lua/ui/game/multifunction.lua").ToggleDefense()` | in_claret=no
- `tog_econ` | Toggle Economy Overlay | `UI_Lua import("/lua/ui/game/multifunction.lua").ToggleEconomy()` | in_claret=no
- `switch_layout_up` | Rotate layouts up | `UI_RotateLayout +` | in_claret=no
- `switch_layout_down` | Rotate layouts down | `UI_RotateLayout -` | in_claret=no
- `switch_skin_down` | Rotate skins down | `UI_RotateSkin -` | in_claret=no
- `switch_skin_up` | Rotate skins up | `UI_RotateSkin +` | in_claret=no
- `escape` | Deselects current selection or cancels current action | `UI_Lua import("/lua/ui/uimain.lua").EscapeHandler()` | in_claret=no
- `pause` | Toggles Game Pause | `UI_Lua import("/lua/ui/game/tabs.lua").TogglePause()` | in_claret=no
- `Render_SelectionSet_Names` | Toggles display of group names | `ui_RenderSelectionSetNames` | in_claret=no
- `Render_Custom_Names` | Toggles display of custom names | `ui_RenderCustomNames` | in_claret=no
- `Render_Unit_Bars` | Toggle display of names and bars of any kind | `ui_RenderUnitBars` | in_claret=no
- `Render_Icons` | Toggle display of Strategic Icons | `ui_RenderIcons` | in_claret=no
- `Always_Render_Strategic_Icons` | Toggle strategic icon cutoff | `ui_AlwaysRenderStrategicIcons` | in_claret=no
- `Show_Bandwidth_Usage` | Show bandwith usage window | `ren_ShowBandwidthUsage` | in_claret=no
- `Execute_Paste_Buffer` | [Debug] Execute Paste Buffer | `ExecutePasteBuffer` | in_claret=no
- `quick_save` | Save the game to a special quick save file | `UI_Lua import("/lua/ui/game/gamemain.lua").QuickSave(LOC("<LOC QuickSave>QuickSa…` | in_claret=no
- `quick_load` | Load the game from the special quick save file | `UI_Lua import("/lua/ui/game/gamemain.lua").QuickLoad(LOC("<LOC QuickSave>QuickSa…` | in_claret=no
- `toggle_key_bindings` | Toggles the Key Bindings Screen | `UI_Lua import("/lua/ui/dialogs/keybindings.lua").CreateUI()` | in_claret=no
- `cap_frame` | Take a screen shot | `Dump_Frame` | in_claret=no
- `military_overlay` | Show all weapon ranges | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleOverlay("Military")` | in_claret=no
- `intel_overlay` | Show all intel ranges | `UI_Lua import("/lua/keymap/misckeyactions.lua").toggleOverlay("Intel")` | in_claret=no
- `show_enemy_life` | Show enemy life bars | `UI_ForceLifbarsOnEnemy` | in_claret=no
- `rename` | Rename the selected unit | `UI_ShowRenameDialog` | in_claret=no
- `split_screen_enable` | Enable split screen | `UI_Lua import("/lua/ui/game/borders.lua").SplitMapGroup(true)` | in_claret=no
- `split_screen_disable` | Disable split screen | `UI_Lua import("/lua/ui/game/borders.lua").SplitMapGroup(false)` | in_claret=no
- `toggle_notify_customiser` | Toggles the Notify customisation screen | `UI_Lua import("/lua/ui/notify/customiser.lua").CreateUI()` | in_claret=no
- `toggle_score_screen` | Toggles the Score Overlay | `UI_Lua import("/lua/ui/game/tabs.lua").ToggleScore()` | in_claret=no
- `toggle_mass_fabricator_panel` | toggle mass fabricator panel | `UI_Lua import("/lua/ui/game/tabs.lua").ToggleMassFabricatorPanel()` | in_claret=no
- `toggle_voting_panel` | toggle voting panel | `UI_Lua import("/lua/ui/game/tabs.lua").ToggleVotingPanel()` | in_claret=no
- `toggle_diplomacy_screen` | Toggles the Diplomacy Window | `UI_Lua import("/lua/ui/game/tabs.lua").ToggleTab("diplomacy")` | in_claret=no
- `ping_alert` | Create an alert ping at the mouse location | `UI_Lua import("/lua/ui/game/ping.lua").DoPing("alert")` | in_claret=no
- `ping_move` | Create a move ping at the mouse location | `UI_Lua import("/lua/ui/game/ping.lua").DoPing("move")` | in_claret=no
- `ping_attack` | Create an attack ping at the mouse location | `UI_Lua import("/lua/ui/game/ping.lua").DoPing("attack")` | in_claret=no
- `ping_marker` | Create a marker at the mouse location | `UI_Lua import("/lua/ui/game/ping.lua").DoPing("marker")` | in_claret=no
- `toggle_main_menu` | Toggles the main menu | `UI_Lua import("/lua/ui/game/tabs.lua").ToggleTab("main")` | in_claret=no
- `toggle_disconnect_screen` | Toggles the Connectivity Screen | `UI_Lua import("/lua/ui/game/connectivity.lua").CreateUI()` | in_claret=no
- `toggle_reclaim_labels` | Toggles reclaim labels on and off | `UI_Lua import("/lua/ui/game/reclaim.lua").ToggleReclaim()` | in_claret=no
- `show_objective_screen` | Show Scenario Options/Objectives Window | `UI_Lua import("/lua/ui/game/objectivedetail.lua").ToggleDisplay()` | in_claret=no

## Game (`game`)

- `decrease_game_speed` | Decrease game speed | `UI_Lua import("/lua/ui/uimain.lua").DecreaseGameSpeed()` | in_claret=no
- `increase_game_speed` | Increase game speed | `UI_Lua import("/lua/ui/uimain.lua").IncreaseGameSpeed()` | in_claret=no
- `reset_game_speed` | Reset game speed to 0 (Normal Speed) | `WLD_ResetSimRate` | in_claret=no

## Chat (`chat`)

- `chat_page_up` | Chat page up | `UI_Lua import("/lua/ui/game/chat/ChatInterface.lua").OpenAndScrollLines(-10)` | in_claret=no
- `chat_page_down` | Chat page down | `UI_Lua import("/lua/ui/game/chat/ChatInterface.lua").OpenAndScrollLines(10)` | in_claret=no
- `chat_line_up` | Chat line up | `UI_Lua import("/lua/ui/game/chat/ChatInterface.lua").OpenAndScrollLines(-1)` | in_claret=no
- `chat_line_down` | Chat line down | `UI_Lua import("/lua/ui/game/chat/ChatInterface.lua").OpenAndScrollLines(1)` | in_claret=no

