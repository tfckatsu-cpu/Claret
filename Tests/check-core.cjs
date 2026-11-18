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
        // LuaPlus has no length operator; production code must use table.getn.
        if (node.type === 'UnaryExpression' && node.operator === '#') {
          throw new Error(`${file}: FAF LuaPlus does not support the # length operator`);
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
// Architecture boundary: Core must never import ClaretHotbuild.
function checkCoreBoundary(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) checkCoreBoundary(file);
    else if (file.endsWith('.lua') && /import\(\s*['"]\/mods\/ClaretHotbuild/.test(fs.readFileSync(file, 'utf8'))) {
      throw new Error(`${file}: ClaretCore must not import ClaretHotbuild`);
    }
  }
}
checkCoreBoundary(root);
// Version identity: Main Version == manifest ReUI == README heading; BuildStamp == newest CHANGELOG build.
function checkVersionIdentity(modName, dir) {
  const main = fs.readFileSync(path.join(dir, 'Main.lua'), 'utf8');
  const manifest = fs.readFileSync(path.join(dir, 'mod_info.lua'), 'utf8');
  const readme = fs.readFileSync(path.join(dir, 'README.md'), 'utf8');
  const changelogPath = path.join(dir, 'CHANGELOG.md');
  const changelog = fs.existsSync(changelogPath) ? fs.readFileSync(changelogPath, 'utf8') : null;
  const version = (main.match(/^Version = '([^']+)'/m) || [])[1];
  const stamp = (main.match(/BuildStamp = '(\d{8}-\d+)'/) || [])[1];
  const manifestVersion = (manifest.match(/ReUI = ['"][^'"]+=([\d.]+)['"]/) || [])[1];
  const readmeVersion = (readme.match(/^# .*?(\d+\.\d+\.\d+)/m) || [])[1];
  const newestBuild = changelog ? (changelog.match(/## Сборка (\d{8}-\d+)/) || [])[1] : null;
  const problems = [];
  if (!version) problems.push('Main.lua Version missing');
  if (version !== manifestVersion) problems.push(`${modName}: Main ${version} != mod_info ${manifestVersion}`);
  if (version !== readmeVersion) problems.push(`${modName}: README ${readmeVersion} != Main ${version}`);
  if (changelog && stamp !== newestBuild) problems.push(`${modName}: BuildStamp ${stamp} != CHANGELOG ${newestBuild}`);
  if (problems.length) throw new Error(problems.join('; '));
}
checkVersionIdentity('ClaretCore', root);
checkVersionIdentity('ClaretHotbuild', '../mods/ClaretHotbuild');
// LuaPlus rejects expression-form varargs accepted by the Lua 5.1 parser.
// These live integration files do not need varargs at all.
for (const file of ['../mods/ClaretHotbuild/Main.lua', '../mods/ClaretCore/modules/ReUICargoIndicator.lua']) {
  if (fs.readFileSync(file, 'utf8').includes('...')) throw new Error(`${file}: varargs require a LuaPlus-specific check`);
}
if (!quiet) console.log(`PASS: parsed ${count} Lua files (Lua 5.1 grammar; FAF runtime still requires game verification)`);
let failed = false;
let passedCount = 0;
const failures = [];
// Every test file on disk runs automatically; only *-helper.lua are shared helpers.
const testFiles = fs.readdirSync(path.join(__dirname))
  .filter((name) => name.endsWith('.lua') && !name.endsWith('-helper.lua'))
  .sort();
for (const file of testFiles) {
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
