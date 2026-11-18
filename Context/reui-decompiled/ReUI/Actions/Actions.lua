-- Generated research-only output. Original SHA256: 8bc109a1590fe64b6c6c30921b608e4b95d8f71931746a3cde6af0fe6d598586. Not for game execution.
Version = "1.3.0"
ReUI.Require({})

function Main()
  local TableGetN = table.getn
  local ipairs = ipairs
  local type = type
  local iscallable = iscallable
  local EntityCategoryFilterDown = EntityCategoryFilterDown
  local GetSelectedUnits = GetSelectedUnits
  local ConExecute = ConExecute
  local categoryActions = {}
  
  local function ProcessAction(name)
    local action = categoryActions[name]
    if not action then
      WARN("Attempt to use action '" .. name .. "' which wasn't registered")
      return
    end
    action:Process(GetSelectedUnits())
  end
  
  local function GetFormattedName(name)
    return (name:gsub("[^A-Za-z0-9]+", "_"))
  end
  
  local function CheckFormattedName(name)
    if name == GetFormattedName(name) then
      return name
    end
    error("name must be made of only letters A-Z, a-z, 0-9 and _")
  end
  
  local function AddSimpleAction(action)
    LOG("ReUI.Actions: adding '" .. action.description .. "'")
    local formattedName = CheckFormattedName(action.formattedName or GetFormattedName(action.description))
    local actionTable = {
      action = action.action,
      category = action.category,
      ReUI = true,
      shift = action.modifiers.shift,
      ctrl = action.modifiers.ctrl,
      alt = action.modifiers.alt
    }
    import("/lua/keymap/keymapper.lua").SetUserKeyAction(formattedName, actionTable)
    local keyDescriptions = import("/lua/keymap/keydescriptions.lua").keyDescriptions
    if keyDescriptions[formattedName] then
      WARN(("Overwriting key action description of '%s'"):format(formattedName))
    end
    keyDescriptions[formattedName] = action.description
  end
  
  local function AddAction(name, matcher, category, formattedName, modifiers)
    category = category or "ReUI.Actions"
    formattedName = formattedName or GetFormattedName(name)
    categoryActions[formattedName] = matcher
    AddSimpleAction({
      description = name,
      action = "UI_Lua ReUI.Actions.ProcessAction('" .. formattedName .. "')",
      category = category,
      formattedName = formattedName,
      modifiers = modifiers
    })
  end
  
  local SelectionAction = Class()({
    __init = function(self, description, func, category, name, modifiers)
      self.func = func
      AddAction(description, self, category, name, modifiers)
    end,
    Process = function(self, selection)
      self.func(selection)
    end
  })
  local CategoryMatcher = Class()({
    __init = function(self, description)
      self.description = description
    end,
    __call = function(self, actions)
      self._actions = actions
      self:Register()
      return self
    end,
    Modifiers = function(self, modifiers)
      self.modifiers = modifiers
      return self
    end,
    Register = function(self)
      AddAction(self.description, self, nil, nil, self.modifiers)
    end,
    Process = function(self, selection)
      for _, action in ipairs(self._actions) do
        if action:Process(selection) then
          break
        end
      end
    end,
    Copy = function(self, other)
      self._actions = table.copy(other._actions)
      self:Register()
      return self
    end
  })
  local CategoryAction = Class()({
    __init = function(self, category)
      self._actions = {}
      self._category = category
      self._matcher = false
    end,
    Action = function(self, action)
      table.insert(self._actions, action)
      return self
    end,
    Matches = function(self, selection)
      local category = self._category
      local matcher = self._matcher
      if matcher then
        return matcher(selection, category)
      end
      return not category and not selection or category and selection and TableGetN(EntityCategoryFilterDown(category, selection)) == TableGetN(selection)
    end,
    Match = function(self, matcher)
      self._matcher = matcher
      return self
    end,
    Process = function(self, selection)
      if self:Matches(selection) then
        self:Execute(selection)
        return true
      end
      return false
    end,
    Execute = function(self, selection)
      for _, action in ipairs(self._actions) do
        if type(action) == "string" then
          ConExecute(action)
        elseif iscallable(action) then
          action(selection)
        else
          error("unknown type of action")
        end
      end
    end
  })
  local Prefs = import("/lua/user/prefs.lua")
  local actions = Prefs.GetFromCurrentProfile("UserKeyActions") or {}
  for name, action in actions, nil do
    if action.category == "ReUI.Actions" or action.ReUI then
      actions[name] = nil
    end
  end
  Prefs.SetToCurrentProfile("UserKeyActions", actions)
  ReUI.Core.Hook("/lua/keymap/keymapper.lua", "GenerateHotbuildModifiers", function(field, module)
    return function()
      local modifiers = field()
      local keyDetails = module.GetKeyMappingDetails()
      for key, info in keyDetails, nil do
        if info.action.shift then
          local modKey = "Shift-" .. key
          local bind = keyDetails[modKey]
          if bind then
            WARN("Hotbuild key " .. modKey .. " is already bound to action \"" .. bind.name .. "\" under \"" .. bind.category .. "\" category")
          else
            modifiers[modKey] = info.action
          end
        end
        if info.action.alt then
          local modKey = "Alt-" .. key
          local bind = keyDetails[modKey]
          if bind then
            WARN("Hotbuild key " .. modKey .. " is already bound to action \"" .. bind.name .. "\" under \"" .. bind.category .. "\" category")
          else
            modifiers[modKey] = info.action
          end
        end
        if info.action.ctrl then
          local modKey = "Ctrl-" .. key
          local bind = keyDetails[modKey]
          if bind then
            WARN("Hotbuild key " .. modKey .. " is already bound to action \"" .. bind.name .. "\" under \"" .. bind.category .. "\" category")
          else
            modifiers[modKey] = info.action
          end
        end
      end
      return modifiers
    end
  end)
  ReUI.Core.OnPostCreateUI(function(isReplay)
    ForkThread(function()
      WaitFrames(1)
      local KeyMapper = import("/lua/keymap/keymapper.lua")
      IN_ClearKeyMap()
      IN_AddKeyMapTable(KeyMapper.GetKeyMappings())
      if SessionIsActive() then
        import("/lua/keymap/hotbuild.lua").addModifiers()
        import("/lua/keymap/hotkeylabels.lua").init()
      end
    end)
  end)
  return {
    CategoryMatcher = CategoryMatcher,
    CategoryAction = CategoryAction,
    SelectionAction = SelectionAction,
    ProcessAction = ProcessAction,
    AddSimpleAction = AddSimpleAction,
    FormatActionName = GetFormattedName
  }
end
