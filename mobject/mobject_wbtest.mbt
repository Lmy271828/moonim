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

///|
test "same_shape ignores position and scale" {
  let box1 = Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 2.0),
  )
  let box2 = Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(10.0, 5.0), 3.0, 6.0),
  )
  assert_true(box1.same_shape(box2))
  let flat = Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 4.0, 1.0),
  )
  assert_true(!box1.same_shape(flat))
}

///|
test "parts decompose group and tex" {
  let g = Mobject::group([
    Mobject::vmobject(@geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0)),
    Mobject::vmobject(@geom.Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 1.0)),
  ])
  assert_eq(g.parts().length(), 2)
  let box = @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 2.0)
  let tex = Mobject::tex("xy", [("x", box), ("y", box)])
  let parts = tex.parts()
  assert_eq(parts.length(), 2)
  assert_eq(parts[0].label, Some("x"))
  assert_eq(parts[1].label, Some("y"))
}

///|
test "with_opacity scales fill and stroke alpha" {
  let m = Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 1.0),
    fill=Some(@math.Color::new(1.0, 1.0, 1.0, a=0.5)),
    stroke=Some((@math.Color::white(), 2.0)),
  )
  match m.with_opacity(0.5) {
    VMobject(fill=Some(c), stroke=Some((sc, _)), ..) => {
      assert_eq(c.opacity(), 0.25)
      assert_eq(sc.opacity(), 0.5)
    }
    _ => abort("expected vmobject")
  }
}
