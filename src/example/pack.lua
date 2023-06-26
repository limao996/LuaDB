local db = require 'db'    -- 导入LuaDB
require 'db-pack':bind(db) -- 导入扩展模块并绑定LuaDB

local g = db.open({ -- 打开数据库
    path = 'assets/g.db',
    can_each = true -- 开启遍历支持
})

g:apply { -- 写入多条数据
    ['1'] = -1, [6553565535] = 65535,
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    a = 1, b = 1.0, c = 3.14, d = 'hello',
    e = false, f = { 1, 2, 3, { [3.14] = 123 } },
    g = db.TYPE_DB {
        -1, -2, -3,
        a = 0, b = 1, c = -2, d = { -32 }
    }
}

g:set('p', g:addr('d'))

g:output('assets/g.bin')
g:close()           -- 导出数据并关闭数据库

local h = db.open({ -- 打开数据库
    path = 'assets/h.db',
    can_each = true -- 开启遍历支持
})

h:input('assets/g.bin') -- 导入数据

for o in h:each() do
    -- 遍历数据库
    local v = h:get(o)
    print(o.name, v)
end

h:close() -- 关闭数据库
--[[输出内容：
1	0
2	1
3	2
4	3
5	4
6	5
7	6
8	7
9	8
10	9
b	1.0
1	-1
6553565535	65535
a	1
g	LuaDB: assets/h.db
f	table: 00000000007C68E0
e	false
d	hello
c	3.14
p	LuaDB @id: 0x430
]]
