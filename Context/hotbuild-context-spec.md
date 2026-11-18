# Claret Hotbuild context binds — target spec (2026-11-13)

Agreed with the user. Follow Context/hotbuild-rules.md and Context/menu-rules.md.
Native FAF command strings: Context/faf-actions-inventory.md (reuse, do not invent).

## Актуализация 2026-11-14

Следующие решения заменяют противоречащие им исторические пункты каталога ниже. «Под курсором» проверяется перед всеми контекстами и содержит три действия улучшения. Однозначные старые строки переносятся без потери дополнительных полей; неоднозначные сохраняются для ручной замены. Встроенные цепочки и занятые результирующие контексты блокируют друг друга, сохранённые конфликты остаются. Новый каталог предлагает только мгновенное самоуничтожение; заправка, режим огня и сброс приоритета целей скрыты. Одна команда запуска ракет доступна ракетным установкам, ACU и SACU и выбирает доступный тип; смешанные типы не запускаются. Старые отдельные запуски и прочие удалённые действия работают и отмечаются как устаревшие. В списке наборов удаление подтверждается с показом назначенных клавиш и снимает только этот набор. В окне клавиатуры слоты снимаются отдельными подписанными кнопками.

## 1. Columns and priority
Mixed selection: the highest-priority matching column with an assigned action
wins; empty rows are skipped. "Nothing selected" is separate.
0. Nothing selected
1. Units (group): Land, Air, Navy. Units = mobile units EXCLUDING builders
   (ACU/SACU/engineers), transports and scouts.
2. Builders (group): ACU, SACU, Engineer
3. Factory
4. Missiles (group): TML, Nuke — replaces the separate TML and Nuke columns
5. Transport
6. Mass extractors
7. Scouts
8. Other

## 2. Groups and inheritance
- Child columns inherit the parent action, may disable it or override it.
- A parent column offers only actions valid for ALL its children.
- Mixed selection inside one group (e.g. land + air) with different effective
  actions -> do nothing. Same effective action -> execute.

## 3. Applicability: no impossible binds
- Every catalog action declares the columns where it is valid. The editor lists
  only valid actions per column, including the repeat and fallback fields.
- Capability-dependent actions (shield toggle, teleport, SACU Overcharge which
  is an upgrade) are valid by column; at press, units that can execute, the rest
  ignore; if nobody can, nothing happens.
- Assigned action not applicable at press -> do nothing; never fall through to
  the next column.
- Saved binds that become invalid: keep them, show as invalid in the editor
  with a replace prompt; never delete silently.

## 4. Row fields
Each column row has:
- Action (first press).
- Quick repeat (optional): same key pressed again within the repeat window and
  the selection unchanged since the result of the previous press.
- Fallback (optional): runs if the action found nothing
  (e.g. no idle transport -> nearest transport).
Notes:
- Chaining also works naturally through columns: after a press selects a
  transport, the next press uses the Transport column. No setting needed.
- Repeat window: one global setting in F10 -> Claret, default 1.5 s.
  Within the window quick repeat has priority over the column row.
- A different key breaks the repeat chain.
- Existing actions with built-in double/accumulate behaviour stay in the
  catalog with the same IDs (compatibility).

## 5. Absolute binds
- The existing per-bind absolute flag stays.
- An absolute bind is one row (action + quick repeat + fallback) used in any
  context.
- Only selection-independent actions are allowed (the "Nothing selected" pool).

## 6. Building hotbuild exclusivity
- One key may hold a building hotbuild (for builders) AND context rows for other
  columns.
- If a key has a building preset, the whole Builders group (common, ACU, SACU,
  Engineer) for that key is locked, label "занято хотбилдом зданий".
  Vice versa: if any Builders row is set, a building preset cannot be assigned
  to that key; the keyboard editor shows what occupies it.
- With Units first, army + builders mixed selection runs the Units row (accepted).

## 7. Catalog per column ("+" = new, native FAF id in brackets)

### Nothing selected (also the pool for absolute binds)
- ACU: Выбрать ACU; Выбрать ACU / перейти по повтору; Перейти к ACU
- Engineers: Ближайший свободный T1 инженер на экране; Свободные инженеры на экране;
  Последовательно добавить инженеров T1 / T2 / T3 / всех уровней
- Army: Наземная армия на экране / на карте; Водные войска на экране / на карте;
  Мобильная T3 артиллерия, Мобильные щиты, Мобильные стелс-генераторы,
  Мобильные MML на экране; Мобильные наземные экспериментальные;
  Все наземные экспериментальные; Все воздушные экспериментальные
- Air: Все бомбардировщики; Все истребители; Все штурмовики;
  Ближайший воздушный разведчик; Выбрать всех воздушных разведчиков
- Transport: Ближайший свободный; Ближайший; Один свободный / все по повтору;
  Транспорт на экране; Транспорт на карте
- Structures: Все радары; Все сенсоры; Все TML; Все ядерные шахты; Спутники
- Factories: + Перебор простаивающих заводов [cycle_idle_factories]
- Under cursor: Улучшить структуру под курсором;
  Улучшить добытчик и выбрать ближайший следующий

### 1. Units
Common: Движение; Атака; Атака с движением; + Патруль [patrol]; Стоп;
+ Режим огня [mode]; + Приоритет целей / сбросить
[set_target_priority / set_default_target_priority]; + Распределить приказы
[spreadattack]; + Скопировать приказы [copy_orders]; + Погрузить в транспорт
[load_transports]; + Разделить выделение: по типу / по уровню / на группы /
следующая подгруппа [split_layer / split_tech / split_into_groups_N / split_next];
+ Переключение суша / флот / авиация в выделении [cycle_unit_types_in_sel];
+ Самоуничтожение [suicide, with confirmation]
- Land: + Переключить щит [toggle_shield]; + Скрытность [toggle_stealth];
  + Разрядить щиты [discharge]
- Air: + На посадку [dock]; + Посадка повреждённых [dock_damaged]
- Navy: + Погрузиться / всплыть [dive / dive_all / undive_all];
  + Переключить щит; + Скрытность

### 2. Builders
Common: Реклейм; Помощь / охрана; Движение; Атака; Атака с движением;
+ Патруль [patrol]; + Ремонт [repair]; + Захват [capture]; Стоп;
Переключить щит; Скрытность; + Распределить приказы [spreadattack];
+ Скопировать приказы [copy_orders]; + Обстроить структуру [cap];
+ Прервать поиск пути [abort_navigation]; + Пауза [pause_unit]
- ACU: Выбрать ACU / перейти по повтору; Overcharge; улучшения (инженерия,
  ресурсы, оружие, защита, телепорт, специальное); + Телепорт [teleport]
- SACU: Overcharge only (upgrade-dependent). Editor: when Overcharge is set on
  ACU, offer "Поставить то же для SACU?".
- Engineer: Последовательно добавить инженеров T1 / T2 / T3 / всех уровней;
  + Оставить старших, остальные помогают [filter_highest_engineer_and_assist]

### 3. Factory
+ Движение (точка сбора); Атака с движением; + Патруль (точка сбора);
Повтор очереди; Пауза производства; Стоп; Мягкая остановка (ONLY here);
Удалить последний заказ завода; + Улучшить завод [upgrade_structure];
+ Улучшить с паузой [upgrade_structure_pause];
+ Шаблон очереди с этого завода [create_template_factory].
Verify: Переключить щит — remove if no factory has a shield toggle.

### 4. Missiles
Common: Стоп; + Пауза (накопление ракет) [pause_unit]
- TML: Запуск тактической ракеты
- Nuke: Запуск стратегической ракеты

### 5. Transport
Один свободный / все по повтору; Перевозка; + Паромный маршрут [ferry];
Отметить следующего юнита для высадки; + На посадку [dock]; Движение; Стоп.
No attack variants, no soft stop.

### 6. Mass extractors
Улучшить добытчик и выбрать ближайший следующий; Улучшить выбранный добытчик;
+ Улучшить с паузой [upgrade_structure_pause]; Пауза производства; Стоп

### 7. Scouts
Выбрать всех воздушных разведчиков; Движение; Атака; Атака с движением;
+ Патруль [patrol]; + На посадку [dock]; Стоп

### 8. Other
Взорвать Fire Beetle; Реклейм; Помощь / охрана; Движение; Атака;
Атака с движением; Пауза производства; + Пауза всего / снять паузу
[pause_unit_all / unpause_unit_all]; Переключить щит; Скрытность;
+ Переключатели: производство, разведка, глушение, маскировка, всё сразу
[toggle_production / toggle_intel / toggle_jamming / toggle_cloak / toggle_all];
+ Улучшить с паузой [upgrade_structure_pause]; + Самоуничтожение [suicide]; Стоп

### Removed from the catalog (offer no more)
SACU: улучшить инженерию; Мягкая остановка everywhere except Factory;
Transport: Атака / Атака с движением; Other: Перевозка.
Deferred: move_hard, toggle_generic, toggle_special. Not added: create_build_template.

## 8. Migration and compatibility
- Keep all existing action IDs and saved binds working.
- TML + Nuke merge: existing rows move unchanged into Missiles -> TML / Nuke.
- Removed catalog items used by saved binds keep working, are shown as
  "устарело" in the editor and are not offered for new assignments.
- Units-first priority changes behaviour for some mixed selections: accepted,
  note it in the changelog.

## 9. Implementation phases (each separately testable)
1. Model: columns, groups, priority, Units category definition, applicability
   metadata, migration.
2. Editor: filtering by applicability, Builders lock vs building preset,
   invalid / "устарело" display, the Overcharge offer.
3. Row fields: quick repeat, fallback, global repeat window setting.
4. Catalog additions per column (routine: suitable for a Luna subagent per column).
5. Removals and cleanup.
## 10. Answers to plan questions (2026-11-13)
1. If the Units row is empty, mobile army falls back to the Other row (legacy behaviour).
2. Empty/disabled siblings do not block; assigned siblings with different actions -> do nothing, key consumed, lower columns are not tried.
3. Children inherit whole rows. No rearm: a press after a quick repeat is a new first press. Fallback only after the main action, not after a repeat.
4. Keep legacy double (0.5 s) / accumulate actions unchanged. Chain breaks on selection change, window expiry, or another Claret key. Key auto-repeat (holding) is not a repeat.
5. Presets with structures/templates lock Builders; presets with factory production lock Factory (as now).
6. Scouts = AIR * INTELLIGENCE (land scouts -> Units). Mobile factories (Fatboy, Czar, Megalith, carriers) -> Units. Mobile missile units -> Missiles when alone; with army Units wins. Drones/engineering stations -> Other. Satellites -> Units.
7. Commands apply to the whole selection, like native FAF keys; no hidden reselection. Overcharge keeps native FAF behaviour.
8. Factory shield: hide for new assignments, mark old as obsolete. Standard FAF units only; modded units must not break anything.
9. not_found = after the action no unit of the target type is selected; already-selected counts as found. Fallback is offered only for selection actions.
10. Remove selection-policy conflicts that block natural chains. Решение от 2026-11-13: пара пресета и составного бинда хранится для каждой клавиши отдельно. Один пресет может сочетаться с разными составными биндами; прежние связи `grid.context` нужно перенести без потери данных.
