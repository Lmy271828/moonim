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

///|
test "mismatched segment counts morph smoothly" {
  // Before point alignment (L3) this pair fell back to a discrete switch:
  // 6 segments vs 4.
  let circle = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0),
  )
  let tri_path = @geom.Path::new()
  tri_path.move_to(@math.Vec2::new(0.0, 1.0))
  tri_path.line_to(@math.Vec2::new(-1.0, -1.0))
  tri_path.line_to(@math.Vec2::new(1.0, -1.0))
  tri_path.close()
  let tri = @mobject.Mobject::vmobject(tri_path)
  let mid = Interpolable::lerp(circle, tri, 0.5)
  assert_true(mid != circle)
  // The midpoint stays inside the union of both bounding boxes.
  match (mid.bbox(), circle.bbox(), tri.bbox()) {
    (Some(mb), Some(cb), Some(tb)) => {
      assert_true(
        mb.min.x >= cb.min.x - 1.0e-9 || mb.min.x >= tb.min.x - 1.0e-9,
      )
      assert_true(mb.max.x <= 1.0 + 1.0e-9)
      assert_true(mb.max.y <= 1.0 + 1.0e-9)
    }
    _ => abort("expected bboxes")
  }
}

///|
test "transform_matching endpoints and purity" {
  let a = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0),
  )
  let b = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(2.0, 0.0), 1.0, 1.0),
  )
  let scene = Scene::new()
  scene.add_layer(
    Layer::new(a, [
      Animation::transform_matching(b, duration=1.0, easing=linear),
    ]),
  )
  // Exact endpoints: start at t = 0, target (structure preserved) at t = 1.
  assert_eq(scene.render_at(0.0), @mobject.Mobject::group([a]))
  assert_eq(scene.render_at(1.0), @mobject.Mobject::group([b]))
  // Pure timeline: same instant, same frame, memoized plan or not.
  assert_eq(scene.render_at(0.5), scene.render_at(0.5))
}

///|
test "transform_matching pairs labels and fades orphans" {
  let box = @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 2.0)
  let start = @mobject.Mobject::tex("x+1", [("x", box), ("+", box), ("1", box)])
  let target = @mobject.Mobject::tex("x", [("x", box)])
  let scene = Scene::new()
  scene.add_layer(
    Layer::new(start, [
      Animation::transform_matching(target, duration=1.0, easing=linear),
    ]),
  )
  // Mid-frame: 1 matched pair (x -> x) plus 2 fading orphans (+ and 1);
  // the scene wraps the single layer in an outer group.
  match scene.render_at(0.5) {
    Group([Group(children)]) => assert_eq(children.length(), 3)
    _ => abort("expected layer group")
  }
  // Lands exactly on the target.
  assert_eq(scene.render_at(1.0), @mobject.Mobject::group([target]))
}

///|
test "rate function family endpoints" {
  // All standard rate functions fix the endpoints 0 -> 0 and 1 -> 1.
  for f in [rush_into, rush_from, slow_into, double_smooth] {
    assert_eq(f(0.0), 0.0)
    assert_eq(f(1.0), 1.0)
  }
  assert_eq(there_and_back(0.0), 0.0)
  assert_eq(there_and_back(0.5), 1.0)
  assert_eq(there_and_back(1.0), 0.0)
  assert_eq(there_and_back_with_pause(0.5), 1.0)
  assert_true(wiggle(0.0).abs() < 1.0e-9)
  assert_true(wiggle(1.0).abs() < 1.0e-9)
}

///|
test "squish and lingering" {
  let s = squish(linear, a=0.4, b=0.6)
  assert_eq(s(0.2), 0.0) // before the window: held at func(0)
  assert_eq(s(0.5), 0.5) // midpoint maps to midpoint
  assert_eq(s(0.8), 1.0) // after the window: held at func(1)
  assert_eq(lingering(0.9), 1.0) // target reached at 80%
  assert_eq(lingering(1.0), 1.0)
}

///|
test "exponential decay" {
  assert_eq(exponential_decay(0.0), 0.0)
  // 1 - exp(-10): close to 1 but not exactly, by design.
  assert_true((exponential_decay(1.0) - 1.0).abs() < 1.0e-4)
}

///|
test "fade_in ramps opacity 0 to 1" {
  let rect = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 1.0),
  )
  let anim = Animation::fade_in(duration=2.0, easing=linear)
  match anim.at(rect, 0.0) {
    VMobject(fill=Some(c), ..) => assert_eq(c.a, 0.0)
    _ => abort("expected vmobject")
  }
  match anim.at(rect, 1.0) {
    VMobject(fill=Some(c), ..) => assert_eq(c.a, 0.5)
    _ => abort("expected vmobject")
  }
  match anim.at(rect, 2.0) {
    VMobject(fill=Some(c), ..) => assert_eq(c.a, 1.0)
    _ => abort("expected vmobject")
  }
  // Pure: same instant, same frame.
  assert_eq(anim.at(rect, 0.7), anim.at(rect, 0.7))
}

///|
test "grow_from_center halves the bbox halfway" {
  let rect = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(-1.0, -1.0), 2.0, 2.0),
  )
  let anim = Animation::grow_from_center(duration=1.0, easing=linear)
  match anim.at(rect, 0.5).bbox() {
    Some(b) => {
      assert_true((b.width() - 1.0).abs() < 1.0e-9)
      assert_true((b.height() - 1.0).abs() < 1.0e-9)
      // Centered growth: center stays put.
      let c = b.center()
      assert_true(c.x.abs() < 1.0e-9)
      assert_true(c.y.abs() < 1.0e-9)
    }
    None => abort("expected bbox")
  }
}

///|
test "rotate swaps bbox extents" {
  let rect = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(-1.0, -0.5), 2.0, 1.0),
  )
  let anim = Animation::rotate(@core_math.PI / 2.0, duration=1.0, easing=linear)
  match anim.at(rect, 1.0).bbox() {
    Some(b) => {
      assert_true((b.width() - 1.0).abs() < 1.0e-9)
      assert_true((b.height() - 2.0).abs() < 1.0e-9)
    }
    None => abort("expected bbox")
  }
}
