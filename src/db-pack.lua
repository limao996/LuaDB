---
--- Generated by LuaDB(https://github.com/limao996/LuaDB)
--- Created by 狸猫呐.
--- DateTime: 2023/6/26 16:26
---

---@type LuaDB
local M = {}

local _NAME = 'db-pack'
---@type LuaDB
local super

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

local pack, unpack, getmetatable, setmetatable
= string.pack, string.unpack, getmetatable, setmetatable
local type, load
, next = type, load, next
local math_type, string_dump,
table_concat, table_insert = math.type, string.dump, table.concat, table.insert

--- 计算数值占用字节数
---@private
---@param n number 数值
---@return number 字节数
local function get_int_size(n)
    local b = 0
    for i = 1, 32 do
        b = (b << 8) + 255
        if n <= b then
            return i
        end
    end
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
    elseif getmetatable(v) == M.TYPE_ID
        or getmetatable(v) == M.TYPE_ADDR then
        tp = 7
        return pack('<BTssB', tp, v.pointer, v.key, v.name, v.level)
    end
end

--- 解包数据
---@private
---@param file file 文件句柄
---@return number, any 类型, 数据
local function _unpack(file)
    local v
    local tp = unpack('<B', file:read(1))
    if tp >= 10 and tp < 20 then
        local b = tp - 10
        v = unpack('<I' .. b, file:read(b))
        v = file:read(v)
    elseif tp == 20 then
        v = unpack('<n', file:read(8))
    elseif tp >= 210 and tp < 220 then
        local b = tp - 210
        v = unpack('<I' .. b, file:read(b))
    elseif tp >= 220 and tp < 230 then
        local b = tp - 220
        v = -unpack('<I' .. b, file:read(b))
    elseif tp >= 30 and tp < 40 then
        local b = tp - 30
        v = b == 1
    elseif tp >= 40 and tp < 50 then
        local b = tp - 40
        v = unpack('<I' .. b, file:read(b))
        v = file:read(v)
        v = load(v)
    elseif tp == 7 then
        local po = unpack('<T', file:read(8))
        local n = unpack('<T', file:read(8))
        local key = file:read(n)
        n = unpack('<T', file:read(8))
        local name = file:read(n)
        local level = unpack('<B', file:read(1))
        local o = { pointer = po, key = key, name = name, level = level }
        v = setmetatable(o, M.TYPE_ID)
    end
    return tp, v
end

local SOT = 0
local INDEX = 1
local KEY = 2
local VALUE = 3
local EOT = 4

---@private
---@class NodeStateB
---@field key any
---@field value any
---@field index number
---@field next function
---@field state number|"SOT"|"INDEX"|"KEY"|"VALUE"|"EOT"

--- 数据归档
---@param path string 输出路径
---@return LuaDB
function M:output(path)
    local last_state ---@type NodeStateB 状态栈顶
    local last_node ---@type any 节点栈顶
    local buffer = {} ---@type string[] 缓冲区
    local node_stack = { self } ---@type any[] 节点栈
    local state_stack = { { state = SOT } } ---@type NodeStateB[] 状态栈
    local buffer_length = 0 ---@type number 缓冲区长度
    local node_count = #node_stack ---@type number 节点数量

    local file = io.open(path, 'w') -- 打开文件句柄

    -- 空栈即结束
    while node_count > 0 do
        -- 取栈顶
        last_node = node_stack[node_count]
        last_state = state_stack[node_count]
        local is_database = getmetatable(last_node) == M
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
            if is_database then
                -- 写入头部
                buffer_length = buffer_length + 1
                buffer[buffer_length] = pack('<B', 61)
                -- 初始化迭代器
                last_state.next = last_node:each()
                -- 迭代
                local k, v
                local o = last_state.next()
                if o == nil then
                    k, v = nil
                else
                    k = self:real_name(o)
                    v = self:get(o)
                end
                -- 改变状态
                last_state.key = k
                last_state.value = v
                last_state.state = KEY
            else
                -- 写入头部
                buffer_length = buffer_length + 1
                buffer[buffer_length] = pack('<B', 51)
                -- 迭代
                local k, v = next(last_node, last_state.key)
                -- 改变状态
                last_state.key = k
                last_state.value = v
                last_state.state = INDEX
            end
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
                buffer[buffer_length] = pack('<B', is_database and 63 or 53)
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
            local k, v
            if is_database then
                -- 迭代
                local o = last_state.next()
                if o == nil then
                    k, v = nil
                else
                    k = self:real_name(o)
                    v = self:get(o)
                end
            else
                k, v = next(last_node, last_state.key)
            end
            last_state.key = k
            last_state.value = v
            state_stack[node_count] = { state = SOT }
            last_state.state = KEY -- 改变状态
        end
        ::pass::
        local res = table_concat(buffer)
        if #res > 4096 then
            buffer = {}
            buffer_length = 0
            file:write(res)
        else
            buffer = { res }
            buffer_length = 1
        end
    end
    file:write(table_concat(buffer)):close()
    return self
end

--- 反序列化
---@param path string 输入路径
---@return LuaDB
function M:input(path)
    local file = io.open(path)
    local node_stack = {} ---@type any[] 节点栈
    local state_stack = {} ---@type NodeStateB[] 状态栈
    local node_count = 0 ---@type number 节点数量
    local no_init = true -- 初始化

    -- 栈底节点死亡即结束
    while no_init or state_stack[1].state ~= EOT do
        no_init = false
        -- 取栈顶
        local last_node = node_stack[node_count] ---@type any 节点栈顶
        local last_state = state_stack[node_count] ---@type NodeStateB 状态栈顶
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

        tp, v = _unpack(file) -- 解包
        if tp == 51 then      -- table节点入栈
            node_count = node_count + 1
            node_stack[node_count] = {}
            state_stack[node_count] = { state = INDEX }
        elseif tp == 61 then -- table节点入栈
            node_count = node_count + 1
            node_stack[node_count] = M.TYPE_DB {}
            state_stack[node_count] = { state = KEY }
        elseif tp == 52 then             -- 切换字典区
            last_state.state = KEY
        elseif tp == 53 or tp == 63 then -- 杀死节点
            last_state.state = EOT
        else                             -- 非table节点直接入栈
            node_count = node_count + 1
            node_stack[node_count] = v
            state_stack[node_count] = { state = EOT }
        end

        ::pass::
    end
    self:apply(node_stack[1])
    file:close()
    return self
end

return M
