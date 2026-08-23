# moonim

一个纯 MoonBit 实现的**数学动画引擎内核**（mathematical animation engine kernel）：
贝塞尔几何、Mobject 场景图、类型化动画组合子与公式子集排版，输出 SVG 帧序列。
灵感来自 [Manim](https://github.com/3b1b/manim)，但架构上是独立重写（详见
[docs/design.md](docs/design.md)）。

> 当前版本 v0.1.0：可构建、可测试、示例可运行的工程骨架。
> 目标规模与边界见下文「功能边界」一节。

## 快速开始

```bash
# 安装 MoonBit 工具链（https://www.moonbitlang.com/download）
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

moon check --target all   # 检查（全目标）
moon test                 # 运行测试（49 个用例）
moon run examples/morph   # 示例一：圆变方动画，输出 SVG 帧序列
moon run examples/formula # 示例二：排版 \frac{x^2}{2} 并输出 SVG
moon run examples/texmorph # 示例三：公式 x^2 ↔ \frac{x^2}{2} 部件匹配变形
```

示例将 SVG 文档打印到 stdout，重定向即可查看：

```bash
moon run examples/morph > frames.txt
```

## 模块结构

每个顶层目录是一个独立的 `mooncakes` 包，可单独发布、单独复用：

| 包 | 导入路径 | 职责 |
|---|---|---|
| `math/` | `lmy271828/moonim/math` | Vec2 / Mat3 仿射变换 / Color / BBox |
| `geom/` | `lmy271828/moonim/geom` | 三次贝塞尔、路径、子路径拆分与点数对齐（`Path::align`）、三角化（earcut 移植）、描边展开 |
| `mobject/` | `lmy271828/moonim/mobject` | 场景图 ADT：`VMobject` / `Group` / `Tex`（带符号标签），部件枚举与 `same_shape` |
| `anim/` | `lmy271828/moonim/anim` | `Interpolable` trait、速率函数族（smooth/rush/wiggle/…）、`Animation`（`transform_to` / `transform_matching` / fade / grow / rotate）、`Scene` 时间轴 |
| `tex/` | `lmy271828/moonim/tex` | `FormulaRenderer` trait（扩展点）+ `MiniTex` 子集排版器 + `CachedRenderer` 记忆化包装 |
| `cache/` | `lmy271828/moonim/cache` | 显式键控 LRU 记忆化（见 design.md「缓存层」） |
| `backend/svg/` | `lmy271828/moonim/backend/svg` | Mobject 树 → SVG 文档序列化 |
| `playground/` | — | 浏览器 playground（js 目标构建 + 静态页面，见下节） |
| `examples/` | — | 可执行示例（CI 中实际运行并校验输出） |

## 浏览器 playground

`playground/` 是一个纯静态、无服务端的在线演示：MoonBit 编译到 js 目标，
浏览器直接调用渲染 API 逐帧生成 SVG 并播放，支持公式输入、seek 与
webm 录制（MediaRecorder）。

```bash
moon build --target js playground   # 产出 _build/js/debug/build/playground/playground.js
python3 -m http.server              # 在仓库根目录启动静态服务
# 打开 http://localhost:8000/playground/
```

页面通过 `globalThis.moonim` 与引擎交互：`prepare(scene, a, b)` 构建并
缓存场景（返回构建耗时 ms），`frame(t)` 渲染一帧，`last_svg()` /
`last_render_ms()` / `last_svg_ms()` 读回结果与分段耗时；`render(...)`
与 `duration(...)` 为兼容封装。示例场景 id：`morph` / `formula` /
`texmorph`；性能套件 id：`bench-light`（2 层，图形 morph + 短公式
morph）/ `bench-standard`（5 层，公式 morph + 坐标轴 + 生长/旋转/
摆动）/ `bench-heavy`（27 层，长公式 morph + 25 个错峰圆 + 持续旋转
外框）。性能套件忽略公式输入、完全确定，用于跨版本对比帧率（标准见
design.md「定位」一节）；`?bench=1` 打开四段归因（场景构建 /
render_at / 序列化 / DOM）的自动测量与结果表。`main_*.mbt` 按后端
拆分（moon.pkg 的 `targets` 声明），非 js 目标只编译空壳 main，不引入
js FFI。

最小用法：

```moonbit
let circle = @mobject.Mobject::vmobject(
  @geom.Path::circle(@math.Vec2::new(200.0, 100.0), 100.0),
)
let square = @mobject.Mobject::vmobject(
  @geom.Path::rect(@math.Vec2::new(100.0, 0.0), 200.0, 200.0),
)
let scene = @anim.Scene::new()
scene.add_layer(
  @anim.Layer::new(circle, [
    @anim.Animation::transform_to(square, duration=2.0),
  ]),
)
let svg = @svg.render_svg(scene.render_at(1.0)) // t = 1.0s 处的一帧
```

## 功能边界

本版本**做**：

- 三次贝塞尔求值 / 分割 / 弧长近似，路径扁平化与仿射变换；
- 简单多边形（单环、无洞）三角化与基础描边展开；
- 场景图递归变换、边界框计算；
- 纯函数式动画时间轴：`render_at(t)` 无内部状态，可任意 seek；
- 结构化插值 morph：任意两条路径经 `Path::align` 点数对齐后点对点变形；
- 部件匹配变形 `transform_matching`：符号标签 / 形状自动配对 + 孤儿淡化，
  支持公式 A → 公式 B 的灵活变换（见 design.md §3.1）；
- manimlib 速率函数族：`smooth` / `rush_into` / `rush_from` / `slow_into` /
  `there_and_back(_with_pause)` / `wiggle` / `squish` / `lingering` /
  `exponential_decay`；
- 淡入淡出 / 生长 / 旋转原语：`fade_in` / `fade_out` / `fade_in_from_point` /
  `fade_out_to_point` / `fade_to_color` / `grow_from_center` / `grow_from_point` /
  `shrink_to_center` / `scale_in_place` / `rotate`；
- 公式子集排版：普通字符、`{...}` 分组、`\frac`、`^`、`_`、常用希腊字母命令；
  字形为内嵌 Latin Modern 轮廓子集（82 字形，子集外字符回退占位盒）；
- SVG 后端：任意时刻场景 → 独立 SVG 文档。

本版本**明确不做**（均为后续路线，见 [docs/design.md](docs/design.md)）：

- OpenGL / 实时窗口预览；
- 完整 LaTeX（计划经 MicroTeX FFI 接入 `FormulaRenderer` trait，上游零改动）;
- 完整字形覆盖（当前为内嵌 Latin Modern 子集，子集外字符回退占位盒；
  扩充方式见 [docs/porting.md](docs/porting.md)）；
- 音频、3D、复杂文本 shaping、路径布尔运算；
- 带洞多边形三角化、earcut 的 z-order 哈希优化（见 [docs/porting.md](docs/porting.md)）。

## 设计文档

- [docs/design.md](docs/design.md) — 架构决策：场景图 ADT、动画代数、缓存层、
  公式渲染扩展点，以及各项"刻意推迟"的理由。
- [docs/porting.md](docs/porting.md) — earcut 移植声明（原项目、许可证、范围与偏差）。

## 开发

```bash
moon fmt              # 格式化
moon check            # 类型检查
moon test             # 白盒测试（各包 *_wbtest.mbt）
moon info             # 生成 .mbti 公共接口文件
```

CI（GitHub Actions，`.github/workflows/ci.yml`）：安装工具链 → 全目标 check →
test → build → 实际运行两个示例并校验输出含 `<svg`。

## 许可证

Apache-2.0（见 [LICENSE](LICENSE)）。`geom/earcut.mbt` 包含移植自
[mapbox/earcut](https://github.com/mapbox/earcut)（ISC 许可证）的代码，
保留原版权声明，详见 [docs/porting.md](docs/porting.md)。
