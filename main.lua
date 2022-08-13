local LuaDB = require 'LuaDB'

local db = LuaDB.open('test.db', false) -- 打开数据库，第二参数为数组模式

db.a = {
  a = 132,
  b = 456,
  c = {
    d = "test",
  }
}

db.b = true

print(db.a.c.d)
print(db.b)
print(#db)

db:close() -- 关闭数据库

