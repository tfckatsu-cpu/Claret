-- Generated research-only output. Original SHA256: f8fa212e1c5c32ec7d9523af746326df7ba5fd56db3384a1f7b4441033820e67. Not for game execution.
Version = "1.0.0"
ReUI.Require({
  "ReUI.Core >= 1.6.0",
  "ReUI.Options >= 1.0.0"
})

function Main(isReplay)
  local SelectUnits = SelectUnits
  local IsKeyDown = IsKeyDown
  local TableEmpty = table.empty
  local ForkThread = ForkThread
  local options = ReUI.Options.Mods["ReUI.Selection"]
  local enabled = options.enabled.Value
  options.enabled.OnChanged:Add(function(o, v)
    enabled = v
  end)
  local ignored = false
  
  local function SelectIgnored(units)
    ignored = true
    SelectUnits(nil)
    SelectUnits(units)
    ignored = false
  end
  
  local Handler = ReUI.Core.Class()({
    Name = "Default",
    Priority = 0,
    Handle = function(self, selection)
      return selection, false
    end
  })
  local Selector = ReUI.Core.Class()({
    __init = function(self)
      self._handlers = {}
    end,
    Process = function(self, oldSelection, newSelection, added, removed)
      local changed, changedSel = false, false
      local selection = newSelection
      for _, handler in self:GetHandlers() do
        selection, changedSel = handler:Handle(selection)
        changed = changed or changedSel
      end
      return selection, changed
    end,
    Get = function(self, name)
      for i, handler in self._handlers, nil do
        if handler.Name == name then
          return handler
        end
      end
      return nil
    end,
    Add = function(self, handler)
      if self:Get(handler.Name) then
        WARN("ReUI.Selection: Handler with name " .. tostring(handler.Name) .. " already exists in selector")
        return
      end
      table.insert(self._handlers, handler)
      table.sort(self._handlers, function(a, b)
        return a.Priority > b.Priority
      end)
    end,
    Remove = function(self, name)
      for i, handler in self._handlers, nil do
        if handler.Name == name then
          table.remove(self._handlers, i)
          return
        end
      end
    end,
    GetHandlers = function(self)
      return self._handlers
    end
  })
  local selector
  
  local function GetSelector()
    if selector == nil then
      selector = ReUI.Selection.Selector()
    end
    return selector
  end
  
  local function HandleSelectionChanged(oldSelection, newSelection, added, removed)
    if not enabled or ignored or IsKeyDown("Shift") or TableEmpty(added) then
      return false
    end
    local selection, changed = nil, false
    if selector then
      selection, changed = selector:Process(oldSelection, newSelection, added, removed)
    end
    if changed then
      ForkThread(SelectIgnored, selection)
      return true
    end
    return false
  end
  
  ReUI.Core.Hook("/lua/ui/game/gamemain.lua", "OnSelectionChanged", function(OnSelectionChanged, module)
    return function(oldSelection, newSelection, added, removed)
      if module.IsIgnoredSelection() then
        return
      end
      if HandleSelectionChanged(oldSelection, newSelection, added, removed) then
        return
      end
      OnSelectionChanged(oldSelection, newSelection, added, removed)
    end
  end)
  ReUI.Core.OnPostCreateUI(function()
    if selector == nil then
      return
    end
    LOG("ReUI.Selection: Handlers:")
    for _, handler in selector:GetHandlers() do
      LOG("\t", handler.Name)
    end
  end)
  return {
    Selector = Selector,
    GetSelector = GetSelector,
    Handler = Handler
  }
end
