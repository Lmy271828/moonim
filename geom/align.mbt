///|
/// Split a path into subpaths at each `MoveTo`. The `Close` marker stays
/// with its subpath. A path with no segments yields no subpaths.
pub fn Path::subpaths(self : Path) -> Array[Path] {
  let out : Array[Path] = []
  let mut current = Path::new()
  for seg in self.segments {
    if seg is MoveTo(_) && !current.segments.is_empty() {
      out.push(current)
      current = Path::new()
    }
    current.segments.push(seg)
  }
  if !current.segments.is_empty() {
    out.push(current)
  }
  out
}

///|
/// Degree-elevate the line segment a -> b to a degenerate cubic.
fn line_cubic(a : @math.Vec2, b : @math.Vec2) -> CubicBezier {
  let d = (b - a).scale(1.0 / 3.0)
  CubicBezier::new(a, a + d, b - d, b)
}

///|
/// Normalize a subpath to a start point plus a chain of cubic curves:
/// `LineTo` is degree-elevated and `Close` becomes an explicit closing
/// curve. The result contains no `Close` markers, so two normalized
/// subpaths with equal curve counts lerp pointwise without type clashes.
fn to_cubics(sp : Path) -> (@math.Vec2, Array[CubicBezier]) {
  let curves : Array[CubicBezier] = []
  let mut current = @math.Vec2::new(0.0, 0.0)
  let mut start = current
  for seg in sp.segments {
    match seg {
      MoveTo(p) => {
        current = p
        start = p
      }
      LineTo(p) => {
        curves.push(line_cubic(current, p))
        current = p
      }
      CubicTo(c1, c2, p) => {
        curves.push(CubicBezier::new(current, c1, c2, p))
        current = p
      }
      Close => {
        if current.distance(start) > 1.0e-9 {
          curves.push(line_cubic(current, start))
        }
        current = start
      }
    }
  }
  (start, curves)
}

///|
/// A degenerate stand-in subpath: trace `sp`'s first subpath forward and
/// then back, so it deforms invisibly against its own silhouette.
fn degenerate_of(sp : Path) -> Path {
  let (start, curves) = to_cubics(sp)
  let out = Path::new()
  out.move_to(start)
  for c in curves {
    out.cubic_to(c.p1, c.p2, c.p3)
  }
  for c in curves.rev() {
    out.cubic_to(c.p2, c.p1, c.p0)
  }
  out
}

///|
/// Control-polygon length, used as the cheap curve-length heuristic for
/// sorting subpaths and picking split points (Manim uses the same
/// approximation spirit in `insert_n_curves_to_point_list`).
fn control_len(c : CubicBezier) -> Double {
  c.p0.distance(c.p1) + c.p1.distance(c.p2) + c.p2.distance(c.p3)
}

///|
/// Split the longest curve in half, growing the chain by one curve.
fn split_longest(curves : Array[CubicBezier]) -> Unit {
  let mut best = 0
  let mut best_len = -1.0
  for i, c in curves {
    let len = control_len(c)
    if len > best_len {
      best_len = len
      best = i
    }
  }
  let (l, r) = curves[best].split(0.5)
  curves[best] = l
  curves.insert(best + 1, r)
}

///|
/// Sort subpaths by perimeter, longest first, so that the dominant shapes
/// pair up on both sides (Manim `align_points` does the same).
fn sort_by_perimeter(sps : Array[Path]) -> Unit {
  sps.sort_by(fn(a, b) {
    let la = perimeter(a)
    let lb = perimeter(b)
    if la > lb {
      -1
    } else if la < lb {
      1
    } else {
      0
    }
  })
}

///|
fn perimeter(sp : Path) -> Double {
  let (_, curves) = to_cubics(sp)
  let mut total = 0.0
  for c in curves {
    total += control_len(c)
  }
  total
}

///|
/// A single-point subpath at `p`, for aligning against an empty path.
fn point_path(p : @math.Vec2) -> Path {
  let out = Path::new()
  out.move_to(p)
  out
}

///|
/// Align two paths so they share the exact same segment sequence
/// (`MoveTo` + equal counts of `CubicTo` per subpath), making pointwise
/// lerp between arbitrary shapes possible — the moonim port of Manim's
/// `VMobject.align_points` (see docs/design.md §3.1, layer L3).
///
/// Subpaths are sorted by perimeter and paired index-wise; the side with
/// fewer subpaths is padded with degenerate forward-and-back traces of
/// its first subpath, and curve-count mismatches are resolved by
/// repeatedly splitting the longest curve of the shorter side.
pub fn Path::align(self : Path, other : Path) -> (Path, Path) {
  let sps1 = self.subpaths()
  let sps2 = other.subpaths()
  if sps1.is_empty() {
    sps1.push(point_path(bbox_center_or_origin(self)))
  }
  if sps2.is_empty() {
    sps2.push(point_path(bbox_center_or_origin(other)))
  }
  sort_by_perimeter(sps1)
  sort_by_perimeter(sps2)
  let n = if sps1.length() > sps2.length() {
    sps1.length()
  } else {
    sps2.length()
  }
  while sps1.length() < n {
    sps1.push(degenerate_of(sps1[0]))
  }
  while sps2.length() < n {
    sps2.push(degenerate_of(sps2[0]))
  }
  let out1 = Path::new()
  let out2 = Path::new()
  for i in 0..<n {
    let (start1, curves1) = to_cubics(sps1[i])
    let (start2, curves2) = to_cubics(sps2[i])
    // A lone point subpath needs a degenerate curve to split from.
    if curves1.is_empty() {
      curves1.push(line_cubic(start1, start1))
    }
    if curves2.is_empty() {
      curves2.push(line_cubic(start2, start2))
    }
    while curves1.length() < curves2.length() {
      split_longest(curves1)
    }
    while curves2.length() < curves1.length() {
      split_longest(curves2)
    }
    out1.move_to(start1)
    for c in curves1 {
      out1.cubic_to(c.p1, c.p2, c.p3)
    }
    out2.move_to(start2)
    for c in curves2 {
      out2.cubic_to(c.p1, c.p2, c.p3)
    }
  }
  (out1, out2)
}

///|
fn bbox_center_or_origin(p : Path) -> @math.Vec2 {
  match p.bbox() {
    Some(b) => b.center()
    None => @math.Vec2::new(0.0, 0.0)
  }
}

///|
/// True when both paths have the same segment count and the same segment
/// variant at every position, i.e. pairwise lerp needs no alignment.
pub fn Path::lerp_compatible(self : Path, other : Path) -> Bool {
  if self.segments.length() != other.segments.length() {
    return false
  }
  for i in 0..<self.segments.length() {
    let ok = match (self.segments[i], other.segments[i]) {
      (MoveTo(_), MoveTo(_)) => true
      (LineTo(_), LineTo(_)) => true
      (CubicTo(_, _, _), CubicTo(_, _, _)) => true
      (Close, Close) => true
      _ => false
    }
    if !ok {
      return false
    }
  }
  true
}
