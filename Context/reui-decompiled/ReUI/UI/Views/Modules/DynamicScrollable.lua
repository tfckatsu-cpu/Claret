-- Generated research-only output. Original SHA256: 76d9c0caaa76226e6c3095e47a3cc45cbf35efbdafa211ff1fe8bd7b4cd92753. Not for game execution.
local StaticScrollable = import("StaticScrollable.lua").StaticScrollable
DynamicScrollable = Class(StaticScrollable)({
  Setup = function(self, topIndex, numLines)
    self._topLine = topIndex
    self._dataSize = self:GetDataSize()
    self._numLines = numLines
  end,
  ScrollSetTop = function(self, axis, top)
    self:GetDataSize()
    StaticScrollable.ScrollSetTop(self, axis, top)
  end,
  GetData = function(self)
    return nil
  end,
  GetDataSize = function(self)
    local n = -1
    local data = self:GetData()
    local key
    repeat
      key = self:DataIter(key, data)
      n = n + 1
    until key == nil
    self._dataSize = n
    return n
  end,
  CalcVisible = function(self)
    local data = self:GetData()
    local lineIndex = 1
    local key, value = self:DataIter(nil, data)
    if key ~= nil then
      for i = 1, self._topLine - 1 do
        key, value = self:DataIter(key, data)
      end
    end
    for index = self._topLine, self._numLines + self._topLine - 1 do
      self:RenderLine(lineIndex, index, key, value)
      if key ~= nil then
        key, value = self:DataIter(key, data)
      end
      lineIndex = lineIndex + 1
    end
  end,
  DataIter = function(self, key, data)
    WARN(debug.traceback("Not implemented method!"))
    return nil, nil
  end,
  RenderLine = function(self, lineIndex, scrollIndex, key, value)
    WARN(debug.traceback("Not implemented method!"))
  end
})
