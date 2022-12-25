local db = require 'db'
local d = db.open({
    path = 'database/d.db',
    can_each = true -- 开启遍历支持
})


d:set('a', {
    1, 2, 3
}) -- 存储table表单，具体特性类似json
local a = d:get('a')
print(a[1]) -- 1


d:set('b', db.TYPE_DB {
    11, 12, 13
}) -- 创建子数据库
local b = d:get('b') -- 返回LuaDB对象
print(b:get(1)) -- 11

d:set('c', db.TYPE_DB) -- 空数据库
local c = d:get('c')
c:set('a', 21)
c:set('b', 22)
c:set('c', 23)
for o in c:each() do -- 遍历子数据库
    print(o.name, c:get(o))
end
--[[输出结果
a       21
b       22
c       23
]]

d:close()
