-- 性能测试
local db = require 'db'

local function test(log, time)
    local time = math.ceil(10000 / time)
    print(log, string.format('%d OP/s', time))
end

print('############ no-each ############')

print('======== key ========')

local sp = db.open('assets/sp.db')
sp:reset()

local a = os.clock()
for i = 1, 10000 do
    sp:set('a' .. i, i)
end
local b = os.clock()
test('new: ', b - a)

local a = os.clock()
for i = 1, 10000 do
    sp:set('a' .. i, -i)
end
local b = os.clock()
test('set: ', b - a)


local a = os.clock()
for i = 1, 10000 do
    sp:get('a' .. i)
end
local b = os.clock()
test('get: ', b - a)

print('======== id =========')

local ids = {}

local a = os.clock()
for i = 1, 10000 do
    ids[i] = sp:id('a' .. i)
end
local b = os.clock()
test('id: ', b - a)

local a = os.clock()
for i = 1, 10000 do
    sp:set(ids[i], i)
end
local b = os.clock()
test('set: ', b - a)


local a = os.clock()
for i = 1, 10000 do
    sp:get(ids[i])
end
local b = os.clock()
test('get: ', b - a)

print('======== addr =======')

local addrs = {}

local a = os.clock()
for i = 1, 10000 do
    addrs[i] = sp:addr(ids[i])
end
local b = os.clock()
test('to: ', b - a)

local a = os.clock()
for i = 1, 10000 do
    sp:addr('a' .. i)
end
local b = os.clock()
test('addr: ', b - a)

local a = os.clock()
for i = 1, 10000 do
    sp:set(addrs[i], -i)
end
local b = os.clock()
test('set: ', b - a)


local a = os.clock()
for i = 1, 10000 do
    sp:get(addrs[i])
end
local b = os.clock()
test('get: ', b - a)

sp:close()



print('############ use-each ############')

print('======== key ========')

local sp = db.open({ -- 打开数据库
    path = 'assets/sp.db',
    can_each = true -- 开启遍历支持
})
sp:reset()

local a = os.clock()
for i = 1, 10000 do
    sp:set('a' .. i, i)
end
local b = os.clock()
test('new: ', b - a)

local a = os.clock()
for i = 1, 10000 do
    sp:set('a' .. i, -i)
end
local b = os.clock()
test('set: ', b - a)


local a = os.clock()
for i = 1, 10000 do
    sp:get('a' .. i)
end
local b = os.clock()
test('get: ', b - a)

print('======== id =========')

local ids = {}

local a = os.clock()
for i = 1, 10000 do
    ids[i] = sp:id('a' .. i)
end
local b = os.clock()
test('id: ', b - a)

local a = os.clock()
for i = 1, 10000 do
    sp:set(ids[i], i)
end
local b = os.clock()
test('set: ', b - a)


local a = os.clock()
for i = 1, 10000 do
    sp:get(ids[i])
end
local b = os.clock()
test('get: ', b - a)

print('======== addr =======')

local addrs = {}

local a = os.clock()
for i = 1, 10000 do
    addrs[i] = sp:addr(ids[i])
end
local b = os.clock()
test('to: ', b - a)

local a = os.clock()
for i = 1, 10000 do
    sp:addr('a' .. i)
end
local b = os.clock()
test('addr: ', b - a)

local a = os.clock()
for i = 1, 10000 do
    sp:set(addrs[i], -i)
end
local b = os.clock()
test('set: ', b - a)

local a = os.clock()
for i = 1, 10000 do
    sp:get(addrs[i])
end
local b = os.clock()
test('get: ', b - a)

print('======== each =======')

local a = os.clock()
for o in sp:each() do
end
local b = os.clock()
test('each: ', b - a)



print('############ db-pack ############')
require 'db-pack':bind(db)

local a = os.clock()
sp:output('assets/sp.bin')
local b = os.clock()
test('output: ', b - a)

sp:close()

local sp = db.open('assets/sp.db')
sp:reset()

local a = os.clock()
sp:input('assets/sp.bin')
local b = os.clock()
test('input: ', b - a)

sp:close()
