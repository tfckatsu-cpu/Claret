-- Generated research-only output. Original SHA256: 073c51b6088e671313e9993245f8d766151fe0a0b9ada972d498e3b9372c7216. Not for game execution.
local type = type
local StringSub = string.sub
local StringGSub = string.gsub
local StringFind = string.find
local TableInsert = table.insert

local function EmptySeparatorIterator(s, i)
  if i then
    return nil, nil
  end
  return 1, s
end

local function SplitIterNext(sep)
  if sep == "" then
    return EmptySeparatorIterator
  end
  local _end = 0
  return function(s)
    if _end == nil then
      return nil, nil
    end
    local _start
    local pos = _end + 1
    _start, _end = StringFind(s, sep, pos, true)
    return pos, StringSub(s, pos, _start and _start - 1)
  end
end

local function SplitIter(s, sep)
  return SplitIterNext(sep), s
end

local function Split(s, sep)
  local result = {}
  for _, split in SplitIter(s, sep or " ") do
    TableInsert(result, split)
  end
  return result
end

local function TrimStart(s)
  local r = StringGSub(s, "^%s+", "")
  return r
end

local function TrimEnd(s)
  local r = StringGSub(s, "%s+$", "")
  return r
end

local function Trim(s)
  return TrimEnd(TrimStart(s))
end

String = {
  Trim = Trim,
  TrimStart = TrimStart,
  TrimEnd = TrimEnd,
  Split = Split,
  SplitIter = SplitIter
}
