///|
/// 2D affine transform stored as a 2x3 matrix:
///   | a c tx |
///   | b d ty |
pub(all) struct Mat3 {
  a : Double
  b : Double
  c : Double
  d : Double
  tx : Double
  ty : Double
} derive(Eq, @debug.Debug)

///|
pub fn Mat3::identity() -> Mat3 {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 0.0, ty: 0.0 }
}

///|
pub fn Mat3::translate(x : Double, y : Double) -> Mat3 {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: x, ty: y }
}

///|
/// Non-uniform scaling.
pub fn Mat3::scale(sx : Double, sy : Double) -> Mat3 {
  { a: sx, b: 0.0, c: 0.0, d: sy, tx: 0.0, ty: 0.0 }
}

///|
/// Rotation around the origin, angle in radians.
pub fn Mat3::rotate(angle : Double) -> Mat3 {
  let cos = @core_math.cos(angle)
  let sin = @core_math.sin(angle)
  { a: cos, b: sin, c: -sin, d: cos, tx: 0.0, ty: 0.0 }
}

///|
/// Matrix product: `m1.mul(m2)` applies `m2` first, then `m1`.
pub fn Mat3::mul(self : Mat3, other : Mat3) -> Mat3 {
  {
    a: self.a * other.a + self.c * other.b,
    b: self.b * other.a + self.d * other.b,
    c: self.a * other.c + self.c * other.d,
    d: self.b * other.c + self.d * other.d,
    tx: self.a * other.tx + self.c * other.ty + self.tx,
    ty: self.b * other.tx + self.d * other.ty + self.ty,
  }
}

///|
/// Apply the transform to a point.
pub fn Mat3::apply(self : Mat3, p : Vec2) -> Vec2 {
  Vec2::new(
    self.a * p.x + self.c * p.y + self.tx,
    self.b * p.x + self.d * p.y + self.ty,
  )
}
