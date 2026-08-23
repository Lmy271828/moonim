# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 新增

- `tex`：`CachedRenderer`，对任意 `FormulaRenderer` 的 LRU 记忆化包装
  （键为公式与字号的组合哈希），见 docs/design.md「缓存层」。
- 三层机制异构 morph（docs/design.md §3.1）：
  - `geom`：`Path::subpaths` 子路径拆分与 `Path::align` 点数对齐
    （子路径周长排序配对、退化路径凑数、最长曲线细分补齐、
    LineTo 升阶 / Close 显式化），任意两条路径可点对点插值；
  - `mobject`：`Tex` 节点携带带标签的符号子结构（`Mobject::tex`）、
    部件枚举 `parts`、`same_shape` 形状等价、`with_opacity`；
  - `anim`：`Animation::transform_matching`——key_map 显式映射 →
    标签最长公共子串 → 形状贪心配对，孤儿 FadeOutToPoint /
    FadeInFromPoint，匹配计划记忆化；
  - `tex`：MiniTex 布局盒带符号标签，新增 `render_symbols`。
- `examples/texmorph`：公式 x^2 ↔ \frac{x^2}{2} 部件匹配变形示例。
- `tex`：内嵌字形子集——`tools/extract_glyphs.py` 从 Latin Modern
  Roman/Math 提取 82 个字形（数字、拉丁字母、希腊字母、常用符号）
  的轮廓与 advance，生成 `tex/glyphs_data.mbt`；MiniTex 布局使用真实
  字宽，子集外字符回退占位盒。来源与许可证见 docs/porting.md。
- `playground/`：纯静态浏览器 playground——js 目标构建，页面内实时
  预览（SVG 直渲）、公式输入、seek、webm 录制；`main_*.mbt` 按后端
  拆分（`moon.pkg` 的 `targets` 声明），全目标 check/build 不受影响。
- `playground/`：界面重写（卡片式工具栏、16:9 自适应舞台、循环播放、
  空格/方向键快捷键、播放中实时 fps/帧耗时读数）；新增确定性性能套件
  `bench-light` / `bench-standard` / `bench-heavy`（忽略公式输入，用于
  跨版本帧率对比，判断标准见 docs/design.md「定位」）。
- 动画原语迁移批次 0+1（对照 manimlib `utils/rate_functions.py` 与
  animation 原语）：
  - `anim`：速率函数族——`smooth` 修正为 manimlib 的 smootherstep
    `6t⁵-15t⁴+10t³`（旧实现为 smoothstep，注释误称与 Manim 一致）；
    新增 `rush_into` / `rush_from` / `slow_into` / `double_smooth` /
    `there_and_back` / `there_and_back_with_pause` / `wiggle` /
    `squish` / `lingering` / `exponential_decay`；
  - `anim`：`Animation::fade_in` / `fade_out` / `fade_in_from_point` /
    `fade_out_to_point` / `fade_to_color`（fading.mbt）与
    `grow_from_center` / `grow_from_point` / `shrink_to_center` /
    `scale_in_place` / `rotate`（growing.mbt）；
  - `mobject`：新增公开 `Mobject::scale_about`（matching.mbt 的私有
    版本上移）与 `Mobject::map_colors`。
- `docs/design.md`：新增「定位：浏览器内的即时数学动画」一节。

### 修复

- `tex`：MiniTex 解析器中 `\alpha^2` 等"命令原子 + 上下标"组合此前报
  `unexpected character`——`\\` 分支漏挂了 `parse_scripts`。

## [0.1.0] - 2026-08-05

工程骨架首次发布。可构建、可测试（27 个用例）、示例可运行。

### 新增

- `math`：Vec2 / Mat3 仿射变换 / Color / BBox。
- `geom`：三次贝塞尔（求值、分割、弧长、采样）、路径（圆、矩形的
  4 段贝塞尔构造）、earcut 移植三角化（单环）、基础描边展开。
- `mobject`：场景图 ADT（VMobject / Group / Tex），递归变换与边界框。
- `anim`：`Interpolable` trait（Double / Vec2 / Color / Mobject）、
  缓动函数、`Animation`（transform_to / wait / apply_matrix）、
  纯函数式 `Scene::render_at(t)` 时间轴。
- `tex`：`FormulaRenderer` trait 扩展点 + `MiniTex` 子集排版器
  （字符、分组、\frac、^、_、希腊字母子集；占位字形盒）。
- `cache`：显式键控 `LruCache` 与结构哈希辅助。
- `backend/svg`：Mobject 树 → SVG 文档（y 轴翻转包装）。
- `examples/morph`、`examples/formula` 两个可执行示例。
- CI：全目标 check / test / build + 示例实际运行校验。

### 移植

- `geom/earcut.mbt` 移植自 mapbox/earcut（ISC），范围与偏差见
  docs/porting.md。

### 已知边界

- 无 OpenGL / 实时预览；无完整 LaTeX；MiniTex 字形为占位盒；
- 三角化不支持带洞多边形；结构不兼容的 morph 为离散切换。
