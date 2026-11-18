-- Generated research-only output. Original SHA256: c18fc257f991cb294413f0cdfa526cb147ac5d242e3f5752b6395ff430452065. Not for game execution.
Version = "1.1.0"
ReUI.Require({
  "ReUI.Core >= 1.4.0",
  "ReUI.UI >= 1.4.0",
  "ReUI.UI.Controls >= 1.0.0",
  "ReUI.Selection >= 1.0.0"
})

function Main(isReplay)
  local updateCacheTicks = 10
  local updateAllTicks = 50
  local GetSelectedUnits = GetSelectedUnits
  local SelectUnits = SelectUnits
  local GetFocusArmy = GetFocusArmy
  local GameTick = GameTick
  local UISelectionByCategory = UISelectionByCategory
  local GameMain = import("/lua/ui/game/gamemain.lua")
  local CommandMode = import("/lua/ui/game/commandmode.lua")
  
  local function HiddenSelect(callback)
    CommandMode.CacheAndClearCommandMode()
    GameMain.SetIgnoreSelection(true)
    local oldSelection = GetSelectedUnits()
    callback(oldSelection)
    SelectUnits(oldSelection)
    GameMain.SetIgnoreSelection(false)
    CommandMode.RestoreCommandMode(true)
  end
  
  local function ApplyToSelectedUnits(fn)
    local selection = GetSelectedUnits()
    if not selection then
      return
    end
    HiddenSelect(function(currentSelection)
      local cachedTable = {}
      for _, unit in currentSelection, nil do
        cachedTable[1] = unit
        SelectUnits(cachedTable)
        fn(unit)
      end
    end)
  end
  
  local currentArmy, units
  local prevReset = 0
  local prevUpdate = 0
  
  local function ProcessAllUnits()
    UISelectionByCategory("ALLUNITS", false, false, false, false)
    local selection = GetSelectedUnits()
    if not selection then
      return
    end
    for _, unit in selection, nil do
      units[unit:GetEntityId()] = unit
    end
  end
  
  local function UpdateAllUnits()
    HiddenSelect(ProcessAllUnits)
  end
  
  local function OnArmyChanged()
  end
  
  local focused = {}
  
  local function UpdateUnits()
    for id, unit in units, nil do
      if unit:IsDead() then
        units[id] = nil
      else
        local focus = unit:GetFocus()
        if focus and not focus:IsDead() then
          local focusId = focus:GetEntityId()
          if not unit[focusId] then
            focused[focusId] = focus
          end
        end
      end
    end
    for id, unit in focused, nil do
      units[id] = unit
      focused[id] = nil
    end
  end
  
  local function Update()
    local currentTick = GameTick()
    local army = GetFocusArmy()
    if army ~= currentArmy then
      prevReset = 0
      prevUpdate = 0
      currentArmy = army
      units = ReUI.Core.Weak.Value({})
      OnArmyChanged()
    end
    if army ~= -1 and currentTick - updateCacheTicks >= prevUpdate then
      if currentTick - updateAllTicks > prevReset then
        UpdateAllUnits()
        prevReset = currentTick
      end
      UpdateUnits()
      prevUpdate = currentTick
    end
  end
  
  local function Get()
    Update()
    return units
  end
  
  return {
    HiddenSelect = HiddenSelect,
    ApplyToSelectedUnits = ApplyToSelectedUnits,
    Get = Get,
    Overlay = import("Modules/Overlay.lua").Overlay
  }
end
