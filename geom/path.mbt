///|
/// A vector path segment.
pub(all) enum Segment {
  MoveTo(@math.Vec2)
  LineTo(@math.Vec2)
  CubicTo(@math.Vec2, @math.Vec2, @math.Vec2)
  Close
} derive(Eq, @debug.Debug)

///|
/// A vector path: the atomic shape carried by VMobjects.
pub(all) struct Path {
  segments : Array[Segment]
} derive(Eq, @debug.Debug)

///|
pub fn Path::new() -> Path {
  { segments: [] }
}

///|
pub fn Path::move_to(self : Path, p : @math.Vec2) -> Unit {
  self.segments.push(MoveTo(p))
}

///|
pub fn Path::line_to(self : Path, p : @math.Vec2) -> Unit {
  self.segments.push(LineTo(p))
}

///|
pub fn Path::cubic_to(
  self : Path,
  c1 : @math.Vec2,
  c2 : @math.Vec2,
  p : @math.Vec2,
) -> Unit {
  self.segments.push(CubicTo(c1, c2, p))
}

///|
pub fn Path::close(self : Path) -> Unit {
  self.segments.push(Close)
}

///|
/// Flatten the path to a polyline by sampling each cubic segment
/// into `subdiv` pieces. Closed paths repeat the start point at the end.
pub fn Path::to_polyline(self : Path, subdiv? : Int = 16) -> Array[@math.Vec2] {
  let points : Array[@math.Vec2] = []
  let mut current = @math.Vec2::new(0.0, 0.0)
  let mut start = @math.Vec2::new(0.0, 0.0)
  for seg in self.segments {
    match seg {
      MoveTo(p) => {
        current = p
        start = p
        points.push(p)
      }
      LineTo(p) => {
        current = p
        points.push(p)
      }
      CubicTo(c1, c2, p) => {
        let curve = CubicBezier::new(current, c1, c2, p)
        for i in 1..<=subdiv {
          points.push(curve.eval(i.to_double() / subdiv.to_double()))
        }
        current = p
      }
      Close => {
        if current.distance(start) > 1.0e-9 {
          points.push(start)
        }
        current = start
      }
    }
  }
  points
}

///|
/// Bounding box of the flattened path (`None` if empty).
pub fn Path::bbox(self : Path) -> @math.BBox? {
  @math.BBox::from_points(self.to_polyline())
}

///|
/// Apply an affine transform, returning a new path.
pub fn Path::transform(self : Path, m : @math.Mat3) -> Path {
  let out = Path::new()
  for seg in self.segments {
    match seg {
      MoveTo(p) => out.move_to(m.apply(p))
      LineTo(p) => out.line_to(m.apply(p))
      CubicTo(c1, c2, p) => out.cubic_to(m.apply(c1), m.apply(c2), m.apply(p))
      Close => out.close()
    }
  }
  out
}

///|
/// Circle approximated by 4 cubic Bezier arcs (kappa = 4/3 * (sqrt(2) - 1)).
pub fn Path::circle(center : @math.Vec2, radius : Double) -> Path {
  let k = 0.5522847498307936 * radius
  let cx = center.x
  let cy = center.y
  let r = radius
  let path = Path::new()
  path.move_to(@math.Vec2::new(cx + r, cy))
  path.cubic_to(
    @math.Vec2::new(cx + r, cy + k),
    @math.Vec2::new(cx + k, cy + r),
    @math.Vec2::new(cx, cy + r),
  )
  path.cubic_to(
    @math.Vec2::new(cx - k, cy + r),
    @math.Vec2::new(cx - r, cy + k),
    @math.Vec2::new(cx - r, cy),
  )
  path.cubic_to(
    @math.Vec2::new(cx - r, cy - k),
    @math.Vec2::new(cx - k, cy - r),
    @math.Vec2::new(cx, cy - r),
  )
  path.cubic_to(
    @math.Vec2::new(cx + k, cy - r),
    @math.Vec2::new(cx + r, cy - k),
    @math.Vec2::new(cx + r, cy),
  )
  path.close()
  path
}

///|
/// Axis-aligned rectangle with `width` x `height`, lower-left corner at
/// `origin`. Built from 4 cubic segments (control points at 1/3 and 2/3 of
/// each edge) so it can morph against other 4-cubic shapes such as circles.
pub fn Path::rect(origin : @math.Vec2, width : Double, height : Double) -> Path {
  let x0 = origin.x
  let y0 = origin.y
  let x1 = x0 + width
  let y1 = y0 + height
  let third_w = width / 3.0
  let third_h = height / 3.0
  let path = Path::new()
  path.move_to(@math.Vec2::new(x0, y0))
  path.cubic_to(
    @math.Vec2::new(x0 + third_w, y0),
    @math.Vec2::new(x1 - third_w, y0),
    @math.Vec2::new(x1, y0),
  )
  path.cubic_to(
    @math.Vec2::new(x1, y0 + third_h),
    @math.Vec2::new(x1, y1 - third_h),
    @math.Vec2::new(x1, y1),
  )
  path.cubic_to(
    @math.Vec2::new(x1 - third_w, y1),
    @math.Vec2::new(x0 + third_w, y1),
    @math.Vec2::new(x0, y1),
  )
  path.cubic_to(
    @math.Vec2::new(x0, y1 - third_h),
    @math.Vec2::new(x0, y0 + third_h),
    @math.Vec2::new(x0, y0),
  )
  path.close()
  path
}
