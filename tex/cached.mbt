///|
/// A memoizing wrapper around any `FormulaRenderer`.
///
/// Typesetting is an expensive leaf computation whose result depends only
/// on `(formula, size)` — across the N frames of an animation the same
/// formula is re-typeset N times. Since `render` is pure, keying an LRU
/// cache on the narrow inputs is transparently correct (see
/// docs/design.md, "缓存层").
pub(all) struct CachedRenderer[R] {
  inner : R
  cache : @cache.LruCache[Result[@geom.Path, RenderError]]
}

///|
/// Wrap `inner` with an LRU cache of the given `capacity` (entries).
pub fn[R] CachedRenderer::new(inner : R, capacity : Int) -> CachedRenderer[R] {
  { inner, cache: @cache.LruCache::new(capacity) }
}

///|
/// Narrow structural hash of the render inputs: formula text and em size.
fn render_key(formula : String, size : Double) -> Int {
  @cache.hash_combine(
    @cache.hash_string(formula),
    @cache.hash_string(size.to_string()),
  )
}

///|
pub impl[R : FormulaRenderer] FormulaRenderer for CachedRenderer[R] with fn render(
  self,
  formula,
  size,
) {
  self.cache.get_or(render_key(formula, size), fn() {
    self.inner.render(formula, size)
  })
}
