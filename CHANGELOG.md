# Changelog

本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

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
