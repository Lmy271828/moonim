///|
/// Types that can be interpolated: the shared currency of the animation
/// system. An animation is just `lerp` lifted over a time axis.
pub(open) trait Interpolable {
  fn lerp(Self, Self, Double) -> Self
}

///|
pub impl Interpolable for Double with fn lerp(a, b, t) {
  a + (b - a) * t
}

///|
pub impl Interpolable for @math.Vec2 with fn lerp(a, b, t) {
  a + (b - a).scale(t)
}

///|
pub impl Interpolable for @math.Color with fn lerp(a, b, t) {
  a.lerp(b, t)
}

///|
/// Structural mobject interpolation. Same-variant pairs lerp pointwise;
/// paths with mismatched segment counts or types are first normalized by
/// `@geom.Path::align` (docs/design.md §3.1, layer L3), so any two shapes
/// morph smoothly. Only cross-variant pairs switch discretely.
pub impl Interpolable for @mobject.Mobject with fn lerp(a, b, t) {
  match (a, b) {
    (
      VMobject(path=p1, fill=f1, stroke=s1),
      VMobject(path=p2, fill=f2, stroke=s2),
    ) => {
      let (pa, pb) = if p1.lerp_compatible(p2) {
        (p1, p2)
      } else {
        p1.align(p2)
      }
      VMobject(
        path=lerp_path(pa, pb, t),
        fill=lerp_opt_color(f1, f2, t),
        stroke=lerp_stroke(s1, s2, t),
      )
    }
    (
      Tex(formula=f1, outline=o1, symbols=sy1),
      Tex(formula=f2, outline=o2, symbols=sy2),
    ) => {
      let (oa, ob) = if o1.lerp_compatible(o2) {
        (o1, o2)
      } else {
        o1.align(o2)
      }
      Tex(
        formula=if t < 1.0 { f1 } else { f2 },
        outline=lerp_path(oa, ob, t),
        symbols=lerp_symbols(sy1, sy2, t),
      )
    }
    (Group(xs), Group(ys)) =>
      if xs.length() == ys.length() {
        let out : Array[@mobject.Mobject] = []
        for i in 0..<xs.length() {
          out.push(Interpolable::lerp(xs[i], ys[i], t))
        }
        Group(out)
      } else {
        discrete(a, b, t)
      }
    _ => discrete(a, b, t)
  }
}

///|
/// Symbol outlines lerp pairwise when both sides carry the same label
/// sequence; anything else switches discretely (symbols only feed the
/// part matching in `Animation::transform_matching`, never the render).
fn lerp_symbols(
  a : Array[@mobject.Symbol],
  b : Array[@mobject.Symbol],
  t : Double,
) -> Array[@mobject.Symbol] {
  let same_labels = a.length() == b.length() &&
    ({
      let mut ok = true
      for i in 0..<a.length() {
        if a[i].label != b[i].label {
          ok = false
        }
      }
      ok
    })
  if same_labels {
    let out : Array[@mobject.Symbol] = []
    for i in 0..<a.length() {
      let (pa, pb) = if a[i].outline.lerp_compatible(b[i].outline) {
        (a[i].outline, b[i].outline)
      } else {
        a[i].outline.align(b[i].outline)
      }
      out.push({ label: a[i].label, outline: lerp_path(pa, pb, t) })
    }
    out
  } else if t < 1.0 {
    a
  } else {
    b
  }
}

///|
fn discrete(
  a : @mobject.Mobject,
  b : @mobject.Mobject,
  t : Double,
) -> @mobject.Mobject {
  if t < 1.0 {
    a
  } else {
    b
  }
}

///|
fn lerp_opt_color(
  a : @math.Color?,
  b : @math.Color?,
  t : Double,
) -> @math.Color? {
  match (a, b) {
    (Some(x), Some(y)) => Some(x.lerp(y, t))
    _ => if t < 1.0 { a } else { b }
  }
}

///|
fn lerp_stroke(
  a : (@math.Color, Double)?,
  b : (@math.Color, Double)?,
  t : Double,
) -> (@math.Color, Double)? {
  match (a, b) {
    (Some((c1, w1)), Some((c2, w2))) =>
      Some((c1.lerp(c2, t), w1 + (w2 - w1) * t))
    _ => if t < 1.0 { a } else { b }
  }
}

///|
fn lerp_path(p1 : @geom.Path, p2 : @geom.Path, t : Double) -> @geom.Path {
  let out = @geom.Path::new()
  for i in 0..<p1.segments.length() {
    out.segments.push(lerp_segment(p1.segments[i], p2.segments[i], t))
  }
  out
}

///|
fn lerp_segment(
  a : @geom.Segment,
  b : @geom.Segment,
  t : Double,
) -> @geom.Segment {
  match (a, b) {
    (MoveTo(p), MoveTo(q)) => MoveTo(Interpolable::lerp(p, q, t))
    (LineTo(p), LineTo(q)) => LineTo(Interpolable::lerp(p, q, t))
    (CubicTo(c1, c2, p), CubicTo(d1, d2, q)) =>
      CubicTo(
        Interpolable::lerp(c1, d1, t),
        Interpolable::lerp(c2, d2, t),
        Interpolable::lerp(p, q, t),
      )
    (Close, Close) => Close
    _ => if t < 0.5 { a } else { b }
  }
}
