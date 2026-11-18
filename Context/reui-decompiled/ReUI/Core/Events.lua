-- Generated research-only output. Original SHA256: 1bd1cb0bc01b4452f8db9a172e296ed6f0c4041fb9443e4a06f8f63df884a171. Not for game execution.
Version = "1.0.0"
ReUI.Require({
  "ReUI.Core >= 1.6.0"
})

function Main()
  local pcall = pcall
  local ipairs = ipairs
  local TableInsert = table.insert
  local TableRemove = table.remove
  local setmetatable = setmetatable
  local getmetatable = getmetatable
  local type = type
  local emptyMetaTable = getmetatable({})
  
  local function IsSimpleTable(t)
    return getmetatable(t) == emptyMetaTable
  end
  
  local EventMethodBindMeta = {
    __eq = function(self, other)
      return self[1] == other[1] and self[2] == other[2]
    end,
    __call = function(self, sender, eventArgs)
      return self[2](self[1], sender, eventArgs)
    end
  }
  
  local function Bind(object, method)
    if object == nil or method == nil then
      error("ReUI.Core.Events.Bind: expected object and method to be non-nil")
    end
    return setmetatable({object, method}, EventMethodBindMeta)
  end
  
  local function FilterEvent(v)
    local ty = type(v)
    if ty == "function" then
      return v
    end
    if ty ~= "table" then
      error("Unsupported event type " .. ty)
    end
    if not IsSimpleTable(v) then
      return v
    end
    if v[1] == nil or v[2] == nil then
      error("ReUI.Core.Events.Bind: expected object and method to be non-nil")
    end
    return setmetatable(v, EventMethodBindMeta)
  end
  
  local function CopyCallbacks(callbacks)
    local t = {}
    for i, f in ipairs(callbacks) do
      t[i] = f
    end
    return t
  end
  
  local Event = ReUI.Core.Class()({
    __init = function(self, name)
      self._name = name or "unnamed"
      self._needsCopy = false
      self._callbacks = nil
    end,
    Add = function(self, callback)
      callback = FilterEvent(callback)
      if self._callbacks == nil then
        self._callbacks = {}
      elseif self._needsCopy then
        self._callbacks = CopyCallbacks(self._callbacks)
        self._needsCopy = false
      end
      TableInsert(self._callbacks, callback)
      return callback
    end,
    Remove = function(self, callback)
      if self._callbacks ~= nil then
        callback = FilterEvent(callback)
        for i, f in ipairs(self._callbacks) do
          if f == callback then
            if self._needsCopy then
              self._callbacks = CopyCallbacks(self._callbacks)
              self._needsCopy = false
            end
            TableRemove(self._callbacks, i)
            return true
          end
        end
      end
      return false
    end,
    Invoke = function(self, sender, eventArgs)
      local callbacks = self._callbacks
      if callbacks == nil then
        return
      end
      self._needsCopy = true
      for i, f in ipairs(callbacks) do
        f(sender, eventArgs)
      end
      self._needsCopy = false
    end,
    Clear = function(self)
      self._callbacks = nil
      self._needsCopy = false
    end
  })
  local SafeEvent = ReUI.Core.Class(Event)({
    Invoke = function(self, sender, eventArgs)
      local callbacks = self._callbacks
      if callbacks == nil then
        return
      end
      self._needsCopy = true
      for i, f in ipairs(callbacks) do
        local ok, err = pcall(f, sender, eventArgs)
        if not ok then
          WARN(("ReUI.Core.Event [%s]: %s"):format(self._name, err))
        end
      end
      self._needsCopy = false
    end
  })
  
  local function SetEvent(self, value, key)
    if type(value) ~= "nil" then
      error(("ReUI.Core.Event [%s]: attempt to manually set event property."):format(key))
    end
    local field = "_event" .. key
    local event = self[field]
    if event == nil then
      return
    end
    event:Clear()
    self[field] = nil
  end
  
  local function EventProperty(class)
    class = class or Event
    return ReUI.Core.Property({
      get = function(self, key)
        local field = "_event" .. key
        local event = self[field]
        if event == nil then
          event = class(key)
          self[field] = event
        end
        return event
      end,
      set = SetEvent
    })
  end
  
  local EventProxy = ReUI.Core.Class()({
    Proxy = function(self, object, key, class)
      self._object = object
      self._key = key
      self._class = class
      return self
    end,
    Add = function(self, callback)
      local object = self._object
      local key = self._key
      local class = self._class
      self:Clear()
      if key == nil or object == nil or class == nil then
        error("EventProxy:Add : attempt to proxy after clear.")
      end
      local event = class(key)
      object["_event" .. key] = event
      return event:Add(callback)
    end,
    Remove = function(self, callback)
      self:Clear()
    end,
    Invoke = function(self, sender, eventArgs)
      self:Clear()
    end,
    Clear = function(self)
      self._object = nil
      self._key = nil
      self._class = nil
    end
  })
  local eventProxy = EventProxy()
  
  local function GetEvent(self, key, class)
    local field = "_event" .. key
    local event = self[field]
    if event then
      return event
    end
    return eventProxy:Proxy(self, key, class)
  end
  
  local function LazyEventProperty(class)
    class = class or Event
    return ReUI.Core.Property({
      get = function(self, key)
        return GetEvent(self, key, class)
      end,
      set = SetEvent
    })
  end
  
  return {
    Bind = Bind,
    EventProperty = EventProperty,
    Event = Event,
    SafeEvent = SafeEvent
  }
end
