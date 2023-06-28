local db = require 'db'
require 'db-stream':bind(db) -- 绑定LuaDB主模块

local f = db.open('assets/f.db')

f:set('a', db.TYPE_STREAM[5])   -- 创建5字节的空间，填充\0
local a = f:stream('a')         -- 打开流
a:write('bf', 64, 1234.5)       -- 写入二进制串
a:seek('set')                   -- 移动指针到头部
print(a:read('bf'))             -- 读取二进制串

local file = io.open('db.lua')  -- 打开文件
local length = file:seek('end') -- 获取文件长度
file:seek('set')                -- 移动到文件头
-- 传入负数，即创建稀疏空间，不填充\0，适合缓冲写入
f:set('db.lua', db.TYPE_STREAM[-length])
-- 打开流对象
local fs = f:stream('db.lua')
-- 缓冲写入数据
while true do
    local s = file:read(1024)
    if not s then
        break
    end
    fs:write(s)
end
print(length, #f:get('db.lua')) -- 26394 26394

f:close()
