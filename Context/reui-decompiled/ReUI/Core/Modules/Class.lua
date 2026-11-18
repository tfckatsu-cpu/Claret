-- Generated research-only output. Original SHA256: 8a3a3e512a5a0edc2ded8b6949f8eb370e068793916d0f9dee353d5041aa1004. Not for game execution.
local rawset = rawset
local type = type
local getmetatable = getmetatable
local setmetatable = setmetatable
local TableEmpty = table.empty
local ipairs = ipairs
local unpack = unpack
local emptyMetaTable = getmetatable({})

local function IsSimpleClass(arg)
  return arg.n == 1 and getmetatable(arg[1]) == emptyMetaTable
end

local function GetError(self, key)
  error(("ReUI.Core.Property: attempt to get '%s' of '%s'"):format(tostring(key), tostring(self)))
end

local function SetError(self, value, key)
  error(("ReUI.Core.Property: attempt to set '%s' on '%s'"):format(tostring(key), tostring(self)))
end

function Property(setup)
  setup.get = setup.get or GetError
  setup.set = setup.set or SetError
  setup.__property = true
  return setup
end

local function MakeProperties(class)
  local setProperties = {}
  local getProperties = {}
  for k, v in class, nil do
    if type(v) == "table" and v.__property then
      if v.get then
        getProperties[k] = v.get
      end
      if v.set then
        setProperties[k] = v.set
      end
    end
  end
  if not TableEmpty(getProperties) then
    function class:__index(key)
      local get = getProperties[key]
      
      if get then
        return get(self, key)
      end
      return class[key]
    end
  end
  if TableEmpty(setProperties) then
    class.__newindex = nil
  else
    function class:__newindex(key, value)
      local set = setProperties[key]
      
      if set then
        return set(self, value, key)
      end
      rawset(self, key, value)
    end
  end
  return class
end

local function CacheClassFields(classes, fields)
  local cache = {}
  for _, field in fields, nil do
    cache[field] = {}
    for i, class in ipairs(classes) do
      if class[field] then
        cache[field][i] = class[field]
        class[field] = false
      end
    end
  end
  return cache
end

local function RestoreClassFields(classes, cache)
  for field, data in cache, nil do
    for i, class in ipairs(classes) do
      if data[i] then
        class[field] = data[i]
      end
    end
  end
end

local function MakeUIClass(bases, spec)
  local cache = CacheClassFields(bases, {"__newindex"})
  if spec then
    spec.__newindex = true
  else
    bases[1].__newindex = true
  end
  local class = Class(unpack(bases))
  if spec then
    class = class(spec)
  end
  RestoreClassFields(bases, cache)
  return MakeProperties(class)
end

function UIClass(...)
  if IsSimpleClass(arg) then
    return MakeUIClass(arg)
  end
  local bases = {
    unpack(arg)
  }
  return function(spec)
    return MakeUIClass(bases, spec)
  end
end
