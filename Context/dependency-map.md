# Зависимости: первый проход

Дата проверки: 2026-11-10. Первый проход этапа 1; полнота исследования не заявляется.

Факт: таблица ниже содержит строки ограничений версий, найденные в читаемом коде. Это не полный граф: optional-проверки, строки в комментариях и зависимости внутри bytecode требуют ручной проверки. Стрелки схемы означают использование, не порядок загрузки.

```mermaid
flowchart LR
  EconomyMiddle --> Economy[ReUI.Economy]
  Economy --> ReUI
  EUT --> UMT
  Beer --> UMT
  ReUI --> Core[Core: хуки и жизненный цикл]
  ReUI --> Options[Options: настройки]
```

Основания схемы: EconomyMiddle/mod_info.lua (описание), ReUI.Economy/Main.lua, EUT/modules/mexmanager.lua, Beer/modules/mexes.lua; ReUI/Core/Core.lua и ReUI/Options/Options.lua из отдельной копии исходников. Схема предварительная.

| Мод-потребитель | Найденное ограничение | Файл |
|---|---|---|
| ACUEnhancements | ReUI.ActionsPanel >= 1.1.0 | Context/sources/MainMods/ACUEnhancements/ACUEnhancements.lua |
| ACUEnhancements | ReUI.LINQ >= 1.4.0 | Context/sources/MainMods/ACUEnhancements/ACUEnhancements.lua |
| ACUEnhancements | ReUI.UI.Views.Grid >= 1.0.0 | Context/sources/MainMods/ACUEnhancements/ACUEnhancements.lua |
| ACUEnhancements | ReUI.Units.Enhancements >= 1.1.0 | Context/sources/MainMods/ACUEnhancements/ACUEnhancements.lua |
| AKA | ReUI.Actions >= 1.3.0 | Context/sources/MainMods/AKA/Main.lua |
| AKA | ReUI.Construction >= 1.2.0 | Context/sources/MainMods/AKA/Main.lua |
| AKA | ReUI.Core >= 1.0.0 | Context/sources/MainMods/AKA/Main.lua |
| AKA | ReUI.Hotbuild >= 1.1.0 | Context/sources/MainMods/AKA/Main.lua |
| AKA | ReUI.LINQ >= 1.1.0 | Context/sources/MainMods/AKA/Main.lua |
| Bi4UI.StrategicRings | ReUI.Options >= 1.0.0 | Context/sources/MainMods/Bi4UI.StrategicRings/Main.lua |
| Ctrl | ReUI.Actions >= 1.2.0 | Context/sources/MainMods/Ctrl/Main.lua |
| Ctrl | ReUI.Core >= 1.0.0 | Context/sources/MainMods/Ctrl/Main.lua |
| Ctrl | ReUI.LINQ >= 1.0.0 | Context/sources/MainMods/Ctrl/Main.lua |
| Ctrl | ReUI.Options >= 1.0.0 | Context/sources/MainMods/Ctrl/Main.lua |
| DelisRedundantEcoHelp | ReUI.Core >= 1.7.0 | Context/sources/MainMods/DelisRedundantEcoHelp/Main.lua |
| DelisRedundantEcoHelp | ReUI.Options >= 2.0.0 | Context/sources/MainMods/DelisRedundantEcoHelp/Main.lua |
| DynamicSelectionInfo | ReUI.Core >= 1.1.0 | Context/sources/MainMods/DynamicSelectionInfo/Main.lua |
| DynamicSelectionInfo | ReUI.Options >= 1.0.0 | Context/sources/MainMods/DynamicSelectionInfo/Main.lua |
| GS | ReUI.Actions >= 1.0.0 | Context/sources/MainMods/GS/Main.lua |
| GS | ReUI.Core >= 1.0.0 | Context/sources/MainMods/GS/Main.lua |
| Mouse | ReUI.Options >= 1.0.0 | Context/sources/MainMods/Mouse/Main.lua |
| ReUI | ReUI.Core = 1.0.0 | Context/sources/MainMods/ReUI/ModuleMeta.lua |
| ReUI | ReUI.Core >= 0.0.1 | Context/sources/MainMods/ReUI/ModuleMeta.lua |
| ReUI | ReUI.Core >= 1.2.0 | Context/sources/MainMods/ReUI/UI/QoL/Main.lua |
| ReUI | ReUI.Core >= 1.7.0 | Context/sources/MainMods/ReUI/Main.lua |
| ReUI | ReUI.Functional == 0.2.0 | Context/sources/MainMods/ReUI/ModuleMeta.lua |
| ReUI | ReUI.LINQ >= 1.0.0 | Context/sources/MainMods/ReUI/ModuleMeta.lua |
| ReUI | ReUI.Options >= 1.2.0 | Context/sources/MainMods/ReUI/UI/QoL/Main.lua |
| ReUI | ReUI.UI >= 1.4.0 | Context/sources/MainMods/ReUI/UI/QoL/Main.lua |
| ReUI | ReUI.UI.QoL >= 1.0.0 | Context/sources/MainMods/ReUI/Main.lua |
| ReUI.ActionsPanel | ReUI.ActionsPanel = 1.1.3 | Context/sources/MainMods/ReUI.ActionsPanel/mod_info.lua |
| ReUI.Construction | ReUI.Actions >= 1.3.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.Construction = 1.3.0 | Context/sources/MainMods/ReUI.Construction/mod_info.lua |
| ReUI.Construction | ReUI.Core >= 1.5.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.LINQ >= 1.4.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.Options >= 1.2.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.UI >= 1.4.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.UI.Animation >= 1.1.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.UI.Color >= 1.0.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.UI.Controls >= 1.0.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.UI.Views >= 1.2.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.UI.Views.Grid >= 1.1.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.Units >= 1.0.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction | ReUI.Units.Enhancements >= 1.2.0 | Context/sources/MainMods/ReUI.Construction/Construction.lua |
| ReUI.Construction.Templates | ReUI.Construction.Templates = 1.0.0 | Context/sources/MainMods/ReUI.Construction.Templates/mod_info.lua |
| ReUI.Economy | ReUI.Economy = 1.2.0 | Context/sources/MainMods/ReUI.Economy/mod_info.lua |
| ReUI.Hotbuild | ReUI.Actions >= 1.3.0 | Context/sources/MainMods/ReUI.Hotbuild/Hotbuild.lua |
| ReUI.Hotbuild | ReUI.Core >= 1.2.0 | Context/sources/MainMods/ReUI.Hotbuild/Hotbuild.lua |
| ReUI.Hotbuild | ReUI.Hotbuild = 1.1.0 | Context/sources/MainMods/ReUI.Hotbuild/mod_info.lua |
| ReUI.Hotbuild | ReUI.LINQ >= 1.4.0 | Context/sources/MainMods/ReUI.Hotbuild/Hotbuild.lua |
| ReUI.Hotbuild | ReUI.Options >= 1.0.0 | Context/sources/MainMods/ReUI.Hotbuild/Hotbuild.lua |
| ReUI.Hotbuild | ReUI.UI >= 1.4.0 | Context/sources/MainMods/ReUI.Hotbuild/Hotbuild.lua |
| ReUI.Hotbuild | ReUI.UI.Animation >= 1.0.0 | Context/sources/MainMods/ReUI.Hotbuild/Hotbuild.lua |
| ReUI.Hotbuild | ReUI.UI.Controls >= 1.0.0 | Context/sources/MainMods/ReUI.Hotbuild/Hotbuild.lua |
| ReUI.Hotbuild | ReUI.UI.Views >= 1.2.0 | Context/sources/MainMods/ReUI.Hotbuild/Hotbuild.lua |
| ReUI.Hotbuild | ReUI.UI.Views.Grid >= 1.0.0 | Context/sources/MainMods/ReUI.Hotbuild/Hotbuild.lua |
| ReUI.MissilePanel | ReUI.ActionsPanel >= 1.1.0 | Context/sources/MainMods/ReUI.MissilePanel/Main.lua |
| ReUI.MissilePanel | ReUI.Core >= 1.1.0 | Context/sources/MainMods/ReUI.MissilePanel/Main.lua |
| ReUI.MissilePanel | ReUI.MissilePanel = 1.0.0 | Context/sources/MainMods/ReUI.MissilePanel/mod_info.lua |
| ReUI.MissilePanel | ReUI.Options >= 1.0.0 | Context/sources/MainMods/ReUI.MissilePanel/Main.lua |
| ReUI.MissilePanel | ReUI.UI.Views.Grid >= 1.0.0 | Context/sources/MainMods/ReUI.MissilePanel/Main.lua |
| ReUI.Reclaim | ReUI.Core >= 1.3.0 | Context/sources/MainMods/ReUI.Reclaim/Reclaim.lua |
| ReUI.Reclaim | ReUI.Options >= 1.0.0 | Context/sources/MainMods/ReUI.Reclaim/Reclaim.lua |
| ReUI.Reclaim | ReUI.Reclaim = 1.2.1 | Context/sources/MainMods/ReUI.Reclaim/mod_info.lua |
| ReUI.Reclaim | ReUI.UI >= 1.4.0 | Context/sources/MainMods/ReUI.Reclaim/Reclaim.lua |
| ReUI.Reclaim | ReUI.WorldView >= 1.0.0 | Context/sources/MainMods/ReUI.Reclaim/Reclaim.lua |
| ReUI.Score | ReUI.Score = 1.2.4 | Context/sources/MainMods/ReUI.Score/mod_info.lua |
| SplitGroupScatter | ReUI.Actions >= 1.0.0 | Context/sources/MainMods/SplitGroupScatter/Main.lua |
| SplitGroupScatter | ReUI.Core >= 1.0.0 | Context/sources/MainMods/SplitGroupScatter/Main.lua |
| TeamMouse | ReUI.Options >= 2.0.0 | Context/sources/MainMods/TeamMouse/Main.lua |

## Хуки gamemain.lua
Подтверждено: найдено 14 файлов. Само число хуков не доказывает конфликт.
- `Context/sources/MainMods/ASE/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/Beer/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/Bi4UI.StrategicRings/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/BindStorage/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/BuilderAltSelect/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/cinematics/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/dear-windowing/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/DelisRedundantEcoHelp/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/Mouse/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/Regen Aura Range/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/ReUI/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/Reveal positions/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/TeamMouse/hook/lua/ui/game/gamemain.lua`
- `Context/sources/MainMods/UMT/hook/lua/ui/game/gamemain.lua`
