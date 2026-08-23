///|
/// The arc-length creation family (manimlib `creation.py` / MoveAlongPath),
/// built on `Path::trim` / `Path::point_at_proportion`.

///|
/// Stroke-only partial copy of `m` covering the arc-length window
/// [t0, t1]. The stroke color falls back to the fill color (then white),
/// matching how Write reuses a mobject's own color. Groups recurse; a Tex
/// writes its outline (glyph subpaths in layout order, so formulas write
/// left to right).
fn partial_outline(
  m : @mobject.Mobject,
  t0 : Double,
  t1 : Double,
  width : Double,
) -> @mobject.Mobject {
  match m {
    VMobject(path~, fill~, stroke~) => {
      let color = match stroke {
        Some((c, _)) => c
        None =>
          match fill {
            Some(c) => c
            None => @math.Color::white()
          }
      }
      VMobject(path=path.trim(t0, t1), fill=None, stroke=Some((color, width)))
    }
    Group(children) =>
      Group(children.map(fn(c) { partial_outline(c, t0, t1, width) }))
    Tex(outline~, ..) =>
      VMobject(
        path=outline.trim(t0, t1),
        fill=None,
        stroke=Some((@math.Color::white(), width)),
      )
  }
}

///|
/// Reveal the outline progressively as a stroke (Manim Write /
/// ShowCreation). Fill is hidden mid-animation; at p = 1 the original
/// mobject returns unchanged. Linear easing reads as constant-speed
/// writing; pass `easing=smooth` for a softer feel.
pub fn Animation::show_creation(
  duration~ : Double,
  easing? : (Double) -> Double = linear,
  stroke_width? : Double = 2.0,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      if p >= 1.0 {
        start
      } else {
        partial_outline(start, 0.0, p, stroke_width)
      }
    },
    duration~,
    easing~,
  )
}

///|
/// Reverse of `show_creation` (Manim Uncreate): the outline retreats from
/// the start; at p = 1 nothing remains.
pub fn Animation::unwrite(
  duration~ : Double,
  easing? : (Double) -> Double = linear,
  stroke_width? : Double = 2.0,
) -> Animation {
  Animation::new(
    fn(start, p, _env) { partial_outline(start, p, 1.0, stroke_width) },
    duration~,
    easing~,
  )
}

///|
/// Move along `path` by arc length (Manim MoveAlongPath): the mobject's
/// displacement equals the displacement of the path point at proportion
/// `p` from the path's start point, so any mobject can ride any path
/// regardless of where either sits in the scene.
pub fn Animation::move_along_path(
  path : @geom.Path,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  let origin = path.point_at_proportion(0.0)
  Animation::new(
    fn(start, p, _env) {
      let pos = path.point_at_proportion(p)
      start.transform(@math.Mat3::translate(pos.x - origin.x, pos.y - origin.y))
    },
    duration~,
    easing~,
  )
}
