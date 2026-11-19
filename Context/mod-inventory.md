# Mod Inventory

Claret (2026-11-19): **Claret Core 0.10.16**, mod version 35, build 20261119-48, UID claret-core-001 (in game, awaiting confirmation; committed mirror is 0.10.15 / mod 34 / build 20261119-47); **Claret Hotbuild 0.10.41**, mod version 77, build 20261119-151, UID claret-hotbuild-001. Both ui_only=true, both require ReUI; Hotbuild requires Core >= 0.10.15.

The table below covers the *reference* mods in Context/sources, not Claret.

Date: 2026-11-10. Confirmed facts from file inspection; feature research has not yet been done.
Sources: `sources/MainMods/<folder>/mod_info.lua`, `sources/<folder>/mod_info.lua`, and corresponding folders in `../mods`.
Versions and UIDs come from manifests. Installed copies were compared using full file lists and SHA-256. Bytecode was identified by the ESC Lua header; other binary formats are not ruled out.

| Folder | MainMods version | UID | ui_only | Bytecode / Lua | Separate source copy: version / UID | Installed copy |
|---|---|---|---|---|---|---|
| ACUEnhancements | 4 | "acu-enhancements-v1.0.3" | true | 0/2 | no separate copy | matches |
| AKA | 5 | "advanced-key-actions-1.2.2" | true | 0/2 | no separate copy | matches |
| AOE | 5 | "additional-orders-extension-v05" | true | 0/5 | no separate copy | matches |
| ASE | 3 | "advanced-selection-extension-v03" | true | 0/8 | no separate copy | matches |
| ASI Medium | 1 | "redux-acu-icons-01" | true | 0/2 | no separate copy | matches |
| Beer | 1 | "beer-beer-beer-v01" | true | 0/4 | no separate copy | matches |
| Bi4UI.StrategicRings | 20 | "bi4ui-strategic-Rings-v15" | true | 0/15 | no separate copy | matches |
| BindStorage | 1 | "04323AB2-1C12-5ED7-9876-2111D3100005" | true | 0/3 | no separate copy | matches |
| BuilderAltSelect | 3 | "builder-alt-select-v3" | true | 0/3 | no separate copy | matches |
| cinematics | 7 | "cinematics-07" | true | 0/8 | no separate copy | matches |
| CinematicsMod | 1 | "0ad0e447-5c65-468a-84c9-af62859453e3" | false | 0/3 | no separate copy | matches |
| Ctrl | 2 | "ctrl-v02" | true | 0/3 | no separate copy | matches |
| dear-windowing | 9 | "dear-windowing-09" | true | 0/7 | no separate copy | matches |
| DelisRedundantEcoHelp | 3 | "delis-redundant-eco-help-v3" | true | 0/5 | no separate copy | matches |
| DynamicSelectionInfo | 3 | "dynamic-selection-info-v03" | true | 0/3 | no separate copy | matches |
| EconomyMiddle | 2 | "EconomyMiddle-1.1.0" | true | 1/3 | 2 / "EconomyMiddle-1.1.0" | matches |
| EUT | 11 | "eco-ui-tools-4z0t-v11" | true | 0/8 | no separate copy | matches |
| Extra mini map | 3 | "b0d9ac94-cetet-11e5-9912-ba1s3e4" | true | 0/2 | no separate copy | matches |
| FactoryTemplates | 2 | "factory-templates-1.0.0" | true | 1/2 | 1 / "factory-templates-v01" | matches |
| GS | 7 | "group-scatter-v07" | true | 0/2 | no separate copy | matches |
| InstantAssist | 3 | "instant-assist-1.1.1" | true | 2/3 | 1 / "instant-assist-v01" | matches |
| Mouse | 3 | "mouse-1-0-2" | true | 0/10 | no separate copy | game files match; only .git differs |
| Music_PhilCrofts | 5 | "8ecaa312-f18b-11e7-8cef-jf89jh2kksn5" | true | 0/2 | no separate copy | matches |
| Regen Aura Range | 1 | "5e7a9c31-2b4d-4f6e-9a18-3c0d7e5b9f42" | true | 0/5 | no separate copy | matches |
| ReUI.ActionsPanel | 4 | "reui-actionspanel-1.1.3" | true | 4/6 | 4 / "reui-actionspanel-1.1.3" | matches |
| ReUI.Construction.Templates | 1 | "ReUI.Construction.Templates-1.0.0" | true | 4/6 | 1 / "ReUI.Construction.Templates-1.0.0" | matches |
| ReUI.Construction | 7 | "ReUI.Construction-1.3.0" | true | 0/21 | no separate copy | matches |
| ReUI.Economy | 2 | "reui-economy-1.2.0" | true | 4/6 | 2 / "reui-economy-1.2.0" | matches |
| ReUI.Hotbuild | 1 | "reui-Hotbuild-1.1.0" | true | 0/10 | no separate copy | matches |
| ReUI.MissilePanel | 3 | "missile-panel-v3" | true | 0/3 | no separate copy | matches |
| ReUI.Reclaim | 7 | "reui-reclaim-1.2.1" | true | 0/3 | no separate copy | matches |
| ReUI.Score | 5 | "reui-score-1.2.4" | true | 27/30 | 5 / "reui-score-1.2.4" | matches |
| ReUI | 7 | "reui-1.3.2" | true | 53/75 | 8 / "reui-1.4.0" | matches |
| Reveal positions | 4 | "128a0b16-a4d0-4bf2-8f84-935de62715e8" | true | 0/2 | no separate copy | matches |
| RFA | 7 | "rings-for-all-v1.0.0" | true | 2/3 | 6 / "rings-for-all-v1.0.0" | matches |
| SplitGroupScatter | 2 | "split-group-scatter-v02" | true | 0/2 | no separate copy | matches |
| STP | 3 | "Specific-Target-Priorities-v03" | true | 0/3 | no separate copy | matches |
| TeamMouse | 6 | "team-mouse-v6" | true | 0/23 | no separate copy | matches |
| TIS | 11 | "teaminfo-share-v11" | true | 0/8 | no separate copy | matches |
| UMT | 13 | "ui-mod-tools-4z0t-v13" | true | 0/45 | no separate copy | matches |

Unknown: behavioral equivalence across versions, asset licenses, compatibility, and in-game performance.

Clarification (2026-11-10): Mouse differs only in the auxiliary file `.git/refs/codex/turn-diffs/checkpoints`; no game-file differences were found. Exclude `.git` metadata directories from future comparisons.

