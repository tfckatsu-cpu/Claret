-- Generated research-only output. Original SHA256: 3b87bcb81f81fef118e115ce07c8e7ae5dc8d757af96eb3a95f23dff96640a67. Not for game execution.
local TableEmpty = table.empty
local Group = ReUI.UI.Controls.Group
local Bitmap = ReUI.UI.Controls.Bitmap
local Text = ReUI.UI.Controls.Text
local Enumerate = ReUI.LINQ.Enumerate
local ArmyViews = import("ArmyView.lua")
local Utils = import("Utils.lua")
local options = ReUI.Options.Mods["ReUI.Score"]
local inTeamSort = false
options.teamScoreSort:Bind(function(var)
  inTeamSort = var()
end)

local function scoreFunction(score)
  return score.general.score
end

local function MakeScoreSorter()
  local TableSort = table.sort
  local _data
  
  local function Ascending(a, b)
    local data1 = _data[a.id]
    local data2 = _data[b.id]
    if data1 == data2 then
      return a.id < b.id
    end
    return data1 > data2
  end
  
  local function Descending(a, b)
    local data1 = _data[a.id]
    local data2 = _data[b.id]
    if data1 == data2 then
      return a.id < b.id
    end
    return data1 < data2
  end
  
  local function Team(a, b)
    if a.teamId == b.teamId then
      local data1 = _data[a.id]
      local data2 = _data[b.id]
      if data1 == data2 then
        return a.id < b.id
      end
      return data1 > data2
    end
    return a.teamId < b.teamId
  end
  
  return function(lines, data, sortType)
    _data = data
    if sortType == "Ascending" then
      TableSort(lines, Ascending)
    elseif sortType == "Descending" then
      TableSort(lines, Descending)
    elseif sortType == "Team" then
      TableSort(lines, Team)
    end
  end
end

local sorter = MakeScoreSorter()
ArmyViewsContainer = ReUI.Core.Class(Group)({
  __init = function(self, parent)
    Group.__init(self, parent)
    self._armyDataCache = false
    self._lines = {}
    self._armyViews = false
    self._top = nil
    self._bottom = nil
    self._sortFunc = false
    self._sortDirection = false
    self._dataSetup = {
      1,
      1,
      1,
      1,
      1
    }
    self:_InitArmyViews()
  end,
  InitLayout = function(self, layouter)
    local last, first
    for i, armyView in self._lines, nil do
      if i == 1 then
        layouter(armyView):AtRightTopIn(self)
        first = armyView
      else
        layouter(armyView):AnchorToBottom(self._lines[i - 1]):Right(self.Right)
      end
      last = armyView
    end
    if not first then
      layouter(self):Height(0):Width(0):DisableHitTest()
      return
    end
    if last then
      self.Bottom:Set(last.Bottom)
    end
    self._top = self._lines[1]
    self._bottom = last
    layouter(self):Width(self._top.Width):DisableHitTest()
  end,
  _InitArmyViews = function(self)
    self._armyViews = {}
    local armiesData = Utils.GetArmiesFormattedTable()
    table.sort(armiesData, function(a, b)
      if a.teamId ~= b.teamId then
        return a.teamId < b.teamId
      end
      return a.id < b.id
    end)
    for i, armyData in armiesData, nil do
      local armyView = ArmyViews.ReplayArmyView(self)
      armyView:SetStaticData(armyData.id, armyData.name, armyData.rating, armyData.faction, armyData.color, armyData.teamColor, armyData.division)
      armyView.teamId = armyData.teamId
      self._lines[i] = armyView
      self._armyViews[armyData.id] = armyView
    end
    self._armyDataCache = armiesData
  end,
  Update = function(self, data)
    if data then
      for i, armyView in self._armyViews, nil do
        armyView:Update(data[i], self._dataSetup)
      end
    end
    self:Sort()
  end,
  Sort = function(self, scoreData, sortFunc, direction)
    self._sortFunc = sortFunc or self._sortFunc
    if not self._sortFunc then
      if not inTeamSort then
        return
      end
      self._sortFunc = scoreFunction
    end
    direction = direction or self._sortDirection
    self._sortDirection = direction
    local sortType
    if direction == 1 then
      sortType = "Ascending"
    elseif direction == -1 then
      sortType = "Descending"
    elseif inTeamSort then
      sortType = "Team"
    end
    if sortType then
      local scoreCache = scoreData or import("/lua/ui/game/score.lua").GetScoreCache()
      local _sortFunc = self._sortFunc
      local dataTable = Enumerate(self._armyViews, next):Select(function(value, armyId)
        return _sortFunc(scoreCache[armyId])
      end):ToTable()
      sorter(self._lines, dataTable, sortType)
    else
      self._sortFunc = false
      for i, armyData in self._armyDataCache, nil do
        self._lines[i] = self._armyViews[armyData.id]
      end
    end
    self:Layout()
  end,
  Expand = function(self, id)
    for _, armyView in self._armyViews, nil do
      armyView:ExpandData(id)
    end
  end,
  Contract = function(self, id)
    for _, armyView in self._armyViews, nil do
      armyView:ContractData(id)
    end
  end,
  Setup = function(self, setup)
    self._dataSetup = setup
    local scoreCache = import("/lua/ui/game/score.lua").GetScoreCache()
    if TableEmpty(scoreCache) then
      return
    end
    self:Update(scoreCache)
  end
})
