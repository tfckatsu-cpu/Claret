-- Generated research-only output. Original SHA256: 2c1572037094646806c3e4d5929e71c3fc98bdeecbefb7c85f732264f5399924. Not for game execution.
local UIUtil = import("/lua/ui/uiutil.lua")
local Tooltip = import("/lua/ui/game/tooltip.lua")
local Group = ReUI.UI.Controls.Group
local Bitmap = ReUI.UI.Controls.Bitmap
local Text = ReUI.UI.Controls.Text
local options = ReUI.Options.Mods["ReUI.Score"]
local textSize = 12
local panelWidth = 300
local panelHeight = 20

local function GetSizeInKM(size)
  return size / 512 * 10
end

local function FormatMapName(name)
  if name:find("neroxis_map_generator") then
    return "Neroxis Map Generator", true
  end
  return name, false
end

InfoPanel = ReUI.Core.Class(Group)({
  __init = function(self, parent)
    Group.__init(self, parent)
    self._mapName = Text(self)
    self._mapSize = Text(self)
  end,
  InitLayout = function(self, layouter)
    local parent = self:GetParent()
    self._mapName:SetFont(options.title.font.mapName:Raw(), textSize)
    layouter(self._mapName):AtCenterIn(self)
    self._mapSize:SetFont(options.title.font.mapSize:Raw(), textSize)
    layouter(self._mapSize):AtVerticalCenterIn(self):AtRightIn(self, 10):DisableHitTest()
    layouter(self):Width(parent.Width):Height(panelHeight):DisableHitTest()
  end,
  Setup = function(self)
    local sessionInfo = SessionGetScenarioInfo()
    local mapWidth = sessionInfo.size[1]
    local mapHeight = sessionInfo.size[2]
    local areaData = Sync.NewPlayableArea
    if areaData then
      mapWidth = areaData[3] - areaData[1]
      mapHeight = areaData[4] - areaData[2]
    end
    self._mapSize:SetText(("%.1f x %.1f"):format(GetSizeInKM(mapWidth), GetSizeInKM(mapHeight)))
    local mapName, isMapGen = FormatMapName(sessionInfo.name)
    local mapDescription = sessionInfo.description
    if not mapDescription or mapDescription == "" then
      mapDescription = "No description set by the author."
    end
    mapDescription = ("%s\r\n\r\n%s: %s\r\n%s: %s"):format(LOC(mapDescription), LOC("<LOC map_version>Map version"), tostring(sessionInfo.map_version), LOC("<LOC replay_id>Replay ID"), tostring(UIUtil.GetReplayId()))
    self._mapName:SetText(mapName)
    Tooltip.AddForcedControlTooltipManual(self._mapName, sessionInfo.name, mapDescription)
  end
})
