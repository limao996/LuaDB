local db = require 'db'

local c = db.open({
    path = 'assets/c.db',
    can_each = true -- 开启遍历支持
})

c:apply { -- 写入多条数据
    a = 1,
    b = 'abc',
    c = false,
    d = {}
}

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
d       {}
1       -1
2       -2
3       -3
4       -4
5       -5
]]
