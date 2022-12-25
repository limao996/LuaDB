local db = require 'db'
local e = db.open('database/e.db')

e:set('a', 123) -- 初始化成员

-- 成员id，无需查找指针，但要读取地址
local a1 = e:id('a')
-- 成员地址，无需读取地址，效率最高
local a2 = e:addr('a')

for i = 1, 100 do
    local v = e:get(a1) -- 使用成员id
    e:set(a2, v + 1) --使用成员地址
end

local a3 = e:addr(a1) -- 成员id转成员地址
local a4 = e:id(a2) -- 成员地址转成员id
print(e:get(a3)) -- 223
print(e:get(a4)) -- 223

e:close()
