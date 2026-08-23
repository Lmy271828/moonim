# moonim 设计说明

本文档记录 v0.1 的关键技术方案，以及若干"刻意推迟"（deliberately deferred）
决策的理由与演进路径。它回答的核心问题不是"我们实现了什么"，而是
"没实现的部分是被刻意推迟的，还是压根没想到的"——本文档证明是前者。

## 定位：浏览器内的即时数学动画

moonim 不做"另一个 Manim"。Manim 的生态位是本地 Python 脚本 + 离线
渲染出视频文件；moonim 的生态位是 **wasm 优先、浏览器内即时数学动画
制作**：场景即写即预览，时间轴可随意 seek，未来可交互，整条链路无服务
端、无 Python、无 ffmpeg。`playground/`（wasm 构建 + 静态页面）是这一
定位的第一分发形态，也是所有技术取舍的试金石：

- **渲染后端路线 SVG → Canvas2D → WebGL**：SVG 纯计算、可 golden
  test、足够支撑教学级场景；只有当实测帧率不足时才向 Canvas2D/WebGL
  演进——触发条件是性能不足，不是功能冲动。判断标准用 playground 的
  确定性性能套件（`bench-light` / `bench-standard` / `bench-heavy`，
  场景定义见 `playground/main_js.mbt` 的 `build_bench`）量化：
  `bench-standard` 在中端设备上**持续**低于 30fps（p95 帧时长
  > 33ms）或 seek 延迟持续超过 100ms，才算"实测帧率不足"；且须先按
  「场景构建 / render_at 计算 / SVG 序列化 / DOM 更新」四段归因再
  决定演进对象——若瓶颈在计算段，换渲染后端无济于事。

  首次实测（2026-08-23，Chromium 桌面，`?bench=1`，60 帧采样，
  DOM 段不含异步排版/绘制，该项由播放中的 rAF fps 读数兜底）：

  | 场景 | 构建 ms | render_at p50/p95 | 序列化 p50/p95 | DOM p50/p95 | 合计 p95 |
  |---|---|---|---|---|---|
  | bench-light | 0.3 | 0.00 / 0.00 | 0.00 / 0.10 | 0.00 / 0.10 | 0.20 |
  | bench-standard | 0.6 | 0.00 / 0.10 | 0.00 / 0.10 | 0.10 / 0.20 | 0.40 |
  | bench-heavy | 0.4 | 0.10 / 0.20 | 0.10 / 0.10 | 0.10 / 0.20 | 0.50 |

  结论：四段合计 p95 ≤ 0.5ms，距 33ms 预算近两个数量级。**SVG 后端
  对当前定位充分，Canvas2D/WebGL 议题冻结**；场景构建（公式排版）
  是最大的一次性成本，但只在输入变化时支付，优化手段是缓存粒度
  （CachedRenderer → 场景级内容寻址），不是换后端。重估触发条件不变。
- **公式走数据生成路线**：内嵌字形子集 + MiniTex 排版已经覆盖演示级
  公式；MicroTeX FFI 仅作为 native 后端的备选保留，有真实需求（复杂
  宏、完整 LaTeX 语义）时才启动，wasm 侧永远不走 FFI。
- **动画原语按批次从 manimlib 迁移，不追求全覆盖**：速率函数族、
  fade/grow/rotate、transform_matching、弧长创建族（Write/Unwrite/
  MoveAlongPath）、坐标系与函数图像（axes/number_line/plot，
  新包 `graph`）已迁移；updater 体系（依赖
  每帧 mutation 的 `add_updater`）与纯函数时间轴冲突，**明确不移植**。
- **纯函数 render_at 是定位的基石而非限制**：seek、帧缓存、将来的
  协同编辑与撤销，全部受益于"同一 (scene, t) 恒得同一帧"。

## 在线开发与交互外壳

「在线开发」= 亚秒级编辑-预览回路 + 零安装 + 链接即作品。按能力分
三层：L0 参数调节（playground 已实现）、L1 场景组装（目标：浏览器
内用 JS 组装真正的场景）、L2 完整 MoonBit 脚本编译（**明确不追**——
需要工具链 wasm 化或服务端编译，均违背定位）。架构选型：**纯函数内核
不动，交互与在线开发全部落在一层有状态外壳上**。

- **JS API 外壳**：wasm 模块暴露 mobject / animation / scene 构造器，
  用户在浏览器编辑器（Monaco/CodeMirror）里写 JS 组装场景，场景代码
  编码进 URL hash 分享——分享的链接无需携带任何运行时状态，这正是
  纯函数内核的红利。内核不感知 JS，外壳只是构造调用的转发层。
- **交互 env**：交互状态（playhead、相机、拖拽偏移、指针位置）集中在
  一个小而明确的 env 结构中，作为参数参与帧求值（已实现：`Env`
  携带指针位置与按键状态，`Animation` 的 update 签名为
  `(start, p, env)`，`Scene::render_at_env` 逐层下传，`render_at` 即
  默认 env 的特例）。同输入同输出，纯度保持；manimgl 的 updater 原地
  mutation 机制不引入——不移植的是 mutation，不是交互能力。
- **相机零成本变换**：pan/zoom 是最高频交互，映射为 SVG 根元素的
  `viewBox` / CSS transform，由浏览器合成器承担，不触发引擎重渲染。
  （已在 playground 实现：拖拽平移、以指针为锚点的滚轮缩放、双击复位；
  缩放范围限制在 viewBox 宽 60–4800。）
- **渲染更新策略**：SVG 保留模式自带命中测试（pointer events 直接落在
  path 上），点选/拖拽比 Canvas2D 手写命中检测简单；高频重渲染（拖拽
  跟手）时按 Layer 拆分 DOM，只替换受影响的子树，而非整棵 innerHTML。
  Canvas2D 仍以四段归因数据为前提，不提前上马。

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

分层依赖单向向下：`anim` 依赖 `mobject`/`geom`/`math`；`backend/svg` 直接
依赖 `mobject`/`geom`/`math`（后两者是 `mobject` 公开 API 的一部分），
不接触 `anim`/`tex`/`cache` 等上层。渲染后端可替换：未来的 OpenGL 后端
同样只面向场景图这一层，接入时不波及动画与几何。

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
   的部分错误（同变体对象经点数对齐后均可平滑 morph，仅跨变体组合
   退化为离散切换；见 §3.1）。

2. **`render_at(t)` 是纯函数**：场景没有内部播放状态，同一 `(scene, t)`
   永远得到同一结果。这是用"放弃增量计算"换"seek 与缓存的平凡正确性"
   ——而性能由记忆化找回（见下节）。Manim 用原地 mutation 换性能、付出
   状态管理负担；本设计反其道而行，并认为对教学/演示级动画引擎，这个
   交换是划算的。

`Animation::transform_to` 对同变体 Mobject 做平滑 morph（VMobject 与
Tex 的轮廓经 `Path::align` 点数对齐后点对点插值；Group 要求子对象数
相同，逐子对象递归）；跨变体组合退化为离散切换。`geom` 中
`Path::circle` 与 `Path::rect` 都刻意构造为 4 段三次贝塞尔，保证经典
"圆变方"动画点对点插值可用。

### 3.1 公式与异构 morph：三层机制（已实现）

参照 Manim `TransformMatchingTex` 的拆解（manimlib 的
`animation/transform_matching_parts.py` 与 `mobject/types/
vectorized_mobject.py` 的 `align_points`），异构对象间的平滑变换
分三层落地，每层独立交付、独立测试：

- **L3 点数对齐（地基）**：`geom` 的 `Path::align`——两条 Path 的
  子路径按周长排序后配对，缺侧用退化路径（首条子路径正反向拼接）
  凑数；曲线条数不等时对较少侧细分补齐（每轮劈当前最长曲线，
  复用 `CubicBezier::split`）；`LineTo` 升阶为退化三次曲线、`Close`
  转为显式闭合曲线，使两侧段序列逐段同型。对齐后任意两条 Path 均可
  点对点 lerp，`Interpolable for Mobject` 对 VMobject/Tex 不再有
  离散退化。此层与公式无关，所有 VMobject 受益。
- **L2 部件匹配 + 孤儿淡化**：`anim` 的 `Animation::transform_matching`。
  匹配依据 `Mobject::same_shape`（平移到中心、按高度归一后逐点比较，
  点集取自 `Path::to_polyline`）做贪心自动配对，并允许用户显式
  指定配对；配不上对的孤儿执行 FadeOutToPoint（缩放到目标中心 +
  透明度渐隐，`Color` 的 alpha 通道直接动画）/ FadeInFromPoint。
  匹配计划在首次求值时计算一次并记忆化——纯函数 `render_at` 每帧
  重放 update，而匹配是昂贵且幂等的子计算，与 §4 的缓存策略一致。
- **L1 符号级匹配（公式专用）**：`Tex` 节点携带带标签的符号子结构
  （`Mobject::tex` 由 `MiniTex::render_symbols` 的逐符号轮廓构造），
  两端符号序列做最长公共子串自动配对（difflib `SequenceMatcher`
  式），叠加用户 `key_map` 显式映射；标签耗尽后回落到 L2 的形状
  匹配。占位字形盒阶段所有字形盒形状相同，形状匹配按阅读顺序
  兜底配对，效果已可用；真实字形落地后标签匹配自动更精确。

三层的组合关系：L3 让任意两条路径可插值，L2 在其上做部件级组装，
L1 只提供 matching 用的标签，不重写下层。

## 4. 缓存层：显式键控记忆化（参照 Typst/comemo）

动画引擎渲染 N 帧意味着 N 次 `render_at` 求值，而帧间大量子计算结果
不变：公式排版、静止对象的三角化与描边。这些毫秒级操作若逐帧重复，
将主导帧生成时间。纯函数设计使结果只依赖输入，因此记忆化是透明正确的。

**理想模型**是 Typst 的 comemo：自动追踪被缓存函数对"世界"（字体、
公式源）的实际访问，据此做细粒度失效（`#[track]` + 约束重放）。
**当前 MoonBit 缺乏过程宏基础设施，无法表达自动依赖追踪**，故退化为
显式键控：

- 只在昂贵的叶子节点缓存，键为窄输入的结构哈希。公式渲染经 `tex` 包的
  `CachedRenderer`（包装任意 `FormulaRenderer`，键为 `hash_string(formula)`
  与 `size` 的组合哈希）；三角化的缓存接入留待后续；
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
  希腊字母子集；布局遵循 TeX box 模型（基线、分数线、上下标抬升）。
  字形为内嵌的 Latin Modern 轮廓子集（82 字形：数字、拉丁字母、
  希腊字母子集、常用符号，由 `tools/extract_glyphs.py` 生成，
  见 docs/porting.md）；子集外字符回退为占位半 em 方盒。扩充覆盖
  范围是重新跑生成脚本的数据改动，不影响 trait 与调用方。
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
| 字形子集覆盖有限 | 子集外字符回退占位盒 | 扩充是重跑生成脚本的数据改动（docs/porting.md） |
| 跨变体 morph 离散切换 | 视觉跳变 | 文档明示；同变体内已由三层机制平滑（§3.1） |
| O(n²) ear clipping | 大多边形慢 | 动画场景多边形小；z-order 哈希为已知优化方向 |
| bbox 忽略描边宽度 | 边界框略小 | 注释明示近似 |
