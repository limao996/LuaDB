# LuaDB
基于 Lua 的高性能本地 kv 数据库 *`(lua >= 5.3)`*

## 更新内容
- **`3.1.1`**（2023-02-04)
  + `stream` 方法改为扩展模块
- **`3.1.0`**（2023-01-26)
  + 新增 `apply` 与 `tidy` 方法
  + 新增 `db-pack` 扩展
  + 更换了更高效的序列化算法
- **`3.0.0`**（2022-12-25)
  + 重构项目
  + 区分 `integer` 与 `double`
  + 支持迭代器遍历
  + 支持地址操作成员
  + 支持设置地址长度
  + 区分表单与子数据库
- **`2.6.0`**（2022-10-28）
  + 支持指针操作成员
  + 更改 `stream` 的 `read` 方法特性
- **`2.5.0`**（2022-09-16）
  + 修复若干 bug
  + 新增流操作

## 联系方式
> QQ：762259384

## 一、导入模块
``` lua
local db = require "db"
```

## 二、打开数据库
> 默认配置
``` lua
local data = db.open("data.db")
```
> 指定配置
``` lua
local data = db.open({
    path = 'data.db', -- 数据库路径
    block_size = 4096, -- 簇大小，适当调整可减少hash碰撞
    can_each = false, -- 遍历支持
    addr_size = db.BIT_32, -- 地址长度
    byte_order = db.BYTE_AUTO -- 二进制字节序
})
```

## 三、存储数据
- **`set`** 存储数据
- **`fset`** 存储二进制数据
``` lua
data:set(1, 123) -- integer
data:set(2, 123.0) -- double
data:set(4, true) -- boolean 
data:set(5, 'hello') -- string
data:set(6, nil) -- nil
data:set(7, {1, 2, 3}) -- table
data:set('push', function(a, b) -- function
    return a + b
end) -- 仅支持lua函数，且会丢失upvalue与调试信息

data:fset('fmt', 'I', 1234) -- 存储二进制数据

data:apply { -- 批量存储数据
    a1 = 1, a2 = 2, a3 = 3
}
```

## 四、读取数据
- **`get`** 读取数据
- **`fget`** 读取二进制数据
``` lua
print(data:get(1)) -- 123
print(data:get(2)) -- 123.0
print(data:get(3)) -- 3.1415926
print(data:get(4)) -- true
print(data:get(5)) -- hello
print(data:get(6)) -- nil
print(data:get(7)) -- table

local push = data:get('push')
print(push(123, 456)) -- 579

print(data:fget('fmt', 'I'))-- 1234
```

## 五、删除成员
> tips: 该方法只会将成员赋为空值，不会真正删除成员
``` lua
data:del('key')
-- 或
data:set('key', nil)
```

## 六、成员是否存在
``` lua
if data:has('key') then
  -- 存在
else
  -- 不存在
end
```

## 七、遍历成员
``` lua
for o in data:each() do -- 返回成员地址对象
    print(o.name, data:get(o)) -- 成员地址可作为成员标识使用
end
```

## 八、子数据库
> 传入 `db.TYPE_DB` 可创建空数据库
``` lua
data:set('a', db.TYPE_DB) -- 空数据库
local a = data:get('a')
a:set('key', 123)
```
> 传入实例将自动写入内部数据
``` lua
data:set('b', db.TYPE_DB {
    a = 1, b = 2, c = 3
}) -- 创建子数据库
local b = data:get('b') -- 返回LuaDB对象
print(b:get('c')) -- 3
```

## 九、流操作
> tips: 该功能需绑定 `db-stream` 扩展
```lua
local db = require 'db' -- 导入LuaDB
require 'db-stream':bind(db) -- 导入扩展模块并绑定LuaDB
```

传入 `db.TYPE_STREAM[index]` 可创建存储空间，如 `index` 为负数，则不填充占位符、
```lua
data:set('io', db.TYPE_STREAM[8])
```
调用 `stream` 方法获取数据流对象
```lua
local stream = data:stream('io')
```
以下为数据流的api
- **`seek(mode, pos)`** 移动指针
  + **set** `数据头`
  + **cur** `偏移`
  + **end** `数据尾`
- **`write(string)`** 写入数据
- **`write(fmt, ...)`** 写入二进制数据 `格式参考string.pack`
- **`read()`** 读取剩余数据
- **`read(number)`** 读取指定长度
- **`read(fmt)`** 读取二进制数据 `不支持变长类型`

```lua
stream:write('abcd') -- 写入数据
stream:write('i', 65535) -- 写入二进制数据
stream:seek('set', 2) -- 移动指针 set数据头 cur偏移 end数据尾
print(stream:read()) -- 读取剩余数据
stream:seek('set') -- 移动指针到数据头
print(stream:read(4)) -- 读取4个字节
print(stream:read('i')) -- 读取二进制数据 仅支持固定字节
```

## 十、指针与地址
- **`id`** 成员指针
  + **pointer** `指针`
  + **key** `成员key`
  + **name** `成员名称`
- **`addr`** 成员地址
  + **pointer** `指针`
  + **key** `成员key`
  + **key_size** `key长度`
  + **name** `成员名称`
  + **addr** `地址`

> tips: 使用指针或地址访问成员可避免重复寻址
```lua
data:set('a', 123) -- 初始化成员

-- 成员id，无需查找指针，但要读取地址
local a1 = data:id('a')
-- 成员地址，无需读取地址，效率最高
local a2 = data:addr('a')

local v = data:get(a1) -- 使用成员id
data:set(a2, v + 1) --使用成员地址

local a3 = data:addr(a1) -- 成员id转成员地址
local a4 = data:id(a2) -- 成员地址转成员id
print(data:get(a3)) -- 124
print(data:get(a4)) -- 124
```

## 十一、关闭数据库
```lua
data:close()
```

## 十二、打包数据
> tips: 该功能需绑定 `db-pack` 扩展
```lua
local db = require 'db' -- 导入LuaDB
require 'db-pack':bind(db) -- 导入扩展模块并绑定LuaDB
```
- **`input`** 导入表单
- **`output`** 导出表单
```lua
local g = db.open({
    path = 'assets/g.db',
    can_each = true
})
g:output('assets/g.bin') -- 导出数据
g:close()

local h = db.open({
    path = 'assets/h.db',
    can_each = true
})
h:input('assets/g.bin') -- 导入数据
h:close()
```


## 常量
- `BIT_16`  地址16位
- `BIT_24`  地址24位
- `BIT_32`  地址32位
- `BIT_48`  地址48位
- `BIT_64`  地址64位
- `BYTE_LE` 小端
- `BYTE_BE` 大端
- `BYTE_AUTO` 跟随系统
- `TYPE_DB` 库类型
- `TYPE_ID` 指针类型
- `TYPE_ADDR` 地址类型
- db-stream
  + `TYPE_STREAM` 流类型

## 方法
+ `db.open` 打开数据库
+ `db:reset` 重置数据库
+ `db:id` 成员id
+ `db:addr` 成员地址
+ `db:load_id` 加载成员id
+ `db:set` 存储数据
+ `db:get` 读取数据
+ `db:del` 删除数据
+ `db:has` 成员是否存在
+ `db:fset` 写入二进制数据
+ `db:fget` 读取二进制数据
+ `db:each` 遍历成员
+ `db:close` 关闭数据库
+ `db:apply` 批量存储数据
+ `db:tidy` 整理碎片表
+ db-pack
  - `db:input` 导入表单
  - `db:output` 导出表单
+ db-stream
  - `db:stream` 打开流
  - `stream:length` 空间长度
  - `stream:seek` 移动流指针
  - `stream:write` 写入数据
  - `stream:read` 读取数据