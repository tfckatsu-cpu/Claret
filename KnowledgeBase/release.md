# Release and commit

> **Answers:** version bumps, sync command, commit rules, rollback, closing a task. **Read when:** shipping a change, syncing mirrors, committing, reverting. **Next:** `testing.md` — the run must be green before step 3 passes.

Applies to any task that changes shipped mod files. Docs-only changes skip the in-game step but keep steps 4–6.

## 1. Scope

- List only the relative paths changed in this task. Do not mix unrelated work.
- No external runtimes, no game-file changes, no simulation changes (`ui_only = true`).

## 2. Version identity (mod code changed)

| File | Field |
|---|---|
| `Main.lua` | `Version`, bumped for every shipped change; `BuildStamp` = `YYYYMMDD-N`, next build number |
| `mod_info.lua` | `version` = integer + 1; `ReUI = '<Mod>=<Version>'` |
| `README.md` | heading version |
| `CHANGELOG.md` | new `## Сборка <stamp>` entry; new entries in English (historical Russian entries stay) |

Claret Core, Claret UI and Claret Hotbuild versions are independent. Hotbuild requires `ClaretCore >= <current Core>`. The runner fails if the identity fields disagree.

## 3. Local checks

- Focused: `node Tests/check-core.cjs --only <pattern>`.
- Full: `node Tests/check-core.cjs --quiet` — all green.
- Static checks run first: `#`, `continue`, localization parity, Core↛Hotbuild, version identity.

## 4. In-game verification

- The user runs the build and confirms the change. Record version, scenario, observed result.
- No sync, commit or push before that confirmation, unless the user explicitly asks for a checkpoint.
- In-game checks can be expensive (screenshots, restarting a match). Do one scenario at a time, or hand the user a short checklist.

## 5. Sync originals → mirrors

Repository copies `mods/ClaretCore`, `mods/ClaretUI`, `mods/ClaretHotbuild` are **mirrors**. Originals live in `../mods/`. Never copy a mirror back over an original.

From the repository root, only the files changed in this task:

```powershell
powershell -NoProfile -File .\Tools\Sync-ClaretMods.ps1 -Mod <ClaretCore|ClaretUI|ClaretHotbuild> -Paths '<path1>','<path2>'
```

- The script copies originals to mirrors, checks for conflicts and verifies SHA-256.
- Deletions are **not** synced: remove the mirror file with `git rm` in the same commit and say so.
- It stops on a conflict — resolve the difference at the original, never by overwriting the original.

## 6. Review and commit

- `git status`, `git diff` — only task files staged.
- One descriptive commit for the task; the body explains the change and the risk.
- Branch `dev` only. No commits to `main`, no force-push, no PRs without an explicit request.
- Push: `git push origin dev`.
- Exclude `Context/sources/`, `.tools/`, caches, temporary files, secrets.

## 7. Close the task

- Rewrite (do not append) `Stage/stage-1-status.md`: results, decisions, pending user checks, open questions, ≤ ~5000 characters.
- Add 2–3 lines to `Stage/stage-1-research.md`: date, what changed, decision.
- If behaviour changed, update the owner document in `Context/` in the same task; move superseded text to `Context/history/`.

## Rollback

- Code: `git revert <commit>`.
- Single-file hotfix: restoring from the mirror is acceptable **after** checking both copies match.
- After any revert, re-run the sync for the touched paths. Never leave originals and mirrors diverged.
