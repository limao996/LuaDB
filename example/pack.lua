local db = require 'db' -- 导入LuaDB
require 'db-pack':bind(db) -- 导入扩展模块并绑定LuaDB

db.open({ -- 打开数据库
    path = 'assets/g.db',
    can_each = true -- 开启遍历支持
}):apply { -- 写入多条数据
    ['1'] = -1, [6553565535] = 65535,
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    a = 1, b = 1.0, c = 3.14, d = 'hello',
    e = false, f = { 1, 2, 3, { [3.14] = 123 } },
    g = db.TYPE_DB {
        -1, -2, -3,
        a = 0, b = 1, c = -2, d = { -32 }
    }
}:output('assets/g.bin'):close() -- 导出数据并关闭数据库

local h = db.open('assets/h.db')

h:input('assets/g.bin') -- 导入数据

for o in h:each() do -- 遍历数据库
    print(o.name, h:get(o))
end

h:close() -- 关闭数据库
--[[输出内容：
1       0
2       1
3       2
4       3
5       4
6       5
7       6
8       7
9       8
10      9
6553565535      65535
b       1.0
c       3.14
1       -1
f       table: 000001874EE95D00
g       table: 000001874EE958C0
d       hello
e       false
a       1
]]
