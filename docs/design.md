# moonim 设计说明

本文档记录 v0.1 的关键技术方案，以及若干"刻意推迟"（deliberately deferred）
决策的理由与演进路径。它回答的核心问题不是"我们实现了什么"，而是
"没实现的部分是被刻意推迟的，还是压根没想到的"——本文档证明是前者。

## 1. 总体架构

```
                 ┌─────────────┐
   场景脚本 ───▶ │ Scene/Layer │  纯函数 render_at(t)
                 └──────┬──────┘
                        ▼
                 ┌─────────────┐     ┌──────────────┐
                 │  Mobject ADT│ ◀── │FormulaRenderer│ (trait，扩展点)
                 └──────┬──────┘     └──────────────┘
                        ▼
                 ┌─────────────┐     ┌──────────────┐
                 │  geom 路径/  │ ◀── │  cache 记忆化 │ (昂贵叶子节点)
                 │  三角化/描边 │     └──────────────┘
                 └──────┬──────┘
                        ▼
                 ┌─────────────┐
                 │ SVG backend │  纯计算，CI 可跑 golden test
                 └─────────────┘
```

分层依赖单向向下：`anim` 依赖 `mobject`/`geom`/`math`，`backend/svg` 只依赖
`mobject`。渲染后端可替换（未来的 OpenGL 后端同样只依赖 `mobject`）。

## 2. 场景图：ADT + 穷尽性检查

`Mobject` 是枚举：`VMobject`（路径 + 绘制属性）、`Group`（子对象树）、
`Tex`（公式源 + 渲染器无关的矢量轮廓）。渲染遍历、边界框、动画目标提取
全部是对该 ADT 的模式匹配。MoonBit 的穷尽性检查意味着：**新增一种
Mobject 变体时，编译器强制在所有 match 分支处理它**。相对 Python 生态
（Manim）靠鸭子类型与 `isinstance` 链，这对一个对象种类持续膨胀的引擎
是重要的维护性保障。

`Tex` 节点持有一份已排版好的 `outline: Path` 而非渲染器内部表示——排版
结果进入场景图后即与普通矢量对象一视同仁，变换、插值、序列化全部复用。

## 3. 动画代数：Interpolable trait + 纯函数时间轴

动画系统的地基是两个决策：

1. **`Interpolable` trait**：`fn lerp(Self, Self, Double) -> Self`。
   `Double`、`Vec2`、`Color`、`Mobject` 均实现之；动画本质是 `lerp`
   在时间轴上的提升。`Animation` = duration × easing ×
   `(start, progress) -> current`，`transform_to` 即对两个 Mobject 的
   结构化 lerp。MoonBit 的类型系统在编译期排除"对不兼容对象做 morph"
   的部分错误（结构上不兼容时退化为离散切换，已在文档与注释中写明；
   crossfade 策略为 roadmap）。

2. **`render_at(t)` 是纯函数**：场景没有内部播放状态，同一 `(scene, t)`
   永远得到同一结果。这是用"放弃增量计算"换"seek 与缓存的平凡正确性"
   ——而性能由记忆化找回（见下节）。Manim 用原地 mutation 换性能、付出
   状态管理负担；本设计反其道而行，并认为对教学/演示级动画引擎，这个
   交换是划算的。

`Animation::transform_to` 要求两个 Mobject 结构兼容（同变体、同段数）
才能平滑 morph。`geom` 中 `Path::circle` 与 `Path::rect` 都刻意构造为
4 段三次贝塞尔，保证经典"圆变方"动画点对点插值可用。

## 4. 缓存层：显式键控记忆化（参照 Typst/comemo）

动画引擎渲染 N 帧意味着 N 次 `render_at` 求值，而帧间大量子计算结果
不变：公式排版、静止对象的三角化与描边。这些毫秒级操作若逐帧重复，
将主导帧生成时间。纯函数设计使结果只依赖输入，因此记忆化是透明正确的。

**理想模型**是 Typst 的 comemo：自动追踪被缓存函数对"世界"（字体、
公式源）的实际访问，据此做细粒度失效（`#[track]` + 约束重放）。
**当前 MoonBit 缺乏过程宏基础设施，无法表达自动依赖追踪**，故退化为
显式键控：

- 只在昂贵的叶子节点缓存（公式渲染、三角化），键为窄输入的结构哈希
  （如 `hash_string(formula) × size`）；
- 失效策略即键不匹配未命中，无约束重放；
- `LruCache` 容量封顶，超容量淘汰最旧条目。

代价是粗粒度失效，收益是零魔法、可单测（"同一输入两次调用，底层构造
只执行一次"有直接断言）。`cache` 包独立发布，若 MoonBit 宏生态成熟，
可按 comemo 模型重写内部而不动上层调用点。

## 5. 公式渲染：FormulaRenderer trait 作为扩展点

完整 LaTeX 排版是本项目最大的外部依赖。设计决策是：**场景图只依赖
`FormulaRenderer` trait，不依赖任何具体排版器**。

```moonbit
pub(open) trait FormulaRenderer {
  fn render(Self, String, Double) -> Result[@geom.Path, RenderError]
}
```

- **v0.1**：`MiniTex` 填充该接口。支持字符、分组、`\frac`、`^`、`_`、
  希腊字母子集；布局遵循 TeX box 模型（基线、分数线、上下标抬升），
  但字形为占位半 em 方盒。换入真实字形轮廓（TTF 解析或内嵌字形数据）
  是局部改动，不影响 trait 与调用方。
- **roadmap**：MicroTeX（原 cLaTeXMath，C++17，MIT）FFI 后端。MicroTeX
  把 TeX 排版逻辑与光栅化后端严格分层（`Graphics2D`/`Font` 抽象接口），
  允许把排版结果回调成原始路径数据——实现一个 `MicroTexRenderer`
  完成同样的 `render` 即可，场景图、动画系统与用户代码零改动。

第一版不接 FFI 的理由：FFI 底座（C 包装、跨目标链接、CI 环境）的工程
成本与行数，在骨架阶段会挤占内核的迭代空间；且 OpenGL 同理（见下节）。

## 6. 为什么首渲染后端是 SVG 而不是 OpenGL

1. **可验证性**：SVG 输出是纯计算，`moon run` 直接产出，CI 可执行示例、
   可做逐字节 golden test；OpenGL 需要窗口/GPU 上下文，CI 与评审环境
   均无法运行。
2. **格式匹配**：数学动画的视觉主体就是矢量轮廓，SVG 是其原生格式；
   导出管线（SVG 帧序列 → 外部 ffmpeg）与 Manim 的帧序列实践一致。
3. **架构不妥协**：后端只依赖 `Mobject` 接口，OpenGL 后端接入时复用
   同一棵场景树，渲染层替换不波及动画与几何。

## 7. 已知取舍清单

| 决策 | 代价 | 缓解 |
|---|---|---|
| 纯函数时间轴 | 每帧全量求值 | 记忆化叶子节点；动画纯函数性保证缓存正确 |
| 显式键控缓存 | 粗粒度失效 | 键窄、可控；trait 边界允许未来换 comemo 式实现 |
| 占位字形盒 | 公式不可用于出片 | 布局已是 TeX box 模型，换字形数据是局部改动 |
| 结构不兼容 morph 离散切换 | 视觉跳变 | 文档明示；crossfade 策略 roadmap |
| O(n²) ear clipping | 大多边形慢 | 动画场景多边形小；z-order 哈希为已知优化方向 |
| bbox 忽略描边宽度 | 边界框略小 | 注释明示近似 |
