///|
test "vec2 arithmetic" {
  let a = Vec2::new(1.0, 2.0)
  let b = Vec2::new(3.0, -1.0)
  assert_eq(a + b, Vec2::new(4.0, 1.0))
  assert_eq(a - b, Vec2::new(-2.0, 3.0))
  assert_eq(a.scale(2.0), Vec2::new(2.0, 4.0))
  assert_eq(a.dot(b), 1.0)
}

///|
test "mat3 apply and compose" {
  let t = Mat3::translate(10.0, 0.0)
  let s = Mat3::scale(2.0, 2.0)
  let m = t.mul(s) // scale first, then translate
  let p = m.apply(Vec2::new(1.0, 1.0))
  assert_true(p.approx_eq(Vec2::new(12.0, 2.0)))
  let r = Mat3::rotate(3.141592653589793 / 2.0)
  let q = r.apply(Vec2::new(1.0, 0.0))
  assert_true(q.approx_eq(Vec2::new(0.0, 1.0), eps=1.0e-9))
}

///|
test "color hex" {
  assert_eq(Color::red().to_hex(), "#ff0000")
  assert_eq(Color::black().to_hex(), "#000000")
  assert_eq(Color::white().opacity(), 1.0)
}

///|
test "bbox union" {
  let b1 = BBox::new(Vec2::new(0.0, 0.0), Vec2::new(2.0, 2.0))
  let b2 = BBox::new(Vec2::new(-1.0, 1.0), Vec2::new(1.0, 5.0))
  let u = b1.union(b2)
  assert_eq(u.min, Vec2::new(-1.0, 0.0))
  assert_eq(u.max, Vec2::new(2.0, 5.0))
  assert_eq(u.width(), 3.0)
}
