# Claret foundation choice: recommendation after studying ReUI

Review date: 2026-11-10. Status: recommendation for the user's decision; architecture has not yet been approved. Based on reading the supplied ReUI 1.4.0, not FPS measurements. Details and source files: `reui-notes.md`, section “Detailed review.”

**Recommendation: start with ReUI as the external foundation for UI and settings, and limit Claret Core to managing features, their resources, and workload. Do not write a full ReUI replacement now.** This updates the earlier preliminary recommendation to build a custom library: detailed review did not show a need to recreate existing settings, layout, and event systems for a presumed speed benefit.

| Criterion | Use ReUI | Write a full replacement |
|---|---|---|
| Settings window | Reactive values, save/cancel, ready-made controls | Build, test, and maintain all of this |
| Scaling and layout | Maui + Layouter/Layoutable, ready-made Views | Create custom rules and test scaling/resolutions |
| Feature activation | Add Claret lifecycle and cleanup | Add the same lifecycle, plus a library foundation |
| Performance | Optimize specific features; ordinary loops can be used in hot paths | Benefit is unknown until comparing equivalent features |
| Independence | Depends on API versions and required QoL | Code control, but full responsibility for FAF compatibility |
| Claret style | Check whether existing Views can be configured; build custom controls for required panels | Full design freedom with more work |

**Start with:** Core hooks/UI creation phases, UI/Layouter and Controls, Options. Add WorldView, Grid, Units, and Animation as features require them. The standard ReUI Main already requires QoL, which in turn requires Options/UI/LINQ; installation is not limited to Core alone. Do not promise zero side effects on the interface.

**Keep custom:** Claret feature registry; activation/deactivation that stops work and unsubscribes; heavy-work budgets; shared data only for consumers that truly share it; settings migration from old mods; styling and diagnostics. The first version does not need a universal replacement for all of ReUI.

**Why a rewrite is not justified yet:** Layouter showed no constant full per-frame traversal; Animator stops updating when no animations are active; settings include subscription cleanup; the loader mainly works at startup. Potentially expensive areas—WorldView/overlays, active animations, long lists, and data retrieval—should be assessed by object count and actual handlers. The claim “ReUI itself reduces FPS” has not been confirmed.

**ReUI risks:** no automatic resolution of hook conflicts or universal runtime unload; standard QoL affects panels; exceptions in ordinary Event subscribers are not isolated; HiddenSelect does not restore state if a callback throws; installed 1.3.2 and readable 1.4.0 are not proven equivalent. These are concrete items to check, not confirmed in-game failures.

**When to choose a custom foundation:** a significant cost is measured in the required part of ReUI; required style/lifecycle repeatedly works around its API; required QoL changes conflict with Claret; or independent distribution matters more than added maintenance. Then build only the minimal required foundation, using prototype results to set scope. Choose a numeric workload threshold after baseline measurements.

**Pinned fork:** gives version control, but shifts update maintenance to Claret and conflicts with the current rule to write code from scratch. A difference between the LINQ.lua header and root MIT notice was also observed; clarify license scope before copying. A fork is not recommended at this stage.

**Checks before the final choice:** ReUI by itself; one representative Claret feature on ReUI; disable/re-enable, army changes, match end, UI scaling, and co-loading with the mods in use. Compare using `performance-hotspots.md`. This research does not require updating installed ReUI or creating a new game mod now.
