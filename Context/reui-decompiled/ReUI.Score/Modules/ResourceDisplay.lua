-- Generated research-only output. Original SHA256: 60e1e1d796e306857de8d52d3d4dd5707c94f5afa048e495332124cb8e22f816. Not for game execution.
local IsKeyDown = IsKeyDown
local Utils = import("Utils.lua")
local FormatNumber = Utils.FormatNumber
IResourceDisplay = Class()({
  Width = 0,
  Update = function(self, scoreboard)
    return false
  end,
  GetResourceStrings = function(self, resources)
    return "", ""
  end,
  Apply = function(self, allyView)
  end
})
DefaultResourceDisplay = Class(IResourceDisplay)({
  Width = 160,
  __init = function(self)
    self._mode = "income"
  end,
  Update = function(self, scoreboard)
    local mode = self._mode
    local isCtrl = IsKeyDown("control")
    if not isCtrl and scoreboard.isHovered and mode ~= "storage" then
      self._mode = "storage"
      return true
    elseif isCtrl and mode ~= "maxstorage" then
      self._mode = "maxstorage"
      return true
    elseif not isCtrl and not scoreboard.isHovered and mode ~= "income" then
      self._mode = "income"
      return true
    end
    return false
  end,
  GetResourceStrings = function(self, resources)
    local mode = self._mode
    if mode == "income" then
      return FormatNumber(resources.massin.rate * 10), FormatNumber(resources.energyin.rate * 10)
    elseif mode == "storage" then
      return FormatNumber(resources.storage.storedMass), FormatNumber(resources.storage.storedEnergy)
    elseif mode == "maxstorage" then
      return FormatNumber(resources.storage.maxMass), FormatNumber(resources.storage.maxEnergy)
    end
    return "", ""
  end,
  Apply = function(self, allyView)
    local layouter = allyView.Layouter
    layouter(allyView._massBtn):Width(35)
    layouter(allyView._energyBtn):Width(35)
    layouter(allyView._mass):AtRightIn(allyView, 50)
  end
})
FullResourceDisplay = Class(IResourceDisplay)({
  Width = 260,
  GetResourceStrings = function(self, resources)
    return ("%s / %s +%s"):format(FormatNumber(resources.storage.storedMass), FormatNumber(resources.storage.maxMass), FormatNumber(resources.massin.rate * 10)), ("%s / %s +%s"):format(FormatNumber(resources.storage.storedEnergy), FormatNumber(resources.storage.maxEnergy), FormatNumber(resources.energyin.rate * 10))
  end,
  Apply = function(self, allyView)
    local layouter = allyView.Layouter
    layouter(allyView._massBtn):Width(85)
    layouter(allyView._energyBtn):Width(85)
    layouter(allyView._mass):AtRightIn(allyView, 110)
  end
})
PairResourceDisplay = Class(IResourceDisplay)({
  Width = 220,
  __init = function(self)
    self._mode = "income"
  end,
  Update = function(self, scoreboard)
    local mode = self._mode
    local isCtrl = IsKeyDown("control")
    if isCtrl and mode ~= "storage" then
      self._mode = "storage"
      return true
    elseif not isCtrl and mode ~= "income" then
      self._mode = "income"
      return true
    end
    return false
  end,
  GetResourceStrings = function(self, resources)
    local mode = self._mode
    if mode == "income" then
      return ("+%s | %s"):format(FormatNumber(resources.massin.rate * 10), FormatNumber(resources.storage.storedMass)), ("+%s | %s"):format(FormatNumber(resources.energyin.rate * 10), FormatNumber(resources.storage.storedEnergy))
    elseif mode == "storage" then
      return ("%s / %s"):format(FormatNumber(resources.storage.storedMass), FormatNumber(resources.storage.maxMass)), ("%s / %s"):format(FormatNumber(resources.storage.storedEnergy), FormatNumber(resources.storage.maxEnergy))
    end
    return "", ""
  end,
  Apply = function(self, allyView)
    local layouter = allyView.Layouter
    layouter(allyView._massBtn):Width(65)
    layouter(allyView._energyBtn):Width(65)
    layouter(allyView._mass):AtRightIn(allyView, 90)
  end
})
