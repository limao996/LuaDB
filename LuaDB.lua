local math = require 'math'
local string = require 'string'
local io = require 'io'
local rawget = _G.rawget
local rawset = _G.rawset
local assert = _G.assert
local tostring = _G.tostring
local pairs = _G.pairs
local setmetatable = _G.setmetatable

local _M = {
  __index = _G
}
setmetatable(_M, _M)
local _ENV = _M
local _C = {}

---哈希函数
---@param str any
---@param is boolean
---@return integer
local function toHash(str, is)
  if is then
    str = math.tointeger(str)
    assert(str, 'LuaDB::数组模式仅支持整数型key!')
    return str
  end
  str = tostring(str)
  local len = #str
  local hash = len
  local step = (len >> 5) + 1
  for i = len, step, -step do
    hash = hash ~ ((hash << 5) + str:byte(i) + (hash >> 2))
  end
  return hash % (0xffffffffff // 6)
end

local tp = {
  ['nil'] = 0,
  number = 1,
  boolean = 2,
  table = 3
}

---取数值类型
---@param v any
---@return integer
local function type(v)
  return tp[_G.type(v)] or 4
end

---取数值大小
---@param v any
---@return integer
local function size(v)
  local tp = type(v)
  if tp == 0 then
    return 0
   elseif tp == 1 then
    return 8
   elseif tp == 2 then
    return 1
   elseif tp == 3 then
    return 6
  end
  return 8 + #v
end

---打包数据
---@param v any
---@return string
local function pack(v)
  local tp = type(v)
  if tp == 0 then
    return ''
   elseif tp == 1 then
    return string.pack('n', v)
   elseif tp == 2 then
    return v and '\1' or '\0'
   elseif tp == 3 then
    return string.pack('I6', toHash(v, false))
  end
  return string.pack('s', tostring(v))
end

---创建数据库
---@param path string
local function newDB(path)
  local f = io.open(path, 'wb')
  f:close()

  local f = io.open(path .. '.map', 'wb')
  f:write(string.pack('I', 0))
  f:close()

  local f = io.open(path .. '.cache', 'wb')
  f:write(string.pack('I', 0))
  f:close()
end

---元方法
---@param self table
---@param k any
---@return any
local function _get(self, k)
  local v = _M[k]
  if v then
    return v
  end
  v = rawget(self, k)
  if v then
    return v
  end
  return _M.get(self, k)
end

---元方法
---@param self table
---@param k any
---@param v any
local function _set(self, k, v)
  if rawget(self, k) then
    rawset(self, k, v)
    return
  end

  _M.set(self, k, v)
end

---元方法
---@param self table
---@param k any
---@return any
local function _get2(self, k)
  local v = _C[k]
  if v then
    return v
  end
  v = rawget(self, k)
  if v then
    return v
  end
  return _C.get(self, k)
end

---元方法
---@param self table
---@param k any
---@param v any
local function _set2(self, k, v)
  _C.set(self, k, v)
end

---打开数据库
---@param path string 
---@param is boolean
---@return void
function open(path, is)
  local self = {
    __index = _get,
    __newindex = _set,
    __len = _M.length,
    __close = _M.close
  }

  if not io.open(path) then
    newDB(path)
  end

  self.fw = io.open(path, 'r+b')
  self.fm = io.open(path .. '.map', 'r+b')
  self.fc = io.open(path .. '.cache', 'r+b')
  self.isArray = is or false

  return setmetatable(self, self)
end

---修改数据库
---@param k any
---@param v any
---@return void
function _M:set(k, v)
  local fw = self.fw
  local addr = self:addr(toHash(k, self.isArray), size(v))
  fw:seek('set', addr)
  fw:write(string.pack('b', type(v)))
  fw:write(pack(v))
  fw:flush()

  if type(v) == 3 then
    local t = self:get(k)
    for k, v in pairs(v) do
      t:set(k, v)
    end
  end

  return self
end

---取长度
---@param is boolean
---@return integer
function _M:length(is)
  local fm = self.fm
  if not is then
    return fm:seek('end') / 6
  end
  fm:seek('set')
  local n = string.unpack('I', fm:read(4))
  return n
end

---数据库寻址
---@param size integer
---@param pointer integer
---@return integer
function _M:addr(pointer, size)
  local fw = self.fw
  local fm = self.fm

  fm:seek('set', 4 + ((pointer - 1) * 6))
  local addr = fm:read(6)
  if addr then
    addr = string.unpack('I', addr)
   else
    addr = 0
  end

  if not size then
    return addr
  end

  if addr > 0 then
    fw:seek('set', addr)
    local len = 0
    local s = string.unpack('b', fw:read(1))
    if s == 1 then
      len = 8
     elseif s == 2 then
      len = 1
     elseif s == 3 then
      len = string.unpack('I6', fw:read(6)) + 6
     elseif s == 4 then
      len = string.unpack('I8', fw:read(8)) + 8
    end
    if len < size then
      self:pushCache(addr, len)
      addr = 0
    end
  end

  if addr == 0 then
    addr = self:scanCache(size)
    if addr > 0 then
      return addr
    end
    addr = fw:seek('end')
    if addr == 0 then
      addr = 1
    end
    fm:seek('set', 4 + ((pointer - 1) * 6))
    fm:write(string.pack('I6', addr))
    fm:seek('set')
    local n = string.unpack('I', fm:read(4))
    fm:seek('set')
    fm:write(string.pack('I', n + 1))
    fm:flush()
    fw:write(string.unpack('b', 0))
    fw:flush()
  end

  return addr
end

---扫描碎片
---@param size integer
---@return integer
function _M:scanCache(size)
  local fc = self.fc
  fc:seek('set')
  local len = string.unpack('I', fc:read(4))
  if len == 0 then
    return 0
  end
  for i = 1, len do
    local s, e = string.unpack('I6I6', fc:read(12))
    if e - s >= size then
      fc:seek('cur', -12)
      if e - s > size then
        fc:write(string.pack('I6', s + size))
       else
        fc:write(string.pack('I6I6', 0, 0))
      end
      fc:flush()
      return s
    end
  end
  return 0
end

---添加碎片
---@param addr integer
---@param size integer
---@return void
function _M:pushCache(addr, size)
  local fc = self.fc
  fc:seek('set')
  local len = string.unpack('I', fc:read(4))

  for i = 1, len do
    local s, e = string.unpack('I6I6', fc:read(12))
    if s == 0 and e == 0 then
      fc:seek('cur', -12)
      fc:write(string.pack('I6I6', addr, addr + size))
      return self
    end
  end

  fc:seek('set')
  fc:write(string.pack('I', len + 1))
  fc:seek('end')
  fc:write(string.pack('II', addr, addr + size))
  fc:flush()
  return self
end

---读取数据库
---@param k any
---@return any
function _M:get(k)
  local fw = self.fw
  local addr = self:addr(toHash(k, self.isArray))

  if addr == 0 then
    return
  end

  fw:seek('set', addr)
  local tp = string.unpack('b', fw:read(1))
  if tp == 0 then
    return nil
   elseif tp == 1 then
    return (string.unpack('n', fw:read(8)))
   elseif tp == 2 then
    return fw:read(1) == '\1'
   elseif tp == 3 then
    local obj = {
      __index = _get2,
      __newindex = _set2
    }

    obj.root = self
    obj.hash = string.unpack('I6', fw:read(6))
    return setmetatable(obj, obj)
   elseif tp == 4 then
    local len = string.unpack('I8', fw:read(8))
    return fw:read(len)
  end
end

---关闭数据库
function _M:close()
  self.fw:close()
  self.fm:close()
  self.fc:close()
end

---修改子表
---@param k any
---@param v any
---@return void
function _C:set(k, v)
  self.root:set((self.hash + toHash(k, false)) % (0xffffffffff // 6), v)
  return self
end

---读取子表
---@param k any
---@return any
function _C:get(k)
  return self.root:get((self.hash + toHash(k, false)) % (0xffffffffff // 6))
end

return _M
