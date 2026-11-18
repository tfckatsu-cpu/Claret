# Claret Hotbuild context binds — target spec (2026-11-13)

> Status (2026-11-18): historical target spec. The global quick-repeat window and its setting were removed; the per-row quick-repeat field remains as legacy saved data only.

Agreed with the user. Follow Context/hotbuild-rules.md and Context/menu-rules.md.
Native FAF command strings: Context/faf-actions-inventory.md (reuse, do not invent).

## Update (2026-11-14)

The following decisions supersede conflicting historical catalog items below. “Under cursor” is checked before all other contexts and contains three upgrade actions. Unambiguous old rows migrate without losing additional fields; ambiguous rows are preserved for manual replacement. Built-in chains and occupied resulting contexts block one another; existing saved conflicts remain. The new catalog offers only instant self-destruct; refuel, fire mode, and target-priority reset are hidden. One missile-launch command is available to TMLs, ACUs, and SACUs and chooses the available type; mixed types do not launch. Old separate launch actions and other removed actions still work and are marked obsolete. Deleting a set in the set list requires confirmation, shows assigned keys, and removes only that set. Slots are cleared using separately labeled buttons in the keyboard window.

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
  Engineer) for that key is locked, label "occupied by building hotbuild".
  Vice versa: if any Builders row is set, a building preset cannot be assigned
  to that key; the keyboard editor shows what occupies it.
- With Units first, army + builders mixed selection runs the Units row (accepted).

## 7. Catalog per column ("+" = new, native FAF id in brackets)

### Nothing selected (also the pool for absolute binds)
- ACU: Select ACU; Select ACU / jump on repeat; Jump to ACU
- Engineers: Nearest idle T1 engineer on screen; Idle engineers on screen;
  Sequentially add T1 / T2 / T3 / all-tier engineers
- Army: Land army on screen / on map; Navy on screen / on map;
  Mobile T3 artillery, mobile shields, mobile stealth generators,
  mobile MMLs on screen; mobile land experimentals;
  all land experimentals; all air experimentals
- Air: All bombers; all fighters; all gunships;
  Nearest air scout; select all air scouts
- Transport: Nearest idle; nearest; one idle / all on repeat;
  transports on screen; transports on map
- Structures: All radars; all sensors; all TMLs; all nuke launchers; satellites
- Factories: + Cycle idle factories [cycle_idle_factories]
- Under cursor: Upgrade structure under cursor;
  upgrade extractor and select the next nearest

### 1. Units
Common: Move; Attack; Attack-move; + Patrol [patrol]; Stop;
+ Fire mode [mode]; + Target priority / reset
[set_target_priority / set_default_target_priority]; + Distribute orders
[spreadattack]; + Copy orders [copy_orders]; + Load into transports
[load_transports]; + Split selection: by type / by tech / into groups /
next subgroup [split_layer / split_tech / split_into_groups_N / split_next];
+ Cycle land / navy / air in selection [cycle_unit_types_in_sel];
+ Self-destruct [suicide, with confirmation]
- Land: + Toggle shield [toggle_shield]; + Stealth [toggle_stealth];
  + Discharge shields [discharge]
- Air: + Dock [dock]; + Dock damaged units [dock_damaged]
- Navy: + Dive / surface [dive / dive_all / undive_all];
  + Toggle shield; + Stealth

### 2. Builders
Common: Reclaim; Assist / guard; Move; Attack; Attack-move;
+ Patrol [patrol]; + Repair [repair]; + Capture [capture]; Stop;
Toggle shield; Stealth; + Distribute orders [spreadattack];
+ Copy orders [copy_orders]; + Cap structure [cap];
+ Abort navigation [abort_navigation]; + Pause [pause_unit]
- ACU: Select ACU / jump on repeat; Overcharge; upgrades (engineering,
  resources, weapons, defense, teleport, special); + Teleport [teleport]
- SACU: Overcharge only (upgrade-dependent). Editor: when Overcharge is set on
  ACU, offer "Set the same for SACU?".
- Engineer: Sequentially add T1 / T2 / T3 / all-tier engineers;
  + Keep highest-tier, have the rest assist [filter_highest_engineer_and_assist]

### 3. Factory
+ Move (rally point); Attack-move; + Patrol (rally point);
Repeat queue; Pause production; Stop; Soft stop (ONLY here);
Remove last factory order; + Upgrade factory [upgrade_structure];
+ Upgrade with pause [upgrade_structure_pause];
+ Queue template from this factory [create_template_factory].
Verify: Toggle shield — remove if no factory has a shield toggle.

### 4. Missiles
Common: Stop; + Pause (missile stockpile) [pause_unit]
- TML: Launch tactical missile
- Nuke: Launch strategic missile

### 5. Transport
One idle / all on repeat; Transport; + Ferry route [ferry];
Mark next unit for drop-off; + Dock [dock]; Move; Stop.
No attack variants, no soft stop.

### 6. Mass extractors
Upgrade extractor and select the next nearest; Upgrade selected extractor;
+ Upgrade with pause [upgrade_structure_pause]; Pause production; Stop

### 7. Scouts
Select all air scouts; Move; Attack; Attack-move;
+ Patrol [patrol]; + Dock [dock]; Stop

### 8. Other
Self-destruct Fire Beetle; Reclaim; Assist / guard; Move; Attack;
Attack-move; Pause production; + Pause all / unpause all
[pause_unit_all / unpause_unit_all]; Toggle shield; Stealth;
+ Toggles: production, intel, jamming, cloak, all
[toggle_production / toggle_intel / toggle_jamming / toggle_cloak / toggle_all];
+ Upgrade with pause [upgrade_structure_pause]; + Self-destruct [suicide]; Stop

### Removed from the catalog (offer no more)
SACU: Engineering upgrade; Soft stop everywhere except Factory;
Transport: Attack / Attack-move; Other: Transport.
Deferred: move_hard, toggle_generic, toggle_special. Not added: create_build_template.

## 8. Migration and compatibility
- Keep all existing action IDs and saved binds working.
- TML + Nuke merge: existing rows move unchanged into Missiles -> TML / Nuke.
- Removed catalog items used by saved binds keep working, are shown as
  "obsolete" in the editor and are not offered for new assignments.
- Units-first priority changes behaviour for some mixed selections: accepted,
  note it in the changelog.

## 9. Implementation phases (each separately testable)
1. Model: columns, groups, priority, Units category definition, applicability
   metadata, migration.
2. Editor: filtering by applicability, Builders lock vs building preset,
   invalid / "obsolete" display, the Overcharge offer.
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
10. Remove selection-policy conflicts that block natural chains. Decision (2026-11-13): store the preset/composite-bind pair separately for each key. One preset may be paired with different composite binds; migrate old `grid.context` links without data loss.
