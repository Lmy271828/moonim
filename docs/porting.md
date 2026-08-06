# 移植声明：mapbox/earcut → geom/earcut.mbt

本文件按移植合规要求，说明 `geom/earcut.mbt` 中移植代码的来源、许可证、
范围与偏差。

## 原项目

- **名称**：earcut
- **链接**：https://github.com/mapbox/earcut
- **许可证**：ISC License
- **版权**：Copyright (c) 2015, Mapbox

ISC 许可证原文：

```
Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

## 移植范围

- 移植内容：**多边形单环三角化（ear clipping）核心算法**。
  原项目为 JavaScript，本移植以 MoonBit 重写，顶点数据结构从扁平
  `number[]` 改为 `Array[Vec2]`，索引结构从链表节点改为索引数组 +
  游标扫描。
- 移植文件：`geom/earcut.mbt`（文件头保留原版权声明与来源链接）。

## 对原项目的修改与适配

1. 输入改为强类型 `Array[Vec2]`，输出为顶点索引三元组数组
   `Array[(Int, Int, Int)]`（与原项目一致返回索引而非坐标）。
2. 自动检测环方向并统一为逆时针（原项目依赖调用方传入方向 + 符号）。
3. 退化输入防护：削耳停滞（stall）达到环长即终止，避免自相交或
   退化多边形导致死循环；此时返回的三角形可能少于 `n - 2`，已在
   文档注释中明示。

## 尚未移植 / 暂不支持的功能

- **带洞多边形**（原项目的 `eliminateHoles` / 桥接算法）；
- **z-order 哈希加速**（原项目对大多边形的 O(n log n) 优化）——当前
  实现为朴素 O(n²) 耳切，动画场景的多边形规模下可接受；
- **3D 投影三角化**与 **steiner 点 / 结果去退化**（`deviation` 接口）。

后续若补齐带洞三角化，将同步更新本文件与 `geom/earcut.mbt` 文件头。
