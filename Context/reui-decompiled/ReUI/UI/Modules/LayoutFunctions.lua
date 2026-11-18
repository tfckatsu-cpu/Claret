-- Generated research-only output. Original SHA256: 7bcd9e474ab49c68f73a0c57533a031631a12ca776a5900b5e5ebf6864a448ba. Not for game execution.
local math = math
local iscallable = iscallable
local MathFloor = math.floor
local MathRound = MATH_IRound

local function _MultVarAndValue(var, value)
  if value == 0 then
    return 0
  end
  return function()
    return var() * value
  end
end

function Mult(n1, n2)
  if iscallable(n1) and iscallable(n2) then
    return function()
      return n1() * n2()
    end
  end
  if iscallable(n1) then
    return _MultVarAndValue(n1, n2)
  end
  if iscallable(n2) then
    return _MultVarAndValue(n2, n1)
  end
  return n1 * n2
end

function Div(n1, n2)
  if iscallable(n1) and iscallable(n2) then
    return function()
      return n1() / n2()
    end
  end
  if iscallable(n1) then
    assert(n2 ~= 0, "Attempt to divide by zero")
    return function()
      return n1() / n2
    end
  end
  if iscallable(n2) then
    if n1 == 0 then
      return 0
    end
    return function()
      return n1 / n2()
    end
  end
  return n1 / n2
end

local function _MaxVarOrValue(var, value, scale)
  scale = scale or 1
  if iscallable(scale) then
    return function()
      return math.max(var(), value * scale())
    end
  end
  local offset = value * scale
  return function()
    return math.max(var(), offset)
  end
end

function Max(n1, n2, scale)
  if iscallable(n1) and iscallable(n2) then
    return function()
      return math.max(n1(), n2())
    end
  end
  if iscallable(n1) then
    return _MaxVarOrValue(n1, n2, scale)
  end
  if iscallable(n2) then
    return _MaxVarOrValue(n2, n1, scale)
  end
  scale = scale or 1
  return Mult(math.max(n1, n2), scale)
end

local function _MinVarOrValue(var, value, scale)
  scale = scale or 1
  if iscallable(scale) then
    return function()
      return math.min(var(), value * scale())
    end
  end
  local offset = value * scale
  return function()
    return math.min(var(), offset)
  end
end

function Min(n1, n2, scale)
  if iscallable(n1) and iscallable(n2) then
    return function()
      return math.min(n1(), n2())
    end
  end
  if iscallable(n1) then
    return _MinVarOrValue(n1, n2, scale)
  end
  if iscallable(n2) then
    return _MinVarOrValue(n2, n1, scale)
  end
  scale = scale or 1
  return Mult(math.min(n1, n2), scale)
end

local function _DiffVarAndValue(var, value, scale)
  if value == 0 then
    return var
  end
  scale = scale or 1
  if iscallable(scale) then
    return function()
      return var() - value * scale()
    end
  end
  local offset = value * scale
  return function()
    return var() - offset
  end
end

local function _DiffValueAndVar(value, var, scale)
  if value == 0 then
    return function()
      return -var()
    end
  end
  scale = scale or 1
  if iscallable(scale) then
    return function()
      return value * scale() - var()
    end
  end
  local offset = value * scale
  return function()
    return offset - var()
  end
end

function Diff(n1, n2, scale)
  if iscallable(n1) and iscallable(n2) then
    return function()
      return n1() - n2()
    end
  end
  if iscallable(n1) then
    return _DiffVarAndValue(n1, n2, scale)
  end
  if iscallable(n2) then
    return _DiffValueAndVar(n1, n2, scale)
  end
  scale = scale or 1
  return Mult(n1 - n2, scale)
end

local function _SumVarAndValue(var, value, scale)
  if value == 0 then
    return var
  end
  scale = scale or 1
  if iscallable(scale) then
    return function()
      return var() + value * scale()
    end
  end
  local offset = value * scale
  return function()
    return var() + offset
  end
end

function Sum(n1, n2, scale)
  if iscallable(n1) and iscallable(n2) then
    return function()
      return n1() + n2()
    end
  end
  if iscallable(n1) then
    return _SumVarAndValue(n1, n2, scale)
  end
  if iscallable(n2) then
    return _SumVarAndValue(n2, n1, scale)
  end
  scale = scale or 1
  return Mult(n1 + n2, scale)
end

function Floor(n)
  if iscallable(n) then
    return function()
      return MathFloor(n())
    end
  end
  return MathFloor(n)
end

function Round(n)
  if iscallable(n) then
    return function()
      return MathRound(n())
    end
  end
  return MathRound(n)
end

function AtCenterOffset(base, baseLen, len, offset, scale)
  if offset == 0 then
    return function()
      return base() + 0.5 * (baseLen() - len())
    end
  end
  scale = scale or 1
  if iscallable(scale) then
    return function()
      return base() + 0.5 * (baseLen() - len()) + offset * scale()
    end
  else
    local _offset = offset * scale
    return function()
      return base() + 0.5 * (baseLen() - len()) + _offset
    end
  end
end

function Calculate(value)
  if iscallable(value) then
    return value()
  end
  return value
end

function Conditional(condition, trueVar, falseVar)
  if not iscallable(condition) then
    if condition then
      return trueVar
    else
      return falseVar
    end
  end
  if iscallable(trueVar) and iscallable(falseVar) then
    return function()
      local t = trueVar()
      local f = falseVar()
      if condition() then
        return t
      end
      return f
    end
  end
  if iscallable(trueVar) then
    return function()
      local t = trueVar()
      if condition() then
        return t
      end
      return falseVar
    end
  end
  if iscallable(falseVar) then
    return function()
      local f = falseVar()
      if condition() then
        return trueVar
      end
      return f
    end
  end
  return function()
    if condition() then
      return trueVar
    end
    return falseVar
  end
end
