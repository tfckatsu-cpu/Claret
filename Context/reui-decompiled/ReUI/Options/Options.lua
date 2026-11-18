-- Generated research-only output. Original SHA256: 8852cb19165441240f87467d1142cb22fd59791391a491064b7db23623c87503. Not for game execution.
Version = "1.2.0"
ReUI.Require({
  "ReUI.Core >= 1.5.0",
  "ReUI.Core.Events >= 1.0.0",
  "ReUI.LINQ >= 1.0.0",
  "ReUI.UI.Views >= 1.0.0"
})

function Main(isReplay)
  local _rawget = rawget
  local _rawset = rawset
  local _type = type
  local Prefs = import("/lua/user/prefs.lua")
  local isLoadedMains = false
  local optionsMainFuncs = {}
  local OptionRef = import("Modules/OptionRef.lua").OptionRef
  local ReactiveOption = import("Modules/ReactiveOption.lua").ReactiveOption
  local DeprecatedOption = import("Modules/ReactiveOption.lua").DeprecatedOption
  
  local function FormatName(name)
    return (name:gsub("[^A-Za-z0-9]+", "_"))
  end
  
  local function HandleOldPath(ref, modName, optionName, default)
    local value = ref:Get()
    if value ~= nil then
      return value
    end
    modName = FormatName(modName)
    optionName = FormatName(optionName)
    local modOptionsTable = Prefs.GetFromCurrentProfile(modName)
    value = modOptionsTable and modOptionsTable[optionName]
    if value == nil then
      value = default
    end
    ref:Set(value)
    return value
  end
  
  local OptionPrototype = ReUI.Core.Class()({
    __option = true,
    __init = function(self, value, class, type)
      self._value = value
      self._class = class
      self._type = type
    end,
    Create = function(self, modName, optionName)
      local default = self._value
      if default == nil then
        error(("Attempt to set option %s:%s to nil by default, don't do that!"):format(modName, optionName))
      end
      local ref = OptionRef({
        "UIModsOptions",
        modName,
        optionName
      })
      default = HandleOldPath(ref, modName, optionName, default)
      return self._class(ref, default, self._type)
    end
  })
  
  local function MakeDeprecatedOpt(value)
    WARN("ReUI.Options.Opt is deprecated. Use ReUI.Options.OptionValue")
    return OptionPrototype(value, DeprecatedOption)
  end
  
  local function OptionValue(defaultValue)
    return OptionPrototype(defaultValue, ReactiveOption)
  end
  
  local function LoadOptions(values, modName, prefix)
    local options = {}
    for optName, defaultValue in values, nil do
      local opt = prefix and prefix .. "." .. optName or optName
      if _type(defaultValue) ~= "table" then
        error(("ReUI.Options: '%s':'%s' has no option specifier"):format(modName, opt))
      end
      if defaultValue.__option then
        LOG(("ReUI.Options: loading option '%s':'%s'"):format(modName, opt))
        options[optName] = defaultValue:Create(modName, opt)
      else
        options[optName] = LoadOptions(defaultValue, modName, opt)
      end
    end
    return options
  end
  
  local function LoadOptionsFile(modsOptions, modName)
    LOG(("ReUI.Options: Loading options of mod '%s'"):format(modName))
    local path
    local module = ReUI.Get(modName)
    if module and module.Type ~= "file" then
      path = module.Path .. "Options.lua"
    else
      path = string.format("/mods/%s/Options.lua", modName)
    end
    local mainF = import(path).Main
    optionsMainFuncs[modName] = mainF
    local options = _rawget(modsOptions, modName)
    if not options then
      WARN(("ReUI.Options: Error trying to load options of mod '%s'"):format(modName))
      return false
    end
    return true
  end
  
  local ModsOptionsMetaTable = {
    __newindex = function(self, key, value)
      local options = LoadOptions(value, key)
      _rawset(self, key, options)
    end,
    __index = function(self, key)
      if LoadOptionsFile(self, key) then
        return _rawget(self, key)
      end
      error(("ReUI.Options: No options for mod '%s'"):format(key))
    end
  }
  local OptionsSelector = import("Modules/Selector.lua")
  ReUI.Core.OnPreCreateUI(function()
    import("/lua/ui/game/tabs.lua").AddToMenu({
      action = "ReUI.Options",
      label = "ReUI Options",
      tooltip = "ReUI Options",
      func = function()
        if not isLoadedMains then
          for modName, mainF in pairs(optionsMainFuncs) do
            local success, err = pcall(mainF, isReplay)
            if not success then
              LOG(("ReUI.Options: Error loading options of mod '%s'"):format(modName))
              LOG(err)
            end
          end
          isLoadedMains = true
        end
        OptionsSelector.Main()
      end
    })
  end)
  return {
    Builder = {
      AddOptions = OptionsSelector.AddOptions,
      Splitter = OptionsSelector.Splitter,
      Column = OptionsSelector.Column,
      Title = OptionsSelector.Title,
      Color = OptionsSelector.Color,
      Filter = OptionsSelector.Filter,
      Slider = OptionsSelector.Slider,
      TextEdit = OptionsSelector.TextEdit,
      ColorSlider = OptionsSelector.ColorSlider,
      Strings = OptionsSelector.Strings,
      Fonts = OptionsSelector.Fonts
    },
    Mods = setmetatable({}, ModsOptionsMetaTable),
    Opt = MakeDeprecatedOpt,
    OptionValue = OptionValue,
    ReactiveOption = ReactiveOption,
    OptionRef = OptionRef
  }
end
