local db = require 'db'
require 'db-type':bind(db) -- 导入扩展模块并绑定LuaDB

local a = db.open('assets/i.db')

-- 更节省空间的类型系统
a:set(1, 123)
a:set(2, 65535)
a:set(3, 3.1415926)
a:set(4, true)
a:set(5, 'hello')
a:set(6, nil)

a:set('push', function(a, b)
    return a + b
end) -- 仅支持lua函数，且会丢失upvalue与调试信息

-- 保存指针
a:set('pointer', a:id(2))
-- 保存地址
a:set('addr', a:addr(5))

print(a:get(1)) -- 123
print(a:get(2)) -- 65535
print(a:get(3)) -- 3.1415926
print(a:get(4)) -- true
print(a:get(5)) -- hello
print(a:get(6)) -- nil

local push = a:get('push')
print(push(123, 456)) -- 579

print('===== po =====:')
local po = a:get('pointer')
print('tostring:', po)
print('pointer:', po.pointer)
print('key:', po.key)
print('name:', po.name)
print('value:', a:get(po))

print('===== addr =====:')
local addr = a:get('addr')
print('tostring:', addr)
print('pointer:', addr.pointer)
print('addr:', addr.addr)
print('key_size:', addr.key_size)
print('key:', addr.key)
print('name:', addr.name)
print('value:', a:get(addr))

a:close()
