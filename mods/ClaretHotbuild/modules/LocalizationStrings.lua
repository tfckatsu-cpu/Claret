-- ClaretHotbuild labels and descriptions; IDs, not translated text, are persisted.
Strings = {
    en = {
        ["hotbuild.context.cursor"] = "Under cursor",
        ["hotbuild.context.units"] = "Units",
        ["hotbuild.context.land"] = "Land",
        ["hotbuild.context.air"] = "Air",
        ["hotbuild.context.fighter"] = "Fighters",
        ["hotbuild.context.bomber"] = "Bombers",
        ["hotbuild.context.gunship"] = "Gunships",
        ["hotbuild.context.navy"] = "Naval",
        ["hotbuild.context.builder"] = "Builders",
        ["hotbuild.context.empty"] = "No selection",
        ["hotbuild.context.acu"] = "ACU",
        ["hotbuild.context.sacu"] = "SACU",
        ["hotbuild.context.engineer"] = "Engineer",
        ["hotbuild.context.factory"] = "Factory",
        ["hotbuild.context.missiles"] = "Missiles",
        ["hotbuild.context.transport"] = "Transport",
        ["hotbuild.context.silo_tactical"] = "TML",
        ["hotbuild.context.silo_nuclear"] = "Nuclear silo",
        ["hotbuild.context.mex"] = "Extractors",
        ["hotbuild.context.scout"] = "Scouts",
        ["hotbuild.context.other"] = "Other",
        ["hotbuild.action.select_acu.label"] = "Select and focus ACU",
        ["hotbuild.action.select_acu_only.label"] = "Select ACU",
        ["hotbuild.action.select_acu_double.label"] = "Select ACU / focus while selected",
        ["hotbuild.action.select_acu_double.description"] = "Selects the ACU; while it remains selected, each press moves the camera to it.",
        ["hotbuild.action.goto_acu.label"] = "Focus on ACU",
        ["hotbuild.action.select_engineer.label"] = "Nearest idle T1 engineer on screen",
        ["hotbuild.action.select_engineers.label"] = "Idle engineers on screen",
        ["hotbuild.action.select_scout.label"] = "Nearest air scout",
        ["hotbuild.action.select_transport.label"] = "Add nearest free transport",
        ["hotbuild.action.select_transport_nearest.label"] = "Add nearest free transport",
        ["hotbuild.action.select_transports_accumulate.label"] = "Add nearest free transports in sequence",
        ["hotbuild.action.select_transports_accumulate.description"] = "Keeps the current selection. Each press adds the nearest idle transport not already selected.",
        ["hotbuild.action.select_all_idle_transports.label"] = "Add all free transports",
        ["hotbuild.action.select_all_idle_transports.description"] = "Keeps the current selection and adds every transport with no queued orders.",
        ["hotbuild.action.select_transport_double.label"] = "One idle transport / all while selected",
        ["hotbuild.action.select_transport_double.description"] = "Selects one idle transport; while a transport remains selected, each press selects all transports on the map.",
        ["hotbuild.action.select_radars.label"] = "Select all radars",
        ["hotbuild.action.select_sensors.label"] = "Select all sensors",
        ["hotbuild.action.select_all_scouts.label"] = "Select all air scouts",
        ["hotbuild.action.select_bombers.label"] = "All bombers",
        ["hotbuild.action.select_fighters.label"] = "All fighters",
        ["hotbuild.action.build_storage_nearest.label"] = "Build storages around mex",
        ["hotbuild.action.build_storage_nearest.description"] = "Immediately uses selected non-ACU engineers to build storages around the nearest idle mex within 3 units of the cursor.",
        ["hotbuild.action.build_fabs_nearest.label"] = "Build mass fabs around mex",
        ["hotbuild.action.build_fabs_nearest.description"] = "Immediately uses selected non-ACU T2/T3 engineers to build fabricators around the nearest idle mex within 3 units of the cursor.",
        ["hotbuild.action.select_gunships.label"] = "All gunships",
        ["hotbuild.action.select_land_army_screen.label"] = "Land army on screen",
        ["hotbuild.action.select_land_army_map.label"] = "Land army on map",
        ["hotbuild.action.select_naval_army_screen.label"] = "Naval army on screen",
        ["hotbuild.action.select_naval_army_map.label"] = "Naval army on map",
        ["hotbuild.action.select_experimentals.label"] = "Mobile land experimentals",
        ["hotbuild.action.select_satellites.label"] = "Select satellites",
        ["hotbuild.action.select_land_experimentals.label"] = "All land experimentals",
        ["hotbuild.action.select_air_experimentals.label"] = "All air experimentals",
        ["hotbuild.action.select_transport_screen.label"] = "Transports on screen",
        ["hotbuild.action.select_transport_map.label"] = "Transports on map",
        ["hotbuild.action.select_engineers_t1.label"] = "Add T1 engineers one by one",
        ["hotbuild.action.select_engineers_t2.label"] = "Add T2 engineers one by one",
        ["hotbuild.action.select_engineers_t3.label"] = "Add T3 engineers one by one",
        ["hotbuild.action.select_engineers_all.label"] = "Add engineers of all tiers one by one",
        ["hotbuild.action.select_t3_artillery.label"] = "Mobile T3 artillery on screen",
        ["hotbuild.action.select_t3_shields.label"] = "Mobile shields on screen",
        ["hotbuild.action.select_t3_stealth.label"] = "Mobile stealth generators on screen",
        ["hotbuild.action.select_t3_mml.label"] = "Mobile MMLs on screen",
        ["hotbuild.action.select_tactical_silos.label"] = "Select all TMLs",
        ["hotbuild.action.select_nuclear_silos.label"] = "Select all nuclear silos",
        ["hotbuild.action.select_land_factories_screen.label"] = "All T1–T3 land factories on screen",
        ["hotbuild.action.select_land_factories_map.label"] = "All T1–T3 land factories on map",
        ["hotbuild.action.select_naval_factories_screen.label"] = "All T1–T3 naval factories on screen",
        ["hotbuild.action.select_naval_factories_map.label"] = "All T1–T3 naval factories on map",
        ["hotbuild.action.select_air_factories_screen.label"] = "All T1–T3 air factories on screen",
        ["hotbuild.action.select_air_factories_map.label"] = "All T1–T3 air factories on map",
        ["hotbuild.action.cycle_idle_factories.label"] = "Cycle idle factories",
        ["hotbuild.action.patrol.label"] = "Patrol",
        ["hotbuild.action.mode.label"] = "Fire mode",
        ["hotbuild.action.set_target_priority.label"] = "Target priority",
        ["hotbuild.action.set_default_target_priority.label"] = "Reset target priority",
        ["hotbuild.action.spreadattack.label"] = "Distribute orders",
        ["hotbuild.action.copy_orders.label"] = "Copy orders",
        ["hotbuild.action.load_transports.label"] = "Load into transports",
        ["hotbuild.action.split_layer.label"] = "Split selection by layer (land / naval / air)",
        ["hotbuild.action.split_tech.label"] = "Split selection by tech tier",
        ["hotbuild.action.split_into_groups_1.label"] = "Split selection into groups of 1",
        ["hotbuild.action.split_into_groups_2.label"] = "Split selection into groups of 2",
        ["hotbuild.action.split_into_groups_4.label"] = "Split selection into groups of 4",
        ["hotbuild.action.split_into_groups_8.label"] = "Split selection into groups of 8",
        ["hotbuild.action.split_into_groups_16.label"] = "Split selection into groups of 16",
        ["hotbuild.action.split_next.label"] = "Next subgroup",
        ["hotbuild.action.cycle_unit_types_in_sel.label"] = "Cycle land / naval / air units in selection",
        ["hotbuild.action.suicide.label"] = "Self-destruct",
        ["hotbuild.action.kill_selected_units.label"] = "Instant self-destruct",
        ["hotbuild.action.discharge.label"] = "Discharge shields",
        ["hotbuild.action.dock.label"] = "Refuel",
        ["hotbuild.action.ferry.label"] = "Ferry route",
        ["hotbuild.action.dock_damaged.label"] = "Land damaged aircraft",
        ["hotbuild.action.dive.label"] = "Dive / surface",
        ["hotbuild.action.dive_all.label"] = "Dive all submarines",
        ["hotbuild.action.undive_all.label"] = "Surface all submarines",
        ["hotbuild.action.repair.label"] = "Repair",
        ["hotbuild.action.capture.label"] = "Capture",
        ["hotbuild.action.cap.label"] = "Build around structure",
        ["hotbuild.action.abort_navigation.label"] = "Interrupt pathfinding",
        ["hotbuild.action.pause_unit.label"] = "Pause unit",
        ["hotbuild.action.teleport.label"] = "ACU: Teleport",
        ["hotbuild.action.filter_highest_engineer_and_assist.label"] = "Keep highest-tier engineers; assist with the rest",
        ["hotbuild.action.build_templates.label"] = "FAF: Build template",
        ["hotbuild.action.build_templates.description"] = "Calls the native FAF Templates action for the selected builder.",
        ["hotbuild.action.upgrade_structure.label"] = "FAF: Upgrade structure under cursor",
        ["hotbuild.action.upgrade_structure_pause.label"] = "Upgrade with pause",
        ["hotbuild.action.create_template_factory.label"] = "Create queue template from this factory",
        ["hotbuild.action.fire_beetle_detonate.label"] = "Detonate Fire Beetle",
        ["hotbuild.action.pause_unit_all.label"] = "Pause entire selection",
        ["hotbuild.action.unpause_unit_all.label"] = "Unpause entire selection",
        ["hotbuild.action.toggle_production.label"] = "Toggle production",
        ["hotbuild.action.toggle_intel.label"] = "Toggle intel",
        ["hotbuild.action.toggle_jamming.label"] = "Toggle jamming",
        ["hotbuild.action.toggle_cloak.label"] = "Toggle cloak",
        ["hotbuild.action.toggle_all.label"] = "Toggle all unit abilities",
        ["hotbuild.action.cycle_mex_screen.label"] = "Next extractor on screen",
        ["hotbuild.action.cycle_mex_map.label"] = "Next extractor on map",
        ["hotbuild.action.upgrade_structure_under_cursor.label"] = "Upgrade structure under cursor",
        ["hotbuild.action.upgrade_mex_select_next.label"] = "Upgrade extractor and select the next nearest one",
        ["hotbuild.action.upgrade_mex.label"] = "Upgrade selected extractors",
        ["hotbuild.action.overcharge.label"] = "Overcharge",
        ["hotbuild.action.acu_tech.label"] = "ACU: Engineering",
        ["hotbuild.action.acu_ras.label"] = "ACU: Resource production",
        ["hotbuild.action.acu_tele.label"] = "ACU: Teleport",
        ["hotbuild.action.acu_gun.label"] = "ACU: Weapon",
        ["hotbuild.action.acu_nano.label"] = "ACU: Defense",
        ["hotbuild.action.acu_special.label"] = "ACU: Special upgrade",
        ["hotbuild.action.sacu_tech.label"] = "SACU: Engineering",
        ["hotbuild.action.transport_order.label"] = "Transport",
        ["hotbuild.action.append_transport_cargo.label"] = "Mark next unit for drop-off",
        ["hotbuild.action.append_transport_cargo.description"] = "Marks one loaded unit for a later selective drop-off.",
        ["hotbuild.action.reclaim.label"] = "Reclaim",
        ["hotbuild.action.assist.label"] = "Assist / guard",
        ["hotbuild.action.move.label"] = "Move",
        ["hotbuild.action.claret_order_reclaim.label"] = "Reclaim",
        ["hotbuild.action.claret_order_reclaim.description"] = "Enter reclaim mode when the selection supports reclaim.",
        ["hotbuild.action.claret_order_assist.label"] = "Assist / guard",
        ["hotbuild.action.claret_order_assist.description"] = "Enter assist/guard mode when available for this selection.",
        ["hotbuild.action.claret_order_move.label"] = "Move",
        ["hotbuild.action.claret_order_move.description"] = "Enter move mode when available for this selection.",
        ["hotbuild.action.claret_strategic_rings_create.label"] = "Create strategic rings",
        ["hotbuild.action.claret_strategic_rings_create.description"] = "Draw the hovered unit's available strategic ranges.",
        ["hotbuild.action.claret_strategic_rings_vision.label"] = "Create vision ring",
        ["hotbuild.action.claret_strategic_rings_vision.description"] = "Draw the hovered structure's line of sight range.",
        ["hotbuild.action.attack.label"] = "Attack ground",
        ["hotbuild.action.attack_move.label"] = "Attack-move",
        ["hotbuild.action.smart_missile.label"] = "Launch missile",
        ["hotbuild.action.nuke.label"] = "Launch strategic missile",
        ["hotbuild.action.tactical.label"] = "Launch tactical missile",
        ["hotbuild.action.repeat_queue.label"] = "Repeat queue",
        ["hotbuild.action.pause.label"] = "Pause production",
        ["hotbuild.action.shield.label"] = "Toggle shield",
        ["hotbuild.action.stealth.label"] = "Toggle stealth",
        ["hotbuild.action.stop.label"] = "Stop",
        ["hotbuild.action.soft_stop.label"] = "Soft stop",
        ["hotbuild.action.remove_queue.label"] = "Remove last factory order",
        ["hotbuild.action.select_factory_level.label"] = "All %s factories (T%s) %s",
        ["hotbuild.domain.land"] = "land",
        ["hotbuild.domain.naval"] = "naval",
        ["hotbuild.domain.air"] = "air",
        ["hotbuild.area.screen"] = "on screen",
        ["hotbuild.area.map"] = "on map",
    },
    ru = {
        ["hotbuild.context.cursor"] = "Под курсором",
        ["hotbuild.context.units"] = "Войска",
        ["hotbuild.context.land"] = "Наземные",
        ["hotbuild.context.air"] = "Авиация",
        ["hotbuild.context.fighter"] = "Истребители",
        ["hotbuild.context.bomber"] = "Бомбардировщики",
        ["hotbuild.context.gunship"] = "Штурмовики",
        ["hotbuild.context.navy"] = "Флот",
        ["hotbuild.context.builder"] = "Строители",
        ["hotbuild.context.empty"] = "Ничего не выделено",
        ["hotbuild.context.acu"] = "ACU",
        ["hotbuild.context.sacu"] = "SACU",
        ["hotbuild.context.engineer"] = "Инженер",
        ["hotbuild.context.factory"] = "Завод",
        ["hotbuild.context.missiles"] = "Ракеты",
        ["hotbuild.context.transport"] = "Транспорт",
        ["hotbuild.context.silo_tactical"] = "ТМЛ",
        ["hotbuild.context.silo_nuclear"] = "Ядерка",
        ["hotbuild.context.mex"] = "Добытчики",
        ["hotbuild.context.scout"] = "Разведчики",
        ["hotbuild.context.other"] = "Остальные",
        ["hotbuild.action.select_acu.label"] = "Выбрать ACU и перейти к нему",
        ["hotbuild.action.select_acu_only.label"] = "Выбрать ACU",
        ["hotbuild.action.select_acu_double.label"] = "Выбрать ACU / переход, пока выбран",
        ["hotbuild.action.select_acu_double.description"] = "Выбирает ACU; пока он остаётся выделен, каждое нажатие перемещает к нему камеру.",
        ["hotbuild.action.goto_acu.label"] = "Перейти к ACU",
        ["hotbuild.action.select_engineer.label"] = "Ближайший свободный T1 инженер на экране",
        ["hotbuild.action.select_engineers.label"] = "Свободные инженеры на экране",
        ["hotbuild.action.select_scout.label"] = "Ближайший воздушный разведчик",
        ["hotbuild.action.select_transport.label"] = "Добавить ближайший свободный транспорт",
        ["hotbuild.action.select_transport_nearest.label"] = "Добавить ближайший свободный транспорт",
        ["hotbuild.action.select_transports_accumulate.label"] = "Последовательно добавлять ближайший свободный транспорт",
        ["hotbuild.action.select_transports_accumulate.description"] = "Сохраняет текущее выделение. Каждое нажатие добавляет ближайший свободный транспорт, который ещё не выбран.",
        ["hotbuild.action.select_all_idle_transports.label"] = "Добавить все свободные транспорты",
        ["hotbuild.action.select_all_idle_transports.description"] = "Сохраняет текущее выделение и добавляет все транспорты без приказов в очереди.",
        ["hotbuild.action.select_transport_double.label"] = "Один свободный транспорт / все, пока выбран",
        ["hotbuild.action.select_transport_double.description"] = "Выбирает один свободный транспорт; пока транспорт выделен, каждое нажатие выбирает все транспорты на карте.",
        ["hotbuild.action.select_radars.label"] = "Выбрать все радары",
        ["hotbuild.action.select_sensors.label"] = "Выбрать все сенсоры",
        ["hotbuild.action.select_all_scouts.label"] = "Выбрать всех воздушных разведчиков",
        ["hotbuild.action.select_bombers.label"] = "Все бомбардировщики",
        ["hotbuild.action.select_fighters.label"] = "Все истребители",
        ["hotbuild.action.build_storage_nearest.label"] = "Обстроить мекс хранилищами",
        ["hotbuild.action.build_storage_nearest.description"] = "Сразу строит Storage вокруг ближайшей свободной mex в пределах 3 единиц от курсора выбранными инженерами, кроме ACU.",
        ["hotbuild.action.build_fabs_nearest.label"] = "Обстроить мекс массфабами",
        ["hotbuild.action.build_fabs_nearest.description"] = "Сразу строит Fabs вокруг ближайшей свободной mex в пределах 3 единиц от курсора выбранными инженерами T2/T3, кроме ACU.",
        ["hotbuild.action.select_gunships.label"] = "Все штурмовики",
        ["hotbuild.action.select_land_army_screen.label"] = "Наземная армия на экране",
        ["hotbuild.action.select_land_army_map.label"] = "Наземная армия на карте",
        ["hotbuild.action.select_naval_army_screen.label"] = "Водные войска на экране",
        ["hotbuild.action.select_naval_army_map.label"] = "Водные войска на карте",
        ["hotbuild.action.select_experimentals.label"] = "Мобильные наземные экспериментальные юниты",
        ["hotbuild.action.select_satellites.label"] = "Выбрать спутники",
        ["hotbuild.action.select_land_experimentals.label"] = "Все наземные экспериментальные юниты",
        ["hotbuild.action.select_air_experimentals.label"] = "Все воздушные экспериментальные юниты",
        ["hotbuild.action.select_transport_screen.label"] = "Транспорт на экране",
        ["hotbuild.action.select_transport_map.label"] = "Транспорт на карте",
        ["hotbuild.action.select_engineers_t1.label"] = "Последовательно добавить инженеров T1",
        ["hotbuild.action.select_engineers_t2.label"] = "Последовательно добавить инженеров T2",
        ["hotbuild.action.select_engineers_t3.label"] = "Последовательно добавить инженеров T3",
        ["hotbuild.action.select_engineers_all.label"] = "Последовательно добавить инженеров всех уровней",
        ["hotbuild.action.select_t3_artillery.label"] = "Мобильная T3 артиллерия на экране",
        ["hotbuild.action.select_t3_shields.label"] = "Мобильные щиты на экране",
        ["hotbuild.action.select_t3_stealth.label"] = "Мобильные стелс-генераторы на экране",
        ["hotbuild.action.select_t3_mml.label"] = "Мобильные MML на экране",
        ["hotbuild.action.select_tactical_silos.label"] = "Выбрать все TML",
        ["hotbuild.action.select_nuclear_silos.label"] = "Выбрать все ядерные шахты",
        ["hotbuild.action.select_land_factories_screen.label"] = "Все наземные заводы T1–T3 на экране",
        ["hotbuild.action.select_land_factories_map.label"] = "Все наземные заводы T1–T3 на карте",
        ["hotbuild.action.select_naval_factories_screen.label"] = "Все морские заводы T1–T3 на экране",
        ["hotbuild.action.select_naval_factories_map.label"] = "Все морские заводы T1–T3 на карте",
        ["hotbuild.action.select_air_factories_screen.label"] = "Все авиационные заводы T1–T3 на экране",
        ["hotbuild.action.select_air_factories_map.label"] = "Все авиационные заводы T1–T3 на карте",
        ["hotbuild.action.cycle_idle_factories.label"] = "Перебор простаивающих заводов",
        ["hotbuild.action.patrol.label"] = "Патруль",
        ["hotbuild.action.mode.label"] = "Режим огня",
        ["hotbuild.action.set_target_priority.label"] = "Приоритет целей",
        ["hotbuild.action.set_default_target_priority.label"] = "Сбросить приоритет целей",
        ["hotbuild.action.spreadattack.label"] = "Распределить приказы [Distribute orders]",
        ["hotbuild.action.copy_orders.label"] = "Скопировать приказы",
        ["hotbuild.action.load_transports.label"] = "Погрузить в транспорт [Load into transports]",
        ["hotbuild.action.split_layer.label"] = "Разделить выделение по типу (суша / флот / авиация)",
        ["hotbuild.action.split_tech.label"] = "Разделить выделение по уровню",
        ["hotbuild.action.split_into_groups_1.label"] = "Разделить выделение на группы по 1",
        ["hotbuild.action.split_into_groups_2.label"] = "Разделить выделение на группы по 2",
        ["hotbuild.action.split_into_groups_4.label"] = "Разделить выделение на группы по 4",
        ["hotbuild.action.split_into_groups_8.label"] = "Разделить выделение на группы по 8",
        ["hotbuild.action.split_into_groups_16.label"] = "Разделить выделение на группы по 16",
        ["hotbuild.action.split_next.label"] = "Следующая подгруппа",
        ["hotbuild.action.cycle_unit_types_in_sel.label"] = "Переключить сушу / флот / авиацию в выделении",
        ["hotbuild.action.suicide.label"] = "Самоуничтожение",
        ["hotbuild.action.kill_selected_units.label"] = "Самоуничтожение мгновенно",
        ["hotbuild.action.discharge.label"] = "Разрядить щиты",
        ["hotbuild.action.dock.label"] = "Заправка",
        ["hotbuild.action.ferry.label"] = "Паромный маршрут",
        ["hotbuild.action.dock_damaged.label"] = "Посадить повреждённые самолёты",
        ["hotbuild.action.dive.label"] = "Погрузиться / всплыть",
        ["hotbuild.action.dive_all.label"] = "Погрузить все подлодки",
        ["hotbuild.action.undive_all.label"] = "Всплыть всем подлодкам",
        ["hotbuild.action.repair.label"] = "Ремонт",
        ["hotbuild.action.capture.label"] = "Захват",
        ["hotbuild.action.cap.label"] = "Обстроить структуру",
        ["hotbuild.action.abort_navigation.label"] = "Прервать поиск пути [Interrupt pathfinding]",
        ["hotbuild.action.pause_unit.label"] = "Пауза",
        ["hotbuild.action.teleport.label"] = "ACU: телепорт",
        ["hotbuild.action.filter_highest_engineer_and_assist.label"] = "Оставить старших, остальные помогают",
        ["hotbuild.action.build_templates.label"] = "FAF: строительные шаблоны",
        ["hotbuild.action.build_templates.description"] = "Вызывает штатное действие FAF Templates для выбранного строителя.",
        ["hotbuild.action.upgrade_structure.label"] = "FAF: улучшить структуру под курсором",
        ["hotbuild.action.upgrade_structure_pause.label"] = "Улучшение с паузой",
        ["hotbuild.action.create_template_factory.label"] = "Шаблон очереди с этого завода",
        ["hotbuild.action.fire_beetle_detonate.label"] = "Взорвать Fire Beetle",
        ["hotbuild.action.pause_unit_all.label"] = "Пауза всего выделения",
        ["hotbuild.action.unpause_unit_all.label"] = "Снять паузу со всего выделения",
        ["hotbuild.action.toggle_production.label"] = "Переключить производство",
        ["hotbuild.action.toggle_intel.label"] = "Переключить разведку",
        ["hotbuild.action.toggle_jamming.label"] = "Переключить глушение",
        ["hotbuild.action.toggle_cloak.label"] = "Переключить маскировку",
        ["hotbuild.action.toggle_all.label"] = "Переключить все функции",
        ["hotbuild.action.cycle_mex_screen.label"] = "Следующий добытчик на экране",
        ["hotbuild.action.cycle_mex_map.label"] = "Следующий добытчик на карте",
        ["hotbuild.action.upgrade_structure_under_cursor.label"] = "Улучшить структуру под курсором",
        ["hotbuild.action.upgrade_mex_select_next.label"] = "Улучшить добытчик и выбрать ближайший следующий",
        ["hotbuild.action.upgrade_mex.label"] = "Улучшить выбранные добытчики",
        ["hotbuild.action.overcharge.label"] = "Overcharge",
        ["hotbuild.action.acu_tech.label"] = "ACU: улучшить инженерию",
        ["hotbuild.action.acu_ras.label"] = "ACU: улучшить производство ресурсов",
        ["hotbuild.action.acu_tele.label"] = "ACU: телепорт",
        ["hotbuild.action.acu_gun.label"] = "ACU: улучшить оружие",
        ["hotbuild.action.acu_nano.label"] = "ACU: улучшить защиту",
        ["hotbuild.action.acu_special.label"] = "ACU: специальное улучшение",
        ["hotbuild.action.sacu_tech.label"] = "SACU: улучшить инженерию",
        ["hotbuild.action.transport_order.label"] = "Перевозка",
        ["hotbuild.action.append_transport_cargo.label"] = "Отметить следующего юнита для высадки",
        ["hotbuild.action.append_transport_cargo.description"] = "Отмечает одного уже погруженного юнита для последующей выборочной высадки.",
        ["hotbuild.action.reclaim.label"] = "Реклейм",
        ["hotbuild.action.assist.label"] = "Помощь / охрана",
        ["hotbuild.action.move.label"] = "Движение",
        ["hotbuild.action.claret_order_reclaim.label"] = "Реклейм",
        ["hotbuild.action.claret_order_reclaim.description"] = "Включить режим реклейма, если он доступен для выбранных юнитов.",
        ["hotbuild.action.claret_order_assist.label"] = "Помощь / охрана",
        ["hotbuild.action.claret_order_assist.description"] = "Включить режим помощи или охраны, если он доступен для выбранных юнитов.",
        ["hotbuild.action.claret_order_move.label"] = "Движение",
        ["hotbuild.action.claret_order_move.description"] = "Включить режим движения, если он доступен для выбранных юнитов.",
        ["hotbuild.action.claret_strategic_rings_create.label"] = "Создать стратегические кольца",
        ["hotbuild.action.claret_strategic_rings_create.description"] = "Нарисовать доступные радиусы объекта под курсором.",
        ["hotbuild.action.claret_strategic_rings_vision.label"] = "Создать кольцо обзора",
        ["hotbuild.action.claret_strategic_rings_vision.description"] = "Нарисовать радиус обзора здания под курсором.",
        ["hotbuild.action.attack.label"] = "Атака по площади",
        ["hotbuild.action.attack_move.label"] = "Атака с движением",
        ["hotbuild.action.smart_missile.label"] = "Запуск ракеты",
        ["hotbuild.action.nuke.label"] = "Запуск стратегической ракеты",
        ["hotbuild.action.tactical.label"] = "Запуск тактической ракеты",
        ["hotbuild.action.repeat_queue.label"] = "Повтор очереди",
        ["hotbuild.action.pause.label"] = "Пауза производства",
        ["hotbuild.action.shield.label"] = "Переключить щит",
        ["hotbuild.action.stealth.label"] = "Переключить скрытность",
        ["hotbuild.action.stop.label"] = "Остановить",
        ["hotbuild.action.soft_stop.label"] = "Мягкая остановка",
        ["hotbuild.action.remove_queue.label"] = "Удалить последний заказ завода",
        ["hotbuild.action.select_factory_level.label"] = "Все %s заводы T%s %s",
        ["hotbuild.domain.land"] = "наземные",
        ["hotbuild.domain.naval"] = "морские",
        ["hotbuild.domain.air"] = "авиационные",
        ["hotbuild.area.screen"] = "на экране",
        ["hotbuild.area.map"] = "на карте",
    },
}

Strings.en['hotbuild.section.title'] = 'Hotbuild'
Strings.ru['hotbuild.section.title'] = 'Hotbuild'
Strings.en['hotbuild.section.description'] = 'Keyboard, building, and multifunction bindings.'
Strings.ru['hotbuild.section.description'] = 'Клавиатура, бинды построек и мультифункциональные бинды.'
Strings.en['hotbuild.page.keyboard.title'] = 'Keyboard'
Strings.ru['hotbuild.page.keyboard.title'] = 'Клавиатура'
Strings.en['hotbuild.page.keyboard.description'] = 'Hotbuild actions and key combinations.'
Strings.ru['hotbuild.page.keyboard.description'] = 'Отдельные действия и сочетания клавиш Hotbuild.'
Strings.en['hotbuild.page.hotbuild.title'] = 'Hotbuild'
Strings.ru['hotbuild.page.hotbuild.title'] = 'Hotbuild'
Strings.en['hotbuild.page.hotbuild.description'] = 'Key combinations for buildings and unit production.'
Strings.ru['hotbuild.page.hotbuild.description'] = 'Сочетания клавиш для построек и производства юнитов.'
Strings.en['hotbuild.page.contexts.title'] = 'Multifunction'
Strings.ru['hotbuild.page.contexts.title'] = 'Мультифункциональные'
Strings.en['hotbuild.page.contexts.description'] = 'Create actions for different selection contexts.'
Strings.ru['hotbuild.page.contexts.description'] = 'Создание действий для разных контекстов выделения.'

Strings.en['hotbuild.common.close'] = 'Close'; Strings.ru['hotbuild.common.close'] = 'Закрыть'
Strings.en['hotbuild.common.cancel'] = 'Cancel'; Strings.ru['hotbuild.common.cancel'] = 'Отмена'
Strings.en['hotbuild.common.save'] = 'Save'; Strings.ru['hotbuild.common.save'] = 'Сохранить'
Strings.en['hotbuild.common.save_continue'] = 'Save and continue'; Strings.ru['hotbuild.common.save_continue'] = 'Сохранить и продолжить'
Strings.en['hotbuild.common.discard'] = 'Do not save'; Strings.ru['hotbuild.common.discard'] = 'Не сохранять'
Strings.en['hotbuild.common.delete'] = 'Delete'; Strings.ru['hotbuild.common.delete'] = 'Удалить'
Strings.en['hotbuild.common.new'] = 'New'; Strings.ru['hotbuild.common.new'] = 'Новый'
Strings.en['hotbuild.common.yes'] = 'Yes'; Strings.ru['hotbuild.common.yes'] = 'Да'
Strings.en['hotbuild.common.no'] = 'No'; Strings.ru['hotbuild.common.no'] = 'Нет'
Strings.en['hotbuild.common.done'] = 'Done'; Strings.ru['hotbuild.common.done'] = 'Готово'
Strings.en['hotbuild.common.understood'] = 'Got it'; Strings.ru['hotbuild.common.understood'] = 'Понятно'
Strings.en['hotbuild.common.save_failed'] = 'Could not save.'; Strings.ru['hotbuild.common.save_failed'] = 'Не удалось сохранить.'
Strings.en['hotbuild.common.saved'] = 'Saved.'; Strings.ru['hotbuild.common.saved'] = 'Сохранено.'
Strings.en['hotbuild.common.unsaved'] = 'Changes have not been saved.'; Strings.ru['hotbuild.common.unsaved'] = 'Изменения не сохранены.'
Strings.en['hotbuild.common.no_changes'] = 'There are no changes to save.'; Strings.ru['hotbuild.common.no_changes'] = 'Изменений для сохранения нет.'
Strings.en['hotbuild.common.unsaved_title'] = 'Unsaved changes'; Strings.ru['hotbuild.common.unsaved_title'] = 'Несохранённые изменения'
Strings.en['hotbuild.common.save_before_leave'] = 'Save changes before leaving?'; Strings.ru['hotbuild.common.save_before_leave'] = 'Сохранить изменения перед переходом?'
Strings.en['hotbuild.common.discarded_retry'] = 'Draft discarded. Repeat the navigation or close action.'; Strings.ru['hotbuild.common.discarded_retry'] = 'Черновик отброшен. Повторите переход или закрытие.'
Strings.en['hotbuild.common.save_draft_tooltip'] = 'Save draft'; Strings.ru['hotbuild.common.save_draft_tooltip'] = 'Сохранить черновик'
Strings.en['hotbuild.common.validate_draft_tooltip'] = 'Check and save changes before leaving.'; Strings.ru['hotbuild.common.validate_draft_tooltip'] = 'Проверить и сохранить изменения перед переходом.'
Strings.en['hotbuild.common.create_or_select'] = 'Create or select a binding.'; Strings.ru['hotbuild.common.create_or_select'] = 'Создайте или выберите бинд.'
Strings.en['hotbuild.common.name_ascii'] = 'Binding name: use English letters, digits, and ASCII punctuation only.'; Strings.ru['hotbuild.common.name_ascii'] = 'Название бинда: только английские буквы, цифры и знаки ASCII.'
Strings.en['hotbuild.common.used_keys'] = 'Assigned to keys: %s'; Strings.ru['hotbuild.common.used_keys'] = 'используется на клавишах: %s'
Strings.en['hotbuild.common.unavailable'] = 'Unavailable: %s'; Strings.ru['hotbuild.common.unavailable'] = 'Недоступно: %s'
Strings.en['hotbuild.common.empty_cell'] = 'Empty cell'; Strings.ru['hotbuild.common.empty_cell'] = 'Пустая ячейка'
Strings.en['hotbuild.editor.conflict_title'] = 'Cannot combine'; Strings.ru['hotbuild.editor.conflict_title'] = 'Нельзя совместить'
Strings.en['hotbuild.editor.create_new'] = 'New Hotbuild'; Strings.ru['hotbuild.editor.create_new'] = 'Новый хотбилд'
Strings.en['hotbuild.editor.buildings'] = 'Buildings'; Strings.ru['hotbuild.editor.buildings'] = 'Постройки'
Strings.en['hotbuild.editor.build_order_hint'] = 'Top entries have priority · right-click to remove'; Strings.ru['hotbuild.editor.build_order_hint'] = 'Приоритет сверху вниз · правая кнопка — удалить'
Strings.en['hotbuild.editor.move_row_up'] = 'Move row up'; Strings.ru['hotbuild.editor.move_row_up'] = 'Переместить строку вверх'
Strings.en['hotbuild.editor.move_row_down'] = 'Move row down'; Strings.ru['hotbuild.editor.move_row_down'] = 'Переместить строку вниз'
Strings.en['hotbuild.editor.unit_orders'] = 'Unit orders'; Strings.ru['hotbuild.editor.unit_orders'] = 'Заказ юнитов'
Strings.en['hotbuild.editor.bindings'] = 'Bindings'; Strings.ru['hotbuild.editor.bindings'] = 'Бинды'
Strings.en['hotbuild.editor.no_bindings'] = 'No bindings'; Strings.ru['hotbuild.editor.no_bindings'] = 'Нет биндов'
Strings.en['hotbuild.editor.template'] = 'TEMPLATE'; Strings.ru['hotbuild.editor.template'] = 'ШАБЛОН'
Strings.en['hotbuild.editor.template_count'] = '▧ TEMPLATE · %s buildings'; Strings.ru['hotbuild.editor.template_count'] = '▧ ШАБЛОН · %s построек'
Strings.en['hotbuild.editor.unit_template_count'] = '▧ UNIT TEMPLATE · %s units'; Strings.ru['hotbuild.editor.unit_template_count'] = '▧ ШАБЛОН ЮНИТОВ · %s юнитов'
Strings.en['hotbuild.editor.choose_object'] = 'Choose an item · %s%s'; Strings.ru['hotbuild.editor.choose_object'] = 'Выберите объект · %s%s'
Strings.en['hotbuild.editor.tier_hint'] = 'T1 → T2 → T3; sorted by role within each tier'; Strings.ru['hotbuild.editor.tier_hint'] = 'T1 → T2 → T3; внутри уровня — по назначению'
Strings.en['hotbuild.editor.gate_hint'] = 'Select one SACU for this faction'; Strings.ru['hotbuild.editor.gate_hint'] = 'Выберите одного SACU для этой фракции'
Strings.en['hotbuild.editor.unavailable'] = 'Unavailable: %s'; Strings.ru['hotbuild.editor.unavailable'] = 'Недоступно: %s'
Strings.en['hotbuild.editor.empty'] = 'Empty cell'; Strings.ru['hotbuild.editor.empty'] = 'Пустая ячейка'
Strings.en['hotbuild.editor.picker.templates'] = 'Build templates'; Strings.ru['hotbuild.editor.picker.templates'] = 'Шаблоны строительства'
Strings.en['hotbuild.editor.picker.unit_templates'] = 'Unit templates'; Strings.ru['hotbuild.editor.picker.unit_templates'] = 'Шаблоны юнитов'
Strings.en['hotbuild.editor.picker.production'] = 'Production'; Strings.ru['hotbuild.editor.picker.production'] = 'Производство'
Strings.en['hotbuild.editor.picker.economy'] = 'Economy'; Strings.ru['hotbuild.editor.picker.economy'] = 'Экономика'
Strings.en['hotbuild.editor.picker.defense'] = 'Defense'; Strings.ru['hotbuild.editor.picker.defense'] = 'Оборона'
Strings.en['hotbuild.editor.picker.other_buildings'] = 'Other buildings'; Strings.ru['hotbuild.editor.picker.other_buildings'] = 'Другие постройки'
Strings.en['hotbuild.editor.picker.units'] = 'Units'; Strings.ru['hotbuild.editor.picker.units'] = 'Юниты'
Strings.en['hotbuild.editor.status.incompatible'] = 'Could not finish navigation: %s'; Strings.ru['hotbuild.editor.status.incompatible'] = 'Не удалось завершить переход: %s'
Strings.en['hotbuild.editor.status.delete_confirm'] = 'Press × again to delete “%s”.'; Strings.ru['hotbuild.editor.status.delete_confirm'] = 'Повторно нажмите ×, чтобы удалить «%s».'
Strings.en['hotbuild.problems.summary'] = 'Damaged records: %d — %s'; Strings.ru['hotbuild.problems.summary'] = 'Повреждённых записей: %d — %s'
Strings.en['hotbuild.editor.status.deleted'] = 'Binding deleted.'; Strings.ru['hotbuild.editor.status.deleted'] = 'Бинд удалён.'
Strings.en['hotbuild.editor.status.new_binding'] = 'New binding'; Strings.ru['hotbuild.editor.status.new_binding'] = 'New binding'
Strings.en['hotbuild.editor.status.legacy_action'] = 'The old binding contains an action or an unknown item.'; Strings.ru['hotbuild.editor.status.legacy_action'] = 'Старый бинд содержит действие или неизвестный объект.'
Strings.en['hotbuild.editor.status.legacy_duplicate'] = 'The old binding contains duplicate units at one tech level or an unsupported item.'; Strings.ru['hotbuild.editor.status.legacy_duplicate'] = 'Старый бинд содержит повторный юнит одного уровня или неподдерживаемый объект.'
Strings.en['hotbuild.editor.status.legacy_unsupported'] = 'The old binding contains an unsupported item.'; Strings.ru['hotbuild.editor.status.legacy_unsupported'] = 'Старый бинд содержит неподдерживаемый объект.'
Strings.en['hotbuild.editor.status.legacy_grid'] = 'The old binding cannot be represented safely in the grid.'; Strings.ru['hotbuild.editor.status.legacy_grid'] = 'Старый бинд нельзя безопасно представить в сетке.'
Strings.en['hotbuild.editor.status.legacy_order'] = 'The old binding order cannot be transferred safely to the grid.'; Strings.ru['hotbuild.editor.status.legacy_order'] = 'Порядок старого бинда нельзя безопасно перенести в сетку.'
Strings.en['hotbuild.editor.status.create_binding'] = 'Create a new binding.'; Strings.ru['hotbuild.editor.status.create_binding'] = 'Создайте новый бинд.'
Strings.en['hotbuild.editor.status.invalid_name'] = 'Use English letters, digits, and ASCII punctuation only.'; Strings.ru['hotbuild.editor.status.invalid_name'] = 'Только английские буквы, цифры и знаки ASCII.'
Strings.en['hotbuild.editor.status.save_or_confirm'] = 'Save changes first or confirm switching.'; Strings.ru['hotbuild.editor.status.save_or_confirm'] = 'Сначала сохраните изменения или переключитесь с подтверждением.'
Strings.en['hotbuild.editor.status.save_no_changes'] = 'There are no changes to save.'; Strings.ru['hotbuild.editor.status.save_no_changes'] = 'Изменений для сохранения нет.'
Strings.en['hotbuild.editor.status.validate_failed'] = 'Could not check compatibility.'; Strings.ru['hotbuild.editor.status.validate_failed'] = 'Не удалось проверить совместимость.'
Strings.en['hotbuild.editor.status.saved_hint'] = 'Saved. Assign a key on the Keyboard page.'; Strings.ru['hotbuild.editor.status.saved_hint'] = 'Сохранено. Назначьте клавишу на вкладке «Клавиатура».'
Strings.en['hotbuild.editor.binding'] = 'Binding'; Strings.ru['hotbuild.editor.binding'] = 'Бинд'
Strings.en['hotbuild.editor.name'] = 'Name'; Strings.ru['hotbuild.editor.name'] = 'Название'
Strings.en['hotbuild.editor.delete_binding'] = 'Delete binding'; Strings.ru['hotbuild.editor.delete_binding'] = 'Удалить бинд'
Strings.en['hotbuild.editor.status.duplicate_used'] = 'This item is already used in another row.'; Strings.ru['hotbuild.editor.status.duplicate_used'] = 'Этот объект уже используется в другом ряду.'
Strings.en['hotbuild.editor.status.selected_variants'] = 'Selected. Matching variants found: %s/4.'; Strings.ru['hotbuild.editor.status.selected_variants'] = 'Выбрано. Найдено аналогов: %s/4.'
Strings.en['hotbuild.domain_header.land'] = 'Land'; Strings.ru['hotbuild.domain_header.land'] = 'Наземные'
Strings.en['hotbuild.domain_header.air'] = 'Air'; Strings.ru['hotbuild.domain_header.air'] = 'Авиация'
Strings.en['hotbuild.domain_header.naval'] = 'Naval'; Strings.ru['hotbuild.domain_header.naval'] = 'Флот'
Strings.en['hotbuild.domain_header.gate'] = 'Gates'; Strings.ru['hotbuild.domain_header.gate'] = 'Врата'

Strings.en['hotbuild.keyboard.instructions'] = 'Left-click to assign, right-click to clear. Ctrl, Shift, and Alt show combinations.'; Strings.ru['hotbuild.keyboard.instructions'] = 'ЛКМ — назначить, ПКМ — снять назначение. Ctrl, Shift и Alt показывают сочетания.'
Strings.en['hotbuild.keyboard.group.selection'] = 'Unit selection'; Strings.ru['hotbuild.keyboard.group.selection'] = 'Выбор юнитов'
Strings.en['hotbuild.keyboard.group.split'] = 'Split selection'; Strings.ru['hotbuild.keyboard.group.split'] = 'Разделение выделения'
Strings.en['hotbuild.keyboard.group.acu'] = 'ACU and abilities'; Strings.ru['hotbuild.keyboard.group.acu'] = 'ACU и способности'
Strings.en['hotbuild.keyboard.group.transport'] = 'Transport'; Strings.ru['hotbuild.keyboard.group.transport'] = 'Транспорт'
Strings.en['hotbuild.keyboard.group.build'] = 'Building and production'; Strings.ru['hotbuild.keyboard.group.build'] = 'Строительство и производство'
Strings.en['hotbuild.keyboard.group.toggle'] = 'Modes and toggles'; Strings.ru['hotbuild.keyboard.group.toggle'] = 'Режимы и переключатели'
Strings.en['hotbuild.keyboard.group.orders'] = 'Orders and other'; Strings.ru['hotbuild.keyboard.group.orders'] = 'Приказы и прочее'
Strings.en['hotbuild.keyboard.group.communication'] = 'Communication'
Strings.ru['hotbuild.keyboard.group.communication'] = 'Коммуникация'
Strings.en['hotbuild.action.ping_marker.label'] = 'Text marker'
Strings.ru['hotbuild.action.ping_marker.label'] = 'Текстовая метка'
Strings.en['hotbuild.action.ping_alert.label'] = 'Alert ping'
Strings.ru['hotbuild.action.ping_alert.label'] = 'Пинг тревоги'
Strings.en['hotbuild.action.ping_move.label'] = 'Move ping'
Strings.ru['hotbuild.action.ping_move.label'] = 'Пинг движения'
Strings.en['hotbuild.action.ping_attack.label'] = 'Attack ping'
Strings.ru['hotbuild.action.ping_attack.label'] = 'Пинг атаки'
Strings.en['hotbuild.keyboard.group.air'] = 'Air'; Strings.ru['hotbuild.keyboard.group.air'] = 'Авиация'
Strings.en['hotbuild.keyboard.legacy'] = ' · obsolete assignment'; Strings.ru['hotbuild.keyboard.legacy'] = ' · старое назначение'
Strings.en['hotbuild.keyboard.building'] = 'Building: %s'; Strings.ru['hotbuild.keyboard.building'] = 'Стройка: %s'
Strings.en['hotbuild.keyboard.actions'] = 'Actions: %s'; Strings.ru['hotbuild.keyboard.actions'] = 'Действия: %s'
Strings.en['hotbuild.keyboard.occupied'] = ' · Occupied: %s'; Strings.ru['hotbuild.keyboard.occupied'] = ' · Занято: %s'
Strings.en['hotbuild.keyboard.repeat'] = 'Repeat: %s'; Strings.ru['hotbuild.keyboard.repeat'] = 'Повтор: %s'
Strings.en['hotbuild.keyboard.no_assignment'] = 'No assignment'; Strings.ru['hotbuild.keyboard.no_assignment'] = 'Нет назначения'
Strings.en['hotbuild.keyboard.assign'] = 'Assign: %s%s'; Strings.ru['hotbuild.keyboard.assign'] = 'Назначить: %s%s'
Strings.en['hotbuild.keyboard.empty'] = 'empty'; Strings.ru['hotbuild.keyboard.empty'] = 'пусто'
Strings.en['hotbuild.keyboard.double_press'] = 'Double press'; Strings.ru['hotbuild.keyboard.double_press'] = 'Двойное нажатие'
Strings.en['hotbuild.keyboard.choose_double'] = 'Choose an action for the second press:'; Strings.ru['hotbuild.keyboard.choose_double'] = 'Выберите действие для повторного нажатия:'
Strings.en['hotbuild.keyboard.double_saved'] = 'Double press saved.'; Strings.ru['hotbuild.keyboard.double_saved'] = 'Двойное нажатие сохранено.'
Strings.en['hotbuild.keyboard.double_disabled'] = 'Double press disabled.'; Strings.ru['hotbuild.keyboard.double_disabled'] = 'Двойное нажатие отключено.'
Strings.en['hotbuild.keyboard.no_repeat'] = 'No repeat'; Strings.ru['hotbuild.keyboard.no_repeat'] = 'Без повтора'
Strings.en['hotbuild.keyboard.empty_slot'] = 'The slot is already empty.'; Strings.ru['hotbuild.keyboard.empty_slot'] = 'Слот уже пуст.'
Strings.en['hotbuild.keyboard.assignment_cleared'] = 'Assignment cleared.'; Strings.ru['hotbuild.keyboard.assignment_cleared'] = 'Назначение снято.'
Strings.en['hotbuild.keyboard.clear_building'] = 'Clear building'; Strings.ru['hotbuild.keyboard.clear_building'] = 'Снять стройку'
Strings.en['hotbuild.keyboard.clear_actions'] = 'Clear actions'; Strings.ru['hotbuild.keyboard.clear_actions'] = 'Снять действия'
Strings.en['hotbuild.keyboard.set_double'] = 'Double press…'; Strings.ru['hotbuild.keyboard.set_double'] = 'Двойное нажатие…'
Strings.en['hotbuild.keyboard.bindings'] = 'Bindings'; Strings.ru['hotbuild.keyboard.bindings'] = 'Бинды'
Strings.en['hotbuild.keyboard.multifunction'] = 'Multifunction'; Strings.ru['hotbuild.keyboard.multifunction'] = 'Мультифункциональные'
Strings.en['hotbuild.keyboard.hotbuild_preset'] = 'Hotbuild preset'; Strings.ru['hotbuild.keyboard.hotbuild_preset'] = 'HotBuild пресет'
Strings.en['hotbuild.keyboard.old'] = '[OLD] '; Strings.ru['hotbuild.keyboard.old'] = '[СТАРЫЙ] '
Strings.en['hotbuild.keyboard.link_assignments'] = 'Link assignments?'; Strings.ru['hotbuild.keyboard.link_assignments'] = 'Связать назначения?'
Strings.en['hotbuild.keyboard.reassign'] = 'Reassign?'; Strings.ru['hotbuild.keyboard.reassign'] = 'Хотите переназначить?'
Strings.en['hotbuild.keyboard.combination_busy'] = 'Combination is occupied.'; Strings.ru['hotbuild.keyboard.combination_busy'] = 'Сочетание занято.'
Strings.en['hotbuild.keyboard.set_connected'] = 'The set will be linked to the preset.'; Strings.ru['hotbuild.keyboard.set_connected'] = 'Набор будет подключён к пресету.'
Strings.en['hotbuild.keyboard.link_for_combo'] = 'The link applies to this key combination.'; Strings.ru['hotbuild.keyboard.link_for_combo'] = 'Связь задаётся для этого сочетания клавиш.'
Strings.en['hotbuild.keyboard.link'] = 'Link'; Strings.ru['hotbuild.keyboard.link'] = 'Связать'
Strings.en['hotbuild.keyboard.reassign_button'] = 'Reassign'; Strings.ru['hotbuild.keyboard.reassign_button'] = 'Переназначить'
Strings.en['hotbuild.keyboard.empty_list'] = 'List is empty'; Strings.ru['hotbuild.keyboard.empty_list'] = 'Список пуст'
Strings.en['hotbuild.keyboard.of'] = 'of'; Strings.ru['hotbuild.keyboard.of'] = 'из'
Strings.en['hotbuild.keyboard.legend'] = 'Filled cells have an assignment. The tooltip shows the selected combination.'; Strings.ru['hotbuild.keyboard.legend'] = 'Закрашена — сочетание занято. Подсказка показывает выбранное сочетание.'
Strings.en['hotbuild.keyboard.no_assignment_here'] = 'This combination has no assignment.'; Strings.ru['hotbuild.keyboard.no_assignment_here'] = 'На этом сочетании нет назначения.'
Strings.en['hotbuild.keyboard.assignments_cleared'] = 'Assignments cleared.'; Strings.ru['hotbuild.keyboard.assignments_cleared'] = 'Назначения сняты.'
Strings.en['hotbuild.keyboard.claret_hotbuild'] = 'Claret Hotbuild'; Strings.ru['hotbuild.keyboard.claret_hotbuild'] = 'Claret Hotbuild'
Strings.en['hotbuild.keyboard.claret_bind'] = 'Claret action'; Strings.ru['hotbuild.keyboard.claret_bind'] = 'Действие Claret'
Strings.en['hotbuild.keyboard.claret_multi'] = 'Claret multifunction'; Strings.ru['hotbuild.keyboard.claret_multi'] = 'Мультифункциональный бинд Claret'
Strings.en['hotbuild.keyboard.action'] = 'Action: %s'; Strings.ru['hotbuild.keyboard.action'] = 'Действие: %s'
Strings.en['hotbuild.keyboard.contexts'] = 'Available for: %s'; Strings.ru['hotbuild.keyboard.contexts'] = 'Доступно для: %s'
Strings.en['hotbuild.keyboard.claret_prefix'] = 'Claret · %s'; Strings.ru['hotbuild.keyboard.claret_prefix'] = 'Claret · %s'
Strings.en['hotbuild.keyboard.numpad_closed'] = '▸ NumPad'; Strings.ru['hotbuild.keyboard.numpad_closed'] = '▸ NumPad'
Strings.en['hotbuild.keyboard.numpad_open'] = '▾ NumPad'; Strings.ru['hotbuild.keyboard.numpad_open'] = '▾ NumPad'


Strings.en['hotbuild.context_editor.s002'] = 'Select a context on the left, then choose an action for it on the right.'; Strings.ru['hotbuild.context_editor.s002'] = 'Выберите контекст слева, затем задайте для него действие справа.'
Strings.en['hotbuild.context_editor.s003'] = 'There are unsaved changes.'; Strings.ru['hotbuild.context_editor.s003'] = 'Есть несохранённые изменения.'
Strings.en['hotbuild.context_editor.s004'] = '● unsaved'; Strings.ru['hotbuild.context_editor.s004'] = '● не сохранено'
Strings.en['hotbuild.context_editor.s005'] = 'Cannot combine'; Strings.ru['hotbuild.context_editor.s005'] = 'Нельзя совместить'
Strings.en['hotbuild.context_editor.s006'] = 'Got it'; Strings.ru['hotbuild.context_editor.s006'] = 'Понятно'
Strings.en['hotbuild.context_editor.s007'] = 'Could not finish navigation: '; Strings.ru['hotbuild.context_editor.s007'] = 'Не удалось завершить переход: '
Strings.en['hotbuild.context_editor.s008'] = 'Unsaved changes'; Strings.ru['hotbuild.context_editor.s008'] = 'Несохранённые изменения'
Strings.en['hotbuild.context_editor.s009'] = 'Save changes before leaving?'; Strings.ru['hotbuild.context_editor.s009'] = 'Сохранить изменения перед переходом?'
Strings.en['hotbuild.context_editor.s010'] = 'Save'; Strings.ru['hotbuild.context_editor.s010'] = 'Сохранить'
Strings.en['hotbuild.context_editor.s011'] = 'Do not save'; Strings.ru['hotbuild.context_editor.s011'] = 'Не сохранять'
Strings.en['hotbuild.context_editor.s012'] = 'Cancel'; Strings.ru['hotbuild.context_editor.s012'] = 'Отмена'
Strings.en['hotbuild.context_editor.s013'] = 'Assigned to keys: '; Strings.ru['hotbuild.context_editor.s013'] = 'используется на клавишах: '
Strings.en['hotbuild.context_editor.s014'] = 'Set'; Strings.ru['hotbuild.context_editor.s014'] = 'Набор'
Strings.en['hotbuild.context_editor.s015'] = 'Name'; Strings.ru['hotbuild.context_editor.s015'] = 'Название'
Strings.en['hotbuild.context_editor.s016'] = 'Delete saved set?'; Strings.ru['hotbuild.context_editor.s016'] = 'Удалить сохранённый набор?'
Strings.en['hotbuild.context_editor.s017'] = 'Delete and unassign from keys?'; Strings.ru['hotbuild.context_editor.s017'] = 'Удалить и снять с клавиш?'
Strings.en['hotbuild.context_editor.s018'] = 'Assigned to: '; Strings.ru['hotbuild.context_editor.s018'] = 'Назначено на: '
Strings.en['hotbuild.context_editor.s019'] = 'Set is not assigned to any keys.'; Strings.ru['hotbuild.context_editor.s019'] = 'Набор не назначен на клавиши.'
Strings.en['hotbuild.context_editor.s020'] = 'Cancel'; Strings.ru['hotbuild.context_editor.s020'] = 'Отмена'
Strings.en['hotbuild.context_editor.s021'] = 'Delete'; Strings.ru['hotbuild.context_editor.s021'] = 'Удалить'
Strings.en['hotbuild.context_editor.s022'] = 'Set deleted.'; Strings.ru['hotbuild.context_editor.s022'] = 'Набор удалён.'
Strings.en['hotbuild.context_editor.s023'] = 'Delete “'; Strings.ru['hotbuild.context_editor.s023'] = 'Удалить «'
Strings.en['hotbuild.context_editor.s024'] = 'Delete set'; Strings.ru['hotbuild.context_editor.s024'] = 'Удалить набор'
Strings.en['hotbuild.context_editor.s025'] = 'Keys: '; Strings.ru['hotbuild.context_editor.s025'] = 'Клавиши: '
Strings.en['hotbuild.context_editor.s026'] = 'Open delete confirmation.'; Strings.ru['hotbuild.context_editor.s026'] = 'Открыть подтверждение удаления.'
Strings.en['hotbuild.context_editor.s027'] = 'Select set'; Strings.ru['hotbuild.context_editor.s027'] = 'Выбрать набор'
Strings.en['hotbuild.context_editor.s028'] = 'Saved sets'; Strings.ru['hotbuild.context_editor.s028'] = 'Сохранённые наборы'
Strings.en['hotbuild.context_editor.s029'] = 'Select a saved set.'; Strings.ru['hotbuild.context_editor.s029'] = 'Выберите сохранённый набор.'
Strings.en['hotbuild.context_editor.s030'] = 'No saved sets'; Strings.ru['hotbuild.context_editor.s030'] = 'Нет сохранённых наборов'
Strings.en['hotbuild.context_editor.s031'] = 'Select a saved set'; Strings.ru['hotbuild.context_editor.s031'] = 'Выберите сохранённый набор'
Strings.en['hotbuild.context_editor.s032'] = 'No saved sets yet.'; Strings.ru['hotbuild.context_editor.s032'] = 'Пока нет сохранённых наборов.'
Strings.en['hotbuild.context_editor.s033'] = 'New'; Strings.ru['hotbuild.context_editor.s033'] = 'Новый'
Strings.en['hotbuild.context_editor.selection_override'] = 'Override selection'
Strings.ru['hotbuild.context_editor.selection_override'] = 'Сбрасывать выделение'
Strings.en['hotbuild.context_editor.selection_override_hint'] = 'Run the selector assigned to No selection if other units are selected. Keep a matching selection and use its assigned context.'
Strings.ru['hotbuild.context_editor.selection_override_hint'] = 'Запускает выбор юнитов из строки «Ничего не выделено», если выделены юниты другого типа. Если нужные юниты уже выделены, используется их контекст.'
Strings.en['hotbuild.context_model.selection_override_type'] = 'The selection override setting must be a boolean.'
Strings.ru['hotbuild.context_model.selection_override_type'] = 'Некорректное значение настройки сброса выделения.'
Strings.en['hotbuild.context_editor.keep_builders'] = 'Exception: Builders'
Strings.ru['hotbuild.context_editor.keep_builders'] = 'Исключение: строители'
Strings.en['hotbuild.context_editor.keep_builders_hint'] = 'Keep the current selection if it includes an ACU, SACU, or engineer.'
Strings.ru['hotbuild.context_editor.keep_builders_hint'] = 'Сохраняет выделение, если в нём есть БМК, ПБМК или инженер.'
Strings.en['hotbuild.context_editor.keep_builders_disabled'] = 'Turn on Override selection to use the exception.'
Strings.ru['hotbuild.context_editor.keep_builders_disabled'] = 'Включите «Сбрасывать выделение», чтобы настроить исключение.'
Strings.en['hotbuild.context_editor.actions_heading'] = 'Actions'
Strings.ru['hotbuild.context_editor.actions_heading'] = 'Действия'
Strings.en['hotbuild.context_model.keep_builders_type'] = 'The Builders exception must be a boolean.'
Strings.ru['hotbuild.context_model.keep_builders_type'] = 'Некорректное значение исключения для строителей.'
Strings.en['hotbuild.context_editor.s140'] = 'New Set'; Strings.ru['hotbuild.context_editor.s140'] = 'New Set'
Strings.en['hotbuild.context_editor.s034'] = 'Create a set first.'; Strings.ru['hotbuild.context_editor.s034'] = 'Сначала создайте набор.'
Strings.en['hotbuild.context_editor.s035'] = 'There are no changes to save.'; Strings.ru['hotbuild.context_editor.s035'] = 'Изменений для сохранения нет.'
Strings.en['hotbuild.context_editor.s036'] = '<LOC claret_hotbuild_saved>Saved.'; Strings.ru['hotbuild.context_editor.s036'] = '<LOC claret_hotbuild_saved>Сохранено.'
Strings.en['hotbuild.context_editor.s037'] = 'Save'; Strings.ru['hotbuild.context_editor.s037'] = 'Сохранить'
Strings.en['hotbuild.context_editor.s038'] = 'Selection contexts'; Strings.ru['hotbuild.context_editor.s038'] = 'Контексты выделения'
Strings.en['hotbuild.context_editor.s039'] = 'Empty selection is separate · child rows inherit the group action'; Strings.ru['hotbuild.context_editor.s039'] = 'Пустое выделение отдельно · дочерние строки наследуют действие группы'
Strings.en['hotbuild.context_editor.s040'] = 'Active: 0 · overridden: 0'; Strings.ru['hotbuild.context_editor.s040'] = 'Активно: 0 · переопределено: 0'
Strings.en['hotbuild.context_editor.s041'] = 'chain-occupied: '; Strings.ru['hotbuild.context_editor.s041'] = 'занято цепочкой: '
Strings.en['hotbuild.context_editor.s042'] = 'Chain-occupied: '; Strings.ru['hotbuild.context_editor.s042'] = 'Занято цепочкой: '
Strings.en['hotbuild.context_editor.s043'] = '. Free the context or change the chain.'; Strings.ru['hotbuild.context_editor.s043'] = '. Освободите контекст или измените цепочку.'
Strings.en['hotbuild.context_editor.s044'] = 'Second press performs the second action.'; Strings.ru['hotbuild.context_editor.s044'] = 'Повторное нажатие выполняет второе действие.'
Strings.en['hotbuild.context_editor.s045'] = 'Second press adds to the selection.'; Strings.ru['hotbuild.context_editor.s045'] = 'Повторное нажатие добавляет к выделению.'
Strings.en['hotbuild.context_editor.s046'] = 'Select a context to see compatible actions.'; Strings.ru['hotbuild.context_editor.s046'] = 'Выберите контекст, чтобы увидеть совместимые действия.'
Strings.en['hotbuild.context_editor.s047'] = 'INHERITS'; Strings.ru['hotbuild.context_editor.s047'] = 'НАСЛЕДУЕТ'
Strings.en['hotbuild.context_editor.s048'] = 'DISABLED'; Strings.ru['hotbuild.context_editor.s048'] = 'ОТКЛЮЧЕНО'
Strings.en['hotbuild.context_editor.s049'] = 'CUSTOM'; Strings.ru['hotbuild.context_editor.s049'] = 'СВОЁ'
Strings.en['hotbuild.context_editor.s050'] = 'inherits'; Strings.ru['hotbuild.context_editor.s050'] = 'наследует'
Strings.en['hotbuild.context_editor.s051'] = 'inherits'; Strings.ru['hotbuild.context_editor.s051'] = 'наследует'
Strings.en['hotbuild.context_editor.s052'] = 'obsolete: '; Strings.ru['hotbuild.context_editor.s052'] = 'устарело: '
Strings.en['hotbuild.context_editor.s053'] = 'Active: '; Strings.ru['hotbuild.context_editor.s053'] = 'Активно: '
Strings.en['hotbuild.context_editor.s054'] = ' · overridden: '; Strings.ru['hotbuild.context_editor.s054'] = ' · переопределено: '
Strings.en['hotbuild.context_editor.s055'] = 'Could not identify tile context.'; Strings.ru['hotbuild.context_editor.s055'] = 'Не удалось определить контекст плитки.'
Strings.en['hotbuild.context_editor.s056'] = 'Only the empty-selection tile is available in absolute mode.'; Strings.ru['hotbuild.context_editor.s056'] = 'В абсолютном режиме доступна только плитка пустого выделения.'
Strings.en['hotbuild.context_editor.s057'] = 'This tile is blocked by the empty-selection action policy. Clear the empty-selection action first or choose an allowed tile.'; Strings.ru['hotbuild.context_editor.s057'] = 'Эта плитка заблокирована политикой действия пустого выделения. Сначала очистите действие пустого выделения либо выберите разрешённую плитку.'
Strings.en['hotbuild.context_editor.s058'] = ' · clear the conflict or change the chain.'; Strings.ru['hotbuild.context_editor.s058'] = ' · очистите конфликт или измените цепочку.'
Strings.en['hotbuild.context_editor.s059'] = 'Disable'; Strings.ru['hotbuild.context_editor.s059'] = 'Отключить'
Strings.en['hotbuild.context_editor.s060'] = 'Inherit'; Strings.ru['hotbuild.context_editor.s060'] = 'Наследовать'
Strings.en['hotbuild.context_editor.s061'] = 'Clear'; Strings.ru['hotbuild.context_editor.s061'] = 'Очистить'
Strings.en['hotbuild.context_editor.s062'] = 'Assignment cleared; child context inherits the group.'; Strings.ru['hotbuild.context_editor.s062'] = 'Назначение очищено; дочерний контекст наследует группу.'
Strings.en['hotbuild.context_editor.s063'] = '. You can clear the saved assignment; to change it, replace the chain action first.'; Strings.ru['hotbuild.context_editor.s063'] = '. Сохранённое назначение можно очистить; для изменения сначала замените действие цепочки.'
Strings.en['hotbuild.context_editor.s064'] = 'Action disabled'; Strings.ru['hotbuild.context_editor.s064'] = 'Действие отключено'
Strings.en['hotbuild.context_editor.s065'] = 'Custom action'; Strings.ru['hotbuild.context_editor.s065'] = 'Собственное действие'
Strings.en['hotbuild.context_editor.s066'] = 'Inherits action “'; Strings.ru['hotbuild.context_editor.s066'] = 'Наследует действие «'
Strings.en['hotbuild.context_editor.s067'] = 'Shared action'; Strings.ru['hotbuild.context_editor.s067'] = 'Общее действие'
Strings.en['hotbuild.context_editor.s068'] = '. You can clear the saved assignment; to change it, replace the chain action first.'; Strings.ru['hotbuild.context_editor.s068'] = '. Сохранённое назначение можно очистить; для изменения сначала замените действие цепочки.'
Strings.en['hotbuild.context_editor.s069'] = 'Priority '; Strings.ru['hotbuild.context_editor.s069'] = 'Приоритет '
Strings.en['hotbuild.context_editor.s070'] = ' of 10'; Strings.ru['hotbuild.context_editor.s070'] = ' из 10'
Strings.en['hotbuild.context_editor.s071'] = 'Empty selection'; Strings.ru['hotbuild.context_editor.s071'] = 'Пустое выделение'
Strings.en['hotbuild.context_editor.s072'] = '. You can clear the saved assignment; to change it, replace the chain action first.'; Strings.ru['hotbuild.context_editor.s072'] = '. Сохранённое назначение можно очистить; для изменения сначала замените действие цепочки.'
Strings.en['hotbuild.context_editor.s073'] = 'Assign action'; Strings.ru['hotbuild.context_editor.s073'] = 'Назначить действие'
Strings.en['hotbuild.context_editor.s074'] = 'Shared action: '; Strings.ru['hotbuild.context_editor.s074'] = 'Общее действие: '
Strings.en['hotbuild.context_editor.s075'] = 'Click to select this context.'; Strings.ru['hotbuild.context_editor.s075'] = 'Нажмите, чтобы выбрать этот контекст.'
Strings.en['hotbuild.context_editor.s076'] = 'action'; Strings.ru['hotbuild.context_editor.s076'] = 'действие'
Strings.en['hotbuild.context_editor.s077'] = 'quick repeat'; Strings.ru['hotbuild.context_editor.s077'] = 'быстрый повтор'
Strings.en['hotbuild.context_editor.s078'] = 'obsolete · '; Strings.ru['hotbuild.context_editor.s078'] = 'устарело · '
Strings.en['hotbuild.context_editor.s079'] = 'Engineers'; Strings.ru['hotbuild.context_editor.s079'] = 'Инженеры'
Strings.en['hotbuild.context_editor.s080'] = 'Army'; Strings.ru['hotbuild.context_editor.s080'] = 'Армия'
Strings.en['hotbuild.context_editor.s081'] = 'Air'; Strings.ru['hotbuild.context_editor.s081'] = 'Авиация'
Strings.en['hotbuild.context_editor.s082'] = 'Transport'; Strings.ru['hotbuild.context_editor.s082'] = 'Транспорт'
Strings.en['hotbuild.context_editor.s083'] = 'Structures'; Strings.ru['hotbuild.context_editor.s083'] = 'Структуры'
Strings.en['hotbuild.context_editor.s084'] = 'Orders'; Strings.ru['hotbuild.context_editor.s084'] = 'Приказы'
Strings.en['hotbuild.context_editor.s085'] = 'Action will run for this selection type.'; Strings.ru['hotbuild.context_editor.s085'] = 'Действие будет выполнено для этого типа выделения.'
Strings.en['hotbuild.context_editor.s086'] = ' · clear the saved row or change the chain action'; Strings.ru['hotbuild.context_editor.s086'] = ' · сохранённую строку можно очистить или изменить действие цепочки'
Strings.en['hotbuild.context_editor.s087'] = 'obsolete: '; Strings.ru['hotbuild.context_editor.s087'] = 'устарело: '
Strings.en['hotbuild.context_editor.s088'] = ' · choose a replacement or click the field button to remove'; Strings.ru['hotbuild.context_editor.s088'] = ' · выберите замену или нажмите кнопку поля для удаления'
Strings.en['hotbuild.context_editor.s089'] = 'obsolete: '; Strings.ru['hotbuild.context_editor.s089'] = 'устарело: '
Strings.en['hotbuild.context_editor.s090'] = ' · choose a replacement or clear the row'; Strings.ru['hotbuild.context_editor.s090'] = ' · выберите замену или очистите строку'
Strings.en['hotbuild.context_editor.s091'] = 'Actions: '; Strings.ru['hotbuild.context_editor.s091'] = 'Действий: '
Strings.en['hotbuild.context_editor.s092'] = ' · use the mouse wheel to scroll the list'; Strings.ru['hotbuild.context_editor.s092'] = ' · колесо мыши прокручивает список'
Strings.en['hotbuild.context_editor.s093'] = 'Obsolete rows · select one to replace or remove'; Strings.ru['hotbuild.context_editor.s093'] = 'Устаревшие строки · выберите для замены или удаления'
Strings.en['hotbuild.context_editor.s094'] = ' · shared action for three types'; Strings.ru['hotbuild.context_editor.s094'] = ' · общее действие для трёх типов'
Strings.en['hotbuild.context_editor.s095'] = 'Select a context on the left to see its actions.'; Strings.ru['hotbuild.context_editor.s095'] = 'Выберите контекст слева, чтобы увидеть действия.'
Strings.en['hotbuild.context_editor.s096'] = 'Choose a compatible action for quick repeat.'; Strings.ru['hotbuild.context_editor.s096'] = 'Выберите совместимое действие для быстрого повтора.'
Strings.en['hotbuild.context_editor.s097'] = 'Assign a primary action first.'; Strings.ru['hotbuild.context_editor.s097'] = 'Сначала назначьте основное действие.'
Strings.en['hotbuild.context_editor.s098'] = 'Choose a selection fallback action.'; Strings.ru['hotbuild.context_editor.s098'] = 'Выберите резервное действие выделения.'
Strings.en['hotbuild.context_editor.s099'] = 'Fallback is only available for custom selection actions.'; Strings.ru['hotbuild.context_editor.s099'] = 'Fallback доступен только для собственного действия выбора.'
Strings.en['hotbuild.context_editor.s100'] = 'No compatible actions for this context.'; Strings.ru['hotbuild.context_editor.s100'] = 'Для этого контекста нет совместимых действий.'
Strings.en['hotbuild.context_editor.s101'] = 'Select a context on the left.'; Strings.ru['hotbuild.context_editor.s101'] = 'Выберите контекст слева.'
Strings.en['hotbuild.context_editor.s102'] = 'No actions for this context.'; Strings.ru['hotbuild.context_editor.s102'] = 'Для этого контекста нет действий.'
Strings.en['hotbuild.context_editor.s103'] = 'Create or select a set.'; Strings.ru['hotbuild.context_editor.s103'] = 'Создайте или выберите набор.'
Strings.en['hotbuild.context_editor.s104'] = 'Set a custom primary action first.'; Strings.ru['hotbuild.context_editor.s104'] = 'Сначала задайте собственное основное действие.'
Strings.en['hotbuild.context_editor.s105'] = 'Quick repeat is incompatible with this context.'; Strings.ru['hotbuild.context_editor.s105'] = 'Быстрый повтор несовместим с этим контекстом.'
Strings.en['hotbuild.context_editor.s106'] = 'Quick repeat selected: '; Strings.ru['hotbuild.context_editor.s106'] = 'Быстрый повтор выбран: '
Strings.en['hotbuild.context_editor.s107'] = 'Fallback is only available for custom selection actions.'; Strings.ru['hotbuild.context_editor.s107'] = 'Fallback доступен только для собственного действия выбора.'
Strings.en['hotbuild.context_editor.s108'] = 'Fallback is incompatible with this context.'; Strings.ru['hotbuild.context_editor.s108'] = 'Fallback несовместим с этим контекстом.'
Strings.en['hotbuild.context_editor.s109'] = 'Fallback selected: '; Strings.ru['hotbuild.context_editor.s109'] = 'Fallback выбран: '
Strings.en['hotbuild.context_editor.s110'] = 'Absolute mode only allows an empty-selection action.'; Strings.ru['hotbuild.context_editor.s110'] = 'В абсолютном режиме назначается только действие пустого выделения.'
Strings.en['hotbuild.context_editor.s111'] = ' · change the chain or disable inheritance for “'; Strings.ru['hotbuild.context_editor.s111'] = ' · сначала измените цепочку или отключите наследование для «'
Strings.en['hotbuild.context_editor.s112'] = 'Cannot assign “'; Strings.ru['hotbuild.context_editor.s112'] = 'Нельзя назначить «'
Strings.en['hotbuild.context_editor.s113'] = '”: context “'; Strings.ru['hotbuild.context_editor.s113'] = '»: контекст «'
Strings.en['hotbuild.context_editor.s114'] = '” is already occupied. Clear or disable it first.'; Strings.ru['hotbuild.context_editor.s114'] = '» уже занят. Сначала очистите или отключите его.'
Strings.en['hotbuild.context_editor.s115'] = 'Cannot assign “'; Strings.ru['hotbuild.context_editor.s115'] = 'Нельзя назначить «'
Strings.en['hotbuild.context_editor.s116'] = '” to tile “'; Strings.ru['hotbuild.context_editor.s116'] = '» плитке «'
Strings.en['hotbuild.context_editor.s117'] = '”: the empty-selection action policy blocks this tile. Clear the conflicting assignment first.'; Strings.ru['hotbuild.context_editor.s117'] = '»: политика действия пустого выделения блокирует эту плитку. Сначала очистите конфликтующее назначение.'
Strings.en['hotbuild.context_editor.s118'] = 'exclusive'; Strings.ru['hotbuild.context_editor.s118'] = 'исключительное'
Strings.en['hotbuild.context_editor.s119'] = 'sequential'; Strings.ru['hotbuild.context_editor.s119'] = 'последовательное'
Strings.en['hotbuild.context_editor.s120'] = 'double'; Strings.ru['hotbuild.context_editor.s120'] = 'двойное'
Strings.en['hotbuild.context_editor.s121'] = 'Cannot select “'; Strings.ru['hotbuild.context_editor.s121'] = 'Нельзя выбрать «'
Strings.en['hotbuild.context_editor.s122'] = ' empty-selection action conflicts with “'; Strings.ru['hotbuild.context_editor.s122'] = ' действие пустого выделения конфликтует с «'
Strings.en['hotbuild.context_editor.s123'] = 'assignment'; Strings.ru['hotbuild.context_editor.s123'] = 'назначением'
Strings.en['hotbuild.context_editor.s124'] = '). Clear the conflicting tile first.'; Strings.ru['hotbuild.context_editor.s124'] = '). Сначала очистите конфликтующую плитку.'
Strings.en['hotbuild.context_editor.s125'] = 'Selected: '; Strings.ru['hotbuild.context_editor.s125'] = 'Выбрано: '
Strings.en['hotbuild.context_editor.s126'] = 'Suggest launching a missile for ACU/SACU?'; Strings.ru['hotbuild.context_editor.s126'] = 'Предложить запуск ракеты для ACU/SACU?'
Strings.en['hotbuild.context_editor.s127'] = 'Choose separately; assign to both or skip.'; Strings.ru['hotbuild.context_editor.s127'] = 'Выберите отдельно; можно назначить обоим или пропустить.'
Strings.en['hotbuild.context_editor.s128'] = 'disabled'; Strings.ru['hotbuild.context_editor.s128'] = 'отключено'
Strings.en['hotbuild.context_editor.s129'] = 'saved in inherit mode'; Strings.ru['hotbuild.context_editor.s129'] = 'сохраняется в режиме наследования'
Strings.en['hotbuild.context_editor.s130'] = 'occupied by inherited action'; Strings.ru['hotbuild.context_editor.s130'] = 'занято наследуемым действием'
Strings.en['hotbuild.context_editor.s131'] = 'Assign '; Strings.ru['hotbuild.context_editor.s131'] = 'Назначить '
Strings.en['hotbuild.context_editor.s132'] = ' is already occupied: '; Strings.ru['hotbuild.context_editor.s132'] = ' уже занято: '
Strings.en['hotbuild.context_editor.s133'] = 'saved row'; Strings.ru['hotbuild.context_editor.s133'] = 'сохранённой строкой'
Strings.en['hotbuild.context_editor.s134'] = 'Done'; Strings.ru['hotbuild.context_editor.s134'] = 'Готово'
Strings.en['hotbuild.context_editor.s135'] = 'Assign the same action to SACU?'; Strings.ru['hotbuild.context_editor.s135'] = 'Поставить то же для SACU?'
Strings.en['hotbuild.context_editor.s136'] = 'Yes'; Strings.ru['hotbuild.context_editor.s136'] = 'Да'
Strings.en['hotbuild.context_editor.s137'] = 'No'; Strings.ru['hotbuild.context_editor.s137'] = 'Нет'
Strings.en['hotbuild.context_editor.s138'] = 'Close'; Strings.ru['hotbuild.context_editor.s138'] = 'Закрыть'
Strings.en['hotbuild.context_editor.s139'] = ' Saving is disabled.'; Strings.ru['hotbuild.context_editor.s139'] = ' Сохранение отключено.'
Strings.en['hotbuild.keyboard_bindings.s001'] = 'Launch missiles'; Strings.ru['hotbuild.keyboard_bindings.s001'] = 'Запуск ракет'
Strings.en['hotbuild.keyboard_bindings.s002'] = ' · obsolete'; Strings.ru['hotbuild.keyboard_bindings.s002'] = ' · устарело'
Strings.en['hotbuild.keyboard_bindings.s003'] = 'External assignment'; Strings.ru['hotbuild.keyboard_bindings.s003'] = 'Чужое назначение'
Strings.en['hotbuild.keyboard_bindings.s004'] = 'Key assignment profile is corrupted or has an unknown version.'; Strings.ru['hotbuild.keyboard_bindings.s004'] = 'Профиль назначений клавиш повреждён или имеет неизвестную версию.'
Strings.en['hotbuild.keyboard_bindings.s005'] = 'Hotbuild profile is corrupted; key migration is disabled.'; Strings.ru['hotbuild.keyboard_bindings.s005'] = 'Повреждён профиль Hotbuild; перенос клавиш отключён.'
Strings.en['hotbuild.keyboard_bindings.s006'] = 'Key assignment '; Strings.ru['hotbuild.keyboard_bindings.s006'] = 'Назначение клавиши '
Strings.en['hotbuild.keyboard_bindings.s007'] = ' does not match saved data; migration cancelled.'; Strings.ru['hotbuild.keyboard_bindings.s007'] = ' не соответствует сохранённым данным; перенос отменён.'
Strings.en['hotbuild.keyboard_bindings.s008'] = 'Conflicting old assignments for key '; Strings.ru['hotbuild.keyboard_bindings.s008'] = 'Противоречивые старые назначения клавиши '
Strings.en['hotbuild.keyboard_bindings.s009'] = '; migration cancelled.'; Strings.ru['hotbuild.keyboard_bindings.s009'] = '; перенос отменён.'
Strings.en['hotbuild.keyboard_bindings.s010'] = 'Could not migrate key assignments: '; Strings.ru['hotbuild.keyboard_bindings.s010'] = 'Не удалось перенести назначения клавиш: '
Strings.en['hotbuild.keyboard_bindings.s011'] = 'Invalid double-press pair.'; Strings.ru['hotbuild.keyboard_bindings.s011'] = 'Недопустимая пара двойного нажатия.'
Strings.en['hotbuild.keyboard_bindings.s012'] = 'Key action does not match the double-press action.'; Strings.ru['hotbuild.keyboard_bindings.s012'] = 'Действие клавиши не соответствует двойному нажатию.'
Strings.en['hotbuild.keyboard_bindings.s013'] = 'Could not save double press: '; Strings.ru['hotbuild.keyboard_bindings.s013'] = 'Не удалось сохранить двойное нажатие: '
Strings.en['hotbuild.keyboard_bindings.s014'] = 'Could not clear double press: '; Strings.ru['hotbuild.keyboard_bindings.s014'] = 'Не удалось очистить двойное нажатие: '
Strings.en['hotbuild.keyboard_bindings.s015'] = 'Assignment is no longer available.'; Strings.ru['hotbuild.keyboard_bindings.s015'] = 'Назначение больше недоступно.'
Strings.en['hotbuild.keyboard_bindings.s016'] = 'Old absolute assignments can only be cleared.'; Strings.ru['hotbuild.keyboard_bindings.s016'] = 'Старое абсолютное назначение можно только снять.'
Strings.en['hotbuild.keyboard_bindings.s017'] = 'Invalid key.'; Strings.ru['hotbuild.keyboard_bindings.s017'] = 'Некорректная клавиша.'
Strings.en['hotbuild.keyboard_bindings.s018'] = 'Key has multiple FAF assignments; saved data was not changed.'; Strings.ru['hotbuild.keyboard_bindings.s018'] = 'Клавиша занята несколькими назначениями FAF; сохранённые данные не изменены.'
Strings.en['hotbuild.keyboard_bindings.s019'] = 'automatic FAF Hotbuild modifier'; Strings.ru['hotbuild.keyboard_bindings.s019'] = 'автоматический модификатор Hotbuild FAF'
Strings.en['hotbuild.keyboard_bindings.s020'] = 'Replace old Claret data and FAF assignment: '; Strings.ru['hotbuild.keyboard_bindings.s020'] = 'Заменить старые данные Claret и назначение FAF: '
Strings.en['hotbuild.keyboard_bindings.s021'] = 'Replace old Claret data for this key?'; Strings.ru['hotbuild.keyboard_bindings.s021'] = 'Заменить старые данные Claret для этой клавиши?'
Strings.en['hotbuild.keyboard_bindings.s022'] = 'Replace the automatic FAF Hotbuild modifier for this combination?'; Strings.ru['hotbuild.keyboard_bindings.s022'] = 'Заменить автоматический модификатор Hotbuild FAF для этого сочетания?'
Strings.en['hotbuild.keyboard_bindings.s023'] = 'Build preset is unavailable.'; Strings.ru['hotbuild.keyboard_bindings.s023'] = 'Строительный пресет недоступен.'
Strings.en['hotbuild.keyboard_bindings.s024'] = 'Buildings are incompatible with builder actions.'; Strings.ru['hotbuild.keyboard_bindings.s024'] = 'Постройки несовместимы с действиями строителей.'
Strings.en['hotbuild.keyboard_bindings.s025'] = 'Production is incompatible with factory actions.'; Strings.ru['hotbuild.keyboard_bindings.s025'] = 'Производство несовместимо с действиями завода.'
Strings.en['hotbuild.keyboard_bindings.s026'] = 'Absolute bindings cannot be combined with presets.'; Strings.ru['hotbuild.keyboard_bindings.s026'] = 'Абсолютный бинд нельзя совместить с пресетом.'
Strings.en['hotbuild.keyboard_bindings.s027'] = 'Multifunction binding is unavailable or incompatible.'; Strings.ru['hotbuild.keyboard_bindings.s027'] = 'Мультифункциональный бинд недоступен или несовместим.'
Strings.en['hotbuild.keyboard_bindings.s028'] = 'Combination has multiple conflicting assignments.'; Strings.ru['hotbuild.keyboard_bindings.s028'] = 'Сочетание занято несколькими разными назначениями.'
Strings.en['hotbuild.keyboard_bindings.s029'] = 'Combination is occupied: '; Strings.ru['hotbuild.keyboard_bindings.s029'] = 'Сочетание занято: '
Strings.en['hotbuild.keyboard_bindings.s030'] = 'Unavailable: '; Strings.ru['hotbuild.keyboard_bindings.s030'] = 'Недоступно: '
Strings.en['hotbuild.keyboard_bindings.s031'] = 'Launch missiles'; Strings.ru['hotbuild.keyboard_bindings.s031'] = 'Запуск ракет'
Strings.en['hotbuild.keyboard_bindings.s032'] = 'Could not save assignment: '; Strings.ru['hotbuild.keyboard_bindings.s032'] = 'Не удалось сохранить назначение: '
Strings.en['hotbuild.keyboard_bindings.s033'] = 'Could not save assignment: '; Strings.ru['hotbuild.keyboard_bindings.s033'] = 'Не удалось сохранить назначение: '
Strings.en['hotbuild.keyboard_bindings.s034'] = 'Context binding is unavailable.'; Strings.ru['hotbuild.keyboard_bindings.s034'] = 'Контекстный бинд недоступен.'
Strings.en['hotbuild.keyboard_bindings.s035'] = 'This combination has no assignment.'; Strings.ru['hotbuild.keyboard_bindings.s035'] = 'На этом сочетании нет назначения.'
Strings.en['hotbuild.keyboard_bindings.s036'] = 'Assignment is unavailable.'; Strings.ru['hotbuild.keyboard_bindings.s036'] = 'Назначение недоступно.'
Strings.en['hotbuild.keyboard_bindings.s037'] = 'Assignment has already changed.'; Strings.ru['hotbuild.keyboard_bindings.s037'] = 'Назначение уже изменено.'
Strings.en['hotbuild.keyboard_bindings.s038'] = 'This slot has already changed.'; Strings.ru['hotbuild.keyboard_bindings.s038'] = 'Этот слот уже изменён.'
Strings.en['hotbuild.keyboard_bindings.s039'] = 'Assignment has already changed.'; Strings.ru['hotbuild.keyboard_bindings.s039'] = 'Назначение уже изменено.'
Strings.en['hotbuild.compatibility.s001'] = ' and '; Strings.ru['hotbuild.compatibility.s001'] = ' и '
Strings.en['hotbuild.compatibility.s002'] = ' and '; Strings.ru['hotbuild.compatibility.s002'] = ' и '
Strings.en['hotbuild.compatibility.s003'] = 'Engineer'; Strings.ru['hotbuild.compatibility.s003'] = 'Инженер'
Strings.en['hotbuild.compatibility.s004'] = 'Engineers'; Strings.ru['hotbuild.compatibility.s004'] = 'Инженера'
Strings.en['hotbuild.compatibility.s005'] = 'ACU and Engineer'; Strings.ru['hotbuild.compatibility.s005'] = 'ACU и Инженер'
Strings.en['hotbuild.compatibility.s006'] = 'ACU and Engineers'; Strings.ru['hotbuild.compatibility.s006'] = 'ACU и Инженера'
Strings.en['hotbuild.compatibility.s007'] = 'SACU and Engineer'; Strings.ru['hotbuild.compatibility.s007'] = 'SACU и Инженер'
Strings.en['hotbuild.compatibility.s008'] = 'SACU and Engineers'; Strings.ru['hotbuild.compatibility.s008'] = 'SACU и Инженера'
Strings.en['hotbuild.compatibility.s009'] = 'ACU, SACU, and Engineer'; Strings.ru['hotbuild.compatibility.s009'] = 'ACU, SACU и Инженер'
Strings.en['hotbuild.compatibility.s010'] = 'ACU, SACU, and Engineers'; Strings.ru['hotbuild.compatibility.s010'] = 'ACU, SACU и Инженера'
Strings.en['hotbuild.compatibility.s011'] = 'tile '; Strings.ru['hotbuild.compatibility.s011'] = 'плитку '
Strings.en['hotbuild.compatibility.s012'] = 'tiles '; Strings.ru['hotbuild.compatibility.s012'] = 'плитки '
Strings.en['hotbuild.compatibility.s013'] = 'Hotbuild “%s” contains buildings, but the set has actions assigned to the Builders and %s tiles. Clear the Builders and %s tiles or choose another set.'; Strings.ru['hotbuild.compatibility.s013'] = 'В хотбилде «%s» есть постройки, а в наборе заданы действия для плиток «Строители» и %s. Очистите плитку «Строители» и %s или выберите другой набор.'
Strings.en['hotbuild.compatibility.s014'] = 'Hotbuild “%s” contains buildings, but the set has an action assigned to the Builders tile. Clear the Builders tile or choose another set.'; Strings.ru['hotbuild.compatibility.s014'] = 'В хотбилде «%s» есть постройки, а в наборе задано действие для плитки «Строители». Очистите плитку «Строители» или выберите другой набор.'
Strings.en['hotbuild.compatibility.s015'] = 'Engineer'; Strings.ru['hotbuild.compatibility.s015'] = 'Инженер'
Strings.en['hotbuild.compatibility.s016'] = 'Engineers'; Strings.ru['hotbuild.compatibility.s016'] = 'Инженера'
Strings.en['hotbuild.compatibility.s017'] = 'ACU and Engineer'; Strings.ru['hotbuild.compatibility.s017'] = 'ACU и Инженер'
Strings.en['hotbuild.compatibility.s018'] = 'ACU and Engineers'; Strings.ru['hotbuild.compatibility.s018'] = 'ACU и Инженера'
Strings.en['hotbuild.compatibility.s019'] = 'SACU and Engineer'; Strings.ru['hotbuild.compatibility.s019'] = 'SACU и Инженер'
Strings.en['hotbuild.compatibility.s020'] = 'SACU and Engineers'; Strings.ru['hotbuild.compatibility.s020'] = 'SACU и Инженера'
Strings.en['hotbuild.compatibility.s021'] = 'ACU, SACU, and Engineer'; Strings.ru['hotbuild.compatibility.s021'] = 'ACU, SACU и Инженер'
Strings.en['hotbuild.compatibility.s022'] = 'ACU, SACU, and Engineers'; Strings.ru['hotbuild.compatibility.s022'] = 'ACU, SACU и Инженера'
Strings.en['hotbuild.compatibility.s023'] = 'tile '; Strings.ru['hotbuild.compatibility.s023'] = 'плитку '
Strings.en['hotbuild.compatibility.s024'] = 'tiles '; Strings.ru['hotbuild.compatibility.s024'] = 'плитки '
Strings.en['hotbuild.compatibility.s025'] = 'Hotbuild “%s” contains buildings, but the set has an action assigned to %s. Clear %s or choose another set.'; Strings.ru['hotbuild.compatibility.s025'] = 'В хотбилде «%s» есть постройки, а в наборе задано действие для %s. Очистите %s или выберите другой набор.'
Strings.en['hotbuild.compatibility.s026'] = 'Binding “%s” references missing multifunction binding “%s”. Select an existing multifunction binding or clear the assignment.'; Strings.ru['hotbuild.compatibility.s026'] = 'Бинд «%s» ссылается на отсутствующий мультифункциональный бинд «%s». Выберите существующий мультифункциональный бинд или очистите назначение.'
Strings.en['hotbuild.compatibility.s027'] = 'Hotbuild “%s” cannot reference absolute multifunction binding “%s”. Remove this link and assign the absolute binding to its own key.'; Strings.ru['hotbuild.compatibility.s027'] = 'Hotbuild «%s» не может ссылаться на абсолютный мультифункциональный бинд «%s». Удалите эту связь и назначьте отдельную клавишу абсолютному бинду.'
Strings.en['hotbuild.compatibility.s028'] = 'unassigned'; Strings.ru['hotbuild.compatibility.s028'] = 'не назначена'
Strings.en['hotbuild.compatibility.s029'] = 'Binding “%s” (key %s), tile “%s”: the preset contains factory-produced units. Remove this tile or change the preset.'; Strings.ru['hotbuild.compatibility.s029'] = 'Бинд «%s» (клавиша %s), плитка «%s»: пресет содержит объекты, производимые заводом. Уберите эту плитку или измените пресет.'
Strings.en['hotbuild.compatibility.s030'] = 'Warning: binding “%s” (key %s), tile “%s” is linked to a build preset. When a mobile factory is selected, the multifunction binding takes priority over the preset.'; Strings.ru['hotbuild.compatibility.s030'] = 'Предупреждение: бинд «%s» (клавиша %s), плитка «%s» связана со строительным пресетом. При выборе мобильного завода приоритет получит мультифункциональный бинд, а не пресет.'
Strings.en['hotbuild.compatibility.s031'] = 'key unassigned'; Strings.ru['hotbuild.compatibility.s031'] = 'клавиша не назначена'
Strings.en['hotbuild.compatibility.s032'] = 'Cannot enable absolute mode: multifunction binding is already linked to Hotbuild '; Strings.ru['hotbuild.compatibility.s032'] = 'Нельзя включить абсолютный режим: мультифункциональный бинд уже подключён к Hotbuild '
Strings.en['hotbuild.compatibility.s033'] = '. Unlink it from every Hotbuild first.'; Strings.ru['hotbuild.compatibility.s033'] = '. Сначала отсоедините его от каждого Hotbuild.'
Strings.en['hotbuild.compatibility.s034'] = 'unassigned'; Strings.ru['hotbuild.compatibility.s034'] = 'не назначена'
Strings.en['hotbuild.compatibility.s035'] = 'Warning: Hotbuild “%s” (key %s) contains factory-produced units; saving with tile “%s” will be rejected.'; Strings.ru['hotbuild.compatibility.s035'] = 'Предупреждение: Hotbuild «%s» (клавиша %s) содержит объекты, производимые заводом; сохранение с плиткой «%s» будет отклонено.'
Strings.en['hotbuild.compatibility.s036'] = 'occupied by building Hotbuild: “'; Strings.ru['hotbuild.compatibility.s036'] = 'занято хотбилдом зданий: «'
Strings.en['hotbuild.runtime.s001'] = 'Action is unavailable for the current selection.'; Strings.ru['hotbuild.runtime.s001'] = 'Действие недоступно для текущего выделения.'
Strings.en['hotbuild.runtime.s002'] = 'Action is unavailable for selection'; Strings.ru['hotbuild.runtime.s002'] = 'Действие недоступно для выделения'
Strings.en['hotbuild.runtime.s003'] = 'Action is unavailable'; Strings.ru['hotbuild.runtime.s003'] = 'Действие недоступно'
Strings.en['hotbuild.runtime.s004'] = 'Hotbuild profile is corrupted or has an unknown version; key assignments were not updated.'; Strings.ru['hotbuild.runtime.s004'] = 'Профиль Hotbuild повреждён или имеет неизвестную версию; назначения клавиш не обновлены.'
Strings.en['hotbuild.runtime.s005'] = 'Action is unavailable for selection'; Strings.ru['hotbuild.runtime.s005'] = 'Действие недоступно для выделения'
Strings.en['hotbuild.runtime.s006'] = 'Multifunction binding is unavailable: '; Strings.ru['hotbuild.runtime.s006'] = 'Мультифункциональный бинд недоступен: '
Strings.en['hotbuild.runtime.s007'] = 'Absolute binding is unavailable.'; Strings.ru['hotbuild.runtime.s007'] = 'Абсолютный бинд недоступен.'
Strings.en['hotbuild.runtime.s008'] = 'No empty-selection action is assigned to the absolute binding.'; Strings.ru['hotbuild.runtime.s008'] = 'В абсолютном бинде не назначено действие пустого выделения.'
Strings.en['hotbuild.runtime.s009'] = 'Action is unavailable for selection'; Strings.ru['hotbuild.runtime.s009'] = 'Действие недоступно для выделения'
Strings.en['hotbuild.runtime.s010'] = 'Action is unavailable for selection'; Strings.ru['hotbuild.runtime.s010'] = 'Действие недоступно для выделения'
Strings.en['hotbuild.runtime.s011'] = 'Action is unavailable.'; Strings.ru['hotbuild.runtime.s011'] = 'Действие недоступно.'
Strings.en['hotbuild.runtime.s012'] = 'Action is unavailable for the current selection.'; Strings.ru['hotbuild.runtime.s012'] = 'Действие недоступно для текущего выделения.'
Strings.en['hotbuild.runtime.s013'] = 'Action is unavailable for selection'; Strings.ru['hotbuild.runtime.s013'] = 'Действие недоступно для выделения'
Strings.en['hotbuild.runtime.s014'] = 'Multifunction binding is unavailable.'; Strings.ru['hotbuild.runtime.s014'] = 'Мультифункциональный бинд недоступен.'
Strings.en['hotbuild.runtime.s015'] = 'No action is assigned for the current selection.'; Strings.ru['hotbuild.runtime.s015'] = 'Для текущего выделения нет назначенного действия.'
Strings.en['hotbuild.runtime.s016'] = 'Key assignment is unavailable.'; Strings.ru['hotbuild.runtime.s016'] = 'Назначение клавиши недоступно.'
Strings.en['hotbuild.runtime.s017'] = 'Key assignment is empty.'; Strings.ru['hotbuild.runtime.s017'] = 'Назначение клавиши пусто.'
Strings.en['hotbuild.runtime.s018'] = 'Hotbuild profile is corrupted or has an unknown version; saving is disabled.'; Strings.ru['hotbuild.runtime.s018'] = 'Профиль Hotbuild повреждён или имеет неизвестную версию; сохранение отключено.'
Strings.en['hotbuild.runtime.s019'] = 'Binding name: English letters, digits, and ASCII punctuation only.'; Strings.ru['hotbuild.runtime.s019'] = 'Название бинда: только английские буквы, цифры и знаки ASCII.'
Strings.en['hotbuild.runtime.s020'] = 'Unassign this preset from all keys first.'; Strings.ru['hotbuild.runtime.s020'] = 'Сначала снимите этот пресет со всех клавиш.'
Strings.en['hotbuild.runtime.s021'] = '<LOC claret_hotbuild_saved>Saved.'; Strings.ru['hotbuild.runtime.s021'] = '<LOC claret_hotbuild_saved>Сохранено.'
Strings.en['hotbuild.runtime.s022'] = 'Multifunction binding data is corrupted or has an unknown version.'; Strings.ru['hotbuild.runtime.s022'] = 'Данные мультифункциональных биндов повреждены или имеют неизвестную версию.'
Strings.en['hotbuild.runtime.s023'] = 'Cannot edit multifunction binding: the Hotbuild profile is corrupted or has an unknown version, so linked tiles cannot be checked.'; Strings.ru['hotbuild.runtime.s023'] = 'Нельзя изменить мультифункциональный бинд: профиль Hotbuild повреждён или имеет неизвестную версию, поэтому связанные плитки нельзя проверить.'
Strings.en['hotbuild.runtime.s024'] = 'Hotbuild profile is corrupted or has an unknown version; deleting context bindings is disabled.'; Strings.ru['hotbuild.runtime.s024'] = 'Профиль Hotbuild повреждён или имеет неизвестную версию; удаление контекстного бинда отключено.'
Strings.en['hotbuild.runtime.s025'] = 'Confirm deletion of this multifunction binding’s direct assignments.'; Strings.ru['hotbuild.runtime.s025'] = 'Подтвердите удаление прямых назначений этого мультифункционального бинда.'
Strings.en['hotbuild.runtime.s026'] = 'Could not save: '; Strings.ru['hotbuild.runtime.s026'] = 'Не удалось сохранить: '
Strings.en['hotbuild.runtime.s027'] = '<LOC claret_hotbuild_saved>Saved.'; Strings.ru['hotbuild.runtime.s027'] = '<LOC claret_hotbuild_saved>Сохранено.'
Strings.en['hotbuild.templates.s001'] = 'Template '; Strings.ru['hotbuild.templates.s001'] = 'Шаблон '
Strings.en['hotbuild.templates.s002'] = 'Build template · '; Strings.ru['hotbuild.templates.s002'] = 'Шаблон строительства · '
Strings.en['hotbuild.templates.s003'] = ' buildings'; Strings.ru['hotbuild.templates.s003'] = ' построек'
Strings.en['hotbuild.templates.s004'] = ' build template'; Strings.ru['hotbuild.templates.s004'] = ' шаблон строительства'
Strings.en['hotbuild.templates.s005'] = 'Unit template · '; Strings.ru['hotbuild.templates.s005'] = 'Шаблон юнитов · '
Strings.en['hotbuild.templates.s006'] = ' units'; Strings.ru['hotbuild.templates.s006'] = ' юнитов'
Strings.en['hotbuild.templates.s007'] = ' unit template'; Strings.ru['hotbuild.templates.s007'] = ' шаблон юнитов'

Strings.en['hotbuild.keyboard_editor.s001'] = 'Assign: '; Strings.ru['hotbuild.keyboard_editor.s001'] = 'Назначить: '
Strings.en['hotbuild.keyboard_editor.s002'] = 'empty'; Strings.ru['hotbuild.keyboard_editor.s002'] = 'пусто'
Strings.en['hotbuild.keyboard_editor.s003'] = 'empty'; Strings.ru['hotbuild.keyboard_editor.s003'] = 'пусто'
Strings.en['hotbuild.keyboard_editor.s004'] = ' · Repeat: '; Strings.ru['hotbuild.keyboard_editor.s004'] = ' · Повтор: '
Strings.en['hotbuild.keyboard_editor.s005'] = 'Building: '; Strings.ru['hotbuild.keyboard_editor.s005'] = 'Стройка: '
Strings.en['hotbuild.keyboard_editor.s006'] = 'Actions: '; Strings.ru['hotbuild.keyboard_editor.s006'] = 'Действия: '
Strings.en['hotbuild.keyboard_editor.s007'] = ' · Occupied: '; Strings.ru['hotbuild.keyboard_editor.s007'] = ' · Занято: '
Strings.en['hotbuild.keyboard_editor.s008'] = 'Double press'; Strings.ru['hotbuild.keyboard_editor.s008'] = 'Двойное нажатие'
Strings.en['hotbuild.keyboard_editor.s009'] = 'Choose an action for the second press:'; Strings.ru['hotbuild.keyboard_editor.s009'] = 'Выберите действие для повторного нажатия:'
Strings.en['hotbuild.keyboard_editor.s010'] = 'Could not save.'; Strings.ru['hotbuild.keyboard_editor.s010'] = 'Не удалось сохранить.'
Strings.en['hotbuild.keyboard_editor.s011'] = 'Double press saved.'; Strings.ru['hotbuild.keyboard_editor.s011'] = 'Двойное нажатие сохранено.'
Strings.en['hotbuild.keyboard_editor.s012'] = 'No repeat'; Strings.ru['hotbuild.keyboard_editor.s012'] = 'Без повтора'
Strings.en['hotbuild.keyboard_editor.s013'] = 'Could not save.'; Strings.ru['hotbuild.keyboard_editor.s013'] = 'Не удалось сохранить.'
Strings.en['hotbuild.keyboard_editor.s014'] = 'Double press disabled.'; Strings.ru['hotbuild.keyboard_editor.s014'] = 'Двойное нажатие отключено.'
Strings.en['hotbuild.keyboard_editor.s015'] = 'Close'; Strings.ru['hotbuild.keyboard_editor.s015'] = 'Закрыть'
Strings.en['hotbuild.keyboard_editor.s016'] = 'The slot is already empty.'; Strings.ru['hotbuild.keyboard_editor.s016'] = 'Слот уже пуст.'
Strings.en['hotbuild.keyboard_editor.s017'] = 'Could not clear assignment.'; Strings.ru['hotbuild.keyboard_editor.s017'] = 'Не удалось снять назначение.'
Strings.en['hotbuild.keyboard_editor.s018'] = 'Assignment cleared.'; Strings.ru['hotbuild.keyboard_editor.s018'] = 'Назначение снято.'
Strings.en['hotbuild.keyboard_editor.s019'] = 'Assignment cleared.'; Strings.ru['hotbuild.keyboard_editor.s019'] = 'Назначение снято.'
Strings.en['hotbuild.keyboard_editor.s020'] = 'Clear building'; Strings.ru['hotbuild.keyboard_editor.s020'] = 'Снять стройку'
Strings.en['hotbuild.keyboard_editor.s021'] = 'Clear actions'; Strings.ru['hotbuild.keyboard_editor.s021'] = 'Снять действия'
Strings.en['hotbuild.keyboard_editor.s022'] = 'Double press…'; Strings.ru['hotbuild.keyboard_editor.s022'] = 'Двойное нажатие…'
Strings.en['hotbuild.keyboard_editor.s023'] = 'Bindings'; Strings.ru['hotbuild.keyboard_editor.s023'] = 'Бинды'
Strings.en['hotbuild.keyboard_editor.s024'] = 'Multifunction'; Strings.ru['hotbuild.keyboard_editor.s024'] = 'Мультифункциональные'
Strings.en['hotbuild.keyboard_editor.s025'] = 'Hotbuild preset'; Strings.ru['hotbuild.keyboard_editor.s025'] = 'HotBuild пресет'
Strings.en['hotbuild.keyboard_editor.s026'] = 'Could not assign combination.'; Strings.ru['hotbuild.keyboard_editor.s026'] = 'Не удалось назначить сочетание.'
Strings.en['hotbuild.keyboard_editor.s027'] = 'Assignment saved.'; Strings.ru['hotbuild.keyboard_editor.s027'] = 'Назначение сохранено.'
Strings.en['hotbuild.keyboard_editor.s028'] = 'Untitled'; Strings.ru['hotbuild.keyboard_editor.s028'] = 'Без названия'
Strings.en['hotbuild.keyboard_editor.s029'] = '[OLD] '; Strings.ru['hotbuild.keyboard_editor.s029'] = '[СТАРЫЙ] '
Strings.en['hotbuild.keyboard_editor.s030'] = 'Could not assign combination.'; Strings.ru['hotbuild.keyboard_editor.s030'] = 'Не удалось назначить сочетание.'
Strings.en['hotbuild.keyboard_editor.s031'] = 'Link assignments?'; Strings.ru['hotbuild.keyboard_editor.s031'] = 'Связать назначения?'
Strings.en['hotbuild.keyboard_editor.s032'] = 'Reassign?'; Strings.ru['hotbuild.keyboard_editor.s032'] = 'Хотите переназначить?'
Strings.en['hotbuild.keyboard_editor.s033'] = 'Combination is occupied.'; Strings.ru['hotbuild.keyboard_editor.s033'] = 'Сочетание занято.'
Strings.en['hotbuild.keyboard_editor.s034'] = 'Set to be replaced: '; Strings.ru['hotbuild.keyboard_editor.s034'] = 'Заменится набор: '
Strings.en['hotbuild.keyboard_editor.s035'] = 'The set will be linked to the preset.'; Strings.ru['hotbuild.keyboard_editor.s035'] = 'Набор будет подключён к пресету.'
Strings.en['hotbuild.keyboard_editor.s036'] = 'The link applies to this key combination.'; Strings.ru['hotbuild.keyboard_editor.s036'] = 'Связь задаётся для этого сочетания клавиш.'
Strings.en['hotbuild.keyboard_editor.s037'] = 'Cancel'; Strings.ru['hotbuild.keyboard_editor.s037'] = 'Отмена'
Strings.en['hotbuild.keyboard_editor.s038'] = 'Link'; Strings.ru['hotbuild.keyboard_editor.s038'] = 'Связать'
Strings.en['hotbuild.keyboard_editor.s039'] = 'Reassign'; Strings.ru['hotbuild.keyboard_editor.s039'] = 'Переназначить'
Strings.en['hotbuild.keyboard_editor.s040'] = 'List is empty'; Strings.ru['hotbuild.keyboard_editor.s040'] = 'Список пуст'
Strings.en['hotbuild.keyboard_editor.s041'] = ' of '; Strings.ru['hotbuild.keyboard_editor.s041'] = ' из '
Strings.en['hotbuild.keyboard_editor.s042'] = 'Close'; Strings.ru['hotbuild.keyboard_editor.s042'] = 'Закрыть'
Strings.en['hotbuild.keyboard_editor.s043'] = 'Filled cells have an assignment. The tooltip shows the selected combination.'; Strings.ru['hotbuild.keyboard_editor.s043'] = 'Закрашена — сочетание занято. Подсказка показывает выбранное сочетание.'
Strings.en['hotbuild.keyboard_editor.s044'] = 'This combination has no assignment.'; Strings.ru['hotbuild.keyboard_editor.s044'] = 'На этом сочетании нет назначения.'
Strings.en['hotbuild.keyboard_editor.s045'] = 'Could not clear assignment.'; Strings.ru['hotbuild.keyboard_editor.s045'] = 'Не удалось снять назначение.'
Strings.en['hotbuild.keyboard_editor.s046'] = 'Assignments cleared.'; Strings.ru['hotbuild.keyboard_editor.s046'] = 'Назначения сняты.'
Strings.en['hotbuild.keyboard_editor.s047'] = '+ Shift'; Strings.ru['hotbuild.keyboard_editor.s047'] = '+ Shift'
Strings.en['hotbuild.keyboard_editor.s048'] = 'Shift is already selected.'; Strings.ru['hotbuild.keyboard_editor.s048'] = 'Shift уже выбрана.'
Strings.en['hotbuild.context_model.s001'] = 'Invalid binding ID'; Strings.ru['hotbuild.context_model.s001'] = 'Некорректный ID бинда'
Strings.en['hotbuild.context_model.s002'] = 'Unknown binding field'; Strings.ru['hotbuild.context_model.s002'] = 'Неизвестное поле бинда'
Strings.en['hotbuild.context_model.s003'] = 'Binding name is required'; Strings.ru['hotbuild.context_model.s003'] = 'Название бинда обязательно'
Strings.en['hotbuild.context_model.s004'] = 'Invalid absolute binding mode'; Strings.ru['hotbuild.context_model.s004'] = 'Некорректный режим абсолютного бинда'
Strings.en['hotbuild.context_model.s005'] = 'Name must be 1–128 bytes long'; Strings.ru['hotbuild.context_model.s005'] = 'Название должно содержать от 1 до 128 байт'
Strings.en['hotbuild.context_model.s006'] = 'Entries must form a contiguous list'; Strings.ru['hotbuild.context_model.s006'] = 'Состав должен быть непрерывным списком'
Strings.en['hotbuild.context_model.s007'] = 'Row count must be between 0 and 64'; Strings.ru['hotbuild.context_model.s007'] = 'Число строк должно быть от 0 до 64'
Strings.en['hotbuild.context_model.s008'] = 'Invalid row '; Strings.ru['hotbuild.context_model.s008'] = 'Некорректная строка '
Strings.en['hotbuild.context_model.s009'] = 'Unknown row field'; Strings.ru['hotbuild.context_model.s009'] = 'Неизвестное поле строки'
Strings.en['hotbuild.context_model.s010'] = 'Invalid extra action ID'; Strings.ru['hotbuild.context_model.s010'] = 'Некорректный ID дополнительного действия'
Strings.en['hotbuild.context_model.s011'] = 'Duplicate context: '; Strings.ru['hotbuild.context_model.s011'] = 'Контекст повторяется: '
Strings.en['hotbuild.context_model.s012'] = 'Fallback action is only valid for selection'; Strings.ru['hotbuild.context_model.s012'] = 'Резервное действие допустимо только для выбора'
Strings.en['hotbuild.context_model.s013'] = 'Fallback action is not supported by context '; Strings.ru['hotbuild.context_model.s013'] = 'Резервное действие не поддерживается контекстом '
Strings.en['hotbuild.context_model.s014'] = 'Unknown context: '; Strings.ru['hotbuild.context_model.s014'] = 'Неизвестный контекст: '
Strings.en['hotbuild.context_model.s015'] = 'Invalid child context mode'; Strings.ru['hotbuild.context_model.s015'] = 'Некорректный режим дочернего контекста'
Strings.en['hotbuild.context_model.s016'] = 'Custom action requires a valid ID'; Strings.ru['hotbuild.context_model.s016'] = 'Для собственного действия нужен корректный ID'
Strings.en['hotbuild.context_model.s017'] = 'Action '; Strings.ru['hotbuild.context_model.s017'] = 'Действие '
Strings.en['hotbuild.context_model.s018'] = ' does not support context '; Strings.ru['hotbuild.context_model.s018'] = ' не поддерживает контекст '
Strings.en['hotbuild.context_model.s019'] = 'Action is not supported by child context '; Strings.ru['hotbuild.context_model.s019'] = 'Действие не поддерживается дочернему контексту '
Strings.en['hotbuild.context_model.s020'] = 'Quick repeat is not supported by context '; Strings.ru['hotbuild.context_model.s020'] = 'Быстрый повтор не поддерживается контекстом '
Strings.en['hotbuild.context_model.s021'] = 'A primary action is required before adding extra actions'; Strings.ru['hotbuild.context_model.s021'] = 'Для дополнительных действий нужно основное действие'
Strings.en['hotbuild.context_model.s022'] = 'Invalid action in row '; Strings.ru['hotbuild.context_model.s022'] = 'Некорректное действие в строке '
Strings.en['hotbuild.context_model.s023'] = 'Unknown action: '; Strings.ru['hotbuild.context_model.s023'] = 'Неизвестное действие: '
Strings.en['hotbuild.context_model.s024'] = 'Action '; Strings.ru['hotbuild.context_model.s024'] = 'Действие '
Strings.en['hotbuild.context_model.s025'] = ' does not support context '; Strings.ru['hotbuild.context_model.s025'] = ' не поддерживает контекст '
Strings.en['hotbuild.context_model.s026'] = 'Quick repeat is not supported by context '; Strings.ru['hotbuild.context_model.s026'] = 'Быстрый повтор не поддерживается контекстом '
Strings.en['hotbuild.context_model.s027'] = 'Mode is only valid for a child row'; Strings.ru['hotbuild.context_model.s027'] = 'Режим допустим только для дочерней строки'
Strings.en['hotbuild.context_model.s028'] = 'ContextActions catalog is missing'; Strings.ru['hotbuild.context_model.s028'] = 'Не передан каталог ContextActions'
Strings.en['hotbuild.context_model.s029'] = 'Maximum bindings: 64'; Strings.ru['hotbuild.context_model.s029'] = 'Максимум биндов: 64'
Strings.en['hotbuild.context_model.s030'] = 'Profile is corrupted or the action catalog is unavailable; saving is disabled'; Strings.ru['hotbuild.context_model.s030'] = 'Профиль повреждён или каталог действий недоступен; сохранение запрещено'
Strings.en['hotbuild.context_model.s031'] = 'Maximum of 64 bindings exceeded'; Strings.ru['hotbuild.context_model.s031'] = 'Превышен максимум в 64 бинда'
Strings.en['hotbuild.context_model.s032'] = 'Duplicate binding ID'; Strings.ru['hotbuild.context_model.s032'] = 'Повторный ID бинда'
Strings.en['hotbuild.context_model.s033'] = 'Binding '; Strings.ru['hotbuild.context_model.s033'] = 'Бинд '
Strings.en['hotbuild.context_model.s034'] = ': multiple old under-cursor actions; choose an action manually for the new context'; Strings.ru['hotbuild.context_model.s034'] = ': несколько прежних действий под курсором; выберите действие для нового контекста вручную'
Strings.en['hotbuild.context_model.s035'] = 'Binding '; Strings.ru['hotbuild.context_model.s035'] = 'Бинд '
Strings.en['hotbuild.context_model.s036'] = ': unknown context or unsupported action '; Strings.ru['hotbuild.context_model.s036'] = ': неизвестный контекст или неприменимое действие '
Strings.en['hotbuild.context_repeat.s001'] = 'Key is held down'; Strings.ru['hotbuild.context_repeat.s001'] = 'Клавиша удерживается'
Strings.en['hotbuild.context_repeat.s002'] = 'Action is unavailable for selection'; Strings.ru['hotbuild.context_repeat.s002'] = 'Действие недоступно для выделения'
Strings.en['hotbuild.context_repeat.s003'] = 'Action is unavailable for selection'; Strings.ru['hotbuild.context_repeat.s003'] = 'Действие недоступно для выделения'
Strings.en['hotbuild.keyboard.mouse4'] = 'Mouse 4'; Strings.ru['hotbuild.keyboard.mouse4'] = 'Мышь 4'
Strings.en['hotbuild.keyboard.mouse5'] = 'Mouse 5'; Strings.ru['hotbuild.keyboard.mouse5'] = 'Мышь 5'
