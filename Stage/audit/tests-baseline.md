# Аудит тестов Claret: истинный базовый уровень и качество проверок

Дата: 2026-11-18. Предикс находок: `TST-`.
Всё ниже получено только чтением кода и запуском готовых команд. Файлы проекта не изменялись
(единственный созданный файл — этот отчёт). Тесты не правились: ни один падающий тест не «позеленён».

## 0. Воспроизведение базовой линии

```
> node Tests/check-core.cjs --quiet
<...>
47 passed, 15 failed: core-smoke.lua, claret-menu.lua, hotbuild-equivalents.lua, hotbuild-templates.lua,
hotbuild-build-key-labels.lua, hotbuild-adapter.lua, hotbuild-keys.lua, hotbuild-runtime.lua,
hotbuild-grid-editor.lua, hotbuild-cycle-menu.lua, hotbuild-keyboard-editor.lua,
hotbuild-context-actions.lua, hotbuild-context-repeat.lua, hotbuild-context-runtime.lua,
hotbuild-context-editor.lua
```

Статическая часть прогона при этом зелёная:

```
PASS: parsed 72 Lua files (Lua 5.1 grammar; FAF runtime still requires game verification)
```

Заявленные 47/15 воспроизводятся точно. Но это **не полная картина** (см. TST-12):
в `Tests/` лежит 66 `.lua` — 62 в списке раннера (все 62 — настоящие тесты), ещё 3 теста в список
не попали, плюс 1 helper (`localization-test-helper.lua`, он и не должен запускаться).

```
UNLISTED Tests/hotbuild-build-key-label-integration.lua ERROR: ...:65: unexpected import: /mods/ClaretHotbuild/modules/LocalizationStrings.lua
UNLISTED Tests/hotbuild-editor.lua ERROR: ...:59: /lua/ui/dialogs/eschandler.lua
UNLISTED Tests/hotbuild-grid-model.lua OK
```

**Истинная база: 65 тестов, 48 проходят, 17 падают.** Объём `Tests/` — 11 965 строк в 66 файлах.

## 1. Механика стенда (`Tests/check-core.cjs`, 7,7 КБ)

Факты (проверено чтением файла):

1. `process.chdir(path.resolve(__dirname,'..'))` — рабочая директория проекта; тесты грузят модули
   относительными путями `../mods/...`.
2. Статическая фаза (до исполнения тестов): разбор **всех** `.lua` в `../mods/ClaretCore` и
   `../mods/ClaretHotbuild` парсером `luaparse` в режиме `luaVersion:'5.1'`; запрет идентификатора
   `continue` (обходится AST); проверка паритета ключей EN/RU в обоих `LocalizationStrings.lua`
   и всех ссылок вида `'core.*'`/`'hotbuild.*'`; запрет `...` в двух файлах (`ClaretHotbuild/Main.lua`,
   `ClaretCore/modules/ReUICargoIndicator.lua`). Счётчик `count` = 72 файла.
3. Каждый тест исполняется в **своём** состоянии Fengari (`luaL_newstate` + `luaL_openlibs`), между тестами
   изоляция есть; в состояние добавляется только `math.mod = math.fmod`.
4. **Нет** общего слоя `import`, `_G`-заглушек FAF, MAUI-контролов, игровых файлов. Каждый тест сам
   определяет `import` и моки. Отсюда — целый класс падений (см. §2, класс «a»).
5. Модули резолвятся из `../mods/ClaretCore` и `../mods/ClaretHotbuild` (живые оригиналы), а не из
   `ClaretCore/`/`ClaretHotbuild/` в корне проекта и не из зеркал `mods/`.
6. `--quiet`: stdout теста перехватывается и при падении печатаются первые 14 строк `error + output`;
   полный traceback обрезается. `--only <pattern>` — подстрочный `file.includes(pattern)`, не точное имя
   (`--only hotbuild-context` даёт 6 тестов).
7. Нет таймаута на тест: зависание = зависание всего прогона.
8. Падение по `assert` обрывает остаток файла — тест не помечается как «частично пройденный».

## 2. Все 17 падений: классификация и доказательства

Классы: **(a)** пробел стенда/мока, **(b)** устаревшее ожидание, **(c)** подозрение на дефект продакшена.

| # | Файл:строка | Класс | Корневая причина | Доказательство |
|---|---|---|---|---|
| 1 | `core-smoke.lua:137` | a (нет игрового стаба) | Нет заглушки `/lua/ui/game/rangeoverlayparams.lua`; общий fallback в `game.import` делает `loadfile('..'..path)` и умирает | `cannot open ../lua/ui/game/rangeoverlayparams.lua: ENOENT`; импорт реален: `ClaretCore/modules/StrategicRings.lua:3: local RangeOverlayParams = import('/lua/ui/game/rangeoverlayparams.lua').RangeOverlayParams`; файл в игре есть (`lua.nx2` содержит `lua/ui/game/rangeoverlayparams.lua`) |
| 2 | `claret-menu.lua:168` | b (устаревшая геометрия) | Тест ищет панель `Width()==1128` и заголовок `1056x72`. После клика по секции `id='core'` панель сжимается до `corePanelWidth=552`, заголовок — `552-72=480` | Проба (in-memory, файл не менялся): `PROBE groupchild 248 304` / `PROBE groupchild 552 408`, далее то же падение. Код: `Theme.lua:38 Metrics = { ... panelWidth=1128 ... corePanelWidth=552 ...}`; `Menu.lua:446 SetPanelSize(section and section.id=='core' and metrics.corePanelWidth ...)`; `Menu.lua:357 if state.panelDragHeader then L(state.panelDragHeader):Width(state.panelWidth-72) end` — заголовок существует, ширина другая |
| 3 | `hotbuild-equivalents` (`Equivalents.lua:72`) | a (мок каталога) | Мок каталога без `List`; продакшен вызывает `catalog:List()` без фильтров, реальный `Catalog:List` подставляет `{}` | Тест: `local catalog={Get=function(self,id) return records[id] end}`. Код: `Equivalents.lua:72 for _, record in ipairs(catalog:List()) do`; `Catalog.lua:245 function catalog:List(filters)` / `246 filters = filters or {}`. Проба с добавленным `List` → `OK` (весь файл зелёный) |
| 4 | `hotbuild-templates.lua:54` | a (устаревшая фикстура) | Фикстура «инженера» без категории `ENGINEER`, а `CanPlaceBuilds` смотрит только категории | `Adapter.lua:21-24 CanPlaceBuilds(unit) return unit:IsInCategory('COMMAND') or ... 'ENGINEER'`; фикстура: `local function unit(buildable,factory) ... IsInCategory=function(self,category) return factory and category=='FACTORY' end`. Проба с `ENGINEER=true` только для не-фабрик → `OK` |
| 5 | `hotbuild-build-key-labels.lua:35` | **c (дефект продакшена)** | `Colours` — не глобал FAF. В игре — ошибка, проглоченная `pcall` в `Main.lua`, фича молча не работает | `BuildKeyLabels.lua:35 local colour = Colours.plain` (и `:102`, `:112`); в архиве игры 1 619 lua-файлов: `definitions=0 usesOfGlobalColours=0` (регистрозависимый скан). `Main.lua:45-46 local okLabels, claretRelations = pcall(BuildKeyLabels.Build, ...)` / `if not okLabels or ... then return idRelations, ... end` — без лога |
| 6 | `hotbuild-adapter.lua:111` | a (устаревшая фикстура) | Тот же `ENGINEER`-пробел: `local engineer = unit({}, {'ueb1103'}, {...})` | Проба с `ENGINEER=true` → `PASS: Hotbuild adapter exact blueprint/count1, direct selection preservation, subset/external transactions, exception restoration, placement, replay guards, contextual actions` |
| 7 | `hotbuild-keys.lua:41` | b (устаревшая строка действия) | Ожидается точное равенство `...Execute("x")`; продакшен добавляет состояние Shift вторым аргументом | `Keys.lua:72 action = string.format('UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").Execute(%q, IsKeyDown(16))', binding.id)`; тест: `assert(registered[idX].action=='UI_Lua import(".../Runtime.lua").Execute("x")')` |
| 8 | `hotbuild-runtime.lua:147` | b (то же) | Подстрока `Execute("b1")` больше не встречается | `assert(userKeyActions[actionId('b1')].action:find('Execute("b1")',1,true))`; фактическая строка — `Execute("b1", IsKeyDown(16))` |
| 9 | `hotbuild-grid-editor.lua:89` | a (мок каталога) | Мок `List` индексирует `filters` без default; продакшен зовёт `List()` | Тест: `List=function(self,filters) if filters.faction~='ALL' ...`; ошибка `Editor.lua:1100: Tests/hotbuild-grid-editor.lua:89: attempt to index a nil value (local 'filters')`; причина — `catalog:List()` без аргументов |
| 10 | `hotbuild-cycle-menu.lua:68` | a (мок каталога) | То же, что №9 | `attempt to index a nil value (local 'filters')` ровно в моке `List` |
| 11 | `hotbuild-keyboard-editor.lua:65` | a (нет MAUI-стаба) | Нет `/lua/maui/edit.lua` в карте импортов, а редактор импортирует `Edit` при создании | `KeyboardEditor.lua:136 local Edit=import('/lua/maui/edit.lua').Edit`; ошибка теста: `Tests/hotbuild-keyboard-editor.lua:65: /lua/maui/edit.lua` (это `assert(modules[path],path)` в его `import`) |
| 12 | `hotbuild-context-actions.lua:306` | b (неверное ожидание) | `select_transport_nearest` — `selectionPolicy='accumulate'` по замыслу и идёт через `SelectNextUnit`; тест требует `exclusive` | `ContextActions.lua:54 {id='select_transport_nearest', ..., selectionPolicy='accumulate'}`; `:664-666 if (action.id=='select_transport' or action.id=='select_transport_nearest' ...) and not context.isRepeat then return SelectNextUnit('AIR TRANSPORTATION',true,true) end`. Тест: `for _,id in ipairs({... 'select_transport_nearest' ...}) do ... assert(item.selectionPolicy=='exclusive', ...)` |
| 13 | `hotbuild-context-repeat.lua:22` | **c (поведение продакшена, низкая тяжесть)** | После успешного `Continue` цепочка `double` взводится заново → третье нажатие снова даёт double | `ContextRepeat.lua:99 if result then self:Remember(bindingId,state.action,context) end` (в `Continue` после `pending=nil`); тест: `assert(not state:Continue('key1',context),'double is consumed')`. В игре обычно спасает смена выделения; спека этого не требует (`Context/hotbuild-context-spec.md:178`: «Chain breaks on selection change, window expiry, or another Claret key») |
| 14 | `hotbuild-context-runtime.lua:360` | b (устаревшая строка действия) | Ожидается `ExecuteKeyboardPair("A")`, фактически есть `, IsKeyDown(16)` | `KeyboardBindings.lua:154 string.format('...ExecuteKeyboardPair(%q, IsKeyDown(16))', ref.id)`; тест: `engineKeyMap.A.action:find('ExecuteKeyboardPair("A")',1,true)` |
| 15 | `hotbuild-context-editor.lua:154` | a (неполный MAUI-мок) | У мока `Bitmap` нет `SetTexture` | Тест: `['/lua/maui/bitmap.lua']={Bitmap=control}`; код: `ContextEditor.lua:154 mark:SetTexture('/mods/ClaretHotbuild/textures/search-icon.dds')` |
| 16 | *(вне списка)* `hotbuild-build-key-label-integration.lua:65` | a (устаревший стаб) | `import` не знает `LocalizationStrings` (появился `T()`), ошибка «unexpected import» | Вывод пробы: `ERROR: ...:65: unexpected import: /mods/ClaretHotbuild/modules/LocalizationStrings.lua` |
| 17 | *(вне списка)* `hotbuild-editor.lua:59` | a (устаревший стаб) | Нет `/lua/ui/dialogs/eschandler.lua` (редактор теперь пушит escape-обработчик) | Вывод пробы: `ERROR: ...:59: /lua/ui/dialogs/eschandler.lua` |

Итог по классам: **(a) 10, (b) 5, (c) 2**. Внутри (a): 5 — отсутствующие игровые/MAUI-стабы,
5 — устаревшие фикстуры данных (моки каталога, категории юнита).

Отдельно: `hotbuild-grid-model.lua` проходит, но **никогда не запускается** раннером.

## 3. Подтверждённые дефекты

### TST-01
- **Severity**: High
- **Category**: Correctness
- **Location**: `ClaretHotbuild/modules/BuildKeyLabels.lua`, `ReadChord` (стр. 35), `Build` (стр. 102, 112); следствие в `ClaretHotbuild/Main.lua:45-46`
- **Problem**: Подписи хоткеев на строительных кнопках читают несуществующий глобал `Colours.plain`. В игре это ошибка индексации `nil`, которую `pcall` в `Main.lua` глушит без лога: отношения BPID→подпись не применяются, фича отсутствует у всех и молча.
- **Evidence**:
  ```
  BuildKeyLabels.lua:35    local colour = Colours.plain
  BuildKeyLabels.lua:102   colour = Colours.plain,
  Main.lua:45-46           local okLabels, claretRelations = pcall(BuildKeyLabels.Build, service.model, assignments)
                           if not okLabels or type(claretRelations) ~= 'table' then return idRelations, upgradeKey, orderKeys end
  ```
  Скан установленного архива `C:/ProgramData/FAForever/gamedata/lua.nx2` (ZIP, 1 619 `.lua`):
  `definitions=0 usesOfGlobalColours=0` (шаблон `^\s*Colours\s*=` и `Colours\.`, регистрозависимо).
  Игра использует локальную таблицу в `lua/keymap/hotkeylabels.lua`: `local colours = {`.
- **Impact**: фича «подписи клавиш Hotbuild на строительных кнопках» не работает в игре; тест падает по той же причине, что и продакшен (то есть тест прав, а не устарел).
- **Recommendation**: убрать зависимость от глобала: передавать цвет параметром/из `Theme` (или литерал ARGB, как ожидает FAF `HotKeyData.colour`). Дополнительно — не глушить ошибку `Build` полностью: логировать через `WARN` при `probeEnabled`.
- **Risk of the fix**: низкий (локальная правка 3 строк + прогон `--only build-key`); нужно свериться с форматом цвета, который ждёт потребитель `idRelations`.
- **Confidence**: High (факт отсутствия глобала в базовом архиве). Остаётся неизвестным, не определяет ли `Colours` другой установленный мод — на это опираться нельзя.

### TST-02
- **Severity**: Low
- **Category**: Correctness
- **Location**: `ClaretHotbuild/modules/ContextRepeat.lua:99`, `Continue`
- **Problem**: После успешного выполнения цепочка `double` взводится заново, поэтому серия нажатий одной клавиши даёт повторное double-действие вместо нового одиночного.
- **Evidence**: `ContextRepeat.lua:99 if result then self:Remember(bindingId,state.action,context) end`; тест ждёт обратного: `assert(not state:Continue('key1',context),'double is consumed')`.
- **Impact**: узкий сценарий (действие double не меняет выделение, напр. `select_acu_double`). Массово не проявляется, потому что смена выделения рвёт цепочку по `SameSelection`.
- **Recommendation**: либо не взводить заново для `continuation=='double'`, либо зафиксировать в спеке обратное и переписать ожидание теста. Решение — за владельцем фичи.
- **Risk of the fix**: средний (логика повторов горячая; нужен прогон `--only context-repeat` + `--only context-runtime`).
- **Confidence**: High по коду, Medium по «дефект ли это» — спека не формулирует требование.

## 4. Сильно поддержанные архитектурные проблемы

### TST-10
- **Severity**: High
- **Category**: Maintainability
- **Location**: `Tests/check-core.cjs` (весь раннер) + 62 теста
- **Problem**: Нет общего слоя моков FAF/MAUI. Каждый тест заново пишет `import`, контролы, события, prefs. Любой новый игровой импорт ломает все тесты, где его нет, а расхождения моков (см. §6) не видны.
- **Evidence**: в раннере нет ни одного `_G`-стаба, кроме `math.mod`; в тестах 62 независимые реализации `import`; 5 падений (№1, 11, 15, 16, 17) — ровно «нет записи в карте импортов».
- **Impact**: 10 из 17 падений — шум стенда, а не сигнал о коде; цена добавления теста высокая; копипаста 12 тыс. строк.
- **Recommendation**: один `Tests/support/faf-env.lua`, который даёт `import` с явным реестром игровых файлов (каждый файл — осознанная заглушка, не «loadfile с диска»), MAUI-контролы (Group/Bitmap/Edit/Button/Text/Scrollbar/Dragger) и события. Тесты оставить с явным переопределением того, что проверяют.
- **Risk of the fix**: средний (массовая правка тестов; делать волнами, по семействам).
- **Confidence**: High.

### TST-11
- **Severity**: High
- **Category**: Testing
- **Location**: `Tests/check-core.cjs:12` (`const root = '../mods/ClaretCore'`), все `loadfile('../mods/...')`
- **Problem**: Тесты проверяют живые копии в папке игры, а не код в репозитории/зеркалах. Зелёный прогон не доказывает, что проверен именно аудируемый исходник; вне установленного FAF прогон вообще невозможен.
- **Evidence**: `const root = '../mods/ClaretCore';` + `check('../mods/ClaretHotbuild');`; тесты грузят `'../mods/ClaretCore/modules/Menu.lua'` и т.п. Папки `ClaretCore/`, `ClaretHotbuild/` в корне проекта тестами не используются; зеркала `mods/` — тоже.
- **Impact**: базлайн «47/15» описывает состояние папки игры на 2026-11-18, а не репозиторий; при рассинхроне результаты вводят в заблуждение.
- **Recommendation**: резолвить корень через переменную (`CLARET_MOD_ROOT`) с приоритетом репозиторных папок; в отчёте прогона печатать фактический путь и SHA-256 хотя бы `Main.lua` обоих модов.
- **Risk of the fix**: низкий (1 файл раннера), но потребует убедиться, что репозиторные копии полные.
- **Confidence**: High.

### TST-12
- **Severity**: High
- **Category**: Testing
- **Location**: `Tests/check-core.cjs`, массив `for (const file of [...])`
- **Problem**: Список тестов поддерживается вручную и рассинхронизирован с диском: 3 настоящих теста не запускаются, 2 из них падают. Итоговая строка «N passed, M failed» создаёт ложное впечатление полноты.
- **Evidence**: `listed=62 onDisk=66`; не запускаются `hotbuild-build-key-label-integration.lua`, `hotbuild-editor.lua`, `hotbuild-grid-model.lua` (+ helper). Прогон вне списка: `ERROR ... LocalizationStrings.lua`, `ERROR ... eschandler.lua`, `OK` для grid-model.
- **Impact**: скрыты 2 падения и 1 прохождение; изменения в этих областях (интеграция подписей клавиш, редактор, grid-модель) не защищены.
- **Recommendation**: auto-discovery `Tests/*.lua` с явным списком исключений (только helper) + падение, если файл на диске не попал в прогон.
- **Risk of the fix**: низкий, но сразу вскроет 2 красных теста — это и есть цель.
- **Confidence**: High.

### TST-13
- **Severity**: Medium
- **Category**: Testing
- **Location**: все падающие тесты (assert-скрипты без изоляции шагов)
- **Problem**: Первый же неудачный `assert` обрывает файл, поэтому «15 failed» скрывает, что большая часть проверок в этих файлах вообще не выполняется.
- **Evidence**: суммарно в 17 падающих файлах 5 793 строки, из них ~3 840 (66%) не исполняются. Примеры: `claret-menu.lua` умирает на 168 из 463 (64% ниже), `hotbuild-keyboard-editor.lua` — 65 из 405 (84%), `hotbuild-context-editor.lua` — 154 из 1 179 (87%), `hotbuild-context-runtime.lua` — 360 из 1 140 (68%).
- **Impact**: нельзя отличить «тест прошёл» от «тест не дошёл»; регрессии в хвосте файлов не видны; в `claret-menu.lua` после строки 168 не исполняется вся секция регистрации Hotbuild (`loadfile('../mods/ClaretHotbuild/Main.lua')` на 416).
- **Recommendation**: разбить длинные тесты на именованные шаги (`local function step(name, fn) ... end`) с накоплением ошибок и итоговым отчётом; или хотя бы на несколько файлов.
- **Risk of the fix**: низкий, механический.
- **Confidence**: High (числа получены из файлов; «не исполняется» верно для одного прогона).

### TST-14
- **Severity**: Medium
- **Category**: Testing
- **Location**: 28 тестов `core-construction-*` (19), `core-multifunction-*` (3), `core-orders-*` (6)
- **Problem**: 28 из 47 зелёных тестов проверяют модули без продакшен-точки входа. Зелёный результат не говорит ничего о том, что игрок увидит.
- **Evidence**: `rg "ConstructionPanel|ConstructionFacade|OrdersPanel|Multifunction|ConstructionController|ConstructionItems" ClaretCore/Main.lua ClaretCore/Options.lua ClaretCore/modules/Menu.lua` → нет совпадений (exit=1); импорты этих семейств есть только внутри самих семейств (`ConstructionEngineAdapters.lua:158-163`, `ConstructionPanel.lua:35-38`).
- **Impact**: 60% зелёной массы — «мёртвый» код; поддержка тестов стоит времени, регрессии реального UI не ловятся.
- **Recommendation**: либо подключить семейства в продакшен, либо пометить тесты как `experimental` и вынести из обязательного прогона, чтобы цифра базлайна отражала реальность.
- **Risk of the fix**: низкий для тестов; подключение модулей — отдельное архитектурное решение.
- **Confidence**: High.

### TST-15
- **Severity**: Medium
- **Category**: Compatibility
- **Location**: `Tests/check-core.cjs`, статическая фаза
- **Problem**: Диалектные ограничения FAF проверяются частично: запрещён только `continue` и `...` в двух файлах, а разбор идёт грамматикой Lua 5.1, поэтому оператор `#` (которого нет в диалекте проекта) считается валидным. Правило «`table.getn` вместо `#`» ничем не защищено.
- **Evidence**: `parser.parse(..., { luaVersion: '5.1' })`; в продакшене `#` не используется ни разу (`rg "[^#]#[A-Za-z_(]" ClaretCore ClaretHotbuild` → 0), а в тестах — в 65 файлах. Проверки «Core не импортирует Hotbuild» в раннере нет вообще.
- **Impact**: регресс диалекта (`#`, `goto`, `//`) пройдёт зелёным и упадёт только в игре; нарушение архитектурного правила тоже не ловится.
- **Recommendation**: добавить в статическую фазу: запрет `#` в продакшен-файлах (AST `UnaryExpression` с `op='#'`), запрет `goto`/`//`, и проверку, что ни один файл `ClaretCore/**` не импортирует `ClaretHotbuild`.
- **Risk of the fix**: низкий (только раннер).
- **Confidence**: High.

## 5. Риски, требующие проверки в игре

### TST-20
- **Severity**: Medium
- **Category**: Compatibility
- **Location**: `ClaretHotbuild/modules/Keys.lua:72`, `KeyboardBindings.lua:154-155`, `Runtime.lua:617-634` (`ExecuteFactoryShift`), `KeyboardBindings.lua:902`
- **Problem**: Состояние Shift передаётся в игровые action-строки как `IsKeyDown(16)`, а перехват Shift+строительная клавиша при выбранной фабрике (`ExecuteFactoryShift`) не покрыт ни одним тестом. Работоспособность `IsKeyDown(16)` внутри строки `UI_Lua ...` в игре не подтверждена.
- **Evidence**: `rg "IsKeyDown\(16\)" Tests` → 0 файлов; `rg "ExecuteFactoryShift" Tests` → 0; в продакшене: `Keys.lua:72 ... .Execute(%q, IsKeyDown(16))`, `Runtime.lua:617 function service:ExecuteFactoryShift(chord,nativeAction)`, `Runtime.lua:626 LOG('[Claret][keys] factory_shift_intercept chord='..chord..' active=true')`.
- **Impact**: если строку с `IsKeyDown` FAF не выполнит, все назначенные клавиши Hotbuild перестанут срабатывать (это не «мелочь» — это весь мод). Проверить это можно только в игре.
- **Recommendation**: один сценарий в игре: назначить пресет, нажать клавишу, затем Shift+клавишу при выбранной фабрике; зафиксировать версию, лог `[Claret][keys]` и результат.
- **Risk of the fix**: n/a (проверка).
- **Confidence**: Medium (код читается корректно, поведение движка неизвестно).

### TST-21
- **Severity**: Low
- **Category**: Testing
- **Location**: `Tests/claret-menu.lua:88-93`
- **Problem**: Локальный `pcall` возвращает только `ok`/`err` и теряет возвращаемые значения, поэтому код вида `local ok, v = pcall(f)` в тесте видит `v=nil`, а в игре — реальное значение. Расхождение может как маскировать, так и фабриковать дефект.
- **Evidence** (`Tests/claret-menu.lua:84`): `pcall=function(fn) local ok,err=pcall(fn); if not ok then return false,err end; return true end`.
- **Impact**: неизвестен (в `Menu.lua` таких мест я не нашёл); риск для будущих правок.
- **Recommendation**: `return pcall(fn)` или `table.pack`-совместимый форвардинг.
- **Risk of the fix**: низкий.
- **Confidence**: Medium.

### TST-22
- **Severity**: Low
- **Category**: Testing
- **Location**: `Tests/hotbuild-adapter.lua:14-25`, `Tests/hotbuild-templates.lua:43-45`
- **Problem**: Контракт движка замокан по предположению: третий возврат `GetUnitCommandData` трактуется как «buildableCategories», а `EntityCategoryGetUnitList` — как identity-функция.
- **Evidence**: мок `module.GetUnitCommandData = function(units) ... return orders, {}, buildable end`, `module.EntityCategoryGetUnitList = function(category) return category end`. В игре третий возврат действительно `buildableCategories`: `lua/ui/game/construction.lua:1306 local _, _, buildableCategories = GetUnitCommandData(unitSel)`; `lua/keymap/hotbuild.lua:399 local availableOrders, availableToggles, buildableCategories = GetUnitCommandData(selection)`.
- **Impact**: сигнатура мока совпадает с игрой (это плюс), но identity-подмена `EntityCategoryGetUnitList` не проверяет реальное поведение (фильтрация по категориям), поэтому ошибки в строке категории не ловятся.
- **Recommendation**: для одного-двух реальных чертежей зафиксировать в тесте ожидаемую строку категории (например, `'ENGINEER TECH1'`) вместо identity.
- **Risk of the fix**: низкий.
- **Confidence**: Medium.

### TST-23
- **Severity**: Medium
- **Category**: Testing
- **Location**: все тесты, использующие `setmetatable({}, {__index=_G})`
- **Problem**: Строгие глобалы FAF не эмулируются: неизвестный глобал даёт `nil` в точке использования, а случайная запись в глобал не детектируется вовсе.
- **Evidence**: `local env=setmetatable({}, {__index=_G})` (core-smoke, adapter, editor и др.); в раннере нет ни одного механизма запрета глобалов.
- **Impact**: опечатки в именах глобалов и «протёкшие» глобалы ловятся только если попадут в исполненную ветку (пример TST-01 — попалась, но лишь потому, что упало).
- **Recommendation**: `__newindex`-ловушка в тестовом окружении с белым списком ожидаемых глобалов.
- **Risk of the fix**: средний (может вскрыть много записей).
- **Confidence**: High по факту, Medium по приоритету.

## 6. Точность моков: где расходятся с настоящим FAF

1. **`import`**: в раннере отсутствует; в `core-smoke` неизвестный путь уходит в `loadfile('..'..path)` и падает на игровых файлах (№1). В остальных — `assert(modules[path], path)`, то есть любой новый игровой импорт = красный тест (№11, 16, 17).
2. **`table.getn`**: шим `table.getn = function(t) return #t end` в части тестов; в остальных его нет вовсе. Fengari — это Lua 5.3, где `table.getn` удалён, а `#` имеет border-семантику. Совпадение с LuaPlus не гарантировано.
3. **`table.getsize`**: API LuaPlus, шимится вручную в двух тестах (`hotbuild-runtime.lua:4`, `hotbuild-keys.lua:3`), в остальных отсутствует — модуль, который его использует, упадёт не в игре, а в тесте (или наоборот).
4. **`math.mod`**: шим `math.mod = math.fmod` — единственная глобальная заглушка раннера; в Lua 5.3 `fmod` ведёт себя иначе на отрицательных/целых (возвращает float).
5. **MAUI**: наборы методов контролов различаются от теста к тесту (`SetTexture` есть в одном, нет в другом — №15; `Edit` отсутствует — №11; `CreateVertScrollbarFor` требуется с проверкой методов в keyboard-editor). Нет ни одного теста, который проверял бы, что мод не вызывает несуществующий метод контрола.
6. **Геометрия/масштаб**: `AtLeftTopIn` в моках просто пишет `x,y`; реальное применение UI-scale проверяется только в `claret-menu` (и именно там сломалась геометрия, №2). Двойное применение масштаба тестами не ловится.
7. **`pcall`**: переопределён в `claret-menu` с потерей возвратов (TST-21); в остальных тестах — настоящий.
8. **`WARN`**: в `claret-menu` превращён в `error`, в других — no-op. Один и тот же продакшен-код ведёт себя по-разному в разных тестах.
9. **Движок**: `GetSelectedUnits`, `IssueBlueprintCommand`, `ClearBuildTemplates`, `SetActiveBuildTemplate`, `StartCommandMode` — всё моки; проверяется только порядок вызовов, не семантика.
10. **Изоляция**: состояния Fengari общие по процессу, но новое на каждый тест; однако `process.stdout.write` подменяется глобально в `--quiet` (корректно восстанавливается в `finally`).

## 7. Пробелы покрытия относительно критичных сценариев

| Сценарий | Состояние | Доказательство |
|---|---|---|
| Shift/модификаторы в назначениях | частично: форматирование подписи и множитель очереди; **ноль** проверок `IsKeyDown(16)` в строках действий | `rg "IsKeyDown\(16\)" Tests` → 0; `shift=true` только в `hotbuild-context-queue/runtime/keyboard-editor` |
| Shift-перехват при выбранной фабрике | **нет тестов** | `ExecuteFactoryShift` (Runtime.lua:617) и `factory_shift_intercept` (KeyboardBindings.lua:902) не упоминаются в `Tests/` |
| Round-trip пресетов, включая legacy | хорошо: `hotbuild-model`, `hotbuild-compatibility`, `hotbuild-grid-model` (последний не запускается) | `legacy` встречается в 10 тестах |
| Порядок и распределение команд | хорошо: точная последовательность транзакции в `hotbuild-adapter` (`cache,ignoreOn,select,issue,select,ignoreOff,restoreMode`), распределение по фабрикам в `hotbuild-context-queue` | см. §2, №6 (после починки фикстуры проходит целиком) |
| Счётчик фабрик / `DecreaseBuildCountInQueue` | частично: множитель Shift проверяется, сам перехват — нет | `DecreaseBuildCountInQueue` в 3 тестах, `Intercept` — 0 |
| Восстановление профиля | средне: `hotbuild-keys`, `hotbuild-runtime`, `hotbuild-context-runtime`, `claret-menu-key` | `GetFromCurrentProfile` в 5 тестах |
| Гейтинг меню | средне, но `claret-menu` умирает на строке 168 из 463 — хвост не исполняется | TST-13 |
| Режим реплея | частично: `isReplay` в 6 тестах (adapter, repeat, upgrade, actions); UI-гейтинг `ExecuteFactoryShift` — нет | `rg isReplay Tests` |
| Точка входа Hotbuild (`Main.lua`): хуки, регистрация, меню | слабо: только `hotbuild-runtime.lua:242` (и `claret-menu.lua:416`, который не достигается) | TST-13 |
| Точка входа Core (`Main.lua`) | `core-smoke` падает на 137 из 278 — половина не исполняется | §2, №1 |

## 8. Минимальный набор регрессионных тестов

Порядок = приоритет. Первые пять закрывают то, что реально ломалось или молча ломалось.

1. **`build-key-labels` без глобала `Colours`** — сейчас красный; после исправления TST-01 он становится защитой от рецидива. Проверять: `Build()` возвращает отношения, `Merge()` уважает существующие отношения, подпись содержит модификаторы, `claret_template_*` игнорируется.
2. **Формат сгенерированной строки действия** — `Execute("<id>", IsKeyDown(16))` и `ExecuteKeyboardPair("<chord>", IsKeyDown(16))`; одна проверка `find(...,1,true)` вместо точного равенства. Плюс `Runtime.Execute(id, true)`: `shiftHeld` кладётся в контекст (`Runtime.lua:294 context.shiftHeld=shiftHeld==true`), при `nil` берётся из `pcall(IsKeyDown,16)` (`Runtime.lua:275-277`).
3. **`ExecuteFactoryShift`** — три ветки: выбранная фабрика + пара → перехват; выбранная фабрика без пары → `ConExecute(nativeAction)`; реплей/`IsKeyCaptureActive` → fallback.
4. **`ContextRepeat`** — цепочка single→double→third press (решить контракт TST-02), accumulate без ограничения по времени, разрыв по смене выделения/армии/другой клавише, `ContinueQuick` с `released`.
5. **`ContextActions`** — матрица `Supports`/`Classify`/приоритеты (тест уже есть, надо привести ожидание `select_transport_nearest` в соответствие с политикой) + проверка, что каждый `id` из `List()` имеет либо `select`, либо `special`.
6. **`Adapter`** — существующий транзакционный тест (порядок команд, откат при исключении, `factorySelection`, реплей) — самый ценный в наборе.
7. **`ContextQueue`** — распределение по фабрикам, `DecreaseBuildCountInQueue`, множитель Shift.
8. **`Model`/`Compatibility`** — legacy-миграция, неизвестная будущая версия, сохранение чужих ключей профиля.
9. **`core-smoke`** — жизненный цикл, реестр, владение хуками (после стаба `rangeoverlayparams`).
10. **`claret-menu`** — заменить магические `1128/1056` на `panel.Width()` и `panel.Width()-72`; проверять наличие заголовка как ребёнка панели, а не конкретную ширину.
11. **Самопроверка раннера** — падать, если `.lua` в `Tests/` не попал в прогон; печатать фактические пути модулей.
12. **Диалект/архитектура** — статические проверки из TST-15 (запрет `#`, `goto`, `//`; Core не импортирует Hotbuild).

## 9. Что не проверялось

- Поведение в игре: ни один сценарий не запускался, скриншоты не снимались. Всё выше — чтение кода + Fengari-прогоны.
- `IsKeyDown(16)` внутри строки `UI_Lua` (TST-20) — только предположение о работоспособности.
- Наличие/отсутствие глобала `Colours` проверено по базовому архиву `lua.nx2` (1 619 файлов). Другой установленный мод мог бы определить `Colours` — не проверял (папка `../mods` в аудите закрыта).
- Реальный контракт `EntityCategoryGetUnitList` (TST-22).
- Производительность и рендеринг: тесты не эмулируют ни то, ни другое.
- Содержимое `Context/compiled-lua.txt` и `Context/sources/` не читалось.
