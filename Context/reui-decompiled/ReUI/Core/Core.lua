-- Generated research-only output. Original SHA256: 7827c4984bd9f5f71c560d9a07654254587bc7e29b97925098a8ce8246a19e73. Not for game execution.
Version = "1.7.0"

function Main()
  local setmetatable = setmetatable
  local weakKey = {__mode = "k"}
  local weakValue = {__mode = "v"}
  local weakKeyValue = {__mode = "kv"}
  
  local function MakeHook(hook)
    LOG(("ReUI.Core: Hooking '%s':%s"):format(hook.moduleName, hook.fieldName))
    local module = import(hook.moduleName)
    local originalField = rawget(module, hook.fieldName)
    local newField = hook.callback(originalField, module)
    module[hook.fieldName] = newField
  end
  
  local hooks = {}
  local loader = ReUI.__loader
  loader:AddPreCreateCallback(function(isReplay)
    local pcall = pcall
    for _, hook in hooks, nil do
      local ok, result = pcall(MakeHook, hook)
      if not ok then
        WARN(("ReUI.Core: Failed to hook '%s':%s"):format(hook.moduleName, hook.fieldName))
        WARN(result)
      end
    end
  end)
  loader:AddPostCreateCallback(function(isReplay)
    hooks = nil
    
    function ReUI.Core.Hook(moduleName, fieldName, callback)
      error(("ReUI.Core.Hook: Attempt to make hook after UI was created. Hooks is '%s':%s"):format(moduleName, fieldName))
    end
  end)
  
  local function PerformHook(moduleName, fieldName, callback)
    table.insert(hooks, {
      moduleName = moduleName,
      fieldName = fieldName,
      callback = callback
    })
  end
  
  local ReUIClass = import("Modules/Class.lua")
  return {
    Hook = PerformHook,
    HookModule = function(moduleName)
      return function(fieldName, callback)
        PerformHook(moduleName, fieldName, callback)
      end
    end,
    OnPreCreateUI = function(callback)
      return loader:AddPreCreateCallback(callback)
    end,
    OnPostCreateUI = function(callback)
      return loader:AddPostCreateCallback(callback)
    end,
    Weak = {
      Key = function(t)
        return setmetatable(t, weakKey)
      end,
      Value = function(t)
        return setmetatable(t, weakValue)
      end,
      KeyValue = function(t)
        return setmetatable(t, weakKeyValue)
      end
    },
    Class = ReUIClass.UIClass,
    Property = ReUIClass.Property,
    String = import("Modules/String.lua").String
  }
end
