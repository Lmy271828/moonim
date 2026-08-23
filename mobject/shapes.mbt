///|
/// Composite shape constructors (manimlib `geometry.py` subset): lines and
/// arrows as ordinary VMobjects/Groups, ready for every animation.

///|
/// A stroked line segment from `a` to `b`.
pub fn Mobject::line(
  a : @math.Vec2,
  b : @math.Vec2,
  color? : @math.Color = @math.Color::white(),
  width? : Double = 2.0,
) -> Mobject {
  let path = @geom.Path::new()
  path.move_to(a)
  path.line_to(b)
  VMobject(path~, fill=None, stroke=Some((color, width)))
}

///|
/// An arrow from `a` to `b`: a stroked shaft plus a filled triangular tip.
/// The tip length is clamped to the shaft length; a degenerate (zero
/// length) arrow collapses to an empty group.
pub fn Mobject::arrow(
  a : @math.Vec2,
  b : @math.Vec2,
  color? : @math.Color = @math.Color::white(),
  width? : Double = 2.0,
  tip_length? : Double = 16.0,
  tip_width? : Double = 12.0,
) -> Mobject {
  let d = b - a
  let len = d.length()
  if len < 1.0e-9 {
    return Group([])
  }
  let u = d.scale(1.0 / len)
  let tip_len = if tip_length < len { tip_length } else { len }
  let base = b - u.scale(tip_len)
  let n = u.normal()
  let shaft = @geom.Path::new()
  shaft.move_to(a)
  shaft.line_to(base)
  let tip = @geom.Path::new()
  tip.move_to(b)
  tip.line_to(base + n.scale(tip_width / 2.0))
  tip.line_to(base - n.scale(tip_width / 2.0))
  tip.close()
  Group([
    VMobject(path=shaft, fill=None, stroke=Some((color, width))),
    VMobject(path=tip, fill=Some(color), stroke=None),
  ])
}

///|
/// A stroked rectangle around the mobject's bbox, padded by `padding`
/// (manimlib SurroundingRectangle). An empty bbox yields an empty group.
pub fn Mobject::surrounding_rectangle(
  m : Mobject,
  padding? : Double = 12.0,
  color? : @math.Color = @math.Color::white(),
  width? : Double = 2.0,
) -> Mobject {
  match m.bbox() {
    Some(b) =>
      VMobject(
        path=@geom.Path::rect(
          @math.Vec2::new(b.min.x - padding, b.min.y - padding),
          b.width() + 2.0 * padding,
          b.height() + 2.0 * padding,
        ),
        fill=None,
        stroke=Some((color, width)),
      )
    None => Group([])
  }
}
