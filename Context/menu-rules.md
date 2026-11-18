# Claret menu, settings and keybind rules

- Read `Context/ui-style.md` first. Reference image: `Context/claret-ui-reference.png`.
- All settings live in **F10 → Claret**, registered via `RegisterSettingsSection`; no `Builder.AddOptions` tabs. Implementation: Core `modules/Menu.lua`; example: Hotbuild `Main.lua`; contract: Core README.
- The menu is a launcher panel plus a separate settings panel; geometry and scale are in `Context/ui-style.md` and `Theme.Metrics`. The Hotbuild keyboard page alone may reduce its panel height to fit its contents and expand it for NumPad or its assignment dialog; other pages use the standard height.
- Do not dim the map or intercept mouse input outside the menu panels. Close the menu via a button or Escape, with draft protection.
- Окно приветствия появляется при запуске игры, пока пользователь не включит «Больше не показывать»; галочку можно включить или снять до закрытия окна. Выбор сохраняется через параметр ReUI в Core; вернуть окно также можно настройкой «Скрывать приветствие при запуске» в F10 → Claret. Окно не получает клавиатурный фокус и не затемняет карту; прозрачная внешняя область закрывает его на `ButtonPress` и передаёт событие родителю. Escape использует стек FAF-обработчиков. Блок настройки Nunito показывается всегда, даже если оба файла уже установлены. Очистку Game.prefs описывать только как рекомендацию и объяснять, какие настройки она сбросит.
- Hotbuild is always active, with no feature toggle. It is embedded into a menu section via `inline(parent, layout)`; use the passed `layout.scale`.
- `CanLeave(intent)` lets an editor ask for confirmation when closing or switching sections with an unsaved draft.
- Настройки шестерёнки Hotbuild открываются в правой панели рядом с меню, с обычной анимацией открытия; выбор раздела заменяет настройки и наоборот, с защитой несохранённого черновика.
- Separate windows connect through actions; respect `RequestClose()`/`OnDestroy` and focus return.
- Simple settings are saved immediately via the existing OptionValue and profile; there is no "Apply" button.
- Launcher and section panels never capture keyboard focus: game hotkeys remain available. They do not handle Tab/Shift+Tab or Enter/Space navigation. FAF’s Escape stack closes the menu, with nested dialogs and active key capture handled first.
- A key-assignment capture temporarily takes keyboard focus and releases it on save, cancellation or teardown. Text fields take focus only while focused. The Hotbuild keyboard reads physical Ctrl, Shift and Alt while the page is visible, including when the pointer is over the map, without keyboard focus or consuming game input; on-screen modifier controls remain available.
- Menu bind: stable ID `ClaretCore_OpenMenu`, category Claret; default Ctrl-Alt-C is assigned once, only if free.
- The only source of the assignment is the standard UserKeyMap/UserDebugKeyMap; change or remove it via the menu, with no second OptionValue.
- Keyboard capture is temporary; reject conflicts with other binds; never reset the global key map.

- Решение пользователя от 2026-11-13: назначение Hotbuild-клавиш должно находиться только на вкладке клавиатуры, с отдельными слотами «Стройка» и «Действия»; редакторы содержимого показывают использование только для чтения. Старый выбор составного бинда в пресете и его подтверждение удалены; исторические данные сохраняются.
