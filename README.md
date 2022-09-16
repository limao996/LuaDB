# LuaDB
基于 Lua 的高性能持久化 kv 数据库 *`(lua >= 5.3)`*

## 更新内容
- **`2.5.0`** (2022-9-16 21:14)
  1.修复若干bug
  2.新增流模式

## 联系方式
> QQ：762259384

## 一、导入模块
``` lua
local db = require "db"
```

## 二、配置属性
- **`byte_order`** 字节序&ensp;&ensp;`"="` 跟随系统&ensp;&ensp;`">"` 大端&ensp;&ensp;`<` 小端
- **`block_size`** 簇大小&ensp;&ensp;`必须为8的倍数`
```lua
db.byte_order = '='
db.block_size = 4096 * 8
```

## 三、打开数据库
``` lua
local data = db.open("data.db")
```

## 四、存储数据
- **`set` `put`** 存储 Lua 类型的数据
  `以下为支持的数据类型`
  + **string**
  + **number**
  + **boolean**
  + **table** `建立子数据库`
  + **function** `会丢失调试信息和upvalue`
- **`fset` `fput`** 存储二进制数据
```lua
data:set('a', 123)
data:set('b', true)
data:set('c', '测试')
data:set('d', function()end)
data:set('e', {a=456})
data:fset('k', 'if', 123, 1.2) --格式可参考string.pack
```

## 五、读取数据
- **`get`** 读取 Lua 类型的数据
- **`fget`** 读取二进制数据
```lua
print(data:get('a')) --输出：123.0
print(data:get('b')) --输出：true
print(data:get('c')) --输出：测试
print(data:get('d')) --输出：function
print(data:fget('k', 'if'))
```
> 如果该成员存储了table类型，`get` 方法将返回一个db对象，该对象可调用数据库大部分方法
```lua
local e = data:get('e')
print(e:get('a')) --输出：456.0
e:put('b', 'abc')
print(e:get('b')) --输出：abc
```
> tips: 删除或覆盖 `table` 类型的数据时，其内部成员需要手动删除
```lua
e:remove('a')
e:remove('b')
data:remove('e')
```

## 六、删除成员
``` lua
data:remove('a')
--或
data:set('a', nil)
```

## 七、成员是否存在
``` lua
if data:has('b') then
  --存在
else
  --不存在
end
```

## 八、数据流操作
传入 `db[index]` 可申请存储空间，如 `index` 为负数，则不填充占位符、
```lua
data:put('io', db[8])
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

## 九、关闭数据库
```lua
data:close()
```
