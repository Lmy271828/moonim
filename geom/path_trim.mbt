///|
/// Arc-length machinery for paths: the enabler behind Write/ShowCreation,
/// MoveAlongPath and dashed styles (manimlib's `point_from_proportion` /
/// `subdivide`, ported on top of cubic splitting). All proportions are
/// fractions of the path's total arc length across ALL subpaths, in segment
/// order — so a multi-subpath glyph outline writes subpath by subpath.

///|
/// One drawable piece of a path (a line or cubic) with a cumulative arc
/// length table of 16 samples, used for length<->parameter mapping.
priv struct Piece {
  curve : CubicBezier
  cum : Array[Double]
  length : Double
}

///|
/// A straight line as a cubic (control points at 1/3 and 2/3), so all
/// arc-length math only has to handle one curve kind.
fn line_curve(a : @math.Vec2, b : @math.Vec2) -> CubicBezier {
  let third = (b - a).scale(1.0 / 3.0)
  CubicBezier::new(a, a + third, b - third, b)
}

///|
/// Decompose into drawable pieces; Close becomes a line back to the
/// subpath start. Zero-length pieces are dropped.
fn Path::pieces(self : Path) -> Array[Piece] {
  let out : Array[Piece] = []
  let mut current = @math.Vec2::new(0.0, 0.0)
  let mut start = @math.Vec2::new(0.0, 0.0)
  for seg in self.segments {
    match seg {
      MoveTo(p) => {
        current = p
        start = p
      }
      LineTo(p) => {
        push_piece(out, line_curve(current, p))
        current = p
      }
      CubicTo(c1, c2, p) => {
        push_piece(out, CubicBezier::new(current, c1, c2, p))
        current = p
      }
      Close => {
        if current.distance(start) > 1.0e-9 {
          push_piece(out, line_curve(current, start))
        }
        current = start
      }
    }
  }
  out
}

///|
fn push_piece(out : Array[Piece], curve : CubicBezier) -> Unit {
  let n = 16
  let cum : Array[Double] = []
  let mut acc = 0.0
  let mut prev = curve.p0
  for i in 1..<=n {
    let p = curve.eval(i.to_double() / n.to_double())
    acc += prev.distance(p)
    cum.push(acc)
    prev = p
  }
  if acc > 1.0e-12 {
    out.push({ curve, cum, length: acc })
  }
}

///|
/// Total arc length (16 samples per piece; matches the resolution used by
/// `trim` / `point_at_proportion`).
pub fn Path::total_length(self : Path) -> Double {
  let mut total = 0.0
  for piece in self.pieces() {
    total += piece.length
  }
  total
}

///|
/// Curve parameter whose arc length into the piece is `s`.
fn param_at(piece : Piece, s : Double) -> Double {
  let n = piece.cum.length()
  let mut prev_cum = 0.0
  for i in 0..<n {
    let c = piece.cum[i]
    if s <= c {
      let d = c - prev_cum
      let frac = if d < 1.0e-12 { 0.0 } else { (s - prev_cum) / d }
      return (i.to_double() + frac) / n.to_double()
    }
    prev_cum = c
  }
  1.0
}

///|
/// The sub-curve between parameters u0 and u1 (de Casteljau splits).
fn sub_curve(c : CubicBezier, u0 : Double, u1 : Double) -> CubicBezier {
  if u0 <= 0.0 && u1 >= 1.0 {
    c
  } else {
    let (_, rest) = c.split(u0)
    if u1 >= 1.0 {
      rest
    } else {
      rest.split((u1 - u0) / (1.0 - u0)).0
    }
  }
}

///|
fn clamp01(t : Double) -> Double {
  if t < 0.0 {
    0.0
  } else if t > 1.0 {
    1.0
  } else {
    t
  }
}

///|
fn dmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn dmax(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Point at arc-length proportion `t` of the whole path. Returns the
/// origin for an empty path.
pub fn Path::point_at_proportion(self : Path, t : Double) -> @math.Vec2 {
  let pieces = self.pieces()
  if pieces.is_empty() {
    return @math.Vec2::new(0.0, 0.0)
  }
  let mut total = 0.0
  for piece in pieces {
    total += piece.length
  }
  let mut s = clamp01(t) * total
  for piece in pieces {
    if s <= piece.length {
      return piece.curve.eval(param_at(piece, s))
    }
    s -= piece.length
  }
  pieces[pieces.length() - 1].curve.p3
}

///|
/// Keep only the arc-length window [t0, t1] (proportions of the total
/// length, either order, clamped). Subpath discontinuities are preserved
/// as MoveTo gaps — no stray connecting curves.
pub fn Path::trim(self : Path, t0 : Double, t1 : Double) -> Path {
  let lo = clamp01(dmin(t0, t1))
  let hi = clamp01(dmax(t0, t1))
  let out = Path::new()
  if hi - lo < 1.0e-12 {
    return out
  }
  let pieces = self.pieces()
  let mut total = 0.0
  for piece in pieces {
    total += piece.length
  }
  let s0 = lo * total
  let s1 = hi * total
  let mut acc = 0.0
  let mut pen : @math.Vec2? = None
  for piece in pieces {
    let a = dmax(s0, acc)
    let b = dmin(s1, acc + piece.length)
    if b > a {
      let sub = sub_curve(
        piece.curve,
        param_at(piece, a - acc),
        param_at(piece, b - acc),
      )
      match pen {
        Some(q) => if q.distance(sub.p0) > 1.0e-6 { out.move_to(sub.p0) }
        None => out.move_to(sub.p0)
      }
      out.cubic_to(sub.p1, sub.p2, sub.p3)
      pen = Some(sub.p3)
    }
    acc += piece.length
  }
  out
}

///|
/// Dashed copy: keep arc-length windows of `dash` separated by `gap`
/// (scene units). manimlib's DashedLine is the special case on a line.
pub fn Path::to_dashed(
  self : Path,
  dash? : Double = 12.0,
  gap? : Double = 8.0,
) -> Path {
  let total = self.total_length()
  let out = Path::new()
  if total <= 0.0 {
    return out
  }
  let mut s = 0.0
  while s < total {
    let e = dmin(s + dash, total)
    let piece = self.trim(s / total, e / total)
    for seg in piece.segments {
      out.segments.push(seg)
    }
    s = e + gap
  }
  out
}
