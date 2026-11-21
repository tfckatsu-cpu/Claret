# Testing

How Claret tests work and how to add one without weakening the suite.

## Runner

- `node Tests/check-core.cjs --quiet` from the project root. `--only <substring>` runs a subset. `--quiet` prints one summary line; without it every test prints its own `PASS:` and the parser summary.
- Auto-discovery: every `Tests/*.lua` runs; files ending in `-helper.lua` are shared helpers and are skipped. Adding a test file is enough — never edit a list.
- Tests load production modules from `../mods/...` (the live mod folders). Keep the project copies and `../mods` identical; the runner reads the live ones.
- The runner first parses all mod Lua files with Lua 5.1 grammar, then runs each test in Fengari (Lua 5.3 with `math.mod` shimmed).

## Static checks (fail before any test runs)

- `#` operator anywhere in production Lua — LuaPlus treats it as a comment marker and the module fails to load.
- `continue` as an identifier — reserved by the project.
- Localization: every referenced `core.*` / `hotbuild.*` key exists in both `en` and `ru`; the two tables have identical key sets.
- Architecture: ClaretCore must not `import('/mods/ClaretHotbuild...')`.
- Version identity: `Version` in `Main.lua` = `ReUI` value in `mod_info.lua` = README heading; `BuildStamp` = newest CHANGELOG build (when a CHANGELOG exists).

## Anatomy of a test

```lua
table.getn = table.getn or function(t) return #t end
local modules = {}
local env = setmetatable({ ... engine stubs ... }, { __index = _G })
env.import = function(path) ... return stubs or loadfile('../mods/...'..path, 't', module)() end
assert(loadfile('../mods/ClaretHotbuild/modules/Thing.lua', 't', env))()
-- arrange, act, assert with messages
print('PASS: what this file proves')
```

- Assertions carry a message explaining the expected behaviour; a bare `assert(x)` is not acceptable in new tests.
- End with one `print('PASS: ...')` describing the coverage.
- Keep tests deterministic: own time counter instead of `os.time`, sorted iteration for output, no randomness.
- Tests must not write real profiles, call the engine or depend on the user's data. Fixtures are plain tables.

## Stubs

- Real module code, fake engine: stub `Prefs`, `Mapper`, `IN_*KeyMap`, `GetSelectedUnits`, `IsDestroyed`, MAUI controls (`Width/Height/Depth` as callable variables, `Destroy`, `OnDestroy`, `SetTexture`, `SetText`, `SetupEditStd`), `ReUI` with `ClaretCore.Localization`.
- Unit fixtures need the categories the code checks: engineers must be `ENGINEER` **and** `MOBILE`; factories `FACTORY`; presets building structures need `STRUCTURE`/`BUILTBY...FACTORY` as the code expects. A missing category is the most common stale fixture.
- Profile fixtures: presets `{version=1, bindings={...}}`, contexts `{version=3, bindings={...}}`, keyboard `{version=2, assignments={['Ctrl-A']={preset='x'}}}`. Corrupt cases use raw tables with unknown fields.
- Do not stub away the behaviour under test. If a test needs `pcall` to hide an error, the test is wrong.

## What to assert

- User-visible result (applied key, saved record, shown label) before internal state.
- Data preservation: raw invalid records keep order, IDs and unknown fields; FAF actions and key assignments of quarantined presets survive.
- Atomicity: a failed save leaves profile and engine maps unchanged.
- No accidental side effects: unassigned presets register no native action, untouched maps stay untouched.

## When a test fails

1. Read the assertion message; run `--only <name>` for the short trace.
2. Decide: stale expectation (cite the current code line) or production defect.
3. Stale expectation: update the value with a one-line justification, keep the intent.
4. Defect: fix the code, keep the test as the regression guard; never delete the assertion.
5. Never weaken a test to make it pass (no always-true checks, no removed coverage).

## Limits

Fengari is not LuaPlus and Maui is mocked. Tests prove logic and data handling, not rendering, input routing or engine orders. In-game checks stay necessary; record version, scenario, result and limitation.
