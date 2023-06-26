---
--- Generated by LuaDB(https://github.com/limao996/LuaDB)
--- Created by 狸猫呐.
--- DateTime: 2023/6/26 16:26
---

---@type LuaDB
local M = {}

local _NAME = 'db-type'
---@type LuaDB
local super

-- global转local
local pack, unpack, tostring = string.pack, string.unpack, tostring
local type, pairs, setmetatable, getmetatable, error, assert, load, next = type, pairs, setmetatable, getmetatable, error,
    assert, load, next
local math_type, string_dump, table_concat, string_byte = math.type, string.dump, table.concat, string.byte

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

local function hash(s)
    -- 判断为整数，返回整数以减少碰撞
    if math_type(s) == 'integer' then
        if s > 0 then
            return s
        end
    end
    -- 将数值转为字符串处理
    s = tostring(s)
    local l = #s
    local h = l
    local step = (l >> 5) + 1
    for i = l, step, -step do
        h = h ~ ((h << 5) + string_byte(s, i) + (h >> 2))
    end
    return h -- 返回hash值
end

--- 打包数据
---@private
---@param v any 数据
---@return string
local function _pack(v)
    local tp = type(v)
    if tp == 'string' then
        local b = get_int_size(#v)
        tp = 10 + b
        return pack('<Bs' .. b, tp, v)
    elseif math_type(v) == 'integer' then
        local u = 10
        if v < 0 then
            u = 20
            v = -v
        end
        local b = get_int_size(v)
        tp = 200 + u + b
        return pack('<BI' .. b, tp, v)
    elseif tp == 'number' then
        tp = 20
        return pack('<Bn', tp, v)
    elseif tp == 'boolean' then
        tp = 30 + (v and 1 or 0)
        return pack('<B', tp)
    elseif tp == 'function' then
        v = string_dump(v, true)
        local b = get_int_size(#v)
        tp = 40 + b
        return pack('<Bs' .. b, tp, v)
    elseif getmetatable(v) == M.TYPE_ID then
        tp = 70
        return pack('<TssB', v.pointer, v.key, v.name, v.level)
    elseif getmetatable(v) == M.TYPE_ADDR then
        tp = 71
        return pack('<TTTssB', v.pointer, v.addr, v.key_size, v.key,
            v.name, v.level)
    end
end

--- 解包数据
---@private
---@param data string 数据
---@param pos number 位置
---@return number, any, number 类型, 数据, 位置
local function _unpack(data, pos)
    local v
    local tp, pos = unpack('<B', data, pos)
    if tp >= 10 and tp < 20 then
        local b = tp - 10
        v, pos = unpack('<s' .. b, data, pos)
    elseif tp == 20 then
        v, pos = unpack('<n', data, pos)
    elseif tp >= 210 and tp < 220 then
        local b = tp - 210
        v, pos = unpack('<I' .. b, data, pos)
    elseif tp >= 220 and tp < 230 then
        local b = tp - 220
        v = -unpack('<I' .. b, data, pos)
        pos = pos + b
    elseif tp >= 30 and tp < 40 then
        local b = tp - 30
        v = b == 1
    elseif tp >= 40 and tp < 50 then
        local b      = tp - 40
        local s, pos = unpack('<s' .. b, data, pos)
        v            = load(s)
    elseif tp == 70 then
        local po, key, name, level
        po, key, name, level, pos = unpack('<TssB', data, pos)
        local o                   = { pointer = po, key = key, name = name, level = level }
        v                         = setmetatable(o, M.TYPE_ID)
    elseif tp == 71 then
        local po, addr, size, key, name, level
        po, addr, size, key, name, pos, level = unpack('<TTTssB', data, pos)
        local o = { pointer = po, addr = addr, key_size = size, key = key, name = name, level = level }
        v = setmetatable(o, M.TYPE_ADDR)
    end
    return tp, v, pos
end

local SOT = 0
local INDEX = 1
local KEY = 2
local VALUE = 3
local EOT = 4

---@private
---@class NodeStateA
---@field key any
---@field value any
---@field index number
---@field state number|"SOT"|"INDEX"|"KEY"|"VALUE"|"EOT"

---@private
--- 序列化
---@param data any 源数据
---@return string 目标数据
local function serialize(data)
    local last_state ---@type NodeStateA 状态栈顶
    local last_node ---@type any 节点栈顶
    local buffer = {} ---@type string[] 缓冲区
    local node_stack = { data } ---@type any[] 节点栈
    local state_stack = { { state = SOT } } ---@type NodeStateA[] 状态栈
    local buffer_length = 0 ---@type number 缓冲区长度
    local node_count = #node_stack ---@type number 节点数量

    -- 空栈即结束
    while node_count > 0 do
        -- 取栈顶
        last_node = node_stack[node_count]
        last_state = state_stack[node_count]
        do
            -- 打包节点，非数据节点返回nil
            local res = _pack(last_node)
            -- 移入缓冲区并出栈
            if res ~= nil then
                buffer_length = buffer_length + 1
                buffer[buffer_length] = res
                node_stack[node_count] = nil
                state_stack[node_count] = nil
                node_count = node_count - 1
                goto pass
            end
        end

        if last_state.state == SOT then -- 初始化节点
            -- 写入头部
            buffer_length = buffer_length + 1
            buffer[buffer_length] = pack('<B', 51)
            -- 迭代
            local k, v = next(last_node, last_state.key)
            last_state.key = k
            last_state.value = v
            last_state.state = INDEX -- 改变状态
        end

        if last_state.state == INDEX then              -- 进入INDEX状态
            last_state.index = last_state.index or 1   -- 初始化索引计数器
            if last_state.key == last_state.index then -- 连续索引
                -- 入栈
                node_count = node_count + 1
                node_stack[node_count] = last_state.value
                state_stack[node_count] = { state = SOT }
                -- 迭代
                local k, v = next(last_node, last_state.key)
                last_state.key = k
                last_state.value = v
                -- 索引计数
                last_state.index = last_state.index + 1
                goto pass
            end
            -- 索引中断，进入字典区
            buffer_length = buffer_length + 1
            buffer[buffer_length] = pack('<B', 52)
            last_state.state = KEY -- 改变状态
        end

        if last_state.state == KEY then   -- 进入KEY状态
            if last_state.key == nil then -- 节点死亡
                -- 写入尾部并出栈
                buffer_length = buffer_length + 1
                buffer[buffer_length] = pack('<B', 53)
                node_stack[node_count] = nil
                state_stack[node_count] = nil
                node_count = node_count - 1
                goto pass
            end
            -- 入栈
            node_count = node_count + 1
            node_stack[node_count] = last_state.key
            state_stack[node_count] = { key = last_state.key, value = last_state.value, state = SOT }
            last_state.state = VALUE          -- 改变状态
        elseif last_state.state == VALUE then -- 进入VALUE状态
            -- 入栈
            node_count = node_count + 1
            node_stack[node_count] = last_state.value
            -- 迭代
            local k, v = next(last_node, last_state.key)
            last_state.key = k
            last_state.value = v
            state_stack[node_count] = { state = SOT }
            last_state.state = KEY -- 改变状态
        end
        ::pass::
    end
    return table_concat(buffer)
end

---@private
--- 反序列化
---@param data string 二进制数据
---@param pos number 数据位置
---@return any, number 数据, 位置
local function deserialize(data, pos)
    local init_pos = pos or 1 ---@type number 初始位置
    local node_stack = {} ---@type any[] 节点栈
    local state_stack = {} ---@type NodeStateA[] 状态栈
    local node_count = 0 ---@type number 节点数量
    pos = init_pos -- 位置

    if pos > #data then return nil, pos end

    -- 栈底节点死亡即结束
    while pos == init_pos or state_stack[1].state ~= EOT do
        -- 取栈顶
        local last_node = node_stack[node_count] ---@type any 节点栈顶
        local last_state = state_stack[node_count] ---@type NodeStateA 状态栈顶
        local tp ---@type number 类型
        local v ---@type any 值

        if last_state and last_state.state == EOT then -- 节点死亡
            -- 出栈
            state_stack[node_count] = nil
            node_stack[node_count] = nil
            node_count = node_count - 1
            -- 取出新栈顶
            local node = node_stack[node_count]
            local state = state_stack[node_count]
            -- 赋值给上一级节点
            if state.state == INDEX then
                node[#node + 1] = last_node
            elseif state.state == KEY then
                state.key = last_node
                state.state = VALUE
            elseif state.state == VALUE then
                node[state.key] = last_node
                state.state = KEY
            end
            goto pass
        end

        tp, v, pos = _unpack(data, pos) -- 解包
        if tp == 51 then                -- table节点入栈
            node_count = node_count + 1
            node_stack[node_count] = {}
            state_stack[node_count] = { state = INDEX }
        elseif tp == 52 then -- 切换字典区
            last_state.state = KEY
        elseif tp == 53 then -- 杀死节点
            last_state.state = EOT
        else                 -- 非table节点直接入栈
            node_count = node_count + 1
            node_stack[node_count] = v
            state_stack[node_count] = { state = EOT }
        end

        ::pass::
    end

    return node_stack[1], pos
end

--- 打包数据
---
--- 0 空值 1x 定长字符串 20 浮点数 21x 定长正整数 22x 定长负整数
--- 30 布尔值-假 31 布尔值-真 4 函数 5 节点 6 表单 70 成员指针 71 成员地址 8 数组
---@private
---@param v any 数据
---@return number,number,any
function M:pack(v)
    -- 申明变量，并获取数据类型
    local F = self.F
    local byte_order = self.byte_order
    local tp, len = type(v), 0
    if v == nil then
        -- 数值为空，即不写入数据
        tp = 0
        v = ''
        len = 0
    elseif tp == 'string' then
        -- 打包数据
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
        v = pack(byte_order .. 'I' .. addr_size .. 'ssB', v.pointer, v.key, v.name, v.level)
        len = #v
    elseif getmetatable(v) == M.TYPE_ADDR then
        local addr_size = self.addr_size
        tp = 71
        -- pointer addr key_size key name
        v = pack(byte_order .. 'I' .. addr_size .. 'I' .. addr_size .. 'TssB', v.pointer, v.addr, v.key_size, v.key,
            v.name, v.level)
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
---@param addr number 解包地址
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
        for k, v in pairs(self) do
            -- 继承对象
            v0[k] = v
        end
        v0.node_id = addr + 1 -- 设置节点id
        return v0
    elseif tp == 6 then
        local n = unpack(F.T, fw:read(8))
        return (deserialize(fw:read(n))) -- 反序列化
    elseif tp == 70 then
        local addr_size = self.addr_size
        local s = fw:read(addr_size)
        local po = unpack(byte_order .. 'I' .. addr_size, s)
        local n = unpack(F.T, fw:read(8))
        local key = fw:read(n)
        local n = unpack(F.T, fw:read(8))
        local name = fw:read(n)
        local level = unpack(F.B, fw:read(1))

        -- 创建成员指针对象
        local o = { pointer = po, key = key, name = name, level = level }
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
        local level = unpack(F.B, fw:read(1))

        -- 创建成员地址对象
        local o = { pointer = po, addr = addr, key_size = size, key = key, name = name, level = level }
        return setmetatable(o, M.TYPE_ADDR)
    end
end

--- 测量数据
---@private
---@param tp number 数据类型
---@return number 长度
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
        if n < len then
            -- 空间不够，标记碎片，申请新的空间
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
        elseif n > len then
            -- 空间过大，截断并标记多余空间
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

--- 删除成员
---@param k any|LUADB_ID|LUADB_ADDR 成员key
---@return LuaDB
function M:del(k)
    local _k = k
    -- 申明变量
    local F = self.F
    local fw, fm = self.fw, self.fm
    -- 得到成员属性
    local po, addr, size, k, ck, level = self:check_key(k)
    -- key转换类型，用于判断是否碰撞
    k = tostring(k)

    -- 读取原本存储的数据类型和长度
    fw:seek('set', addr + 8 + size)
    local tp = unpack(F.B, fw:read(1))
    local n = self:packsize(tp)

    self:add_gc(addr, addr + 8 + size + 1 + n)

    -- 定义当前簇深度和簇大小
    level = level + 1
    local block_size = self.block_size
    local addr_size = self.addr_size
    local hash_code = (hash(_k) % block_size) + 1 -- 获取hash值
    k = tostring(_k)                              -- key转字符串
    -- 判断数据库可遍历，即留出next属性的空间
    if self.can_each then
        block_size = block_size * 2
        hash_code = hash_code * 2
    end
    -- 计算实际占用空间
    block_size = block_size * addr_size
    -- 计算指针实际位置
    hash_code = hash_code * addr_size

    while true do
        local po1 = (level * block_size) + hash_code
        fm:seek('set', po1)
        local addr1 = fm:read(addr_size)
        if addr1 then
            addr1 = unpack(F.A, addr1)
        else
            addr1 = 0
        end
        local po2 = ((level - 1) * block_size) + hash_code
        fm:seek('set', po2)
        fm:write((pack(F.A, addr1)))

        if addr1 == 0 then
            break
        end
        level = level + 1 -- 下降深度
    end

    return self
end

return M
