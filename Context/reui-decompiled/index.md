# ReUI: File-by-File Index of Recovered Code

Reviewed 2026-11-13. Covers only 92 originally compiled files; 68 text originals are listed in the manifest. Method and limitations: [README](README.md). Names below were found in recovered code; they are not a promise of public API.

## ReUI

| File and instructions | Version in file | Function names (up to 10) | Check |
|---|---|---|---|
| [Actions/Actions.lua](ReUI/Actions/Actions.lua) · [disasm](ReUI/Actions/Actions.disasm) | 1.3.0 | `Main`, `ProcessAction`, `GetFormattedName`, `CheckFormattedName`, `AddSimpleAction`, `AddAction`, `__init`, `Process`, `__call`, `Modifiers` | byte-for-byte match |
| [Core/Core.lua](ReUI/Core/Core.lua) · [disasm](ReUI/Core/Core.disasm) | 1.7.0 | `Main`, `MakeHook`, `ReUI.Core.Hook`, `PerformHook`, `HookModule`, `OnPreCreateUI`, `OnPostCreateUI`, `Key`, `Value`, `KeyValue` | byte-for-byte match |
| [Core/Events.lua](ReUI/Core/Events.lua) · [disasm](ReUI/Core/Events.disasm) | 1.0.0 | `Main`, `IsSimpleTable`, `__eq`, `__call`, `Bind`, `FilterEvent`, `CopyCallbacks`, `__init`, `Add`, `Remove` | byte-for-byte match |
| [Core/Modules/Class.lua](ReUI/Core/Modules/Class.lua) · [disasm](ReUI/Core/Modules/Class.disasm) | — | `IsSimpleClass`, `GetError`, `SetError`, `Property`, `MakeProperties`, `class:__index`, `class:__newindex`, `CacheClassFields`, `RestoreClassFields`, `MakeUIClass` | byte-for-byte match |
| [Core/Modules/Loader.lua](ReUI/Core/Modules/Loader.lua) · [disasm](ReUI/Core/Modules/Loader.disasm) | — | `RemoveSpaces`, `ParseVersion`, `ParseNameAndVersion`, `DemangleName`, `VersionEqual`, `VersionGreater`, `CheckVersion`, `VersionToString`, `MatchDependencyString`, `DoScript` | byte-for-byte match |
| [Core/Modules/String.lua](ReUI/Core/Modules/String.lua) · [disasm](ReUI/Core/Modules/String.disasm) | — | `EmptySeparatorIterator`, `SplitIterNext`, `SplitIter`, `Split`, `TrimStart`, `TrimEnd`, `Trim` | byte-for-byte match |
| [ECS/ECS.lua](ReUI/ECS/ECS.lua) · [disasm](ReUI/ECS/ECS.disasm) | 1.0.0 | `Main` | byte-for-byte match |
| [ECS/Modules/ALazyComponentContainer.lua](ReUI/ECS/Modules/ALazyComponentContainer.lua) · [disasm](ReUI/ECS/Modules/ALazyComponentContainer.disasm) | — | `GetComponent`, `CreateComponent` | byte-for-byte match |
| [ECS/Modules/ComponentContainer.lua](ReUI/ECS/Modules/ComponentContainer.lua) · [disasm](ReUI/ECS/Modules/ComponentContainer.disasm) | — | `EnabledComponentsIterator`, `ComponentsIterator`, `GetComponents`, `IterateComponents`, `IterateEnabledComponents`, `GetComponent`, `AddComponent`, `RemoveComponent`, `DestroyComponents` | byte-for-byte match |
| [LINQ.lua](ReUI/LINQ.lua) · [disasm](ReUI/LINQ.disasm) | 1.4.0 | `Main`, `Identity`, `CallStatefulIterator`, `SelectIterator`, `WhereIterator`, `KeysIterator`, `CreateDistinctIterator`, `DistinctIterator`, `ForeachIterator`, `ReverseTransformer` | byte-for-byte match |
| [Options/Modules/OptionControls/OptionControl.lua](ReUI/Options/Modules/OptionControls/OptionControl.lua) · [disasm](ReUI/Options/Modules/OptionControls/OptionControl.disasm) | — | `__init`, `get`, `ValueChanged`, `Destroy` | byte-for-byte match |
| [Options/Modules/OptionControls/OptionsMenu.lua](ReUI/Options/Modules/OptionControls/OptionsMenu.lua) · [disasm](ReUI/Options/Modules/OptionControls/OptionsMenu.disasm) | — | `__init`, `InitLayout`, `AddControl` | byte-for-byte match |
| [Options/Modules/OptionRef.lua](ReUI/Options/Modules/OptionRef.lua) · [disasm](ReUI/Options/Modules/OptionRef.disasm) | — | `IsValidLevels`, `__init`, `GetPath`, `Get`, `Set` | byte-for-byte match |
| [Options/Modules/OptionsWindow.lua](ReUI/Options/Modules/OptionsWindow.lua) · [disasm](ReUI/Options/Modules/OptionsWindow.disasm) | — | `Splitter`, `Title`, `Color`, `Filter`, `Slider`, `ColorSlider`, `Extend`, `norm`, `setAlpha`, `setRed` | byte-for-byte match |
| [Options/Modules/ReactiveOption.lua](ReUI/Options/Modules/ReactiveOption.lua) · [disasm](ReUI/Options/Modules/ReactiveOption.disasm) | — | `get`, `set`, `__init`, `Raw`, `Get`, `Prev`, `Set`, `Restore`, `Save`, `Destroy` | byte-for-byte match |
| [Options/Modules/Selector.lua](ReUI/Options/Modules/Selector.lua) · [disasm](ReUI/Options/Modules/Selector.disasm) | — | `Splitter`, `Column`, `Title`, `Color`, `Filter`, `Slider`, `TextEdit`, `ColorSlider`, `Strings`, `Fonts` | byte-for-byte match |
| [Options/Modules/StringSelector.lua](ReUI/Options/Modules/StringSelector.lua) · [disasm](ReUI/Options/Modules/StringSelector.disasm) | — | `__init`, `self._combo.OnClick`, `__post_init`, `InitLayout`, `OnDestroy` | byte-for-byte match |
| [Options/Modules/TextEdit.lua](ReUI/Options/Modules/TextEdit.lua) · [disasm](ReUI/Options/Modules/TextEdit.disasm) | — | `__init`, `self._edit.OnEnterPressed`, `__post_init`, `InitLayout`, `OnDestroy` | byte-for-byte match |
| [Options/Options.lua](ReUI/Options/Options.lua) · [disasm](ReUI/Options/Options.disasm) | 1.2.0 | `Main`, `FormatName`, `HandleOldPath`, `__init`, `Create`, `MakeDeprecatedOpt`, `OptionValue`, `LoadOptions`, `LoadOptionsFile`, `__newindex` | byte-for-byte match |
| [Selection/Options.lua](ReUI/Selection/Options.lua) · [disasm](ReUI/Selection/Options.disasm) | — | `Main` | byte-for-byte match |
| [Selection/Selection.lua](ReUI/Selection/Selection.lua) · [disasm](ReUI/Selection/Selection.disasm) | 1.0.0 | `Main`, `SelectIgnored`, `Handle`, `__init`, `Process`, `Get`, `Add`, `Remove`, `GetHandlers`, `GetSelector` | byte-for-byte match |
| [UI/Animation/Animation.lua](ReUI/UI/Animation/Animation.lua) · [disasm](ReUI/UI/Animation/Animation.disasm) | 1.1.0 | `Main`, `emptyFunc`, `__init`, `AnimateControls`, `OnFrame`, `Add`, `Remove`, `OnDestroy`, `ApplyAnimation`, `StopAnimation` | byte-for-byte match |
| [UI/Color/Color.lua](ReUI/UI/Color/Color.lua) · [disasm](ReUI/UI/Color/Color.disasm) | 1.0.0 | `Main`, `ToHexString`, `SetAlpha`, `SetRed`, `SetGreen`, `SetBlue`, `GetAlpha`, `GetRed`, `GetGreen`, `GetBlue` | byte-for-byte match |
| [UI/Controls/Controls.lua](ReUI/UI/Controls/Controls.lua) · [disasm](ReUI/UI/Controls/Controls.disasm) | 1.0.0 | `Main`, `OnInit`, `ResetLayout`, `Create`, `SetFont` | byte-for-byte match |
| [UI/Modules/LayoutFunctions.lua](ReUI/UI/Modules/LayoutFunctions.lua) · [disasm](ReUI/UI/Modules/LayoutFunctions.disasm) | — | `_MultVarAndValue`, `Mult`, `Div`, `_MaxVarOrValue`, `Max`, `_MinVarOrValue`, `Min`, `_DiffVarAndValue`, `_DiffValueAndVar`, `Diff` | byte-for-byte match |
| [UI/Modules/Layoutable.lua](ReUI/UI/Modules/Layoutable.lua) · [disasm](ReUI/UI/Modules/Layoutable.disasm) | — | `__call`, `Apply`, `Restore`, `__init`, `InitLayouter`, `set`, `get`, `__post_init`, `InitLayout` | byte-for-byte match |
| [UI/Modules/Layouter.lua](ReUI/UI/Modules/Layouter.lua) · [disasm](ReUI/UI/Modules/Layouter.disasm) | — | `__init`, `get`, `set`, `__call`, `PerformLayout`, `AtCenterOffset`, `ScaleVar`, `ScaleNumber`, `Sum`, `Diff` | byte-for-byte match |
| [UI/QoL/Options.lua](ReUI/UI/QoL/Options.lua) · [disasm](ReUI/UI/QoL/Options.disasm) | — | `Main` | byte-for-byte match |
| [UI/UI.lua](ReUI/UI/UI.lua) · [disasm](ReUI/UI/UI.disasm) | 1.4.0 | `Main` | byte-for-byte match |
| [UI/Views/Grid/Grid.lua](ReUI/UI/Views/Grid/Grid.lua) · [disasm](ReUI/UI/Views/Grid/Grid.disasm) | 1.1.0 | `Main` | byte-for-byte match |
| [UI/Views/Grid/Modules/AGridItem.lua](ReUI/UI/Views/Grid/Modules/AGridItem.lua) · [disasm](ReUI/UI/Views/Grid/Modules/AGridItem.disasm) | — | `__init`, `InitLayout`, `EnableComponent`, `DisableComponents`, `OnDisable`, `GetActiveComponent`, `SetActiveComponent`, `HandleEvent`, `OnFrame`, `OnDestroy` | byte-for-byte match |
| [UI/Views/Grid/Modules/AItemComponent.lua](ReUI/UI/Views/Grid/Modules/AItemComponent.lua) · [disasm](ReUI/UI/Views/Grid/Modules/AItemComponent.disasm) | — | `__init`, `Create`, `HandleEvent`, `OnFrame`, `Enable`, `Disable`, `Destroy` | byte-for-byte match |
| [UI/Views/Grid/Modules/ASelectionHandler.lua](ReUI/UI/Views/Grid/Modules/ASelectionHandler.lua) · [disasm](ReUI/UI/Views/Grid/Modules/ASelectionHandler.disasm) | — | `__init`, `OnInit`, `Update`, `Destroy`, `OnDestroy` | byte-for-byte match |
| [UI/Views/Grid/Modules/BaseGridItem.lua](ReUI/UI/Views/Grid/Modules/BaseGridItem.lua) · [disasm](ReUI/UI/Views/Grid/Modules/BaseGridItem.disasm) | — | `__init`, `get`, `set`, `CreateComponent`, `OnDestroy` | byte-for-byte match |
| [UI/Views/Grid/Modules/BaseGridPanel.lua](ReUI/UI/Views/Grid/Modules/BaseGridPanel.lua) · [disasm](ReUI/UI/Views/Grid/Modules/BaseGridPanel.disasm) | — | `CreateItem`, `CreateItems`, `AddItemComponent`, `DisableItems`, `OnResized`, `Refresh`, `GetItemComponentClasses` | byte-for-byte match |
| [UI/Views/Grid/Modules/Grid.lua](ReUI/UI/Views/Grid/Modules/Grid.lua) · [disasm](ReUI/UI/Views/Grid/Modules/Grid.disasm) | — | `OffsetFn`, `SizeFn`, `__init`, `self._resizeFn`, `get`, `set`, `InitLayout`, `InitSize`, `ComputeRows`, `ComputeColumns` | byte-for-byte match |
| [UI/Views/Grid/Modules/HandlerTemplate.lua](ReUI/UI/Views/Grid/Modules/HandlerTemplate.lua) · [disasm](ReUI/UI/Views/Grid/Modules/HandlerTemplate.disasm) | — | `OnInit`, `Update`, `OnDestroy`, `Create`, `HandleEvent`, `OnFrame`, `Enable`, `Disable`, `Destroy` | byte-for-byte match |
| [UI/Views/Modules/Brackets.lua](ReUI/UI/Views/Modules/Brackets.lua) · [disasm](ReUI/UI/Views/Modules/Brackets.disasm) | — | `__init`, `InitLayout` | byte-for-byte match |
| [UI/Views/Modules/Button.lua](ReUI/UI/Views/Modules/Button.lua) · [disasm](ReUI/UI/Views/Modules/Button.disasm) | — | `__init`, `OnRolloverEvent`, `OnClick` | byte-for-byte match |
| [UI/Views/Modules/CollapseArrow.lua](ReUI/UI/Views/Modules/CollapseArrow.lua) · [disasm](ReUI/UI/Views/Modules/CollapseArrow.disasm) | — | `__init` | byte-for-byte match |
| [UI/Views/Modules/DynamicScrollable.lua](ReUI/UI/Views/Modules/DynamicScrollable.lua) · [disasm](ReUI/UI/Views/Modules/DynamicScrollable.disasm) | — | `Setup`, `ScrollSetTop`, `GetData`, `GetDataSize`, `CalcVisible`, `DataIter`, `RenderLine` | byte-for-byte match |
| [UI/Views/Modules/EscapeCover.lua](ReUI/UI/Views/Modules/EscapeCover.lua) · [disasm](ReUI/UI/Views/Modules/EscapeCover.disasm) | — | `__init`, `HandleEvent`, `Close`, `OnEscapePressed`, `OnShadowClicked`, `OnDestroy`, `OnClose` | byte-for-byte match |
| [UI/Views/Modules/GlowBorder.lua](ReUI/UI/Views/Modules/GlowBorder.lua) · [disasm](ReUI/UI/Views/Modules/GlowBorder.disasm) | — | `__init`, `InitLayout` | byte-for-byte match |
| [UI/Views/Modules/StaticScrollable.lua](ReUI/UI/Views/Modules/StaticScrollable.lua) · [disasm](ReUI/UI/Views/Modules/StaticScrollable.disasm) | — | `Setup`, `GetScrollValues`, `ScrollLines`, `ScrollPages`, `ScrollSetTop`, `ScrollToBottom`, `CalcVisible`, `RenderLine`, `HandleEvent`, `OnEvent` | byte-for-byte match |
| [UI/Views/Modules/WindowFrame.lua](ReUI/UI/Views/Modules/WindowFrame.lua) · [disasm](ReUI/UI/Views/Modules/WindowFrame.disasm) | — | `__init`, `InitLayout` | byte-for-byte match |
| [UI/Views/Views.lua](ReUI/UI/Views/Views.lua) · [disasm](ReUI/UI/Views/Views.disasm) | 1.2.0 | `Main` | byte-for-byte match |
| [UI/Widget/Widget.lua](ReUI/UI/Widget/Widget.lua) · [disasm](ReUI/UI/Widget/Widget.disasm) | 1.0.0 | `Main`, `__init`, `InitLayout`, `get`, `set` | byte-for-byte match |
| [Units/Enhancements/Enhancements.lua](ReUI/Units/Enhancements/Enhancements.lua) · [disasm](ReUI/Units/Enhancements/Enhancements.disasm) | 1.2.1 | `Main`, `HasOrderedUpgrades`, `GetBluePrintEnhancements`, `GetAllInstalledEnhancements`, `IsPrerequisite`, `IsInstalled`, `IsQueued`, `HasPrerequisite`, `IsOccupiedSlotFor`, `OrderUnitEnhancement` | byte-for-byte match |
| [Units/Modules/Overlay.lua](ReUI/Units/Modules/Overlay.lua) · [disasm](ReUI/Units/Modules/Overlay.disasm) | — | `__init`, `InitLayout`, `GetUnitPosition`, `Update`, `OnDestroy` | byte-for-byte match |
| [Units/Units.lua](ReUI/Units/Units.lua) · [disasm](ReUI/Units/Units.disasm) | 1.1.0 | `Main`, `HiddenSelect`, `ApplyToSelectedUnits`, `ProcessAllUnits`, `UpdateAllUnits`, `OnArmyChanged`, `UpdateUnits`, `Update`, `Get` | byte-for-byte match |
| [WorldView/Modules/WorldViewComponent.lua](ReUI/WorldView/Modules/WorldViewComponent.lua) · [disasm](ReUI/WorldView/Modules/WorldViewComponent.disasm) | — | `__init`, `Init`, `Enable`, `Disable`, `OnInit`, `OnEnabled`, `OnDisabled`, `OnHandleEvent`, `OnFrame`, `OnUpdateCursor` | byte-for-byte match |
| [WorldView/Options.lua](ReUI/WorldView/Options.lua) · [disasm](ReUI/WorldView/Options.disasm) | — | `Main` | byte-for-byte match |
| [WorldView/WorldView.lua](ReUI/WorldView/WorldView.lua) · [disasm](ReUI/WorldView/WorldView.disasm) | 1.0.0 | `Main`, `__post_init`, `HandleEvent`, `OnFrame`, `OnUpdateCursor`, `OnDestroy`, `GetCamera` | byte-for-byte match |

## ReUI.ActionsPanel

| File and instructions | Version in file | Function names (up to 10) | Check |
|---|---|---|---|
| [Main.lua](ReUI.ActionsPanel/Main.lua) · [disasm](ReUI.ActionsPanel/Main.disasm) | — | `Main`, `AddExtension`, `SetLayout`, `OnSelectionChanged` | byte-for-byte match |
| [Modules/ActionsGrid.lua](ReUI.ActionsPanel/Modules/ActionsGrid.lua) · [disasm](ReUI.ActionsPanel/Modules/ActionsGrid.disasm) | — | `__init`, `UpdatePanel`, `OnDestroy`, `get`, `InitLayout`, `LoadExtensions`, `self._sorter`, `ReloadExtensions`, `GetActions`, `OnSelectionChanged` | byte-for-byte match |
| [Modules/Selector.lua](ReUI.ActionsPanel/Modules/Selector.lua) · [disasm](ReUI.ActionsPanel/Modules/Selector.disasm) | — | `__init`, `self._bg.OnCheck`, `__post_init`, `InitLayout`, `Render`, `self._quitButton.OnClick`, `self._cover.OnClose`, `SetData`, `OnSelect`, `GetData` | byte-for-byte match |
| [Options.lua](ReUI.ActionsPanel/Options.lua) · [disasm](ReUI.ActionsPanel/Options.disasm) | — | `Main`, `selector:OnSelect`, `selector:OnClose` | byte-for-byte match |

## ReUI.Construction.Templates

| File and instructions | Version in file | Function names (up to 10) | Check |
|---|---|---|---|
| [BuildTemplatePreview.lua](ReUI.Construction.Templates/BuildTemplatePreview.lua) · [disasm](ReUI.Construction.Templates/BuildTemplatePreview.disasm) | — | `GetBackgroundImage`, `GetUnitImage`, `GetUnitSkirtSizes`, `GetSkirtCentreOffset`, `__init`, `InitLayout` | byte-for-byte match |
| [FactoryTemplatePreview.lua](ReUI.Construction.Templates/FactoryTemplatePreview.lua) · [disasm](ReUI.Construction.Templates/FactoryTemplatePreview.disasm) | — | `__init`, `InitLayout`, `Set`, `PositionItem`, `DisplayTemplate` | byte-for-byte match |
| [Options.lua](ReUI.Construction.Templates/Options.lua) · [disasm](ReUI.Construction.Templates/Options.disasm) | — | `Main` | byte-for-byte match |
| [Templates.lua](ReUI.Construction.Templates/Templates.lua) · [disasm](ReUI.Construction.Templates/Templates.disasm) | — | `Main`, `ConvertToBuildable`, `ConvertBuildTemplate`, `CanBuildTemplate`, `GetAvailableFactoryTemplates`, `IssueFactoryTemplate`, `Create`, `Enable`, `Disable`, `Destroy` | byte-for-byte match |

## ReUI.Economy

| File and instructions | Version in file | Function names (up to 10) | Check |
|---|---|---|---|
| [Main.lua](ReUI.Economy/Main.lua) · [disasm](ReUI.Economy/Main.disasm) | — | `Main` | byte-for-byte match |
| [Modules/Panel.lua](ReUI.Economy/Modules/Panel.lua) · [disasm](ReUI.Economy/Modules/Panel.disasm) | — | `FormatNumber`, `__init`, `SetBGMode`, `StartBlink`, `StartFade`, `SetBGState`, `FlipFlop`, `UpdateWarning`, `Update`, `ResetState` | byte-for-byte match |
| [Modules/StatusBar.lua](ReUI.Economy/Modules/StatusBar.lua) · [disasm](ReUI.Economy/Modules/StatusBar.disasm) | — | `__init`, `get`, `set`, `InitLayout` | byte-for-byte match |
| [Options.lua](ReUI.Economy/Options.lua) · [disasm](ReUI.Economy/Options.disasm) | — | `Main` | byte-for-byte match |

## ReUI.Score

| File and instructions | Version in file | Function names (up to 10) | Check |
|---|---|---|---|
| [Main.lua](ReUI.Score/Main.lua) · [disasm](ReUI.Score/Main.disasm) | — | `Main`, `options.scoreboardScale.OnChange`, `options.teamColorAsBG.OnChange`, `scoreboard:OnDestroy`, `__init`, `OnFrame`, `WorldView:__init`, `WorldView:DisplayTempMarker`, `WorldView:DisplayPing` | byte-for-byte match |
| [Modules/Animations.lua](ReUI.Score/Modules/Animations.lua) · [disasm](ReUI.Score/Modules/Animations.disasm) | — |  | byte-for-byte match |
| [Modules/ArmyView.lua](ReUI.Score/Modules/ArmyView.lua) · [disasm](ReUI.Score/Modules/ArmyView.disasm) | — | `__init`, `self._color.OnDirty`, `_SetModeTexture`, `get`, `set`, `InitLayout`, `SetStaticData`, `ResetFont`, `Update`, `MarkOutOfGame` | byte-for-byte match |
| [Modules/ArmyViewsContainer.lua](ReUI.Score/Modules/ArmyViewsContainer.lua) · [disasm](ReUI.Score/Modules/ArmyViewsContainer.disasm) | — | `scoreFunction`, `MakeScoreSorter`, `Ascending`, `Descending`, `Team`, `__init`, `InitLayout`, `_InitArmyViews`, `Update`, `Sort` | byte-for-byte match |
| [Modules/DataPanelConfig.lua](ReUI.Score/Modules/DataPanelConfig.lua) · [disasm](ReUI.Score/Modules/DataPanelConfig.disasm) | — | `RGBA`, `GetData` | byte-for-byte match |
| [Modules/InfoPanel.lua](ReUI.Score/Modules/InfoPanel.lua) · [disasm](ReUI.Score/Modules/InfoPanel.disasm) | — | `GetSizeInKM`, `FormatMapName`, `__init`, `InitLayout`, `Setup` | byte-for-byte match |
| [Modules/Layouts/GameGlowBorder.lua](ReUI.Score/Modules/Layouts/GameGlowBorder.lua) · [disasm](ReUI.Score/Modules/Layouts/GameGlowBorder.disasm) | — | `Clear`, `InitialAnimation`, `Layout`, `scoreboard._arrow.OnCheck` | byte-for-byte match |
| [Modules/Layouts/GameWindowFrame.lua](ReUI.Score/Modules/Layouts/GameWindowFrame.lua) · [disasm](ReUI.Score/Modules/Layouts/GameWindowFrame.disasm) | — | `Clear`, `InitialAnimation`, `Layout`, `scoreboard._arrow.OnCheck` | byte-for-byte match |
| [Modules/Layouts/ReplayGlowBorder.lua](ReUI.Score/Modules/Layouts/ReplayGlowBorder.lua) · [disasm](ReUI.Score/Modules/Layouts/ReplayGlowBorder.disasm) | — | `Clear`, `InitialAnimation`, `Layout`, `scoreboard._arrow.OnCheck` | byte-for-byte match |
| [Modules/Layouts/ReplayWindowFrame.lua](ReUI.Score/Modules/Layouts/ReplayWindowFrame.lua) · [disasm](ReUI.Score/Modules/Layouts/ReplayWindowFrame.disasm) | — | `Clear`, `InitialAnimation`, `Layout`, `scoreboard._arrow.OnCheck` | byte-for-byte match |
| [Modules/ObserverPanel.lua](ReUI.Score/Modules/ObserverPanel.lua) · [disasm](ReUI.Score/Modules/ObserverPanel.disasm) | — | `__init`, `self._slider.OnValueSet`, `self._slider.OnValueChanged`, `InitLayout`, `SetGameSpeed`, `HandleEvent` | byte-for-byte match |
| [Modules/ReplayDataPanel.lua](ReUI.Score/Modules/ReplayDataPanel.lua) · [disasm](ReUI.Score/Modules/ReplayDataPanel.disasm) | — | `HandleEvent`, `__init`, `AddControls`, `CheckBoxOnClick`, `SetDirection`, `SetActiveControl`, `InitLayout`, `_SetupCheckBoxes`, `UpdateDataSetup`, `ResetDirection` | byte-for-byte match |
| [Modules/ResourceDisplay.lua](ReUI.Score/Modules/ResourceDisplay.lua) · [disasm](ReUI.Score/Modules/ResourceDisplay.disasm) | — | `Update`, `GetResourceStrings`, `Apply`, `__init` | byte-for-byte match |
| [Modules/ScoreBoard.lua](ReUI.Score/Modules/ScoreBoard.lua) · [disasm](ReUI.Score/Modules/ScoreBoard.disasm) | — | `__init`, `get`, `ResetWidthComponents`, `SetDisplay`, `InitLayout`, `_InitArmyViews`, `ResetArmyData`, `GetArmyViews`, `GetTitlePanel`, `Update` | byte-for-byte match |
| [Modules/ShareManager.lua](ReUI.Score/Modules/ShareManager.lua) · [disasm](ReUI.Score/Modules/ShareManager.disasm) | — | `SendMessage`, `GiveResourcesToPlayer`, `GiveMassToPlayer`, `GiveEnergyToPlayer`, `GiveUnitsToPlayer`, `RequestResourceFromPlayer`, `RequestMassFromPlayer`, `RequestEnergyFromPlayer`, `RequestUnitFromPlayer`, `GiveAllMassToPlayer` | byte-for-byte match |
| [Modules/TeamViewsContainer.lua](ReUI.Score/Modules/TeamViewsContainer.lua) · [disasm](ReUI.Score/Modules/TeamViewsContainer.disasm) | — | `_InitArmyViews`, `SetStaticData`, `Update` | byte-for-byte match |
| [Modules/TitlePanel.lua](ReUI.Score/Modules/TitlePanel.lua) · [disasm](ReUI.Score/Modules/TitlePanel.disasm) | — | `Split`, `__init`, `Set`, `Format`, `ToSeconds`, `HasPassed`, `ParseString`, `self._time.HandleEvent`, `InitLayout`, `SetQuality` | byte-for-byte match |
| [Modules/Utils.lua](ReUI.Score/Modules/Utils.lua) · [disasm](ReUI.Score/Modules/Utils.disasm) | — | `GetFactionIcon`, `GetWhiteFactionIcon`, `ShortAIName`, `GetArmiesFormattedTable`, `FormatNumber`, `FormatRatioNumber`, `TextWidth` | byte-for-byte match |
| [Modules/Views/Border.lua](ReUI.Score/Modules/Views/Border.lua) · [disasm](ReUI.Score/Modules/Views/Border.disasm) | — | `__init`, `self._color.OnDirty`, `SetColor`, `GetColor`, `SetAlpha`, `OnDestroy` | byte-for-byte match |
| [Modules/Views/BorderedButton.lua](ReUI.Score/Modules/Views/BorderedButton.lua) · [disasm](ReUI.Score/Modules/Views/BorderedButton.disasm) | — | `__init`, `SetNewColors`, `ApplyColors`, `OnDisable`, `OnEnable`, `HandleEvent`, `dragger.OnRelease`, `dragger.OnCancel`, `OnRolloverEvent`, `OnClick` | byte-for-byte match |
| [Modules/Views/BorderedCheckBox.lua](ReUI.Score/Modules/Views/BorderedCheckBox.lua) · [disasm](ReUI.Score/Modules/Views/BorderedCheckBox.disasm) | — | `__init`, `SetNewColors`, `SetCheck`, `ToggleCheck`, `IsChecked`, `OnDisable`, `OnEnable`, `HandleEvent`, `OnStateChange`, `OnCheck` | byte-for-byte match |
| [Modules/Views/BorderedText.lua](ReUI.Score/Modules/Views/BorderedText.lua) · [disasm](ReUI.Score/Modules/Views/BorderedText.disasm) | — | `__init`, `SetText`, `GetText`, `SetFont`, `SetTextColor`, `SetColor`, `SetAlpha` | byte-for-byte match |
| [Modules/Views/ColoredSlider.lua](ReUI.Score/Modules/Views/ColoredSlider.lua) · [disasm](ReUI.Score/Modules/Views/ColoredSlider.disasm) | — | `__init`, `self._thumb.HandleEvent`, `dragger.OnMove`, `dragger.OnRelease`, `HandleEvent`, `__post_init`, `SetValue`, `GetValue`, `SetStartValue`, `SetEndValue` | byte-for-byte match |
| [Modules/Views/ExpandableGroup.lua](ReUI.Score/Modules/Views/ExpandableGroup.lua) · [disasm](ReUI.Score/Modules/Views/ExpandableGroup.disasm) | — | `__init`, `__post_init`, `AddControls`, `ClearControls`, `Expand`, `Contract`, `OnExpandControl`, `OnContractControl` | byte-for-byte match |
| [Modules/Views/ExpandableSelectionGroup.lua](ReUI.Score/Modules/Views/ExpandableSelectionGroup.lua) · [disasm](ReUI.Score/Modules/Views/ExpandableSelectionGroup.disasm) | — | `AddControls`, `ControlEvent`, `Expand`, `SetActiveControl` | byte-for-byte match |
| [Modules/Views/PingAnimation.lua](ReUI.Score/Modules/Views/PingAnimation.lua) · [disasm](ReUI.Score/Modules/Views/PingAnimation.disasm) | — | `__init`, `InitLayout`, `_InitLayers`, `_LayoutLayers`, `HandleEvent`, `Animate`, `Fade` | byte-for-byte match |
| [Options.lua](ReUI.Score/Options.lua) · [disasm](ReUI.Score/Options.disasm) | — | `Main` | byte-for-byte match |
