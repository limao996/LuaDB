local db = require 'db' -- 导入库

db.byte_order = '=' -- 数据库字节序 =为跟随系统 >为大端字节序 <为小端字节序
db.block_size = 4096 * 8 -- 数据库簇大小 指针占8字节 簇大小必须为8的倍数

local test = db.open('test.db') -- 打开数据库

test:put('a', 123) -- 存储数值
test:put('b', true) -- 存储布尔值
test:put('c', '测试') -- 存储字符串
test:put('d', function()
end) -- 存储函数
test:put('e', {
    a = 123
}) -- 创建子表并赋值a

print(test:get('a')) -- 读取数据
print(test:get('b'))
print(test:get('c'))
print(test:get('d'))

local e = test:get('e') -- 获取子表 
print(e:get('a'))
e:put('b', 'abc')
print(e:get('b'))

print(test:has('a')) -- 成员是否存在
test:remove('a') -- 删除成员a
print(test:has('a'))

test:fput('key', 'ii', 123, 456) -- 存储二进制数据
print(test:fget('key', 'ii')) -- 读取二进制数据

if not test:has('io') then
    test:put('io', db[8]) -- 申请8字节的存储空间 负数不填充\0
end
local stream = test:stream('io') -- 打开数据流 仅限string类型
stream:write('abcd') -- 写入数据
stream:write('i', 65535) -- 写入二进制数据
stream:seek('set', 2) -- 移动指针 put数据头 cur偏移 end数据尾
print(stream:read()) -- 读取剩余数据
stream:seek('set') -- 移动指针到数据头
print(stream:read(4)) -- 读取4个字节
print(stream:read('i')) -- 读取二进制数据 仅支持固定字节

local f = test:id('f') -- 获取成员指针
if not f.exist then -- 判断指针是否不存在
    test:put(f, 'pointer') -- 使用指针put
end
print(test:get(f)) -- 使用指针get

test:close() -- 关闭数据库
