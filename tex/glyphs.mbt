///|
/// One segment of an embedded glyph outline, in 1em units
/// (y-up, baseline at y = 0).
priv enum GSeg {
  M(Double, Double)
  L(Double, Double)
  C(Double, Double, Double, Double, Double, Double)
  Z
}

///|
/// An embedded glyph: advance width plus outline, both in 1em units.
/// Data lives in the generated `glyphs_data.mbt` (Latin Modern Roman /
/// Latin Modern Math, GUST Font License — see docs/porting.md).
priv struct GlyphData {
  adv : Double
  segs : Array[GSeg]
}

///|
/// Build the outline of `g` scaled to `size` and translated by (dx, dy).
fn glyph_path(
  g : GlyphData,
  dx : Double,
  dy : Double,
  size : Double,
) -> @geom.Path {
  let path = @geom.Path::new()
  for seg in g.segs {
    match seg {
      M(x, y) => path.move_to(@math.Vec2::new(dx + x * size, dy + y * size))
      L(x, y) => path.line_to(@math.Vec2::new(dx + x * size, dy + y * size))
      C(x1, y1, x2, y2, x3, y3) =>
        path.cubic_to(
          @math.Vec2::new(dx + x1 * size, dy + y1 * size),
          @math.Vec2::new(dx + x2 * size, dy + y2 * size),
          @math.Vec2::new(dx + x3 * size, dy + y3 * size),
        )
      Z => path.close()
    }
  }
  path
}
