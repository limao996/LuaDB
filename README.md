# LuaDB
基于 Lua 的高性能持久化 kv 数据库 *`(lua >= 5.3)`*

## 一、导入模块
``` lua
local db = require "db"
```

## 二、配置属性
- **`byte_order`** 字节序&ensp;&ensp;`"="` 跟随系统&ensp;`">"` 大端&ensp;`"<"` 小端
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
  ~以下为支持的数据类型~
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

## 八、关闭数据库
```lua
data:close()
```

### 联系方式
> QQ：762259384
