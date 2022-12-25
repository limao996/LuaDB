local db = require 'db'

local c = db.open({
    path = 'database/c.db',
    can_each = true -- 开启遍历支持
})

c:set('a', 1)
c:set('b', 'abc')
c:set('c', false)
c:set('d', nil)

for i = 1, 5 do
    c:set(i, -i)
end

for o in c:each() do -- 返回成员地址对象
    print(o.name, c:get(o)) -- 成员地址对象可作为成员身份使用
end

c:close()

--[[输出内容
a       1
b       abc
c       false
d       nil
1       -1
2       -2
3       -3
4       -4
5       -5
]]
