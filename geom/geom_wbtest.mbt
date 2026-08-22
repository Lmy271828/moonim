///|
fn triangle_area(a : @math.Vec2, b : @math.Vec2, c : @math.Vec2) -> Double {
  (b - a).cross(c - a).abs() / 2.0
}

///|
fn mesh_area(poly : Array[@math.Vec2], tris : Array[(Int, Int, Int)]) -> Double {
  let mut sum = 0.0
  for t in tris {
    sum += triangle_area(poly[t.0], poly[t.1], poly[t.2])
  }
  sum
}

///|
test "bezier eval and split" {
  let curve = CubicBezier::new(
    @math.Vec2::new(0.0, 0.0),
    @math.Vec2::new(0.0, 1.0),
    @math.Vec2::new(1.0, 1.0),
    @math.Vec2::new(1.0, 0.0),
  )
  assert_eq(curve.eval(0.0), @math.Vec2::new(0.0, 0.0))
  assert_eq(curve.eval(1.0), @math.Vec2::new(1.0, 0.0))
  let (left, right) = curve.split(0.5)
  assert_true(left.eval(1.0).approx_eq(right.eval(0.0)))
  assert_true(curve.approx_length() > 1.0)
}

///|
test "circle bbox" {
  let c = Path::circle(@math.Vec2::new(2.0, 3.0), 1.5)
  match c.bbox() {
    Some(b) => {
      assert_true((b.min.x - 0.5).abs() < 1.0e-6)
      assert_true((b.max.y - 4.5).abs() < 1.0e-6)
    }
    None => abort("expected bbox")
  }
}

///|
test "triangulate square" {
  let square = [
    @math.Vec2::new(0.0, 0.0),
    @math.Vec2::new(2.0, 0.0),
    @math.Vec2::new(2.0, 2.0),
    @math.Vec2::new(0.0, 2.0),
  ]
  let tris = triangulate(square)
  assert_eq(tris.length(), 2)
  assert_true((mesh_area(square, tris) - 4.0).abs() < 1.0e-9)
}

///|
test "triangulate concave L-shape" {
  let l_shape = [
    @math.Vec2::new(0.0, 0.0),
    @math.Vec2::new(2.0, 0.0),
    @math.Vec2::new(2.0, 1.0),
    @math.Vec2::new(1.0, 1.0),
    @math.Vec2::new(1.0, 2.0),
    @math.Vec2::new(0.0, 2.0),
  ]
  let tris = triangulate(l_shape)
  assert_eq(tris.length(), 4)
  assert_true((mesh_area(l_shape, tris) - 3.0).abs() < 1.0e-9)
}

///|
test "stroke of a straight segment is a rectangle" {
  let line = [@math.Vec2::new(0.0, 0.0), @math.Vec2::new(4.0, 0.0)]
  let outline = stroke_outline(line, 2.0)
  let tris = triangulate(outline)
  assert_true((mesh_area(outline, tris) - 8.0).abs() < 1.0e-9)
}

///|
test "subpaths split on MoveTo" {
  let p = Path::new()
  for seg in Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 1.0).segments {
    p.segments.push(seg)
  }
  for seg in Path::rect(@math.Vec2::new(2.0, 0.0), 1.0, 1.0).segments {
    p.segments.push(seg)
  }
  assert_eq(p.subpaths().length(), 2)
  assert_eq(Path::circle(@math.Vec2::new(0.0, 0.0), 1.0).subpaths().length(), 1)
  assert_eq(Path::new().subpaths().length(), 0)
}

///|
test "align equalizes segment sequences" {
  let circle = Path::circle(@math.Vec2::new(0.0, 0.0), 1.0)
  // One closed subpath of 4 cubics vs two open polyline subpaths.
  let two = Path::new()
  two.move_to(@math.Vec2::new(0.0, 0.0))
  two.line_to(@math.Vec2::new(1.0, 0.0))
  two.line_to(@math.Vec2::new(1.0, 1.0))
  two.move_to(@math.Vec2::new(2.0, 0.0))
  two.line_to(@math.Vec2::new(3.0, 0.0))
  let (a, b) = circle.align(two)
  assert_eq(a.segments.length(), b.segments.length())
  assert_true(a.lerp_compatible(b))
}

///|
test "align preserves geometry" {
  let circle = Path::circle(@math.Vec2::new(1.0, 2.0), 1.5)
  let rect = Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 1.0)
  let (a, _) = circle.align(rect)
  match (a.bbox(), circle.bbox()) {
    (Some(ba), Some(bc)) => {
      assert_true((ba.min.x - bc.min.x).abs() < 1.0e-9)
      assert_true((ba.max.x - bc.max.x).abs() < 1.0e-9)
      assert_true((ba.min.y - bc.min.y).abs() < 1.0e-9)
      assert_true((ba.max.y - bc.max.y).abs() < 1.0e-9)
    }
    _ => abort("expected bboxes")
  }
}

///|
test "align with empty path" {
  let circle = Path::circle(@math.Vec2::new(0.0, 0.0), 1.0)
  let (a, b) = Path::new().align(circle)
  assert_true(a.lerp_compatible(b))
}
