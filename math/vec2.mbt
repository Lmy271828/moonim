///|
/// 2D vector.
pub(all) struct Vec2 {
  x : Double
  y : Double
} derive(Eq, @debug.Debug)

///|
pub fn Vec2::new(x : Double, y : Double) -> Vec2 {
  { x, y }
}

///|
pub impl Add for Vec2 with fn add(a, b) {
  Vec2::new(a.x + b.x, a.y + b.y)
}

///|
pub impl Sub for Vec2 with fn sub(a, b) {
  Vec2::new(a.x - b.x, a.y - b.y)
}

///|
pub impl Neg for Vec2 with fn neg(a) {
  Vec2::new(-a.x, -a.y)
}

///|
/// Scalar multiplication.
pub fn Vec2::scale(self : Vec2, k : Double) -> Vec2 {
  Vec2::new(self.x * k, self.y * k)
}

///|
pub fn Vec2::dot(self : Vec2, other : Vec2) -> Double {
  self.x * other.x + self.y * other.y
}

///|
/// 2D cross product (z component of the 3D cross product).
pub fn Vec2::cross(self : Vec2, other : Vec2) -> Double {
  self.x * other.y - self.y * other.x
}

///|
pub fn Vec2::length(self : Vec2) -> Double {
  (self.x * self.x + self.y * self.y).sqrt()
}

///|
pub fn Vec2::distance(self : Vec2, other : Vec2) -> Double {
  (self - other).length()
}

///|
/// Unit normal (rotate 90 degrees counter-clockwise).
pub fn Vec2::normal(self : Vec2) -> Vec2 {
  let len = self.length()
  if len < 1.0e-12 {
    Vec2::new(0.0, 0.0)
  } else {
    Vec2::new(-self.y / len, self.x / len)
  }
}

///|
pub fn Vec2::approx_eq(
  self : Vec2,
  other : Vec2,
  eps? : Double = 1.0e-9,
) -> Bool {
  (self.x - other.x).abs() < eps && (self.y - other.y).abs() < eps
}
