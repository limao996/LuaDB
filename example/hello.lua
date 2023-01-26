local db = require 'db'

local a = db.open('assets/a.db')
-- 以上代码等同于
local b = db.open({
    path = 'assets/b.db', -- 数据库路径
    block_size = 4096, -- 簇大小，适当调整可减少hash碰撞
    can_each = false, -- 遍历支持
    addr_size = db.BIT_32, -- 地址长度
    byte_order = db.BYTE_AUTO -- 二进制字节序
})

a:set(1, 123)
a:set(2, 123.0)
a:set(3, 3.1415926)
a:set(4, true)
a:set(5, 'hello')
a:set(6, nil)

b:set('push', function(a, b)
    return a + b
end) -- 仅支持lua函数，且会丢失upvalue与调试信息

print(a:get(1)) -- 123
print(a:get(2)) -- 123.0
print(a:get(3)) -- 3.1415926
print(a:get(4)) -- true
print(a:get(5)) -- hello
print(a:get(6)) -- nil

local push = b:get('push')
print(push(123, 456)) -- 579

a:close()
b:close()
