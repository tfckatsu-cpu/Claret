# ClaretHotbuild rules

- Working modules Model/Catalog/Adapter/Keys/Runtime/Editor live in the separate ClaretHotbuild mod. Profile: ClaretHotbuild.
- При смешанном выделении назначенные «Войска» имеют приоритет над «Строителями» и строительным хотбилдом; если строка войск пуста, используется «Остальные». ID действий постоянны; чужие и стандартные назначения не перезаписываются без запроса.
- TemplateCatalog reads the game's `build_templates`. Do not modify the source; do not execute invalid data.
- Template ID `claret_template_<hash>` depends on composition, order and geometry, not on name or index. A changed or deleted source makes the old bind unavailable; never silently substitute another template.
- Cross-faction conversion goes through TemplateCatalog/Equivalents, only on a complete unambiguous match, without guessing prefixes. Preserve geometry, sizes, orientation and order.
- Do not auto-extend old binds: the user re-selects the template and saves.
- Catalog refresh happens on open, selection or bind press — no background polling.
- Adapter passes a copy of the geometry to `SetActiveBuildTemplate`; the selected engineer must build the whole composition. Factories and replays do not execute templates.
- In selection lists, templates come first, then the usual sort by tech level, category, name.
- The list and the bind cell must show the text «ШАБЛОН» and the burgundy accent from Theme.

- Решение пользователя от 2026-11-13: пара слотов хранится для каждой клавиши отдельно; совместимость проверяется при назначении с сохранением остальных слотов. Старые связи `grid.context` переносятся для каждой назначенной клавиши; старое поле остаётся только в данных как историческое. Назначение и снятие клавиш выполняются только на вкладке «Клавиатура»; редакторы пресета и составного бинда показывают использование клавиш только для чтения.

- Удалённые из каталога пары действия и контекста не предлагаются для новых назначений; сохранённые строки и их быстрый повтор или «если пусто» сохраняют прежние ID и выполнение. Нативное улучшение FAF с паузой работает по структуре под курсором.

- Сборка 20261113-30: кнопки абсолютного режима, быстрого повтора, Fallback и списка устаревших строк убраны из редактора составного бинда; сохранённые данные и их выполнение оставлены. Для совместимых отдельных действий двойное нажатие задаётся по сочетанию на вкладке «Клавиатура» и не смешивает типы юнитов. При паре отдельного действия и строительного пресета подходящий строитель получает приоритет, если способен выполнить запись пресета; иначе выполняется действие. Игровая проверка ожидается.

- Решение от 2026-11-14: контекст «Под курсором» проверяется первым по собственной доступной для улучшения структуре; цепочки резервируют результирующие контексты в обе стороны. Непригодные курсор или структура передают управление обычному контексту. Удалённые действия сохраняются в старых назначениях с пометкой «устарело» и не предлагаются вновь. Запуск ракет выбирает тип по доступному приказу, неоднородное выделение не запускается. Удаление набора подтверждается и снимает его с клавиш без удаления других слотов.

- 2026-11-14: По решению пользователя ПКМ по клавише снимает любые видимые назначения Claret, FAF и других модов для показанного сочетания; сохранённые наборы, определения действий и другие сочетания не удаляются.
- 2026-11-14: В исходной раскладке каждый заказовый тайл домена/фракции разделён на три иконные секции слева направо: T1/T2/T3; отображаются все сразу без подписей юнитов. Выбор уровня сверяется с `GetCurrentTechTab()` FAF3840. Старые одиночные слоты распределяются по уровню blueprint, T4/нераспознанные данные сохраняются.
- Решение пользователя от 2026-11-15: подписи LAND/AIR/NAVAL центрируются над сеткой заказов; в каждой секции виден уровень T1/T2/T3. Автодобавление аналогов меняет выбранную ячейку и заполняет только пустые ячейки других фракций. Цепочки `Percival–Harbinger–Brick–Othuum` и `Mongoose–Hoplite` учитываются вместе; `xsl0205` Iashavoh включён в аналоги T2 Flak.

- Локализация Hotbuild (проверка пользователя в FAF 2026-11-15, сборка `20261115-48`): для английских имён зданий и юнитов передавать в `Catalog:DisplayName` полный blueprint, а не таблицу категорий; `LOC` зависит от языка игры, поэтому при EN Claret используются английские fallback-поля blueprint. Проверять отдельно при русской локали игры. Источник: `../mods/ClaretHotbuild/modules/Catalog.lua`, `Tests/hotbuild-catalog.lua`.
- Для подписей действий обращаться к локализатору через `ReUI.ClaretCore.Localization`, как в существующих модулях; не полагаться на `rawget(_G, 'ReUI')`. После перехода на прямой доступ пользователь подтвердил исправление ключей в списке приказов; сам механизм отказа `rawget` в этом сценарии отдельно не измерялся. Проверять доступные приказы в FAF и локальные тесты с ReUI в окружении модуля. Источники: `KeyboardBindings.lua`, `KeyboardEditor.lua`, `ContextActions.lua`, `Tests/hotbuild-context-labels.lua`.
