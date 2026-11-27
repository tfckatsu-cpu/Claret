# Claret Hotbuild — prototype 0.10.82

The build-cycle preview shows the available buildings while placing through Hotbuild. T1–T3 labels sit at the bottom center of each icon. The row fades in and out over 150 ms.

Build 20261113-30: double-tap actions for compatible standalone actions can be configured on the **Keyboard** tab. When an action and a building preset share an assignment, the preset takes priority if the current builder can use it; otherwise, the action runs. Existing saved assignments and additional fields are preserved. In-game verification is pending.

Selecting the ACU moves the camera to it. The **Select ACU** key can be configured to use Overcharge on a second press with the **Double-tap…** setting; the second press uses the current ACU selection.

0.10.14: refined the depth of the modal keyboard assignment list and restoration of hover states. These fixes require in-game verification.

Enable ReUI, Claret Core 0.10.23, and Claret Hotbuild 0.10.78, then start a new match. Hotbuild requires Core >= 0.10.23 and is always active; there is no menu toggle. A previously saved disable option is ignored; the profile and bindings are saved. Open the main menu with F10 → Claret → Hotbuild. Claret tabs have been removed from ReUI Options.

Hotbuild uses the shared Claret language setting. The interface follows the game language by default; choose **English** or **Russian** under F10 → Claret → Core → **Interface language** to override it. The setting is saved and applies to open Claret windows immediately.

Create a binding, give it a name, and add buildings or units from the catalog. Filters help find items; the list on the right defines the order checked from top to bottom. Press **Save**. Assign a key on Claret's **Keyboard** page.

When a builder is selected, the binding starts placement of a suitable building. When a factory is selected, it queues one suitable unit. Binding contents are stored in the ClaretHotbuild profile; key assignments are saved in FAF's profile key settings.

## Saved data

Bindings are stored per chord in `ClaretHotbuildKeyboard` (`chord -> preset / composite / action`, plus the optional double action). That profile is the single source of truth: dispatch, the keyboard editor and compatibility checks read it, and FAF's key maps are rebuilt from it.

`key` and `grid.context` inside `ClaretHotbuild` presets are historical metadata from the pre-pair format. They are preserved but never updated when a binding changes, and current builds use them only as a fallback when the keyboard profile cannot be read. An older Claret build may therefore not see bindings created after the migration to pairs.

## Multifunction bindings and unit selection

In normal mode, a multifunction binding applies to the current selection according to its selected context. Absolute mode uses only the **Nothing selected** row, regardless of the current selection. Assign a multifunction binding in the **Actions** slot on the **Keyboard** page.

Existing absolute multifunction bindings keep their previous behavior; the editor no longer offers the mode switch.

The empty-selection action catalog includes separate actions for selecting land and air experimentals, satellites, the land army on screen or across the whole map, T3 mobile artillery, eligible mobile shields, Cybran T2 mobile ground stealth generators, and mobile MMLs excluding engineers. Mobile land experimentals exclude Scathis and the satellite by BlueprintId; a separate action selects the satellite. Mobile shields are limited to UEF T2, Aeon T2, and Seraphim T3. Old on-screen/map extractor-cycle actions are hidden when creating new sets, but their IDs remain available to saved profiles.

Gameplay, keyboard assignments, appearance, and modded-unit categories require checking in a new FAF match; local tests do not confirm them.

## Building editor and diagnostics

The editor shows priority rows of buildings for all four factions. Adding an item to row 2 creates row 3; after selection, the item should appear in the row, and the final empty row lets you continue the list. There are no arrows for reordering rows: the rows themselves define the order. Empty rows in the middle preserve priority; trailing empty rows are removed. The list scrolls with the mouse wheel.

When Core diagnostics (`probeEnabled`, off by default) are enabled, opening a cell and selecting an item create `Building editor` log entries with the event, row number, faction, item ID, and the number of total/visible rows. Profile data and assignments are not logged. These entries help determine whether the selection was accepted and whether the list length was updated.

Local editor scenarios pass, including adding to row 2, displaying the third row, reopening with saved data, and scrolling. They do not confirm rendering or input in FAF. In a new match, check an existing binding: choose an item in the second row, confirm that it appears and that the third empty row becomes visible; save, close, reopen the editor, and confirm it persisted. Then fill at least six rows and check scrolling to rows five and six. If a row remains empty, attach a screenshot immediately after closing the picker and the game log with diagnostic entries. In-game verification is still pending.

Editor 0.2.0 (historical description): select a binding from the top dropdown. The card catalog with search and filters is on the left, and the binding contents are on the right. In older versions, arrows and × changed the order and removed an item; the current building editor uses priority rows without reorder arrows. The catalog and contents scroll with the mouse wheel or scrollbar. The full item name appears in a tooltip.

Version 0.3.0: by default, a card adds equivalents from available factions while preserving tech level and item type. The faction filter limits search results but does not limit the factions added to the group. Choose the addition mode above the binding contents: **All-faction equivalents** or **Selected item only**. A group is shown as one row, with its contents in a tooltip; arrows and × apply to the whole group. Clicking again does not create duplicates and fills incomplete groups. The card shows the number of factions found. Unique items and items without a reliable equivalent are added on their own. Existing sets are not supplemented automatically: select the desired card and save.

Hotbuild 0.4.0 uses the shared Claret style (Core >= 0.5.0): black/graphite background, thin borders, and a burgundy accent. Guidelines for future windows are in the project's `Context/ui-style.md`.

Building cycle menu: when a builder presses a binding, a panel shows available buildings in binding order; the current building is marked with a border and `>`. The next press updates the selection and display time. The panel hides after 1.1 seconds without another press or when leaving placement mode. Mouse input passes through the panel. Factory orders do not show it. The panel is centered near the bottom of the screen; rendering needs to be checked in FAF.

## Keyboard page — 0.10.14

Open **F10 → Claret → Hotbuild → Keyboard**. Press a key on the layout, then choose one of three assignment types: a saved Hotbuild preset, a saved multifunction binding, or a standalone action from the context catalog. A multifunction binding runs directly: a normal binding keeps its behavior based on the selection context, while an absolute binding uses only the empty-selection action regardless of the current selection. Actions from the empty-selection context work regardless of the current selection. All T1–T3 land, air and naval factories can each be selected directly across the map. The same three actions are offered in the Empty selection context. For eligible standalone actions, the editor offers a double-tap action for the same unit type.

The **Ctrl**, **Shift**, and **Alt** toggles set the modifiers for the next assignment. The **+ Shift** button assigns both the chosen chord and its Shift variant. Confirm each occupied chord before either assignment is saved. The key displays assignments for all modifier combinations at once. The page legend maps colors to combinations: no modifiers, Ctrl, Shift, Ctrl+Shift, Alt, Ctrl+Alt, Shift+Alt, and Ctrl+Shift+Alt. A single assignment colors the key for its combination; multiple assignments appear as colored indicators. The key tooltip lists combinations and actions, including assignments from other mods and old assignments.

The keyboard catalogue offers **Create strategic rings** and **Create vision ring**. They draw the radii of the object under the cursor; a second press expands a shield or blast radius into a sphere and then a sector. Rings are removed with FAF stock drawing eraser: hold Alt and drag RMB along the outline. Radii of one object are removed together.

Every variant in the assignment dialog has a **+ Shift** button. It assigns the same variant to the selected chord and to the chord with Shift added. If one of the chords is occupied, the editor asks to confirm the replacement.

Right-click a key to remove the displayed Claret, FAF, and other-mod assignments for the current modifier combination; hold Ctrl, Shift, or Alt to use that combination. Saved sets and other combinations remain. Assignments are saved immediately in the FAF profile key map. If a combination is occupied, the editor shows its current assignment and asks whether to reassign it; cancelling preserves the existing assignment. Reserved Hotbuild modifiers cannot be reassigned. Other combinations are unchanged.

Hotbuild also has **Hotbuild** and **Multifunction** pages. The navigator handles page switching and closing the shared window. The local page test passes; appearance and assignments in FAF still need to be checked in a new match.

The **Communication** group offers FAF's text marker and alert, move, and attack pings. They work with any unit selection.

## Build templates — Hotbuild 0.8.0

The building-cell picker now includes saved in-game build templates for a compatible faction. They appear in the shared list with buildings, can be searched by name or by the word “template,” are labeled **Build templates** with a building count in the list, and marked **TEMPLATE** on the tile. A template occupies one cell and one position in the binding order. Equivalent faction templates are not invented automatically; manually choose a saved template for the desired faction.

Templates are read from the standard `build_templates` profile without executing code from settings. A stable ID is computed from the full contents, orientation, and geometry; the name and list index are not part of it. Renaming or reordering therefore does not break a binding. A changed or deleted template becomes unavailable in its old cell and must be selected again; a neighboring template at the same index is never run in its place. Contents are not copied into the ClaretHotbuild profile, and the format of existing `entries/grid` data does not change. Exact duplicates with identical contents use one record.

When a binding is pressed, a template is available if at least one selected engineer can build every building in it; factories and the combined capabilities of several engineers who cannot individually build the whole template do not qualify. After validation, the normal placement mode for the whole template starts through `StartCommandMode`/`SetActiveBuildTemplate`, with geometry passed as a copy. Templates use the same cycle and panel as regular buildings. Templates are refreshed when opening the editor/picker and when pressing the binding, without continuous polling.

Current limitations: only standard build templates from `build_templates` (factory queue templates have their own section below); only valid templates for one of the four factions, containing existing buildings from a single faction, with a maximum of 256 buildings. Loading templates from third-party mods and keeping an independent copy of a deleted template are not supported. Cross-faction conversion is described below.

API cross-check: FAF3840, `C:/ProgramData/FAForever/gamedata/lua.nx2`, 2026-11-10. `build_templates.lua:GetTemplates` reads the `build_templates` profile; a record contains `name/icon/templateData`, where the first two `templateData` entries are numeric dimensions followed by rows of `{blueprintId, orientation, x, z}`. `construction.lua:OnClickHandler` handles `type templates` by calling `StartCommandMode('build', {name=first blueprint})` and `SetActiveBuildTemplate(templateData)`. After its own availability check, Claret starts the same user-facing mode in its own code. Reference and game source files were not changed.

Local checks: `Tests/hotbuild-templates.lua` (catalog/data/ID/grid/geometry/availability), `hotbuild-grid-editor.lua` (selecting and saving a template in a cell), and `hotbuild-cycle-menu.lua` (regular building → template → next building, preserving the panel by `claretEntry`). In FAF, create and rename a template, select one for the appropriate faction, save the binding and assign a key; check the full contents and rotation during placement, cycling with two regular buildings, an unavailable engineer/factory, editing and deleting the template in the same match, restart behavior, and tile readability. Local simulations do not confirm engine behavior.

The current Core menu opens the launcher; Core and Hotbuild are selected there and shown in a separate fixed-size panel. Clicking outside the menu closes it after checking for an unsaved draft.

## Cross-faction templates — Hotbuild 0.9.0

A template is available to other faction selections when every building has one unambiguous equivalent. When a template is selected in a cell, available faction variants fill the same row. Existing saved rows are not supplemented automatically: select the template again and save the binding.

The converter preserves order, dimensions, coordinates, and orientation; it replaces only the blueprints. Source game templates are not changed or duplicated. Existing content IDs stay the same. A variant is not created if any building lacks an equivalent or has an ambiguous one. Layouts are not repacked for buildings with different footprints; the engine determines whether placement is valid.

Principle cross-check: `Context/sources/MainMods/ReUI.Hotbuild/Modules/viewmodel.lua`, `FindSimilarBlueprints/ConvertTemplate`, 2026-11-10. ReUI finds blueprints and preserves the template copy's geometry. Claret code is independently written: instead of substituting prefixes, it uses its own `Equivalents` (FAF unitkeygroups and explicit HQ mappings) and accepts only complete conversions. The binding profile and game `build_templates` are not migrated.

In a new match, choose a simple template from a generator/storage building in one faction, check that it fills four faction cells, save it, and execute it with engineers of the other factions. Check contents and geometry; a template with a unique building should have only confirmed variants. Local tests do not replace this check.

In the dropdown, templates are sorted before regular buildings. They have a burgundy border and a **TEMPLATE** label; the same label and color appear in the saved binding cell. Hovering a template row shows a card with its composition. Construction templates copy the geometry of the game's own preview: one scale for the whole template, every building centred on its template anchor and sized by the blueprint skirt (Physics.SkirtSizeX/Z, centre offset SkirtOffsetX/Z), so a 2x2 structure draws twice as large as a 1x1 one and neighbours stand flush. A terrain tile of the building layer (land, sea, air) sits behind each icon, and cells keep an outline that reads as a hitbox. Queue templates are one horizontal strip of larger icons (up to 416 px wide), and a stack count sits on a dark plate in the corner of its icon so it stays readable on bright art. The card sizes itself to the composition — a minimum for the title, a maximum for huge templates, small tiles for a wall of a hundred parts — and never covers row text or takes the pointer. The card is hit-test disabled, so it never steals the pointer, and it disappears with the row hover, the search or the popup.

## Unit (factory queue) templates — Hotbuild 0.10.43

The unit rows of the picker now include saved factory queue templates: one key queues a whole composition such as 3 tanks + 1 mobile AA. Templates are created and renamed in the game itself — the **Templates** tab of the construction panel with a factory selected (save-template button), or FAF's `create_template_factory` action. Claret only reads them from the `build_templates_factory` profile and never executes data from settings.

A unit template is listed in the row of its faction and unit type, shows a burgundy border and the **TEMPLATE** label with its unit count in the picker list, and marks its bind cell with the same accent and a ▧ glyph. Its tier is the highest tier in the queue, so a T2 template is picked in the T2 cell. A queue template occupies one cell and one position in the binding order, exactly like a building template.

The identifier `claret_unit_template_<hash>` is computed from the member units, their order and their counts; the name and list index are not part of it. Renaming or reordering a source template therefore keeps the binding. A changed or deleted source makes the old binding unavailable and is never replaced by a neighboring template with the same index. Nothing is copied into the ClaretHotbuild profile and the `entries/grid` format does not change.

Pressing a bound key with a factory selected queues every member in saved order with its saved count. Shift never repeats an order: a press queues the composition once, and a single-unit preset queues one unit. A template is offered only when the selected factory can queue every member: the blueprint must be in the engine list `GetUnitCommandData` → `EntityCategoryGetUnitList`, and one exception follows FAF's own rule — an entry may be queued when an earlier entry of the same template is a factory upgrade that unlocks it, so a T2 queue captured on a T2 factory works from a T1 factory that builds the upgrade first. Replays, observers and non-factory selections receive no order. Only the factories take part in a selection that also contains other units, and Claret restores the UI selection afterwards. Both queue templates and unit presets require all selected factories to share a domain and faction.

A queue template is faction-bound: no cross-faction variants are created, and selecting it fills only the cell of its own faction. Create one template per faction if the same composition is needed there.

Data checks: member entries must be existing blueprints of one faction and one unit type, counts must be whole positive numbers, a structure is accepted only as a factory upgrade, and a queue without units is rejected. Invalid records are ignored and logged; they are never executed. The catalog is refreshed when the editor or picker opens and when a binding is pressed — there is no background polling.

API cross-check: FAF3840, `C:/ProgramData/FAForever/gamedata/lua.nx2`, 2026-11-19. `lua/ui/templates_factory.lua` reads `build_templates_factory` and stores `{name, icon, templateData = {{id, count}, ...}}`; `lua/keymap/hotbuild.lua` (`buildActionFactoryTemplate`, `availableTemplate`) queues entries with `IssueBlueprintCommand('UNITCOMMAND_BuildFactory', id, count)` and allows a higher entry after a preceding factory upgrade. `lua/ui/game/construction.lua` builds the same list for the construction panel.

Local checks: `Tests/hotbuild-unit-templates.lua` (identity, malformed data, upgrade chain, dispatch counts, shift repeat, mixed selection, faction conversion), plus `hotbuild-adapter.lua` for the shared factory-order path. In a new match: create a template from a factory queue, bind it to a unit cell, and check the queued composition, Shift repeat, a T2 queue pressed from a T1 factory, an upgrade template, restart persistence and the tile label. Local simulations do not confirm engine behavior.

## Selection-context multifunction bindings — Hotbuild 0.10.1

A multifunction binding assigns one action to each selected context type. Create one under **F10 → Claret → Hotbuild → Multifunction**: click **New set**, enter a name, then choose context tiles and compatible actions. Parent groups stay expanded, and clicking a parent selects its context. Names may contain Cyrillic. To clear a regular tile, select it and click **Clear**; child tiles under the **Builders** group also support inheritance and disabling. **Save** stores the set. When switching sets, pages, or closing with an unsaved draft, the editor offers to save, discard, or cancel the transition.

Assign a preset and a multifunction binding in separate slots for the desired key on the **Keyboard** tab. Editors show keys as read-only; historical references in the data are preserved.

The catalog offers selection actions, orders, and toggles compatible with the chosen context. The **Under cursor** context contains three upgrade actions. When migration is unambiguous, the previous row moves there; ambiguous rows and additional fields are preserved for manual correction. An embedded chain blocks its resulting context, and a chain-occupied context prevents assigning a new chain. Saved conflicts remain. **Stop firing** is offered for factories; old assignments in other contexts remain marked obsolete. **Mark next unit for drop-off** marks an already loaded unit for a later selective drop-off. Order availability depends on selected units and game state.

For an assigned **Under cursor** context, Claret first checks for a suitable owned structure under the pointer. Ordinary mixed selections execute one composite command only when every represented context resolves to that command. Different assignments or a combination of assigned and unassigned contexts consume the press. An entirely army selection with no army assignments can still use the legacy **Other** fallback. Mobile missile launchers belong to land forces, and missile cruisers belong to naval forces. The launcher contexts use the tactical platform and nuclear launcher categories. The selected action receives the whole selection; its availability is checked before execution. Composite profiles still read legacy repeat data for compatibility, but only keyboard action assignments can trigger a second action. Sequential selectors continue normally. Toggle all unit abilities is offered for every selected-unit context and in the keyboard picker. It uses the nine native FAF script toggles. Legacy individual toggle assignments still execute.

An assigned army action takes priority over building Hotbuild. A building preset blocks assignments in the **Builders** group, and factory production blocks **Factory**. ACU upgrades include engineering, resources, weapons, defense, teleportation, and special upgrades; the old engineering upgrade for SACU remains available to existing bindings but is no longer offered. Upgrade actions check selection, blueprint, and queue. In-game results, including cargo selection and later unloading, require verification.

In the set list, the × button opens a confirmation showing assigned keys; after confirmation, the set is deleted and unassigned from those keys while other slots are preserved. Historical preset references remain in the data. Corrupt or unknown profile formats block writes.

**Launch missile** selects a tactical or nuclear order based on the selected units' capabilities; mixed types do not launch. For ACU/SACU, the action depends on the available order after upgrades. When assigned to **Missiles**, the editor separately offers to fill free ACU and SACU rows. Old delayed self-destruct, refuel, fire mode, target-priority reset, and separate missile-launch actions remain in saved assignments marked **Obsolete**, but are not offered for new assignments. Immediate self-destruct is available for new assignments.

**Upgrade selected extractors** issues each eligible owned extractor's next upgrade in place. **Upgrade with pause** and **Upgrade extractor and select the next nearest one** are offered in **Under cursor**. Legacy empty-selection assignments move to the cursor when migration is unambiguous. Any remaining assignments of select-next in the empty-selection context are retired.

**Load into transports** is available on the keyboard page and in the multifunction **Transport** context. A Transport row can load a mixed selection with unassigned cargo contexts. A different assigned action still blocks a conflicting selection. The action dispatches FAF's load hotkey when the selection contains a transport and mobile non-air cargo, including engineers and commanders. FAF 3841 groups cargo by T1–T3, which leaves stock ACUs outside automatic loading. Claret transport selectors temporarily suspend ASE v3 filters for their selection changes, restoring the prior filter state afterwards.

### Check in a new match

Create a preset and a multifunction binding, assign them to the key's slots on the **Keyboard** tab, and check the editor tooltips and in-game actions. Check replacing and clearing each slot, persistence after restart, and conflict handling.
