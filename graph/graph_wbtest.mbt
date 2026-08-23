///|
test "axes spans the requested data range" {
  let ax = axes(
    x_min=-2.0,
    x_max=2.0,
    y_min=-1.0,
    y_max=1.0,
    origin=@math.Vec2::new(0.0, 0.0),
    unit=100.0,
  )
  match ax.bbox() {
    Some(b) => {
      // x line from -200 to +200, y labels extend a bit further out.
      assert_true(b.min.x <= -200.0 && b.max.x >= 200.0)
      assert_true(b.min.y <= -100.0 && b.max.y >= 100.0)
    }
    None => abort("expected bbox")
  }
}

///|
test "number_line has a tick and a label per step" {
  let nl = number_line(min=-2.0, max=2.0, origin=@math.Vec2::new(0.0, 0.0))
  // Group: axis line + 5 ticks + 5 labels (0 included on a number line).
  match nl {
    Group(children) => assert_eq(children.length(), 11)
    _ => abort("expected group")
  }
}

///|
test "plot samples f into scene coordinates" {
  let path = plot(
    fn(x) { x },
    x_min=-1.0,
    x_max=1.0,
    origin=@math.Vec2::new(100.0, 100.0),
    unit=50.0,
    samples=10,
  )
  // 1 MoveTo + 10 LineTo.
  assert_eq(path.segments.length(), 11)
  // The midpoint of the line y = x maps to the origin of the axes.
  let mid = path.point_at_proportion(0.5)
  assert_true((mid.x - 100.0).abs() < 1.0e-9)
  assert_true((mid.y - 100.0).abs() < 1.0e-9)
}

///|
test "plot endpoints land on the curve" {
  let path = plot(
    fn(x) { x * x },
    x_min=0.0,
    x_max=2.0,
    origin=@math.Vec2::new(0.0, 0.0),
    unit=10.0,
    samples=20,
  )
  let last = path.point_at_proportion(1.0)
  // f(2) = 4 -> scene (20, 40).
  assert_true((last.x - 20.0).abs() < 1.0e-9)
  assert_true((last.y - 40.0).abs() < 1.0e-9)
}

///|
test "count typesets the lerped value, wider at two digits" {
  let probe = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0),
  )
  let anim = count(0.0, 10.0, duration=1.0, easing=@anim.linear)
  let w = fn(t) {
    match anim.at(probe, t).bbox() {
      Some(b) => b.width()
      None => 0.0
    }
  }
  // "0" vs "10": two digits are wider than one.
  assert_true(w(1.0) > w(0.0))
  // The number stays centered on the start mobject.
  match anim.at(probe, 0.5).bbox() {
    Some(b) => assert_true(b.center().x.abs() < 1.0e-9)
    None => abort("expected bbox")
  }
}
