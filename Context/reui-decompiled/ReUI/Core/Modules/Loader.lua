-- Generated research-only output. Original SHA256: 5043eaf4d7511d7d9aa58d30b2270dac718e14a54b3f128c02d934d3d4d8628e. Not for game execution.
local _error = error
local _rawget = rawget
local _pcall = pcall
local _tonumber = tonumber
local StringFormat = string.format
local StringSub = string.sub
local StringGSub = string.gsub
local StringFind = string.find
local TableInsert = table.insert
local setmetatable = setmetatable
local _assert = assert
local import = import
local exists = exists
local String = import("String.lua").String

local function RemoveSpaces(s)
  s = StringGSub(s, "%s+", "")
  return s
end

local VERSION_NUMBER_REGEX = "^(%d+)%.(%d+)%.(%d+)$"

local function ParseVersion(vs)
  local start = StringFind(vs, VERSION_NUMBER_REGEX)
  if not start then
    error("invalid ReUI version: " .. vs)
  end
  local major = StringGSub(vs, VERSION_NUMBER_REGEX, "%1")
  local minor = StringGSub(vs, VERSION_NUMBER_REGEX, "%2")
  local revision = StringGSub(vs, VERSION_NUMBER_REGEX, "%3")
  return {
    major = _tonumber(major),
    minor = _tonumber(minor),
    revision = _tonumber(revision)
  }
end

local NAME_REGEX = "^%a[%a%.%d]*$"
local TAG_REGEX = "^(%a[%a%.%d]*)=(%d+%.%d+%.%d+)$"

local function ParseNameAndVersion(s)
  s = RemoveSpaces(s)
  local start = StringFind(s, TAG_REGEX)
  if start ~= nil then
    local name = StringGSub(s, TAG_REGEX, "%1")
    local version = StringGSub(s, TAG_REGEX, "%2")
    return name, ParseVersion(version)
  end
  start = StringFind(s, NAME_REGEX)
  if start == nil then
    error("invalid ReUI tag: " .. s)
  end
  return s, {
    major = 0,
    minor = 0,
    revision = 0
  }
end

local function DemangleName(moduleName)
  local splitName = String.Split(moduleName, ".")
  if table.empty(splitName) then
    _error("Name can't have 0 parts")
  end
  if splitName[1] == "ReUI" then
    table.remove(splitName, 1)
  end
  return splitName
end

local function VersionEqual(v1, v2)
  return v1.major == v2.major and v1.minor == v2.minor and v1.revision == v2.revision
end

local function VersionGreater(v1, v2)
  return v1.major > v2.major or v1.major == v2.major and v1.minor > v2.minor or v1.major == v2.major and v1.minor == v2.minor and v1.revision > v2.revision
end

local function CheckVersion(v1, operator, v2)
  if operator == ">=" then
    return VersionEqual(v1, v2) or VersionGreater(v1, v2)
  elseif operator == "<=" then
    return VersionEqual(v1, v2) or VersionGreater(v2, v1)
  elseif operator == ">" then
    return VersionGreater(v1, v2)
  elseif operator == "<" then
    return VersionGreater(v2, v1)
  elseif operator == "==" or operator == "=" then
    return VersionEqual(v1, v2)
  else
    _error("Invalid operator " .. operator)
  end
end

local function VersionToString(version)
  return ("%d.%d.%d"):format(version.major, version.minor, version.revision)
end

local VERSION_REGEX = "^(%a[%a%.%d]*)([><=]=?)(%d+%.%d+%.%d+)$"

local function MatchDependencyString(s)
  s = RemoveSpaces(s)
  local start = StringFind(s, VERSION_REGEX)
  if not start then
    return nil, nil, nil
  end
  local moduleName = StringGSub(s, VERSION_REGEX, "%1")
  local op = StringGSub(s, VERSION_REGEX, "%2")
  local versionS = StringGSub(s, VERSION_REGEX, "%3")
  return moduleName, op, ParseVersion(versionS)
end

local function DoScript(path)
  local r = {}
  doscript(path, r)
  return r
end

local ModuleMeta = {
  __index = function(self, key)
    _error(("ReUI.Core: attempt to get '%s' from module '%s', which doesn't exist"):format(tostring(key), _rawget(self, "Name") or "UNKNOWN"))
  end
}
Loader = Class()({
  __init = function(self, internalData, internalModulesList)
    self._isReplay = false
    self._stage = "disposed"
    self._internalData = internalData
    self._modules = {}
    self._loadedModulesInOrder = {}
    self._modulesInProgress = {}
    self._loadingErrors = {}
    self._preCreateCallbacks = {}
    self._postCreateCallbacks = {}
    self._preloadStack = {}
    self._internalModules = {}
    local ok, result = pcall(function()
      for _, info in ipairs(internalModulesList or {}) do
        local name, version = ParseNameAndVersion(info.tag)
        self._internalModules[name] = {
          path = info.path,
          version = version,
          name = name
        }
        LOG(("ReUI: loaded internal module '%s':%s"):format(name, VersionToString(version)))
      end
    end)
    if not ok then
      WARN("ReUI: failed to load internal modules: " .. result)
    end
  end,
  Wrap = function(self, func)
    self:PreLoad()
    return function(isReplay)
      self._isReplay = isReplay
      self:Load()
      self:PreCreateUI()
      func(isReplay)
      self:PostCreateUI()
      self:PrintLoadedModules()
      self:Dispose()
    end
  end,
  AddError = function(self, message)
    TableInsert(self._loadingErrors, message)
  end,
  GetErrors = function(self)
    return self._loadingErrors
  end,
  PreLoad = function(self)
    self._stage = "preload"
    for _, mod in __active_mods, nil do
      if mod.ReUI and mod.ui_only then
        if mod.selectable then
          self:PreLoadMod(mod)
        else
          self:AddError(("Do not select mods through client mod list! Use ingame mod manager. Mod '%s' is unselectable."):format(mod.name))
        end
      end
    end
  end,
  ImportModule = function(self, moduleName)
    if self:IsLoadStage() then
      error("ReUI.Loader: attempt to import module '" .. moduleName .. "' in load stage")
    end
    local module = self._modules[moduleName]
    local moduleType, path, name = self:FindModuleMainFilePath(moduleName)
    module.Path = path
    module.Type = moduleType
    local mainPath = path .. name .. ".lua"
    LOG(("ReUI.Loader: importing '%s' at '%s'."):format(moduleName, mainPath))
    local m = import(mainPath)
    local moduleVersion
    local v = rawget(m, "Version")
    if v == nil then
      WARN("ReUI.Loader: Specify Version in main file, it is deprecated to set it in mod_info.lua")
      local tag = DoScript(path .. "mod_info.lua").ReUI
      local name, version = ParseNameAndVersion(tag)
      moduleVersion = version
    else
      moduleVersion = ParseVersion(v)
    end
    module.Version = moduleVersion
    module.Main = m.Main
    return module
  end,
  TryLoadModule = function(self, moduleName)
    local modulesInProgress = self._modulesInProgress
    if modulesInProgress[moduleName] then
      local msgError = ("Module '%s' is already loading. Is there circular dependency?"):format(moduleName)
      self:AddError(msgError)
      _error(msgError)
    end
    local loadingModule = setmetatable({
      Name = moduleName,
      Status = "loading",
      Dependencies = {}
    }, ModuleMeta)
    self._modules[moduleName] = loadingModule
    modulesInProgress[moduleName] = true
    table.insert(self._preloadStack, loadingModule)
    local ok, result = _pcall(self.ImportModule, self, moduleName)
    table.remove(self._preloadStack)
    modulesInProgress[moduleName] = nil
    if not ok then
      loadingModule.Status = "failed"
      self:AddError(("Failed to load module '%s'. See log for more info."):format(moduleName))
      _error(([[
Failed to load module '%s' due to following error:
%s]]):format(moduleName, result))
    end
    LOG(("ReUI.Loader: loaded module '%s':%s"):format(moduleName, VersionToString(result.Version)))
    TableInsert(self._loadedModulesInOrder, loadingModule)
    local demangledName = DemangleName(moduleName)
    self:AssignModule(demangledName, loadingModule)
    return loadingModule
  end,
  TryPreLoad = function(self, moduleTag)
    self:CheckNotDisposed()
    local name, version = ParseNameAndVersion(moduleTag)
    local module = self._modules[name] or self:TryLoadModule(name)
    if module.Status == "failed" then
      _error(("Module '%s' failed to load previously"):format(name))
    end
    return module
  end,
  PreLoadMod = function(self, mod)
    local ok, module = _pcall(self.TryPreLoad, self, mod.ReUI)
    if not ok then
      WARN(module)
      return
    end
    local cok, cerr = _pcall(self.CheckPreloadedModule, self, module, mod)
    if not cok then
      module.Status = "failed"
      self:AddError(("Failed to load module '%s' from mod '%s': %s"):format(module.Name, mod.name or mod.uid or "?", cerr))
      WARN(cerr)
    end
  end,
  CheckPreloadedModule = function(self, module, mod)
    if module.Type ~= "mod" then
      _error(("module resolved to a %s at '%s', but an enabled mod must be a mod folder containing a mod_info.lua"):format(module.Type or "?", module.Path))
    end
    local info = DoScript(module.Path .. "mod_info.lua")
    if info.uid ~= mod.uid then
      _error(("module declared by mod '%s' (uid '%s') resolved to '%s' which belongs to a different mod (uid '%s'). Tag and location do not match."):format(mod.name or "?", mod.uid or "?", module.Path, info.uid or "?"))
    end
  end,
  Load = function(self)
    self._stage = "load"
    for _, module in ipairs(self._loadedModulesInOrder) do
      self:LoadModule(module)
    end
  end,
  IsLoadStage = function(self)
    return self._stage == "load"
  end,
  CheckDependencies = function(self, module)
    for _, dep in ipairs(module.Dependencies) do
      if dep.Status == "loading" then
        self:LoadModule(dep)
      end
      if dep.Status == "failed" then
        return false
      end
    end
    return true
  end,
  TryCallModuleMain = function(self, module)
    if module.Status == "loaded" or module.Status == "failed" then
      return
    end
    if not self:CheckDependencies(module) then
      self:AddError(("Module '%s' failed to load due to failed dependencies."):format(module.Name))
      module.Status = "failed"
      return
    end
    local r = module.Main(self._isReplay)
    module.Main = nil
    if r then
      for k, v in r, nil do
        rawset(module, k, v)
      end
    end
    module.Status = "loaded"
  end,
  LoadModule = function(self, module)
    local ok, result = _pcall(self.TryCallModuleMain, self, module)
    if not ok then
      self:AddError(("Failed to load module '%s' due to error in Main. See log for more info."):format(module.Name))
      module.Status = "failed"
      WARN(result)
    end
  end,
  AddPreCreateCallback = function(self, callback)
    self:CheckNotDisposed()
    TableInsert(self._preCreateCallbacks, callback)
  end,
  PreCreateUI = function(self)
    for _, callback in self._preCreateCallbacks, nil do
      local ok, result = _pcall(callback, self._isReplay)
      if not ok then
        WARN(result)
      end
    end
  end,
  AddPostCreateCallback = function(self, callback)
    self:CheckNotDisposed()
    TableInsert(self._postCreateCallbacks, callback)
  end,
  PostCreateUI = function(self)
    for _, callback in self._postCreateCallbacks, nil do
      local ok, result = _pcall(callback, self._isReplay)
      if not ok then
        WARN(result)
      end
    end
    local errors = self:GetErrors()
    local ok, r = pcall(function()
      local ReceiveChatFromSim = import("/lua/ui/game/chat.lua").ReceiveChatFromSim
      for _, err in errors, nil do
        ReceiveChatFromSim(GetFocusArmy(), {
          Chat = true,
          to = "notify",
          text = err
        })
      end
    end)
    if not ok then
      WARN(r)
    end
  end,
  GetModule = function(self, name)
    return self._modules[name]
  end,
  Exists = function(self, tag)
    local name, op, version = MatchDependencyString(tag)
    if not name then
      WARN("ReUI: failed to parse dependency string: " .. tag)
      return nil
    end
    local module = self:GetModule(name)
    if module == nil then
      return nil
    end
    if module.Status == "failed" then
      return nil
    end
    if not CheckVersion(module.Version, op, version) then
      return nil
    end
    if module.Status == "loading" then
      self:LoadModule(module)
    end
    if module.Status == "loaded" then
      return module
    end
    return nil
  end,
  CheckModEnabled = function(self, module)
    if module.Type == "mod" then
      local uid = import(module.Path .. "mod_info.lua").uid
      for _, mod in __active_mods, nil do
        if mod.uid == uid then
          return
        end
      end
    end
    local msg = ("Mod '%s' is not enabled."):format(module.Name)
    self:AddError(msg)
    _error(msg)
  end,
  Require = function(self, deps)
    self:CheckPreLoadStage()
    local topModule = self._preloadStack[table.getn(self._preloadStack)]
    assert(topModule, "ReUI.Loader: there is no module in preload stack")
    if deps.enabled then
      self:CheckModEnabled(topModule)
    end
    if deps.version then
      local version = tonumber(import("/lua/version.lua").GetVersion()) or 0
      if version < deps.version then
        local msg = ("Module '%s' requires game version %s or higher."):format(topModule.Name, deps.version)
        self:AddError(msg)
        _error(msg)
      end
    end
    for _, dep in ipairs(deps) do
      local name, op, version = MatchDependencyString(dep)
      if not name then
        _error(("Invalid dependency string '%s'!"):format(dep))
      end
      local module = self._modules[name] or self:TryLoadModule(name)
      if module.Status == "failed" then
        _error(("Module '%s' failed to load previously"):format(name))
      end
      TableInsert(topModule.Dependencies, module)
      if self:IsLoadStage() then
        self:LoadModule(module)
      end
      if not CheckVersion(module.Version, op, version) then
        local msg = ("Module '%s' doesn't match required version: current: %s, required: %s%s"):format(name, VersionToString(module.Version), op, VersionToString(version))
        self:AddError(msg)
        _error(msg)
      end
    end
  end,
  AssignModule = function(self, parts, module)
    local data = self._internalData
    local n = table.getn(parts)
    for i = 1, n do
      local part = parts[i]
      local t = _rawget(data, part)
      if i == n then
        if t then
          if t.Name then
            _error("Attempt to override module " .. t.Name)
          end
          for k, v in t, nil do
            module[k] = v
          end
        end
        data[part] = module
      else
        data[part] = t or {}
        data = data[part]
      end
    end
  end,
  CheckNotDisposed = function(self)
    _assert(self._stage ~= "disposed", "ReUI loader was disposed. Are you trying to require modules outside of creation of UI?")
  end,
  CheckPreLoadStage = function(self)
    _assert(self._stage == "preload", "ReUI loader is not in preload stage. Are you trying to require modules within Main function?")
  end,
  FindModuleMainFilePath = function(self, moduleName)
    local splitName = String.Split(moduleName, ".")
    local lastPart = splitName[table.getn(splitName)]
    local path = "/mods/" .. splitName[1]
    local moduleType = "package"
    for i = 2, table.getn(splitName) do
      local dotPath = path .. "/" .. table.concat(splitName, "/", i)
      if exists(dotPath .. "/" .. lastPart .. ".lua") then
        path = dotPath
        break
      end
      if exists(dotPath .. "/Main.lua") then
        path = dotPath
        break
      end
      if exists(dotPath .. ".lua") then
        path = path .. "/" .. table.concat(splitName, "/", i, table.getn(splitName) - 1)
        moduleType = "file"
        break
      end
      path = path .. "." .. splitName[i]
    end
    if moduleType ~= "file" then
      local existsInfo = exists(path .. "/mod_info.lua")
      moduleType = existsInfo and "mod" or "package"
    end
    if exists(path .. "/" .. lastPart .. ".lua") then
      return moduleType, path .. "/", lastPart
    end
    if moduleType ~= "file" and exists(path .. "/Main.lua") then
      return moduleType, path .. "/", "Main"
    end
    error(StringFormat("ReUI.Loader: couldn't find module '%s'", moduleName))
  end,
  PrintLoadedModules = function(self)
    LOG("ReUI modules:")
    for _, module in ipairs(self._loadedModulesInOrder) do
      LOG(module.Name .. ":")
      LOG("\t", "Version: " .. VersionToString(module.Version))
      LOG("\t", "Type: " .. module.Type)
      LOG("\t", "Path: " .. module.Path)
      LOG("\t", "Status: " .. module.Status)
    end
  end,
  Dispose = function(self)
    if not table.empty(self._preloadStack) then
      WARN("ReUI: Preload stack is not empty.")
    end
    self._stage = "disposed"
    self._loadedModulesInOrder = nil
    self._modulesInProgress = nil
    self._loadingErrors = nil
    self._internalModules = nil
    self._preCreateCallbacks = nil
    self._postCreateCallbacks = nil
  end
})

function Create(internalModules)
  local __ReUI = {}
  local loader = Loader(__ReUI, internalModules)
  
  function __ReUI.Exists(tag)
    return loader:Exists(tag)
  end
  
  function __ReUI.Require(deps)
    return loader:Require(deps)
  end
  
  function __ReUI.Get(name)
    return loader:GetModule(name)
  end
  
  local ReUI = setmetatable({__loader = loader}, {
    __newindex = function(self, k, v)
      error("Manual assignment into ReUI is forbidden")
    end,
    __index = function(self, k)
      local v = __ReUI[k]
      if not v then
        error(("'ReUI.%s' doesn't exist"):format(k))
      end
      return v
    end
  })
  return ReUI
end
