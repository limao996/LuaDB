# LuaDB

基于 Lua 的高性能本地 kv 数据库 *`(lua >= 5.3)`*

[![license](https://img.shields.io/github/license/limao996/LuaDB.svg)](LICENSE)
[![releases](https://img.shields.io/github/v/tag/limao996/LuaDB?color=C71D23&label=releases&logo=github)](https://gitee.com/AideLua/AideLua/releases)
![](https://img.shields.io/github/last-commit/limao996/LuaDB.svg)

[![Github repository](https://img.shields.io/badge/Github-repository-0969DA?logo=github)](https://github.com/limao996/LuaDB)
[![QQ: 762259384](https://img.shields.io/badge/QQ-762259384-0099FF?logo=tencentqq)](https://qm.qq.com/cgi-bin/qm/qr?k=cXJY7qL3Vm3OKtk8_PjJdgnHqoS_sfGL&noverify=0&personal_qrcode_source=3)

## 更新内容

- **`3.2.3`**（2023-06-26)
    + 删除 `no_flush` 属性
    + 新增 `buffer_size` 属性
    + 新增 `buff` 方法
    + 优化 `del` 方法
    + 更换 `db-type` 的序列化算法
    + 重构 `db-pack` 扩展
    + 支持真正删除成员
- **`3.2.2`**（2023-06-22)
    + 新增 `flush` 方法
    + 新增 `no_flush` 属性
    + 修复 `db-type` 扩展的致命性 bug
    + 新增数据库版本校验
- **`3.2.1`**（2023-05-24)
    + 新增 `db-type` 扩展
- **`3.2.0`**（2023-02-05)
    + 新增 `db-query` 扩展
    + 修复若干 bug
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
    byte_order = db.BYTE_AUTO -- 字节序
})
```

> 缓冲模式
>
> 大幅度提升效率，但需要手动调用 `flush` 方法写入缓冲

``` lua
local data = db.open({
    path = 'data.db',
    buffer_size = 4096, -- 设置缓冲区大小
})
-- data:buff(4096) -- 设置缓冲区大小

data:flush() -- 写入缓冲
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

> tips: 经过新版本优化，现已支持真正删除成员

``` lua
data:del('key') -- 删除成员
-- 以下方法仅用于占位
data:set('key', nil) -- 赋值为nil
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

local h = db.open('assets/h.db')
h:input('assets/g.bin') -- 导入数据
h:close()
```

## 十三、联合查询

> tips: 该功能需绑定 `db-query` 扩展

```lua
local db = require 'db' -- 导入LuaDB
require 'db-query':bind(db) -- 导入扩展模块并绑定LuaDB
db.Exp:bind(_G) -- 绑定表达式到环境
```

- **`db:query`** 打开查询对象
- **`query:key`** 过滤 key
- **`query:value`** 过滤 value
- **`query:find`** 迭代查询
- **`query:findone`** 查询单条
- **`query:map`** 查询并返回数组
- **`query:reset`** 重置位置

> 该模块查询返回 `addr` 对象，过滤值将使之获得 `value` 属性

```lua
local f = db.open { -- 打开数据库
	path = 'assets/f.db',
	can_each = true
}
--打开查询对象
local fq = f:query()
-- 查询单条
fq:findone()
-- 迭代查询50条
for o in fq:find(50) do end
-- 迭代查询剩余全部
for o in fq:find() do end
-- 重置进度
fq:reset()
-- 查询50条 返回数组
fq:map(50)
-- 查询剩余全部 返回数组
fq:map()
```

- **`db.Exp`** 表达式
- **`Exp.EQ`** 等于
- **`Exp.NE`** 不等于
- **`Exp.LT`** 小于
- **`Exp.LTE`** 小于等于
- **`Exp.GT`** 大于
- **`Exp.GTE`** 大于等于
- **`Exp.DB`** 匹配子数据库
- **`Exp.ALL`** 常量 匹配全部
- **`Exp.SIZE`** 表或字符串大小
- **`Exp.TABLE`** 匹配 table
- **`Exp.TYPE`** 常量表 匹配类型
- **`Exp.NOT`** 逻辑 非
- **`Exp.AND`** 逻辑 且
- **`Exp.OR`** 逻辑 或
- **`Exp.REQ`** 正则匹配
- **`Exp.IN`** 属于
- **`Exp.NIN`** 不属于
- **`Exp.RANGE`** 范围
- **`Exp.CONTAIN`** 包含
- **`Exp.NO_CONTAIN`** 不包含

```lua
--打开查询对象
f:query()
 :key(CONTAIN('a')) -- 包含字符串 "a"
 :value(RANGE(0, 100)) -- 匹配范围 0-100
 :map() -- 返回数组
```

```lua
f:query()
 :value(
		AND { -- 逻辑且
			TYPE.STRING, -- 匹配字符串类型
			REQ '^a', -- 正则匹配开头为a的字符串
			OR { -- 逻辑或
				IN { 'a', 'b', 'c' }, -- 匹配属于其中的值
				IN 'abcdefg', -- 匹配属于其中的字符串
				SIZE(LTE(3)) -- 匹配长度小于等于3的字符串或表
			}
		}
)
 :map()
```

```lua
f:query()
 :value(
		DB {         -- 匹配 子数据库
			a = 1, b = 'b', -- 精确匹配
			[ALL] = NE(nil), -- 匹配所有成员 不等于nil
			c = TABLE(SIZE(5)) -- 匹配table大小为5
			-- 参数2为true 满足其中一个条件即通过
			-- 反之为false，不满足其中一个即不通过 默认为false
			-- TABLE表达式与DB表达式用法相同
		}
)
 :map()

```

```lua
-- 自定义表达式
function BEGIN(s)
	return function(v)
		--- 限制类型为 string
		if not TYPE.STRING(v) then return false end
		--匹配开头
		return v:sub(1, #s) == s
	end
end

f:query()
 :value(BEGIN('exp'))
 :map()
```

## 十四、类型重载

> tips: 该功能需绑定 `db-type` 扩展

```lua
local db = require 'db' -- 导入LuaDB
require 'db-type':bind(db) -- 导入扩展模块并绑定LuaDB
```

> 该模块重载了所有数据类型，大幅度减少空间占用，且提供了 `pointer` 与 `addr` 类型
>
> 但可能会影响效率，尽管影响非常小

```lua
-- 保存指针
data:set('pointer', data:id('a'))
-- 保存地址
data:set('addr', data:addr('b'))
```

## 十五、常量

| 名称            | 备注    | 模块          |
|---------------|-------|-------------|
| `BIT_16`      | 地址16位 | `db`        |
| `BIT_24`      | 地址24位 | `db`        |
| `BIT_32`      | 地址32位 | `db`        |
| `BIT_48`      | 地址48位 | `db`        |
| `BIT_64`      | 地址64位 | `db`        |
| `BYTE_LE`     | 小端    | `db`        |
| `BYTE_BE`     | 大端    | `db`        |
| `BYTE_AUTO`   | 跟随系统  | `db`        |
| `TYPE_DB`     | 库类型   | `db`        |
| `TYPE_ID`     | 指针类型  | `db`        |
| `TYPE_ADDR`   | 地址类型  | `db`        |
| `TYPE_STREAM` | 流类型   | `db-stream` |

## 十六、方法

| 名称               | 备注       | 模块          |
|------------------|----------|-------------|
| `db.open`        | 打开数据库    | `db`        |
| `db:reset`       | 重置数据库    | `db`        |
| `db:id`          | 成员id     | `db`        |
| `db:addr`        | 成员地址     | `db`        |
| `db:load_id`     | 加载成员id   | `db`        |
| `db:set`         | 存储数据     | `db`        |
| `db:get`         | 读取数据     | `db`        |
| `db:del`         | 删除数据     | `db`        |
| `db:has`         | 成员是否存在   | `db`        |
| `db:fset`        | 写入二进制数据  | `db`        |
| `db:fget`        | 读取二进制数据  | `db`        |
| `db:each`        | 遍历成员     | `db`        |
| `db:buff`        | 缓冲区大小    | `db`        |
| `db:flush`       | 写入缓冲     | `db`        |
| `db:close`       | 关闭数据库    | `db`        |
| `db:apply`       | 批量存储数据   | `db`        |
| `db:tidy`        | 整理碎片表    | `db`        |
| `db:real_name`   | 成员真实名称   | `db`        |
| `db:input`       | 导入表单     | `db-pack`   |
| `db:output`      | 导出表单     | `db-pack`   |
| `db:stream`      | 打开流      | `db-stream` |
| `stream:length`  | 空间长度     | `db-stream` |
| `stream:seek`    | 移动流指针    | `db-stream` |
| `stream:write`   | 写入数据     | `db-stream` |
| `stream:read`    | 读取数据     | `db-stream` |
| `db:query`       | 打开查询对象   | `db-query`  |
| `query:key`      | 过滤 key   | `db-query`  |
| `query:value`    | 过滤 value | `db-query`  |
| `query:find`     | 迭代查询     | `db-query`  |
| `query:findone`  | 查询单条     | `db-query`  |
| `query:map`      | 查询并返回数组  | `db-query`  |
| `query:reset`    | 重置位置     | `db-query`  |
| `query.Exp`      | 表达式      | `db-query`  |
| `Exp.EQ`         | 等于       | `db-query`  |
| `Exp.NE`         | 不等于      | `db-query`  |
| `Exp.LT`         | 小于       | `db-query`  |
| `Exp.LTE`        | 小于等于     | `db-query`  |
| `Exp.GT`         | 大于       | `db-query`  |
| `Exp.GTE`        | 大于等于     | `db-query`  |
| `Exp.DB`         | 匹配子数据库   | `db-query`  |
| `Exp.ALL`        | 常量 匹配全部  | `db-query`  |
| `Exp.SIZE`       | 表或字符串大小  | `db-query`  |
| `Exp.TABLE`      | 匹配 table | `db-query`  |
| `Exp.TYPE`       | 常量表 匹配类型 | `db-query`  |
| `Exp.NOT`        | 逻辑 非     | `db-query`  |
| `Exp.AND`        | 逻辑 且     | `db-query`  |
| `Exp.OR`         | 逻辑 或     | `db-query`  |
| `Exp.REQ`        | 正则匹配     | `db-query`  |
| `Exp.IN`         | 属于       | `db-query`  |
| `Exp.NIN`        | 不属于      | `db-query`  |
| `Exp.RANGE`      | 范围       | `db-query`  |
| `Exp.CONTAIN`    | 包含       | `db-query`  |
| `Exp.NO_CONTAIN` | 不包含      | `db-query`  |

## 十七、属性

| 名称          | 备注    | 默认值          | 模块 |
|-------------|-------|--------------|----|
| path        | 数据库路径 | nil          | db |
| byte_order  | 字节序   | db.BYTE_AUTO | db |
| addr_size   | 地址位深度 | db.BIT_32    | db |
| can_each    | 遍历支持  | false        | db |
| block_size  | 簇大小   | 4096         | db |
| buffer_size | 缓冲区大小 | 0            | db |
