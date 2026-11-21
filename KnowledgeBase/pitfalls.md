# Pitfalls, past bugs, open gaps

> **Answers:** known traps, past bugs and their fixes, unverified claims, deferred code. **Read when:** something should work but does not, or code looks unused or broken. **Next:** the owner doc named in the row for the fix itself.

## Engine traps

| Trap | Symptom | Fix |
|---|---|---|
| `#t` in a module | module table stays empty; caller reports `access to nonexistent global variable "Create"` | `table.getn`, `table.insert` |
| `local function X` + `X = X` | nothing exported, same error | `function X()` at module level |
| trailing `return { ... }` | chunk return value ignored by `import` | export module globals |
| varargs in expression position (`f(x, ...)`) | module load aborts, empty table | fixed parameters |
| > 32 upvalues | load-time error in nested closures | hoist into a table, split functions |
| reading an unassigned module field | strict table raises `access to nonexistent global variable` | export everything; guard optional fields |
| `math.huge` | may be absent | `1/0` or a large literal |
| `GetSystemTimeSecondsOnlyForProfileUse` | strict-globals error in UI | `GetSystemTimeSeconds` |
| `type(x) ~= 'function'` on a Maui class | valid control rejected (classes are callable tables) | `x == nil` check |
| `rawget(_G, 'ReUI')` | `nil` in Claret modules; labels/feature registration break | direct `ReUI...` access inside `pcall` if needed |
| standard Lua compiler says OK | still fails in LuaPlus | run `Tests/check-core.cjs`, then check in game |

## UI bugs already paid for

| Symptom | Cause | Rule |
|---|---|---|
| Mex panel failed to start (0.2.50) | multiplied by `layout.Scale` directly | `Scale` is a callable `LazyVar`; use layouter sizing or `ScaleNumber` |
| `nonexistent global variable Create/Start` (UiSection, AcuHealth) | files used `local` + `return {...}` | export module globals |
| Overlay/dialog behind a raised panel | frozen depth number | live depth closure |
| Crash on hover after close | tooltip still holding a destroyed control | `DestroyMouseoverDisplay` on close |
| Close-cancel destroyed the editor | `CanLeave` destroyed state on `continuation(false)` | cancel must not destroy |
| Clicks swallowed below a shrunken panel | container taller than the panel kept its rect | resize the scroll viewport with the panel |
| Empty band under a collapsed section eats input | hit area outside the visible window | clamp hit areas |
| Controls vanish when opening a section | embedded editor built while the panel was hidden | build in `AfterParentShow` |
| Wrong English names in the order list | category table passed to `Catalog:DisplayName` | pass the full blueprint |
| Stuck pressed colour after a closing callback | button state resolved in the click callback | engine resolves after `ButtonRelease` |
| `GetBlueprint` failed in UI 0.2.9 | unknown | do not repeat the pattern; log and fall back |

## Data and compatibility

- Downgrade below the pair migration: presets created on 0.10.38+ carry no `key`/`grid.context`, older builds dispatch from those fields, so bindings may be invisible. Not fixable retroactively.
- Quarantined records stay in the profile until the user fixes them; there is no deletion/recovery UI (deferred). The editor reports count and first reason.
- Contexts saved by v1–3 are read and exported as v3; an unknown future version is read-only for that profile only.
- Preset `key`/`grid.context` are historical metadata: preserved, never updated, never used for new behaviour.
- Unknown version in one profile must not block the others.

## Deferred code (do not delete, do not wire)

`ClaretCore/modules/Construction*.lua`, `Orders*.lua`, `Multifunction*.lua`, `SelectionIgnore*.lua`, `CargoSelection.lua` are a deliberate deferred replacement for the ReUI HUD (ADR-010). They are preserved and tested, and never loaded in game (`import` is lazy). Wiring them — including an ownership decision against `ReUI.Construction` — is a separate future step.

The cargo bridge uses ReUI private APIs (`ReUI.UI.Global.Construction`, `TransportCargo` handler fields) that were never verified against the installed version; it fails soft with a `WARN`.

## Verification gaps (as of 2026-11-21)

- Tests prove logic and data handling only. Rendering, input routing, drag, scale, dialogs and engine orders are unproven by the suite.
- Pending in-game checks: Hotbuild preview after closing, sizes and seams, unit-layer tiling, unit row; Claret UI input under a short column, both locales, ACU Health scale persistence, both alert thresholds and their release, shield at zero, dragging; cargo indicator builds 132/134/135/126/127; dialog depth after a panel raise; UI scale at extremes; duplicate legacy key in a real profile; Shift intercept after build 147.
- Performance has not been measured for Claret.

## Community claims still unverified

| Claim | Status |
|---|---|
| Orders can only be appended to the end of a queue | unknown — no engine API check |
| UI cannot issue reclaim orders on props/buildings | unknown |
| Enemy information is available only on hover | unknown in that absolute form |
| Allied information requires an exe patch | unknown; depends on data type and version |
| Icons cannot be changed after loading | unknown; strategic icons, button images and 3D textures are different things |
| `nil` is always safe, `GetFrame(1)` crashes | unknown for FAF 3840 |

Never promote these to rules without a check against `lua.nx2` or a live session.

## Documentation hygiene

- `Stage/stage-1-status.md` and `stage-1-research.md` are Russian working notes, not specifications.
- `Context/.local/friend-notes.md`, `Context/.local/community-notes.md`, `Context/.local/prestudy-notes.md` are unverified by definition.
- Empty-texture log noise `GetResource: Invalid name ""` was observed once and not investigated.
- A document that no longer matches the code is updated or moved to history; it is never left as current-looking prose.
