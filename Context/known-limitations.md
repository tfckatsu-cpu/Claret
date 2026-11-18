# Known limitations

Current gaps that are accepted, deferred or unverified. Update this page when a limitation is fixed or a new one becomes known.

## Verification gaps

- Tests run in Fengari with mocked Maui and engine: they prove logic and data handling, never rendering, input routing or engine orders.
- In-game checks done so far: S1 defaults, S2 quarantine, S4 repeat/editor fixes, S3 metadata. Still unverified: the build-147 Shift intercept, the cargo indicator sequence, builds 127/126/135/134/132, UI scale at extremes, dialog depth after a panel raise, and the duplicate-legacy-key edge case in a real profile.
- Performance has not been measured for Claret at all; `performance-hotspots.md` lists candidates and the method.

## Data and compatibility

- Downgrade: presets created after the pair migration carry no `key`/`grid.context`, and older Claret builds dispatch from those fields. A downgrade may not see bindings created on 0.10.38+.
- Quarantined records stay in the profile until the user fixes or removes them. There is no deletion/recovery UI yet (deferred); the editor only reports the count and the first reason.
- Contexts saved by versions 1–3 are read and exported as version 3; an unknown future version is read-only for that profile only.
- Preset `key`/`grid.context` are historical metadata: preserved but never updated. Do not use them for new behaviour.

## Deferred functionality

- `Construction*`, `Orders*`, `Multifunction*`, `SelectionIgnore*` and `CargoSelection` in Core are a deferred replacement for the ReUI HUD. They are preserved and tested but never loaded in game; integration and refactoring are out of scope (ADR-010).
- ReUI private APIs used by the cargo bridge (`ReUI.UI.Global.Construction`, `TransportCargo` handler fields) were not verified against the installed version; the bridge fails soft with a `WARN`.

## Engine facts that can bite

- LuaPlus has no `#` length operator (it treats it as a comment marker); a module with `#` fails to load and the error surfaces far away. `continue`, `goto` and integer division are also banned.
- Upvalue limit is 32 per function; Lua 5.3 (`_ENV`) counts differently.
- Module tables are strict: reading a missing field raises `access to nonexistent global variable`.
- `math.huge` may be absent; `GetSystemTimeSecondsOnlyForProfileUse` does not exist in UI, `GetSystemTimeSeconds` does.
- A standard Lua parser or compiler does not prove FAF compatibility.

## Documentation

- Historical `ClaretHotbuild/CHANGELOG.md` entries stay in Russian; new entries are English.
- `Stage/stage-1-status.md` and `stage-1-research.md` are Russian working notes, not knowledge base.
- `friend-notes.md`, `community-notes.md`, `prestudy-notes.md` are unverified by definition.
- Empty-texture log noise (`GetResource: Invalid name ""`) was observed in a session and not investigated.
