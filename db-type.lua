---@class LuaDB
local M = {}

local _NAME = 'db-type'
---@type LuaDB
local super

-- global转local
local pack, unpack, tostring = string.pack, string.unpack, tostring
local type, pairs, setmetatable, getmetatable, error, assert, load, next =
    type, pairs, setmetatable, getmetatable, error, assert, load, next
local math_type, string_dump, table_concat, table_insert =
    math.type, string.dump, table.concat, table.insert

---@private
---绑定LuaDB主模块
function M:bind(db)
    assert(db.ver, _NAME .. '::请使用LuaDB 3.2以上版本！')
    assert(db.ver >= 32, _NAME .. '::请使用LuaDB 3.2以上版本！')
    self.bind = nil
    if not db.super then
        super = {}
        for k, v in pairs(db) do
            super[k] = v
        end
        db.super = super
    end
    super = db.super
    for k, v in pairs(self) do
        db[k] = v
        self[k] = nil
    end
    M = db
    return db
end

local function get_int_size(n)
    local b = 0
    for i = 1, 32 do
        b = (b << 8) + 255
        if n <= b then
            return i
        end
    end
end


---序列化类型
local NIL = 0
local STRING = 1
local INTEGER = 2
local DOUBLE = 3
local BOOLEAN = 4
local FUNCTION = 5
local TABLE = 6
local NUMBER = 7

--- 序列化table
---@private
---@param t table
---@return string
local function serialize(t)
    local s = {}
    for k, v in next, t do
        local tp = type(k)
        if tp == 'string' then
            table_insert(s, (pack('Bs2', STRING, k)))
        elseif tp == 'number' then
            table_insert(s, (pack('Bn', NUMBER, k)))
        end
        tp = type(v)
        if tp == 'string' then
            table_insert(s, (pack('Bs4', STRING, v)))
        elseif tp == 'number' then
            if math_type(v) == 'integer' then
                table_insert(s, (pack('Bi8', INTEGER, v)))
            else
                table_insert(s, (pack('Bn', DOUBLE, v)))
            end
        elseif tp == 'boolean' then
            table_insert(s, (pack('BB', BOOLEAN, v and 1 or 0)))
        elseif tp == 'function' then
            table_insert(s, (pack('Bs4', FUNCTION, string_dump(v, true))))
        elseif tp == 'table' then
            table_insert(s, (pack('B', TABLE)))
            table_insert(s, serialize(v))
            table_insert(s, (pack('B', TABLE)))
        else
            table_insert(s, (pack('B', NIL)))
        end
    end
    return table_concat(s)
end

--- 反序列化table
---@private
---@param b string 二进制串
---@return table
local function deserialize(b)
    local pos = 1
    local sf = {}
    local stack = {}
    while true do
        local pop, pass = stack[#stack] or sf
        local tp, k = b:sub(pos, pos)
        pos = pos + 1
        if tp == '' then break end
        tp = unpack('B', tp)
        if tp == NUMBER then
            k = unpack('n', b, pos)
            pos = pos + 8
        elseif tp == STRING then
            k = unpack('s2', b, pos)
            pos = pos + #k + 2
        else
            stack[#stack] = nil
            pass = true
        end
        if not pass then
            local tp, v = b:sub(pos, pos)
            pos = pos + 1
            tp = unpack('B', tp)
            if tp == STRING then
                v = unpack('s4', b, pos)
                pos = pos + #v + 4
            elseif tp == INTEGER then
                v = unpack('i8', b, pos)
                pos = pos + 8
            elseif tp == DOUBLE then
                v = unpack('n', b, pos)
                pos = pos + 8
            elseif tp == BOOLEAN then
                v = unpack('B', b, pos) == 1
                pos = pos + 1
            elseif tp == FUNCTION then
                v = unpack('s4', b, pos)
                pos = pos + #v + 4
                v = load(v)
            elseif tp == TABLE then
                v = {}
                stack[#stack + 1] = v
            end
            pop[k] = v
        end
    end
    return sf
end


--- 打包数据
---
--- 0 空值 1x 定长字符串 20 浮点数 21x 定长正整数 22x 定长负整数
--- 30 布尔值-假 31 布尔值-真 4 函数 5 节点 6 表单 70 成员指针 71 成员地址 8 数组
---@private
---@param v any 数据
---@return integer,integer,any
function M:pack(v)
    -- 申明变量，并获取数据类型
    local F = self.F
    local byte_order = self.byte_order
    local tp, len = type(v), 0
    if v == nil then -- 数值为空，即不写入数据
        tp = 0
        v = ''
        len = 0
    elseif tp == 'string' then -- 打包数据
        local n = #v
        local b = get_int_size(n)
        tp = 10 + b
        v = pack(byte_order .. 's' .. b, v)
        len = b + len
    elseif math_type(v) == 'integer' then
        local u = 10
        if v < 0 then
            u = 20
            v = -v
        end
        local b = get_int_size(v)
        tp = 200 + u + b
        len = b
        v = pack(byte_order .. 'I' .. b, v)
    elseif tp == 'number' then
        tp = 20
        len = 8
        v = pack(F.n, v)
    elseif tp == 'boolean' then
        tp = 30 + (v and 1 or 0)
        len = 0
        v = ''
    elseif tp == 'function' then
        tp = 4
        v = pack(F.s, string_dump(v, true))
        len = #v
    elseif getmetatable(v) == M.TYPE_ID then
        local addr_size = self.addr_size
        tp = 70
        -- pointer key name
        v = pack(byte_order .. 'I' .. addr_size .. 'ss', v.pointer, v.key, v.name)
        len = #v
    elseif getmetatable(v) == M.TYPE_ADDR then
        local addr_size = self.addr_size
        tp = 71
        -- pointer addr key_size key name
        v = pack(byte_order .. 'I' .. addr_size .. 'I' .. addr_size .. 'Tss', v.pointer, v.addr, v.key_size, v.key,
            v.name)
        len = #v
    elseif getmetatable(v) == M.TYPE_DB then
        -- 判断为子数据库，写入起始指针和最近指针
        tp = 5
        v = pack(F.AA, 0, 0)
        len = self.addr_size * 2
    elseif tp == 'table' then
        tp = 6
        v = pack(F.s, serialize(v))
        len = #v
    else
        error('LuaDB::不支持的类型::' .. tp)
    end
    return tp, len, v
end

--- 解包数据
---@private
---@param addr integer 解包地址
---@return any|LUADB_ID|LUADB_ADDR
function M:unpack(addr)
    -- 申明变量
    local F = self.F
    local fw = self.fw
    local byte_order = self.byte_order
    -- 定位到地址
    fw:seek('set', addr)
    -- 获取类型值
    local tp = unpack(F.B, fw:read(1))
    -- 判断类型值并解包
    if tp >= 10 and tp < 20 then
        local b = tp - 10
        local n = unpack(byte_order .. 'I' .. b, fw:read(b))
        return fw:read(n)
    elseif tp == 20 then
        return (unpack(F.n, fw:read(8)))
    elseif tp >= 210 and tp < 220 then
        local b = tp - 210
        return (unpack(byte_order .. 'I' .. b, fw:read(b)))
    elseif tp >= 220 and tp < 230 then
        local b = tp - 220
        return -(unpack(byte_order .. 'I' .. b, fw:read(b)))
    elseif tp >= 30 and tp < 40 then
        local b = tp - 30
        return b == 1
    elseif tp == 4 then
        local n = unpack(F.T, fw:read(8))
        return load(fw:read(n))
    elseif tp == 5 then
        -- 创建子数据库对象
        local v0 = setmetatable({}, M)
        for k, v in pairs(self) do -- 继承对象
            v0[k] = v
        end
        v0.node_id = addr + 1 -- 设置节点id
        return v0
    elseif tp == 6 then
        local n = unpack(F.T, fw:read(8))
        return deserialize(fw:read(n)) -- 反序列化
    elseif tp == 70 then
        local addr_size = self.addr_size
        local s = fw:read(addr_size)
        local po = unpack(byte_order .. 'I' .. addr_size, s)
        local n = unpack(F.T, fw:read(8))
        local key = fw:read(n)
        local n = unpack(F.T, fw:read(8))
        local name = fw:read(n)

        -- 创建成员指针对象
        local o = { pointer = po, key = key, name = name }
        return setmetatable(o, M.TYPE_ID)
    elseif tp == 71 then
        local addr_size = self.addr_size
        local s = fw:read(addr_size)
        local po = unpack(byte_order .. 'I' .. addr_size, s)
        local s = fw:read(addr_size)
        local addr = unpack(byte_order .. 'I' .. addr_size, s)
        local size = unpack(F.T, fw:read(8))
        local n = unpack(F.T, fw:read(8))
        local key = fw:read(n)
        local n = unpack(F.T, fw:read(8))
        local name = fw:read(n)

        -- 创建成员地址对象
        local o = { pointer = po, addr = addr, key_size = size, key = key, name = name }
        return setmetatable(o, M.TYPE_ADDR)
    end
end

--- 测量数据
---@private
---@param tp integer 数据类型
---@return integer 长度
function M:packsize(tp)
    -- 申明变量
    local F = self.F
    local fw = self.fw
    local byte_order = self.byte_order
    -- 判断类型值并解包
    if tp >= 10 and tp < 20 then
        local b = tp - 10
        local n = unpack(byte_order .. 'I' .. b, fw:read(b))
        return b + n
    elseif tp == 20 then
        return 8
    elseif tp >= 210 and tp < 220 then
        local b = tp - 210
        return b
    elseif tp >= 220 and tp < 230 then
        local b = tp - 220
        return b
    elseif tp >= 30 and tp < 40 then
        return 0
    elseif tp == 4 then
        local n = unpack(F.T, fw:read(8))
        return 8 + n
    elseif tp == 5 then
        return self.addr_size * 2
    elseif tp == 6 then
        local n = unpack(F.T, fw:read(8))
        return 8 + n
    elseif tp == 70 then
        local addr_size = self.addr_size
        fw:seek('cur', addr_size)
        local n1 = unpack(F.T, fw:read(8))
        fw:seek('cur', n1)
        local n2 = unpack(F.T, fw:read(8))

        return addr_size + 16 + n1 + n2
    elseif tp == 71 then
        local addr_size = self.addr_size
        fw:seek('cur', (addr_size * 2) + 8)
        local n1 = unpack(F.T, fw:read(8))
        fw:seek('cur', n1)
        local n2 = unpack(F.T, fw:read(8))

        return (addr_size * 2) + 24 + n1 + n2
    end
    return 0
end

--- 写入数据
---@param k any|LUADB_ID|LUADB_ADDR 成员身份
---@param v any|LUADB_DB 值
---@return LuaDB
function M:set(k, v)
    -- 申明变量
    local F = self.F
    local _v = v
    local fw, fm = self.fw, self.fm
    -- 打包数据
    local tp, len, v = self:pack(v)
    -- 得到成员属性
    local po, addr, size, k, ck = self:check_key(k)
    -- key转换类型，用于判断是否碰撞
    k = tostring(k)
    -- 地址不存在，即创建新地址
    if addr == 0 then
        size = #k
        addr = self:scan_gc(len + 8 + size + 1)
        if addr == 0 then
            addr = self:new_addr(po)
        else
            fm:seek('set', po)
            -- 将指针指向数据尾
            fm:write(pack(F.A, addr))
        end
        self:add_next(po)
    else
        -- 读取原本存储的数据类型和长度
        fw:seek('set', addr + 8 + size)
        local tp = unpack(F.B, fw:read(1))
        local n = self:packsize(tp)

        -- 处理成员原本空间
        if n < len then -- 空间不够，标记碎片，申请新的空间
            self:add_gc(addr, addr + 8 + size + 1 + n)
            addr = self:scan_gc(len + 8 + size + 1)
            if addr == 0 then
                addr = self:new_addr(po)
            else
                fm:seek('set', po)
                -- 将指针指向数据尾
                fm:write(pack(F.A, addr))
            end
            if ck then
                ck.addr = addr
            end
        elseif n > len then -- 空间过大，截断并标记多余空间
            self:add_gc(addr + len + 8 + size + 1 + 1, addr + 8 + size + 1 + n)
        end
    end
    -- 写入数据
    fw:seek('set', addr)
    fw:write(pack(F.sB, k, tp))
    fw:write(v)
    -- 处理子数据库的初始成员
    if tp == 5 then
        local v0
        for k, v in pairs(_v) do
            if k ~= '__call' then
                if not v0 then
                    v0 = setmetatable({}, M)
                    for k, v in pairs(self) do
                        v0[k] = v
                    end
                    v0.node_id = addr + 8 + size + 1
                end
                v0:set(k, v)
            end
        end
    end
    return self
end

return M
