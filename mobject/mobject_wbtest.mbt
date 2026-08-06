///|
test "vmobject bbox and transform" {
  let path = @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 2.0, 4.0)
  let m = Mobject::vmobject(path)
  match m.bbox() {
    Some(b) => {
      assert_eq(b.width(), 2.0)
      assert_eq(b.height(), 4.0)
    }
    None => abort("expected bbox")
  }
  let moved = m.transform(@math.Mat3::translate(10.0, 0.0))
  match moved.bbox() {
    Some(b) => assert_eq(b.min.x, 10.0)
    None => abort("expected bbox")
  }
}

///|
test "group union bbox" {
  let a = Mobject::vmobject(@geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0))
  let b = Mobject::vmobject(@geom.Path::circle(@math.Vec2::new(4.0, 0.0), 1.0))
  let g = Mobject::group([a, b])
  assert_eq(g.submobjects().length(), 2)
  match g.bbox() {
    Some(bb) => {
      assert_true((bb.min.x - -1.0).abs() < 1.0e-6)
      assert_true((bb.max.x - 5.0).abs() < 1.0e-6)
    }
    None => abort("expected bbox")
  }
}

///|
test "move center to" {
  let m = Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 2.0, 2.0),
  )
  let centered = m.move_center_to(@math.Vec2::new(10.0, 10.0))
  match centered.bbox() {
    Some(b) => {
      let c = b.center()
      assert_true(c.approx_eq(@math.Vec2::new(10.0, 10.0), eps=1.0e-9))
    }
    None => abort("expected bbox")
  }
}
