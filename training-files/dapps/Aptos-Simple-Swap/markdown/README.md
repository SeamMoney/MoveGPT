# Aptos-Simple-Swap

## 符号含义

```txt
x: a token数量
y: b token数量
x_add:增加池子a token数量
y_add:增加池子b token数量
x_remove:减少池子a token数量
y_remove:减少池子b token数量
lp:流动性代币数量
lp_total:流动性代币总发行量
公式 x * y = k
```

## 添加流动性

```txt
第一次增加流动性
lp = 根号下的x * y - 1000，为提高攻击成本，会销毁1000的流动性

第二次增加流动性
lp = min(x_add / x * lp_total , y_add / y * lp_total)
```

## 减少流动性

```txt
x_remove = lp / lp_total * x
y_remove = lp / lp_total * y
```

## getAmountOut x_add

```txt
(x + x_add) (y - y_remove) = k
y_remove = y - k / (x + x_add)  = x_add * y / (x + x_add)
```

## getAmountIn y_remove

```txt
(x + x_add) (y - y_remove) = k
x_add = k  / (y - y_remove) - x = x * y_remove / (y - y_remove)
```

