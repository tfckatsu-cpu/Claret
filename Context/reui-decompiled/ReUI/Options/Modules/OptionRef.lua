-- Generated research-only output. Original SHA256: cdc721b9ca0b5a02097cb99c09d0767069613288d7cb9388d47a9142aba6ffe6. Not for game execution.
local GetPreference = GetPreference
local SetPreference = SetPreference
local String = ReUI.Core.String

local function IsValidLevels(levels)
  if type(levels) ~= "string" then
    return false
  end
  local pattern = "^[a-zA-Z_][a-zA-Z0-9_]*(%.[a-zA-Z_][a-zA-Z0-9_]*)*$"
  return levels:find(pattern) ~= nil
end

OptionRef = ReUI.Core.Class()({
  __init = function(self, levels)
    local lvls = table.concat(levels, ".")
    self._levels = lvls
  end,
  GetPath = function(self, start)
    if start then
      local ss = String.Split(self._levels, ".")
      return table.concat(ss, ".", start)
    end
    return self._levels
  end,
  Get = function(self, default)
    return GetPreference(self._levels, default)
  end,
  Set = function(self, value)
    SetPreference(self._levels, value)
    return true
  end
})
