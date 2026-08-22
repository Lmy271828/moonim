///|
/// A matchable piece of a mobject, with an optional source-symbol label
/// (present for glyph parts of a `Tex` node). Used by
/// `Animation::transform_matching` (docs/design.md §3.1, layer L2).
pub(all) struct Part {
  mobject : Mobject
  label : String?
} derive(Eq, @debug.Debug)

///|
/// Decompose into matchable parts: groups flatten recursively to their
/// leaves; a `Tex` node yields one part per symbol (or, for label-less
/// outlines, one per subpath); a `VMobject` is a single part.
pub fn Mobject::parts(self : Mobject) -> Array[Part] {
  match self {
    VMobject(..) => [{ mobject: self, label: None }]
    Group(children) => {
      let out : Array[Part] = []
      for child in children {
        for part in child.parts() {
          out.push(part)
        }
      }
      out
    }
    Tex(outline~, symbols~, ..) =>
      if symbols.is_empty() {
        outline
        .subpaths()
        .map(fn(p) {
          {
            mobject: VMobject(
              path=p,
              fill=Some(@math.Color::white()),
              stroke=None,
            ),
            label: None,
          }
        })
      } else {
        symbols.map(fn(s) {
          {
            mobject: VMobject(
              path=s.outline,
              fill=Some(@math.Color::white()),
              stroke=None,
            ),
            label: Some(s.label),
          }
        })
      }
  }
}

///|
/// All flattened sample points of the mobject's paths.
fn Mobject::all_points(self : Mobject) -> Array[@math.Vec2] {
  match self {
    VMobject(path~, ..) => path.to_polyline()
    Tex(outline~, ..) => outline.to_polyline()
    Group(children) => {
      let out : Array[@math.Vec2] = []
      for child in children {
        for p in child.all_points() {
          out.push(p)
        }
      }
      out
    }
  }
}

///|
/// Shape comparison insensitive to position and scale, in the spirit of
/// Manim's `has_same_shape_as`: both point sets are centered and scaled
/// to unit height, then compared pointwise. Point counts must match.
pub fn Mobject::same_shape(self : Mobject, other : Mobject) -> Bool {
  let p1 = normalized(self.all_points())
  let p2 = normalized(other.all_points())
  match (p1, p2) {
    (Some(a), Some(b)) => {
      if a.length() != b.length() {
        return false
      }
      // Unit-height normalized coordinates: fixed tolerance suffices.
      let atol = 0.02
      for i in 0..<a.length() {
        if a[i].distance(b[i]) > atol {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
/// Center points at the origin and scale to unit height; `None` when the
/// point set is degenerate (empty or zero-height).
fn normalized(points : Array[@math.Vec2]) -> Array[@math.Vec2]? {
  if points.length() < 2 {
    return None
  }
  match @math.BBox::from_points(points) {
    None => None
    Some(b) =>
      if b.height() < 1.0e-9 {
        None
      } else {
        let c = b.center()
        Some(points.map(fn(p) { (p - c).scale(1.0 / b.height()) }))
      }
  }
}

///|
/// Multiply all paint alpha channels by `alpha` (recursive). Tex nodes
/// carry no paint of their own — the SVG backend renders them white — so
/// they are returned unchanged; fading a Tex goes through its parts.
pub fn Mobject::with_opacity(self : Mobject, alpha : Double) -> Mobject {
  match self {
    VMobject(path~, fill~, stroke~) =>
      VMobject(
        path~,
        fill=fill.map(fn(c) { scale_alpha(c, alpha) }),
        stroke=stroke.map(fn(s) {
          let (c, w) = s
          (scale_alpha(c, alpha), w)
        }),
      )
    Group(children) => Group(children.map(fn(c) { c.with_opacity(alpha) }))
    Tex(..) => self
  }
}

///|
fn scale_alpha(c : @math.Color, alpha : Double) -> @math.Color {
  @math.Color::new(c.r, c.g, c.b, a=c.a * alpha)
}
