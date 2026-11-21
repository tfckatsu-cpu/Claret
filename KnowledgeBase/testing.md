# Testing

> **Answers:** how to run and add tests, static rules, stub and fixture shapes, triage, in-game check procedure. **Read when:** adding a feature (it needs a test), a check fails, a fixture looks stale, you need reload/log commands. **Next:** `release.md` once green.

## Runner

Command: `node Tests/check-core.cjs` from the repository root.

- `--quiet` prints one summary line; without it every test prints `PASS:` plus the parse summary.
- `--only <substring>` runs a subset.
- **Auto-discovery**: every `Tests/*.lua` runs; files ending in `-helper.lua` are shared helpers and are skipped. Adding a file is enough — never edit a list.
- Tests load production modules from `../mods/...` (the live mod folders), so originals and project mirrors must stay identical.
- Phase 1 parses every mod Lua file with Lua 5.1 grammar. Phase 2 runs each test in **Fengari** (Lua 5.3 with a `math.mod` shim).
- The baseline is "all green". The count grows; never record a fixed number as a target.

## Static checks (fail before any test runs)

| Check | Rule |
|---|---|
| `#` operator | forbidden in production Lua — LuaPlus reads it as a comment marker and the module fails to load |
| `continue` | forbidden as an identifier |
| Localization | every referenced localization key exists in both `en` and `ru`; all registered tables share one key set |
| Architecture | `ClaretCore` must not `import('/mods/ClaretHotbuild...')` |
| Version identity | `Version` in `Main.lua` = `ReUI` in `mod_info.lua` = README heading; `BuildStamp` = newest CHANGELOG build |

## Anatomy of a test

```lua
local modules = {}
local env = setmetatable({ ... engine stubs ... }, { __index = _G })
env.import = function(path)
    if modules[path] then return modules[path] end
    local chunk = assert(loadfile('../mods/ClaretHotbuild/modules/Thing.lua', 't', env))
    modules[path] = chunk()
    return modules[path]
end
assert(loadfile('../mods/ClaretHotbuild/modules/Thing.lua', 't', env))()
-- arrange, act, assert with messages
print('PASS: what this file proves')
```

- Every assertion carries a message describing the expected behaviour. A bare `assert(x)` is not acceptable in new tests.
- End with exactly one `print('PASS: ...')` describing coverage.
- Deterministic: own time counter instead of `os.time`, sorted iteration for output, no randomness.
- Tests never write real profiles, never call the engine, never depend on the user's data. Fixtures are plain tables.

## Stubs

Real module code, fake engine. Typical set: `Prefs`, `Mapper`, `IN_*KeyMap`, `GetSelectedUnits`, `IsDestroyed`, Maui controls (`Width`/`Height`/`Depth` as callable variables, `Destroy`, `OnDestroy`, `SetTexture`, `SetText`, `SetupEditStd`), `ReUI` with `ClaretCore.Localization`.

Unit fixtures need the categories the code checks: engineers must be `ENGINEER` **and** `MOBILE`; factories `FACTORY`; presets building structures need `STRUCTURE` / `BUILTBY...FACTORY` as the code expects. A missing category is the most common stale fixture.

Profile fixtures:

| Profile | Shape |
|---|---|
| presets | `{version = 1, bindings = {...}}` |
| contexts | `{version = 3, bindings = {...}}` |
| keyboard | `{version = 2, assignments = {['Ctrl-A'] = {preset = 'x'}}}` |
| corrupt | raw tables with unknown fields, wrong types, future versions |

Do not stub away the behaviour under test. If a test needs `pcall` to hide an error, the test is wrong.

## What to assert

1. User-visible result first (applied key, saved record, shown label), internal state second.
2. Data preservation: raw invalid records keep order, ids and unknown fields; FAF actions and key assignments of quarantined presets survive.
3. Atomicity: a failed save leaves profile and engine maps unchanged.
4. No accidental side effects: unassigned presets register no native action; untouched maps stay untouched.

## When a test fails

1. Read the assertion message; run `--only <name>` for the short trace.
2. Decide: stale expectation (cite the current code line) or production defect.
3. Stale expectation: update the value with a one-line justification, keep the intent.
4. Defect: fix the code, keep the test as the regression guard; never delete the assertion.
5. Never weaken a test to make it pass — no always-true checks, no removed coverage.

A real case: 14 red tests once hid a broken module load, and a hand-kept test list silently lost three files. Both are why discovery and static checks exist.

## In-game checks

Stubs prove nothing about rendering, input, focus or orders. When a real check is needed:

- One scenario at a time; note version, map/scenario, UI scale, observed result, limitation.
- Quick reload in a test match: reveal the hidden top panel, press "Menu (F10)", then "Restart game", wait for the new match. Allowed for testing; never restart an important or networked game without separate permission.
- Read the log with `node .tools/faf-log.cjs`; open the raw `game.log` only for a specific fragment, from the end.
- `ClaretHotbuild/modules/OpenPerf.lua`, gated by `probeEnabled`, logs the hotbuild open path for timing work.
- Performance measurements are run by the user (`performance.md`), not inferred from a single session.

## Limits

Fengari is not LuaPlus and Maui is mocked. Tests prove logic and data handling — never rendering, input routing, drag, scale or engine orders. In-game checks stay necessary; record version, scenario, observed result and limitation.
