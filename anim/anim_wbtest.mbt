///|
test "lerp double and vec2" {
  assert_eq(Interpolable::lerp(0.0, 10.0, 0.3), 3.0)
  let v = Interpolable::lerp(
    @math.Vec2::new(0.0, 0.0),
    @math.Vec2::new(4.0, 2.0),
    0.5,
  )
  assert_eq(v, @math.Vec2::new(2.0, 1.0))
}

///|
test "easing endpoints" {
  assert_eq(smooth(0.0), 0.0)
  assert_eq(smooth(1.0), 1.0)
  assert_eq(smooth(0.5), 0.5)
  assert_true(ease_in_out_quad(0.25) < 0.25)
}

///|
test "circle morphs to rect pointwise" {
  let circle = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0),
  )
  let rect = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(-1.0, -1.0), 2.0, 2.0),
  )
  let mid = Interpolable::lerp(circle, rect, 0.5)
  // Convexity: the lerp of two shapes stays inside the union of their
  // bounding boxes (the max of a lerp is NOT the lerp of the maxes).
  match (mid.bbox(), circle.bbox(), rect.bbox()) {
    (Some(mb), Some(cb), Some(rb)) => {
      let lo = if cb.min.x < rb.min.x { cb.min.x } else { rb.min.x }
      let hi = if cb.max.x > rb.max.x { cb.max.x } else { rb.max.x }
      assert_true(mb.min.x >= lo - 1.0e-9)
      assert_true(mb.max.x <= hi + 1.0e-9)
    }
    _ => abort("expected bboxes")
  }
}

///|
test "scene timeline sequencing" {
  let base = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 1.0),
  )
  let target = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(10.0, 0.0), 1.0, 1.0),
  )
  let scene = Scene::new()
  scene.add_layer(
    Layer::new(base, [
      Animation::wait(duration=1.0),
      Animation::transform_to(target, duration=2.0, easing=linear),
    ]),
  )
  assert_eq(scene.duration(), 3.0)
  // During the wait, nothing moves.
  match scene.render_at(0.5).bbox() {
    Some(b) => assert_eq(b.min.x, 0.0)
    None => abort("expected bbox")
  }
  // Halfway through the transform (t = 2.0), x is halfway.
  match scene.render_at(2.0).bbox() {
    Some(b) => assert_true((b.min.x - 5.0).abs() < 1.0e-9)
    None => abort("expected bbox")
  }
  // Past the end, it stays at the target.
  match scene.render_at(99.0).bbox() {
    Some(b) => assert_eq(b.min.x, 10.0)
    None => abort("expected bbox")
  }
}
