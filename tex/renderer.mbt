///|
/// Errors of the formula typesetting pipeline.
pub(all) enum RenderError {
  EmptyFormula
  UnsupportedSyntax(String)
  UnbalancedBraces
} derive(Eq, @debug.Debug)

///|
/// The formula-rendering extension point.
///
/// Anything implementing this trait can be plugged into the scene graph:
/// the engine only ever talks to `FormulaRenderer`, never to a concrete
/// typesetter. v0.1 ships `MiniTex` (a subset renderer); a MicroTeX FFI
/// backend implementing this same trait is on the roadmap and requires no
/// changes upstream (see docs/design.md).
pub(open) trait FormulaRenderer {
  /// Typeset `formula` at the given em `size`, returning a vector outline.
  fn render(Self, String, Double) -> Result[@geom.Path, RenderError]
}
