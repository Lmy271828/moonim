///| moonim — a mathematical animation engine kernel in pure MoonBit.
///|
///| This root package is intentionally empty; functionality lives in the
///| subpackages, which are imported individually:
///|
///| - `math`: Vec2 / Mat3 affine transforms / Color / BBox
///| - `geom`: cubic beziers, paths, `Path::align` point-count alignment,
///|   arc-length trim, earcut triangulation, stroke expansion
///| - `mobject`: scene graph ADT (VMobject / Group / Tex with symbol labels)
///| - `anim`: `Interpolable`, rate functions, `Animation` combinators,
///|   interactive `Env`, pure seekable `Scene::render_at` timeline
///| - `tex`: `FormulaRenderer` trait + MiniTex typesetting subset +
///|   `CachedRenderer` memoization
///| - `graph`: axes / number line / function plots / counting decimals
///| - `cache`: explicit-key LRU memoization
///| - `backend/svg`: mobject tree → SVG document
///|
///| Minimal example:
///|
///| ```moonbit
///| let circle = @mobject.Mobject::vmobject(
///|   @geom.Path::circle(@math.Vec2::new(200.0, 100.0), 100.0),
///| )
///| let square = @mobject.Mobject::vmobject(
///|   @geom.Path::rect(@math.Vec2::new(100.0, 0.0), 200.0, 200.0),
///| )
///| let scene = @anim.Scene::new()
///| scene.add_layer(
///|   @anim.Layer::new(circle, [
///|     @anim.Animation::transform_to(square, duration=2.0),
///|   ]),
///| )
///| let svg = @svg.render_svg(scene.render_at(1.0)) // one frame at t = 1.0s
///| ```
pub fn version() -> String {
  "0.2.1"
}
