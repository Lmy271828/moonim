///|
/// Cubic Bezier curve defined by four control points.
pub(all) struct CubicBezier {
  p0 : @math.Vec2
  p1 : @math.Vec2
  p2 : @math.Vec2
  p3 : @math.Vec2
} derive(Eq, @debug.Debug)

///|
pub fn CubicBezier::new(
  p0 : @math.Vec2,
  p1 : @math.Vec2,
  p2 : @math.Vec2,
  p3 : @math.Vec2,
) -> CubicBezier {
  { p0, p1, p2, p3 }
}

///|
/// Evaluate the curve at parameter `t` (de Casteljau).
pub fn CubicBezier::eval(self : CubicBezier, t : Double) -> @math.Vec2 {
  let q0 = lerp_vec(self.p0, self.p1, t)
  let q1 = lerp_vec(self.p1, self.p2, t)
  let q2 = lerp_vec(self.p2, self.p3, t)
  let r0 = lerp_vec(q0, q1, t)
  let r1 = lerp_vec(q1, q2, t)
  lerp_vec(r0, r1, t)
}

///|
fn lerp_vec(a : @math.Vec2, b : @math.Vec2, t : Double) -> @math.Vec2 {
  a + (b - a).scale(t)
}

///|
/// Split the curve at `t` into two sub-curves.
pub fn CubicBezier::split(
  self : CubicBezier,
  t : Double,
) -> (CubicBezier, CubicBezier) {
  let q0 = lerp_vec(self.p0, self.p1, t)
  let q1 = lerp_vec(self.p1, self.p2, t)
  let q2 = lerp_vec(self.p2, self.p3, t)
  let r0 = lerp_vec(q0, q1, t)
  let r1 = lerp_vec(q1, q2, t)
  let s = lerp_vec(r0, r1, t)
  (CubicBezier::new(self.p0, q0, r0, s), CubicBezier::new(s, r1, q2, self.p3))
}

///|
/// Approximate arc length by sampling `n` segments.
pub fn CubicBezier::approx_length(self : CubicBezier, n? : Int = 32) -> Double {
  let mut len = 0.0
  let mut prev = self.p0
  for i in 1..<=n {
    let p = self.eval(i.to_double() / n.to_double())
    len += prev.distance(p)
    prev = p
  }
  len
}

///|
/// Sample `n + 1` evenly spaced points (including both endpoints).
pub fn CubicBezier::sample(self : CubicBezier, n : Int) -> Array[@math.Vec2] {
  let points : Array[@math.Vec2] = []
  for i in 0..<=n {
    points.push(self.eval(i.to_double() / n.to_double()))
  }
  points
}
