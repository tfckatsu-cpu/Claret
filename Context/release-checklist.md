# Release checklist

Use for every task that changes shipped mod files. Docs-only changes skip the game step but follow steps 4–7.

## 1. Scope

- List the relative paths changed in this task only. Do not mix unrelated work.
- No external runtimes, no game-file changes, no simulation changes (`ui_only = true`).

## 2. Version identity (when mod code changes)

| File | Field |
|---|---|
| `Main.lua` | `Version` and `BuildStamp` (`YYYYMMDD-N`, next build number) |
| `mod_info.lua` | `version` (mod version +1) and `ReUI = '<Mod>=<Version>'` |
| `README.md` | heading version |
| `CHANGELOG.md` | new `## Сборка <stamp>` entry (English text for new entries) |

- Core and Hotbuild versions are independent; Hotbuild requires `ClaretCore >= <current Core>`.
- The runner fails if these disagree (step 3).

### FAF Mod Vault updates

- For a new version of an already published mod, keep the published `name` exactly and set `version` to an integer above the latest published version. Assign a fresh `uid` in the working `mod_info.lua` as part of the version bump so the build can be uploaded directly. For Claret Hotbuild, use `claret-hotbuild-<version>` with at least three digits, for example `claret-hotbuild-087` for version 87. Use a fresh UID if that value is already taken.
- Check references to the outgoing UID, including UID-based dependencies and load-order declarations. Keep profile keys and bind IDs stable. Report the upload folder and new UID to the user.
- [FAF mod manifest documentation](https://github.com/FAForever/fa/blob/develop/lua/MODS.LUA)

## 3. Local checks

- Focused: `node Tests/check-core.cjs --only <pattern>`.
- Full: `node Tests/check-core.cjs --quiet` — must be all green (currently 66/0).
- Static checks run first: `#`, `continue`, localization parity, Core↛Hotbuild, version identity.

## 4. In-game verification (user)

- The user runs the build and confirms the change; record version, scenario, observed result.
- No sync or commit before this confirmation, unless the user explicitly asks for a checkpoint.

## 5. Sync originals → mirrors

From the repository root:

```
powershell -NoProfile -File .\Tools\Sync-ClaretMods.ps1 -Mod <ClaretCore|ClaretHotbuild> -Paths '<path1>','<path2>'
```

- Only the files listed in step 1. The script copies originals to mirrors, stops on conflicts and verifies SHA-256.
- Deletions are not synced: remove the mirror file with `git rm` in the same commit and mention it.
- Never copy a mirror back over an original.

## 6. Review and commit

- `git status` and `git diff` — only task files staged.
- One descriptive commit for the task; body explains the change and the risk.
- Push `dev` only: `git push origin dev`. No force-push, no PRs without a request.

## 7. Close the task

- Rewrite `Stage/stage-1-status.md` (results, decisions, pending checks, open questions, ≤ ~5000 characters).
- Add 2–3 lines to `Stage/stage-1-research.md` (date, change, decision).
- Update the owner document in `Context/` if behaviour changed; move superseded text to `Context/.local/history/`.

## Rollback

- Code: `git revert <commit>`; restoring a single file from the mirror is acceptable for hotfixes after checking both copies match.
- Never leave originals and mirrors diverged: after a revert, re-run the sync for the touched paths.
