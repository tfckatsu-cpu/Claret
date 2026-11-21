# LuaPlus dialect and module loading

> **Answers:** what breaks a module at load, how `import` really works, what must be exported, hard limits. **Read when:** a module fails to load, `nonexistent global variable`, `#`, `continue`, upvalue errors, `pcall` cost, `return` ignored. **Next:** `engine.md` for API context; `testing.md` for the checks that enforce this.

FAF runs UI Lua on **LuaPlus 5.01**, not stock Lua 5.1. A file that compiles with lua5.1/LuaJIT can still fail to load in game. The failure is usually silent at the module level and surfaces elsewhere.

## Banned syntax

| Construct | Why | Use instead |
|---|---|---|
| `#t` | LuaPlus treats `#` as a comment marker; the rest of the line is lost, the module table stays empty | `table.getn(t)`, `table.insert`, `table.remove` |
| `continue` | Reserved by the project; the runner rejects it as an identifier | restructure with `if`/`elseif` |
| `goto` / labels | Not supported by the project | helper function or flag |
| `//` integer division | Not Lua 5.0 | `math.floor(a / b)` |
| Varargs in expression position: `f(x, ...)`, `return ...`, `{...}` | Aborts the module load in LuaPlus; the module table stays empty | fixed parameters, or build a table explicitly |
| `!=`, `&&`, `||` | Not Lua | `~=`, `and`, `or` |

Bitwise operators and `^` as XOR exist in LuaPlus per the official syntax page but are avoided: tooling and the runner do not model them. `math.pow` for powers.

## Module system

- `import('/mods/<Mod>/modules/Foo.lua')` returns the **module environment table**, cached after the first call. It does **not** return the chunk's `return` value.
- Therefore a module must export through module globals:

```lua
-- correct
function Create(deps)
    ...
end
Start = function(scope) ... end
```

```lua
-- wrong: loads as an empty table
local function Helper() end
return { Create = Helper }
```

```lua
-- wrong: the assignment binds to the local, nothing is exported
local function Create() end
Create = Create
```

- Caller side failure signature: `access to nonexistent global variable "Create"`.
- **Strict module tables**: reading a field that was never assigned raises `access to nonexistent global variable <name>` instead of returning `nil`. Export every public symbol; guard optional fields with `rawget` on your own table or keep a sentinel field.
- `rawget(_G, 'X')` does not reliably see engine globals in Claret modules. Use normal access inside `pcall`, or capture the value once at file scope where it exists.
- Import is lazy: a module that is never imported never runs. Heavy modules are imported on demand; `Runtime`-style modules are imported at file scope where hooks need them.
- Imports are cheap after the first call — the result is memoised per path, not per module name.

## Limits

- **32 upvalues per function.** Lua 5.3 counts `_ENV` too; FAF does not have `_ENV`. Keep nested closures shallow and hoist shared values into a table.
- No `io`/`os` in UI at runtime. `os` is unavailable; file checks use `DiskGetFileInfo(path)`.
- `math.huge` may be missing in some contexts. Use `1/0` or a large literal.
- `pcall` is comparatively expensive. Use it at boundaries only: engine calls, profile access, optional module loading. Never per frame, per list item or per key in a dispatch loop.
- `GetSystemTimeSeconds()` exists in UI. `GetSystemTimeSecondsOnlyForProfileUse()` does not exist in UI context (strict-globals error).

## Types

Maui classes (`Bitmap`, `Group`, classes built with `ClassUI`) are **callable tables with `__call`**, not functions. Guards such as `type(x) ~= 'function'` reject valid controls. Test `x == nil`, or accept `table`, or just call inside `pcall`.

## Errors

- Do not `error()` inside UI callbacks: a thrown handler leaves half-applied state and a dead control. Return `false, message` and render the message in a status line.
- Log with `LOG`/`WARN` and a module prefix (`'[ClaretCore ' .. Version .. '] '`). Logs stay English.
- `error()` is acceptable at module init when a required dependency is missing (Claret UI does this when `RegisterFeature` fails), because nothing has been built yet.

## Why a normal Lua compiler proves nothing

- The runner parses production files with Lua 5.1 grammar and executes tests in Fengari (Lua 5.3 with a `math.mod` shim). Passing both does not prove LuaPlus acceptance of syntax it does not model (varargs position, callable tables, strict module tables).
- The only authoritative reference is the installed snapshot `C:/ProgramData/FAForever/gamedata/lua.nx2` (FAF 3840). `lua.nx4` next to it is **Beta 3839** — not the target.
- A real FAF session remains the only proof for rendering, input routing and order execution.

## Static checks that enforce this file

`node Tests/check-core.cjs` fails the run before any test executes on: `#` in production Lua, `continue` as an identifier, missing localization keys in `en`/`ru`, Core importing Hotbuild, version identity mismatch. See `testing.md`.
