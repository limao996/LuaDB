local db = require 'db' -- 导入LuaDB主类
require 'db-query':bind(db) -- 绑定扩展模块
db.Exp:bind(_G) -- 绑定表达式到环境

local f = db.open({ -- 打开数据库
    path = 'assets/f.db',
    can_each = true -- 开启遍历支持
})

f:apply { -- 写入数据
    456,
    key1 = 1,
    key2 = 2,
    a = 1,
    key = 0.35,
    ['1'] = '123',
    t = db.TYPE_DB {
        1, 2, 3, 4, 5,
        a = 1, b = 2, c = 3,
        d = db.TYPE_DB { a = 10, b = 11, c = 12 }
    },
    b = db.TYPE_DB {
        a = 4, b = 5, c = 6, e = '23',
        d = { a = 7, b = 8, c = 9 }
    }
}

local fq = f:query()-- 查询数据
    :value(-- 过滤值
        DB { -- 匹配数据库
            a = RANGE(1, 5), -- 匹配1~5范围数值
            d = OR { -- 逻辑或
                DB { -- 匹配数据库
                    a = 10 -- 精确匹配
                },
                TABLE { -- 匹配表单
                    b = 8 -- 精确匹配
                },
            }
        }
    )

-- 迭代查询，返回成员对象
for o in fq:find() do
    -- 如果过滤了数值，成员对象将得到value属性
    print(o.name, o.value)
end
