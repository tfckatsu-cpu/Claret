const fs = require('node:fs');
const path = require('node:path');
const parser = require('../.tools/lua-check/node_modules/luaparse');
const { lua, lauxlib, lualib, to_luastring } = require('../.tools/lua-check/node_modules/fengari');
process.chdir(path.resolve(__dirname, '..'));
const args = process.argv.slice(2);
const quiet = args.includes('--quiet');
const onlyIndex = args.indexOf('--only');
if (onlyIndex !== -1 && (!args[onlyIndex + 1] || args[onlyIndex + 1].startsWith('--'))) {
  console.error('Expected a pattern after --only'); process.exit(1);
}
const pattern = onlyIndex === -1 ? null : args[onlyIndex + 1];
const root = '../mods/ClaretCore';
let count = 0;
function check(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) check(file);
    else if (file.endsWith('.lua')) {
      const ast = parser.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1' });
      // FAF's LuaPlus reserves `continue` even though stock Lua 5.1 does not.
      // Inspect identifiers in the syntax tree so strings/comments do not trigger it.
      const pending = [ast];
      while (pending.length) {
        const node = pending.pop();
        if (!node || typeof node !== 'object') continue;
        if (node.type === 'Identifier' && node.name === 'continue') {
          throw new Error(`${file}: FAF-reserved identifier "continue"`);
        }
        for (const value of Object.values(node)) {
          if (Array.isArray(value)) pending.push(...value);
          else if (value && typeof value === 'object') pending.push(value);
        }
      }
      count++;
    }
  }
}
check(root);
check('../mods/ClaretHotbuild');
function readLocalizationKeys(file) {
  const source = fs.readFileSync(file, 'utf8');
  const keys = { en: new Set(), ru: new Set() };
  const table = source.match(/en\s*=\s*\{([\s\S]*?)\n\s*\},\s*\n\s*ru\s*=\s*\{([\s\S]*?)\n\s*\}/);
  if (!table) throw new Error(`${file}: EN/RU tables were not found`);
  for (const [index, language] of [[1, 'en'], [2, 'ru']]) {
    const matcher = /\[\s*(['"])([^'"]+)\1\s*\]\s*=/g;
    let match;
    while ((match = matcher.exec(table[index]))) keys[language].add(match[2]);
  }
  const assignment = /Strings\.(en|ru)\s*\[\s*(['"])([^'"]+)\2\s*\]\s*=/g;
  let match;
  while ((match = assignment.exec(source))) keys[match[1]].add(match[3]);
  return keys;
}
const localizationFiles = [
  '../mods/ClaretCore/modules/LocalizationStrings.lua',
  '../mods/ClaretHotbuild/modules/LocalizationStrings.lua',
];
const localizationKeys = { en: new Set(), ru: new Set() };
for (const file of localizationFiles) {
  const keys = readLocalizationKeys(file);
  for (const language of ['en', 'ru']) for (const key of keys[language]) localizationKeys[language].add(key);
}
for (const language of ['en', 'ru']) {
  const other = language === 'en' ? 'ru' : 'en';
  for (const key of localizationKeys[language]) {
    if (!localizationKeys[other].has(key)) throw new Error(`Localization key missing from ${other}: ${key}`);
  }
}
function checkLocalizationReferences(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) checkLocalizationReferences(file);
    else if (file.endsWith('.lua') && !file.endsWith('LocalizationStrings.lua')) {
      const source = fs.readFileSync(file, 'utf8');
      const matcher = /(['"])((?:core|hotbuild)\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)\1/g;
      let match;
      while ((match = matcher.exec(source))) {
        const key = match[2];
        if (key.endsWith('_')) continue; // Runtime suffix, such as auto_en/auto_ru.
        if (!localizationKeys.en.has(key) || !localizationKeys.ru.has(key)) {
          throw new Error(`${file}: referenced localization key is missing from EN/RU: ${key}`);
        }
      }
    }
  }
}
checkLocalizationReferences(root);
checkLocalizationReferences('../mods/ClaretHotbuild');
// LuaPlus rejects expression-form varargs accepted by the Lua 5.1 parser.
// These live integration files do not need varargs at all.
for (const file of ['../mods/ClaretHotbuild/Main.lua', '../mods/ClaretCore/modules/ReUICargoIndicator.lua']) {
  if (fs.readFileSync(file, 'utf8').includes('...')) throw new Error(`${file}: varargs require a LuaPlus-specific check`);
}
if (!quiet) console.log(`PASS: parsed ${count} Lua files (Lua 5.1 grammar; FAF runtime still requires game verification)`);
let failed = false;
let passedCount = 0;
const failures = [];
for (const file of ['core-localization.lua', 'core-smoke.lua', 'core-welcome.lua', 'core-transport-cargo.lua', 'core-reui-cargo-indicator.lua', 'core-cargo-selection.lua', 'core-selection-ignore-scope.lua', 'core-selection-ignore-hook.lua', 'core-construction-facade.lua', 'core-construction-panel.lua', 'core-construction-choices.lua', 'core-construction-cargo-view.lua', 'core-construction-cargo-integration.lua', 'core-construction-queue.lua', 'core-construction-panel-shell.lua', 'core-construction-grid-model.lua', 'core-construction-selection.lua', 'core-construction-templates.lua', 'core-construction-items-view.lua', 'core-construction-controller.lua', 'core-construction-enhancements.lua', 'core-construction-actions.lua', 'core-construction-engine-adapters.lua', 'core-construction-template-actions.lua', 'core-construction-template-integration.lua', 'core-construction-enhancement-actions.lua', 'core-construction-enhancement-scope-integration.lua', 'core-multifunction-shell.lua', 'core-multifunction-controller.lua', 'core-multifunction-integration.lua', 'core-orders-panel-shell.lua', 'core-orders-panel-model.lua', 'core-orders-panel-integration.lua', 'core-orders-catalog.lua', 'core-orders-overrides.lua', 'core-orders-actions.lua', 'claret-menu.lua', 'claret-menu-key.lua', 'hotbuild-catalog.lua', 'hotbuild-equivalents.lua', 'hotbuild-templates.lua', 'hotbuild-model.lua', 'hotbuild-build-key-labels.lua', 'hotbuild-adapter.lua', 'hotbuild-keys.lua', 'hotbuild-runtime.lua', 'hotbuild-grid-editor.lua', 'hotbuild-cycle-menu.lua', 'hotbuild-navigator.lua', 'hotbuild-keyboard-editor.lua', 'hotbuild-open-perf.lua', 'hotbuild-compatibility.lua', 'hotbuild-context-model.lua', 'hotbuild-context-actions.lua', 'hotbuild-context-labels.lua', 'hotbuild-context-repeat.lua', 'hotbuild-engineer-hold.lua', 'hotbuild-context-runtime.lua', 'hotbuild-context-editor.lua', 'hotbuild-context-enhancements.lua', 'hotbuild-context-queue.lua', 'hotbuild-context-upgrade.lua']) {
  if (pattern !== null && !file.includes(pattern)) continue;
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  // FAF supplies this Lua 5.0 API; Fengari uses the newer spelling.
  lauxlib.luaL_dostring(L, to_luastring('math.mod = math.fmod'));
  let output = '';
  const write = process.stdout.write;
  if (quiet) process.stdout.write = function (chunk) { output += chunk.toString(); return true; };
  let result;
  try { result = lauxlib.luaL_dofile(L, to_luastring(`Tests/${file}`)); }
  finally { if (quiet) process.stdout.write = write; }
  if (result !== lua.LUA_OK) {
    const error = lua.lua_tojsstring(L, -1);
    if (quiet) {
      const lines = (error + '\n' + output).split(/\r?\n/).filter(Boolean).slice(0, 14);
      console.error(`FAIL: ${file}`);
      for (const line of lines) console.error(line);
    } else console.error(`FAIL: ${file}: ${error}`);
    failures.push(file);
    failed = true;
  } else passedCount++;
  lua.lua_close(L);
}
if (quiet) console.log(`${passedCount} passed, ${failures.length} failed${failures.length ? ': ' + failures.join(', ') : ''}`);
if (failed) process.exitCode = 1;
