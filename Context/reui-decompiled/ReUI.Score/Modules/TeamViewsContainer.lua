-- Generated research-only output. Original SHA256: 04fc304c320f278a96fd87d22acad757c9d3ea051bd9e64f821bbb72b3d76f79. Not for game execution.
local Utils = import("Utils.lua")
local ArmyViewsContainer = import("ArmyViewsContainer.lua").ArmyViewsContainer
local ArmyViews = import("ArmyView.lua")
TeamViewsContainer = ReUI.Core.Class(ArmyViewsContainer)({
  _InitArmyViews = function(self)
    local Enumerate = ReUI.LINQ.Enumerate
    local IPairsEnumerator = ReUI.LINQ.IPairsEnumerator
    self._armyViews = {}
    local armiesData = Utils.GetArmiesFormattedTable()
    local teams = Enumerate(armiesData):Select("teamId"):AsSet():ToTable()
    self._armyDataCache = armiesData
    if table.getsize(teams) == table.getn(armiesData) then
      return
    end
    teams = Enumerate(teams, next):Select(function(_, id)
      local sameTeamArmiesEnumerator = IPairsEnumerator:Where(function(armyData)
        return armyData.teamId == id
      end)
      return {
        id = id,
        name = ("Team %d"):format(id),
        armies = sameTeamArmiesEnumerator:Enumerate(armiesData):Select("id"):AsSet():ToTable(),
        color = sameTeamArmiesEnumerator:Enumerate(armiesData):First().teamColor,
        rating = sameTeamArmiesEnumerator:Enumerate(armiesData):Select(function(armyData)
          return armyData.rating
        end):Sum()
      }
    end):ToTable()
    for team, _ in teams, nil do
      local teamView = ArmyViews.ReplayTeamView(self)
      table.insert(self._lines, teamView)
      self._armyViews[team] = teamView
    end
    self._teams = teams
    self:SetStaticData()
  end,
  SetStaticData = function(self)
    if not self._teams then
      return
    end
    for team, data in self._teams, nil do
      local teamView = self._armyViews[team]
      teamView:SetStaticData(data.id, data.name, data.rating, data.color, data.armies)
    end
  end,
  Update = function(self, data)
    if not data then
      return
    end
    for i, armyView in self._armyViews, nil do
      armyView:Update(data, self._dataSetup)
    end
  end
})
