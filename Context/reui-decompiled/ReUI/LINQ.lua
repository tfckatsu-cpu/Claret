-- Generated research-only output. Original SHA256: 18e10266a19bb4d8e940249adbcd9d765133ab93cecc6972115aa6ca4b4dc41f. Not for game execution.
Version = "1.4.0"

function Main(isReplay)
  local _setmetatable = setmetatable
  local _iscallable = iscallable
  local TableInsert = table.insert
  local _getmetatable = getmetatable
  local _next = next
  local _ipairs = ipairs
  local TableGetN = table.getn
  local unpack = unpack
  local TableSize = table.getsize
  local TableSort = table.sort
  local _type = type
  
  local function Identity(v)
    return v
  end
  
  local function CallStatefulIterator(it, k)
    return it(k)
  end
  
  local function SelectIterator(iterator, transformer, selector)
    local selectorType = _type(selector)
    if selectorType == "function" then
      return function(t, k)
        local v
        k, v = iterator(t, k)
        if k == nil then
          return nil, nil
        end
        return k, selector(v, k)
      end, transformer
    elseif selectorType == "string" or selectorType == "number" then
      return function(t, k)
        local v
        k, v = iterator(t, k)
        if k == nil then
          return nil, nil
        end
        return k, v[selector]
      end, transformer
    end
    error("Invalid selector type: " .. selectorType)
  end
  
  local function WhereIterator(iterator, transformer, condition)
    return function(t, k)
      local v
      repeat
        k, v = iterator(t, k)
        if k == nil then
          return nil, nil
        end
      until condition(v, k)
      return k, v
    end, transformer
  end
  
  local function KeysIterator(iterator, transformer)
    return function(t, k)
      k = iterator(t, k)
      return k, k
    end, transformer
  end
  
  local function CreateDistinctIterator(iterator, t)
    local seen
    return function(sk)
      seen = seen or {}
      for k, v in iterator, t do
        if not seen[v] then
          seen[v] = true
          return k, v
        end
      end
      seen = nil
      return nil, nil
    end
  end
  
  local function DistinctIterator(iterator, transformer)
    if transformer then
      return CallStatefulIterator, function(t)
        return CreateDistinctIterator(iterator, transformer(t))
      end
    end
    return CallStatefulIterator, function(t)
      return CreateDistinctIterator(iterator, t)
    end
  end
  
  local function ForeachIterator(iterator, transformer, func)
    return function(t, k)
      local v
      k, v = iterator(t, k)
      if k == nil then
        return nil, nil
      end
      func(v, k)
      return k, v
    end, transformer
  end
  
  local function ReverseTransformer(iterator, transformer)
    if transformer then
      return _ipairs, function(t)
        local nt = {}
        for _, v in iterator, transformer(t) do
          TableInsert(nt, 1, v)
        end
        return nt
      end
    end
    return _ipairs, function(t)
      local nt = {}
      for _, v in iterator, t do
        TableInsert(nt, 1, v)
      end
      return nt
    end
  end
  
  local function IterateMany(iterator, outTable, outKey, inTable, inKey, index)
    if outKey == nil then
      outKey, inTable = iterator(outTable, outKey)
      inKey = nil
      index = 0
      while true do
        local v
        inKey, v = _next(inTable, inKey)
        if inKey ~= nil then
          return outKey, inTable, inKey, index + 1, v
        end
        outKey, inTable = iterator(outTable, outKey)
        if outKey == nil then
          return nil, nil, nil, nil, nil
        end
      end
    end
  end
  
  local function IterateManyWithSelector(iterator, selector, outTable, outKey, inTable, inKey, index)
    if outKey == nil then
      outKey, inTable = iterator(outTable, outKey)
      if outKey == nil then
        return nil, nil, nil, nil, nil
      end
      inTable = selector(inTable, outKey)
      inKey = nil
      index = 0
      while true do
        local v
        inKey, v = _next(inTable, inKey)
        if inKey ~= nil then
          return outKey, inTable, inKey, index + 1, v
        end
        outKey, inTable = iterator(outTable, outKey)
        if outKey == nil then
          return nil, nil, nil, nil, nil
        end
        inTable = selector(inTable, outKey)
      end
    end
  end
  
  local function SelectManyIterator(iterator, transformer, selector)
    if selector then
      if transformer then
        return CallStatefulIterator, function(t)
          t = transformer(t)
          local outerKey, inTable, innerKey
          local curIndex = 0
          return function(_)
            local v
            outerKey, inTable, innerKey, curIndex, v = IterateManyWithSelector(iterator, selector, t, outerKey, inTable, innerKey, curIndex)
            return curIndex, v
          end
        end
      end
      return CallStatefulIterator, function(t)
        local outerKey, inTable, innerKey
        local curIndex = 0
        return function(_)
          local v
          outerKey, inTable, innerKey, curIndex, v = IterateManyWithSelector(iterator, selector, t, outerKey, inTable, innerKey, curIndex)
          return curIndex, v
        end
      end
    end
    if transformer then
      return CallStatefulIterator, function(t)
        t = transformer(t)
        local outerKey, inTable, innerKey
        local curIndex = 0
        return function(_)
          local v
          outerKey, inTable, innerKey, curIndex, v = IterateMany(iterator, t, outerKey, inTable, innerKey, curIndex)
          return curIndex, v
        end
      end
    end
    return CallStatefulIterator, function(t)
      local outerKey, inTable, innerKey
      local curIndex = 0
      return function(_)
        local v
        outerKey, inTable, innerKey, curIndex, v = IterateMany(iterator, t, outerKey, inTable, innerKey, curIndex)
        return curIndex, v
      end
    end
  end
  
  local function GroupByTransformer(iterator, transformer, selector)
    if transformer then
      return _next, function(t)
        local r = {}
        for k, v in iterator, transformer(t) do
          local nk = selector(v, k)
          r[nk] = r[nk] or {}
          TableInsert(r[nk], v)
        end
        return r
      end
    end
    return _next, function(t)
      local r = {}
      for k, v in iterator, t do
        local nk = selector(v, k)
        r[nk] = r[nk] or {}
        TableInsert(r[nk], v)
      end
      return r
    end
  end
  
  local function CountByTransformer(iterator, transformer, selector)
    if transformer then
      return _next, function(t)
        local r = {}
        for k, v in iterator, transformer(t) do
          local nk = selector(v, k)
          r[nk] = (r[nk] or 0) + 1
        end
        return r
      end
    end
    return _next, function(t)
      local r = {}
      for k, v in iterator, t do
        local nk = selector(v, k)
        r[nk] = (r[nk] or 0) + 1
      end
      return r
    end
  end
  
  local function MinTerminator(iterator, transformer, comparer)
    if comparer then
      if transformer then
        return function(t)
          local minValue
          for _, value in iterator, transformer(t) do
            if minValue == nil or not comparer(minValue, value) then
              minValue = value
            end
          end
          return minValue
        end
      end
      return function(t)
        local minValue
        for _, value in iterator, t do
          if minValue == nil or not comparer(minValue, value) then
            minValue = value
          end
        end
        return minValue
      end
    end
    if transformer then
      return function(t)
        local minValue
        for _, value in iterator, transformer(t) do
          if minValue == nil or minValue > value then
            minValue = value
          end
        end
        return minValue
      end
    end
    return function(t)
      local minValue
      for _, value in iterator, t do
        if minValue == nil or minValue > value then
          minValue = value
        end
      end
      return minValue
    end
  end
  
  local function MaxTerminator(iterator, transformer, comparer)
    if comparer then
      if transformer then
        return function(t)
          local maxValue
          for _, value in iterator, transformer(t) do
            if maxValue == nil or comparer(maxValue, value) then
              maxValue = value
            end
          end
          return maxValue
        end
      end
      return function(t)
        local maxValue
        for _, value in iterator, t do
          if maxValue == nil or comparer(maxValue, value) then
            maxValue = value
          end
        end
        return maxValue
      end
    end
    if transformer then
      return function(t)
        local maxValue
        for _, value in iterator, transformer(t) do
          if maxValue == nil or maxValue < value then
            maxValue = value
          end
        end
        return maxValue
      end
    end
    return function(t)
      local maxValue
      for _, value in iterator, t do
        if maxValue == nil or maxValue < value then
          maxValue = value
        end
      end
      return maxValue
    end
  end
  
  local function ReduceTerminator(iterator, transformer, reducer, initial)
    if transformer then
      return function(t)
        local r = initial
        for k, v in iterator, transformer(t) do
          r = reducer(r, v, k)
        end
        return r
      end
    end
    return function(t)
      local r = initial
      for k, v in iterator, t do
        r = reducer(r, v, k)
      end
      return r
    end
  end
  
  local function AscendingSortFunction(selector, comparer)
    if comparer then
      return function(a, b)
        return comparer(selector(a), selector(b))
      end
    end
    return function(a, b)
      return selector(a) < selector(b)
    end
  end
  
  local function DescendingSortFunction(selector, comparer)
    if comparer then
      return function(a, b)
        return not comparer(selector(b), selector(a))
      end
    end
    return function(a, b)
      return selector(b) > selector(a)
    end
  end
  
  local function OrderByTransformer(iterator, transformer, sortFunc)
    if iterator == _ipairs then
      if transformer then
        return _ipairs, function(t)
          local nt = transformer(t)
          TableSort(nt, sortFunc)
          return nt
        end
      end
      return _ipairs, function(t)
        TableSort(t, sortFunc)
        return t
      end
    end
    if transformer then
      return _ipairs, function(t)
        local nt = {}
        for _, v in iterator, transformer(t) do
          TableInsert(nt, v)
        end
        TableSort(nt, sortFunc)
        return nt
      end
    end
    return _ipairs, function(t)
      local nt = {}
      for _, v in iterator, t do
        TableInsert(nt, v)
      end
      TableSort(nt, sortFunc)
      return nt
    end
  end
  
  local function AsSetTransformer(iterator, transformer)
    if transformer then
      return _next, function(t)
        local nt = {}
        for _, v in iterator, transformer(t) do
          nt[v] = true
        end
        return nt
      end
    end
    return _next, function(t)
      local nt = {}
      for _, v in iterator, t do
        nt[v] = true
      end
      return nt
    end
  end
  
  local EnumeratorMeta = {}
  EnumeratorMeta.__index = EnumeratorMeta
  
  function EnumeratorMeta:__call(t)
    local transformer = self.transformer
    if transformer then
      t = transformer(t)
    end
    return self.iterator, t
  end
  
  local function EnumeratorCreate(iterator, transformer)
    return _setmetatable({
      iterator = iterator,
      transformer = transformer or false
    }, EnumeratorMeta)
  end
  
  EnumeratorMeta.Create = EnumeratorCreate
  
  function EnumeratorMeta:Where(condition)
    if condition == nil then
      error("Enumerator:Where: condition is required")
    end
    return EnumeratorCreate(WhereIterator(self.iterator, self.transformer, condition))
  end
  
  function EnumeratorMeta:Select(selector)
    if selector == nil then
      error("Enumerator:Select: selector is required")
    end
    return EnumeratorCreate(SelectIterator(self.iterator, self.transformer, selector))
  end
  
  function EnumeratorMeta:Keys()
    return EnumeratorCreate(KeysIterator(self.iterator, self.transformer))
  end
  
  function EnumeratorMeta:Distinct()
    return EnumeratorCreate(DistinctIterator(self.iterator, self.transformer))
  end
  
  function EnumeratorMeta:Foreach(func)
    if func == nil then
      error("Enumerator:Foreach: func is required")
    end
    return EnumeratorCreate(ForeachIterator(self.iterator, self.transformer, func))
  end
  
  function EnumeratorMeta:Reverse()
    return EnumeratorCreate(ReverseTransformer(self.iterator, self.transformer))
  end
  
  function EnumeratorMeta:GroupBy(selector)
    if selector == nil then
      error("Enumerator:GroupBy: selector is required")
    end
    return EnumeratorCreate(GroupByTransformer(self.iterator, self.transformer, selector))
  end
  
  function EnumeratorMeta:CountBy(selector)
    if selector == nil then
      error("Enumerator:CountBy: selector is required")
    end
    return EnumeratorCreate(CountByTransformer(self.iterator, self.transformer, selector))
  end
  
  function EnumeratorMeta:OrderBy(selector, comparer)
    return EnumeratorCreate(OrderByTransformer(self.iterator, self.transformer, AscendingSortFunction(selector, comparer)))
  end
  
  function EnumeratorMeta:OrderByDescending(selector, comparer)
    return EnumeratorCreate(OrderByTransformer(self.iterator, self.transformer, DescendingSortFunction(selector, comparer)))
  end
  
  function EnumeratorMeta:AsSet()
    return EnumeratorCreate(AsSetTransformer(self.iterator, self.transformer))
  end
  
  function EnumeratorMeta:SelectMany(selector)
    return EnumeratorCreate(SelectManyIterator(self.iterator, self.transformer, selector))
  end
  
  function EnumeratorMeta:Use(fn, ...)
    return EnumeratorCreate(fn(self.iterator, self.transformer, unpack(arg)))
  end
  
  function EnumeratorMeta:Execute(callback)
    if callback == nil then
      error("Enumerator:Execute: callback is required")
    end
    local iterator, transformer = self.iterator, self.transformer
    if transformer then
      return function(t)
        for k, v in iterator, transformer(t) do
          callback(v, k)
        end
      end
    end
    return function(t)
      for k, v in iterator, t do
        callback(v, k)
      end
    end
  end
  
  function EnumeratorMeta:Min(comparer)
    return MinTerminator(self.iterator, self.transformer, comparer)
  end
  
  function EnumeratorMeta:Max(comparer)
    return MaxTerminator(self.iterator, self.transformer, comparer)
  end
  
  function EnumeratorMeta:All(condition)
    local iterator, transformer = self.iterator, self.transformer
    if condition then
      if transformer then
        return function(t)
          for k, value in iterator, transformer(t) do
            if not condition(value, k) then
              return false
            end
          end
          return true
        end
      end
      return function(t)
        for k, value in iterator, t do
          if not condition(value, k) then
            return false
          end
        end
        return true
      end
    end
    if transformer then
      return function(t)
        for _, value in iterator, transformer(t) do
          if not value then
            return false
          end
        end
        return true
      end
    end
    return function(t)
      for _, value in iterator, t do
        if not value then
          return false
        end
      end
      return true
    end
  end
  
  function EnumeratorMeta:Any(condition)
    local iterator, transformer = self.iterator, self.transformer
    if condition then
      if transformer then
        return function(t)
          for k, value in iterator, transformer(t) do
            if condition(value, k) then
              return true
            end
          end
          return false
        end
      end
      return function(t)
        for k, value in iterator, t do
          if condition(value, k) then
            return true
          end
        end
        return false
      end
    end
    if transformer then
      return function(t)
        for _, value in iterator, transformer(t) do
          if value then
            return true
          end
        end
        return false
      end
    end
    return function(t)
      for _, value in iterator, t do
        if value then
          return true
        end
      end
      return false
    end
  end
  
  function EnumeratorMeta:First(condition)
    local iterator, transformer = self.iterator, self.transformer
    if condition then
      if transformer then
        return function(t)
          for k, value in iterator, transformer(t) do
            if condition(value, k) then
              return value
            end
          end
          return nil
        end
      end
      return function(t)
        for k, value in iterator, t do
          if condition(value, k) then
            return value
          end
        end
        return nil
      end
    end
    if transformer then
      return function(t)
        for _, value in iterator, transformer(t) do
          return value
        end
        return nil
      end
    end
    return function(t)
      for _, value in iterator, t do
        return value
      end
      return nil
    end
  end
  
  function EnumeratorMeta:Last(condition)
    local iterator, transformer = self.iterator, self.transformer
    if condition then
      if transformer then
        return function(t)
          local result
          for k, value in iterator, transformer(t) do
            if condition(value, k) then
              result = value
            end
          end
          return result
        end
      end
      return function(t)
        local result
        for k, value in iterator, t do
          if condition(value, k) then
            result = value
          end
        end
        return result
      end
    end
    if transformer then
      return function(t)
        local result
        for _, value in iterator, transformer(t) do
          result = value
        end
        return result
      end
    end
    return function(t)
      local result
      for _, value in iterator, t do
        result = value
      end
      return result
    end
  end
  
  function EnumeratorMeta:Reduce(reducer, initial)
    if reducer == nil then
      error("Enumerator:Reduce: reducer is required")
    end
    return ReduceTerminator(self.iterator, self.transformer, reducer, initial)
  end
  
  function EnumeratorMeta:Average()
    local iterator, transformer = self.iterator, self.transformer
    if transformer then
      return function(t)
        local r, n = 0, 0
        for _, v in iterator, transformer(t) do
          r = r + v
          n = n + 1
        end
        if n == 0 then
          return nil
        end
        return r / n
      end
    end
    return function(t)
      local r, n = 0, 0
      for _, v in iterator, t do
        r = r + v
        n = n + 1
      end
      if n == 0 then
        return nil
      end
      return r / n
    end
  end
  
  function EnumeratorMeta:Count(condition)
    local iterator, transformer = self.iterator, self.transformer
    if condition then
      if transformer then
        return function(t)
          local n = 0
          for k, v in iterator, transformer(t) do
            if condition(v, k) then
              n = n + 1
            end
          end
          return n
        end
      end
      return function(t)
        local n = 0
        for k, v in iterator, t do
          if condition(v, k) then
            n = n + 1
          end
        end
        return n
      end
    end
    if transformer then
      if iterator == _ipairs then
        return function(t)
          t = transformer(t)
          return TableGetN(t)
        end
      end
      if iterator == _next then
        return function(t)
          t = transformer(t)
          return TableSize(t)
        end
      end
      return function(t)
        local n = 0
        for _ in iterator, transformer(t) do
          n = n + 1
        end
        return n
      end
    end
    if iterator == _ipairs then
      return TableGetN
    end
    if iterator == _next then
      return TableSize
    end
    return function(t)
      local n = 0
      for _ in iterator, t do
        n = n + 1
      end
      return n
    end
  end
  
  function EnumeratorMeta:Sum()
    local iterator, transformer = self.iterator, self.transformer
    if transformer then
      return function(t)
        local s = 0
        for _, v in iterator, transformer(t) do
          s = s + v
        end
        return s
      end
    end
    return function(t)
      local s = 0
      for _, v in iterator, t do
        s = s + v
      end
      return s
    end
  end
  
  function EnumeratorMeta:Contains()
    local iterator, transformer = self.iterator, self.transformer
    if transformer then
      return function(t, value)
        for k, v in iterator, transformer(t) do
          if v == value then
            return k
          end
        end
        return nil
      end
    end
    return function(t, value)
      for k, v in iterator, t do
        if v == value then
          return k
        end
      end
      return nil
    end
  end
  
  function EnumeratorMeta:Single(condition)
    local iterator, transformer = self.iterator, self.transformer
    if condition then
      if transformer then
        return function(t)
          local value
          for k, v in iterator, transformer(t) do
            if condition(v, k) then
              if value ~= nil then
                return nil
              end
              value = v
            end
          end
          return value
        end
      end
      return function(t)
        local value
        for k, v in iterator, t do
          if condition(v, k) then
            if value ~= nil then
              return nil
            end
            value = v
          end
        end
        return value
      end
    end
    if transformer then
      return function(t)
        local value
        for k, v in iterator, transformer(t) do
          if value ~= nil then
            return nil
          end
          value = v
        end
        return value
      end
    end
    return function(t)
      local value
      for k, v in iterator, t do
        if value ~= nil then
          return nil
        end
        value = v
      end
      return value
    end
  end
  
  function EnumeratorMeta:ToFunction()
    local iterator, transformer = self.iterator, self.transformer
    if transformer then
      return function(t)
        return iterator, transformer(t)
      end
    end
    return function(t)
      return iterator, t
    end
  end
  
  function EnumeratorMeta:ToIterator()
    local iterator, transformer = self.iterator, self.transformer
    if transformer then
      return function(t)
        t = transformer(t)
        return function(_, k)
          return iterator(t, k)
        end
      end
    end
    return function(t)
      return function(_, k)
        return iterator(t, k)
      end
    end
  end
  
  function EnumeratorMeta:ToArray()
    local iterator, transformer = self.iterator, self.transformer
    if iterator == _ipairs then
      return transformer or Identity
    end
    if transformer then
      return function(t)
        local nt = {}
        for _, v in iterator, transformer(t) do
          TableInsert(nt, v)
        end
        return nt
      end
    end
    return function(t)
      local nt = {}
      for _, v in iterator, t do
        TableInsert(nt, v)
      end
      return nt
    end
  end
  
  function EnumeratorMeta:ToTable(selector)
    local iterator, transformer = self.iterator, self.transformer
    if selector then
      if transformer then
        return function(t)
          local nt = {}
          for k, v in iterator, transformer(t) do
            local nk, nv = selector(k, v)
            nt[nk] = nv
          end
          return nt
        end
      end
      return function(t)
        local nt = {}
        for k, v in iterator, t do
          local nk, nv = selector(k, v)
          nt[nk] = nv
        end
        return nt
      end
    end
    if iterator == _next or iterator == _ipairs then
      return transformer or Identity
    end
    if transformer then
      return function(t)
        local nt = {}
        for k, v in iterator, transformer(t) do
          nt[k] = v
        end
        return nt
      end
    end
    return function(t)
      local nt = {}
      for k, v in iterator, t do
        nt[k] = v
      end
      return nt
    end
  end
  
  function EnumeratorMeta:ToSet()
    local iterator, transformer = self.iterator, self.transformer
    if transformer then
      return function(t)
        local nt = {}
        for _, v in iterator, transformer(t) do
          nt[v] = true
        end
        return nt
      end
    end
    return function(t)
      local nt = {}
      for _, v in iterator, t do
        nt[v] = true
      end
      return nt
    end
  end
  
  local EnumerableMeta = {}
  EnumerableMeta.__index = EnumerableMeta
  
  local function EnumerableCreate(t, iterator, transformer)
    return _setmetatable({
      t = t,
      iterator = iterator or _ipairs,
      transformer = transformer or false
    }, EnumerableMeta)
  end
  
  EnumerableMeta.Enumerate = EnumerableCreate
  
  function EnumerableMeta:__call()
    local t, transformer = self.t, self.transformer
    if transformer then
      t = transformer(t)
    end
    return self.iterator, t
  end
  
  function EnumerableMeta:Clone()
    return EnumerableCreate(self.t, self.iterator, self.transformer)
  end
  
  function EnumerableMeta:Where(condition)
    if condition == nil then
      error("Enumerable:Where: condition is required")
    end
    self.iterator, self.transformer = WhereIterator(self.iterator, self.transformer, condition)
    return self
  end
  
  function EnumerableMeta:Select(selector)
    if selector == nil then
      error("Enumerable:Select: selector is required")
    end
    self.iterator, self.transformer = SelectIterator(self.iterator, self.transformer, selector)
    return self
  end
  
  function EnumerableMeta:Keys()
    self.iterator, self.transformer = KeysIterator(self.iterator, self.transformer)
    return self
  end
  
  function EnumerableMeta:Distinct()
    self.iterator, self.transformer = DistinctIterator(self.iterator, self.transformer)
    return self
  end
  
  function EnumerableMeta:Foreach(func)
    if func == nil then
      error("Enumerable:Foreach: func is required")
    end
    self.iterator, self.transformer = ForeachIterator(self.iterator, self.transformer, func)
    return self
  end
  
  function EnumerableMeta:Reverse()
    self.iterator, self.transformer = ReverseTransformer(self.iterator, self.transformer)
    return self
  end
  
  function EnumerableMeta:GroupBy(selector)
    if selector == nil then
      error("Enumerable:GroupBy: selector is required")
    end
    self.iterator, self.transformer = GroupByTransformer(self.iterator, self.transformer, selector)
    return self
  end
  
  function EnumerableMeta:CountBy(selector)
    if selector == nil then
      error("Enumerable:CountBy: selector is required")
    end
    self.iterator, self.transformer = CountByTransformer(self.iterator, self.transformer, selector)
    return self
  end
  
  function EnumerableMeta:OrderBy(selector, comparer)
    self.iterator, self.transformer = OrderByTransformer(self.iterator, self.transformer, AscendingSortFunction(selector, comparer))
    return self
  end
  
  function EnumerableMeta:OrderByDescending(selector, comparer)
    self.iterator, self.transformer = OrderByTransformer(self.iterator, self.transformer, DescendingSortFunction(selector, comparer))
    return self
  end
  
  function EnumerableMeta:AsSet()
    self.iterator, self.transformer = AsSetTransformer(self.iterator, self.transformer)
    return self
  end
  
  function EnumerableMeta:SelectMany(selector)
    self.iterator, self.transformer = SelectManyIterator(self.iterator, self.transformer, selector)
    return self
  end
  
  function EnumerableMeta:Use(fn, ...)
    self.iterator, self.transformer = fn(self.iterator, self.transformer, unpack(arg))
    return self
  end
  
  function EnumerableMeta:Execute(callback)
    if callback == nil then
      error("Enumerable:Execute: callback is required")
    end
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    for k, v in iterator, t do
      callback(v, k)
    end
  end
  
  function EnumerableMeta:Cache()
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    return EnumerableCreate(t, iterator)
  end
  
  function EnumerableMeta:First(condition)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if condition then
      for k, v in iterator, t do
        if condition(v, k) then
          return v
        end
      end
      return nil
    end
    for _, v in iterator, t do
      return v
    end
    return nil
  end
  
  function EnumerableMeta:Last(condition)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if condition then
      local result
      for k, v in iterator, t do
        if condition(v, k) then
          result = v
        end
      end
      return result
    end
    local result
    for _, v in iterator, t do
      result = v
    end
    return result
  end
  
  function EnumerableMeta:Average()
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    local r, n = 0, 0
    for _, v in iterator, t do
      r = r + v
      n = n + 1
    end
    if n == 0 then
      return nil
    end
    return r / n
  end
  
  function EnumerableMeta:Count(condition)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if condition then
      local n = 0
      for k, v in iterator, t do
        if condition(v, k) then
          n = n + 1
        end
      end
      return n
    end
    if iterator == _ipairs then
      return TableGetN(t)
    end
    if iterator == _next then
      return TableSize(t)
    end
    local n = 0
    for _ in iterator, t do
      n = n + 1
    end
    return n
  end
  
  function EnumerableMeta:Reduce(reducer, initial)
    if reducer == nil then
      error("Enumerable:Reduce: reducer is required")
    end
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    local r = initial
    for k, v in iterator, t do
      r = reducer(r, v, k)
    end
    return r
  end
  
  function EnumerableMeta:Sum()
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    local s = 0
    for _, v in iterator, t do
      s = s + v
    end
    return s
  end
  
  function EnumerableMeta:Contains(value)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    for k, v in iterator, t do
      if v == value then
        return k
      end
    end
    return nil
  end
  
  function EnumerableMeta:Single(condition)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if condition then
      local value
      for k, v in iterator, t do
        if condition(v, k) then
          if value ~= nil then
            return nil
          end
          value = v
        end
      end
      return value
    end
    local value
    for k, v in iterator, t do
      if value ~= nil then
        return nil
      end
      value = v
    end
    return value
  end
  
  function EnumerableMeta:Min(comparer)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if comparer then
      local minValue
      for _, value in iterator, t do
        if minValue == nil or not comparer(minValue, value) then
          minValue = value
        end
      end
      return minValue
    end
    local minValue
    for _, value in iterator, t do
      if minValue == nil or minValue > value then
        minValue = value
      end
    end
    return minValue
  end
  
  function EnumerableMeta:Max(comparer)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if comparer then
      local maxValue
      for _, value in iterator, t do
        if maxValue == nil or comparer(maxValue, value) then
          maxValue = value
        end
      end
      return maxValue
    end
    local maxValue
    for _, value in iterator, t do
      if maxValue == nil or maxValue < value then
        maxValue = value
      end
    end
    return maxValue
  end
  
  function EnumerableMeta:All(condition)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if condition then
      for k, v in iterator, t do
        if not condition(v, k) then
          return false
        end
      end
      return true
    end
    for _, v in iterator, t do
      if not v then
        return false
      end
    end
    return true
  end
  
  function EnumerableMeta:Any(condition)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if condition then
      for k, v in iterator, t do
        if condition(v, k) then
          return true
        end
      end
      return false
    end
    for _, v in iterator, t do
      if v then
        return true
      end
    end
    return false
  end
  
  function EnumerableMeta:ToArray()
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if iterator == _ipairs then
      return t
    end
    local nt = {}
    for _, v in iterator, t do
      TableInsert(nt, v)
    end
    return nt
  end
  
  function EnumerableMeta:ToTable(selector)
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    if selector then
      local nt = {}
      for k, v in iterator, t do
        local nk, nv = selector(k, v)
        nt[nk] = nv
      end
      return nt
    end
    if iterator == _next or iterator == _ipairs then
      return t
    end
    local nt = {}
    for k, v in iterator, t do
      nt[k] = v
    end
    return nt
  end
  
  function EnumerableMeta:ToSet()
    local t, iterator, transformer = self.t, self.iterator, self.transformer
    if transformer then
      t = transformer(t)
    end
    local nt = {}
    for _, v in iterator, t do
      nt[v] = true
    end
    return nt
  end
  
  function EnumeratorMeta:Enumerate(t)
    return EnumerableCreate(t, self.iterator, self.transformer)
  end
  
  return {
    PairsEnumerator = EnumeratorMeta.Create(_next),
    IPairsEnumerator = EnumeratorMeta.Create(_ipairs),
    Enumerate = EnumerableMeta.Enumerate,
    Enumerable = EnumerableMeta,
    Enumerator = EnumeratorMeta
  }
end
