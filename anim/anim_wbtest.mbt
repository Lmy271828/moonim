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

///|
test "env reaches update closures; render_at stays pure" {
  let dot = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0),
  )
  let anim = Animation::new(
    fn(start, _p, env) {
      match env.pointer {
        Some(p) => start.move_center_to(p)
        None => start
      }
    },
    duration=10.0,
    easing=linear,
  )
  let scene = Scene::new()
  scene.add_layer(Layer::new(dot, [anim]))
  // With a pointer in the env, the dot follows it.
  let env = { pointer: Some(@math.Vec2::new(5.0, 3.0)), pointer_down: false }
  match scene.render_at_env(1.0, env).bbox() {
    Some(b) => assert_eq(b.center(), @math.Vec2::new(5.0, 3.0))
    None => abort("expected bbox")
  }
  // Same scene, same t, default env -> the no-interaction frame.
  match scene.render_at(1.0).bbox() {
    Some(b) => assert_eq(b.center(), @math.Vec2::new(0.0, 0.0))
    None => abort("expected bbox")
  }
  // Purity per (scene, t, env): repeated evaluation is identical.
  assert_eq(scene.render_at_env(0.5, env), scene.render_at_env(0.5, env))
}

///|
test "show_creation reveals by arc length" {
  let line = @mobject.Mobject::vmobject(
    {
      let p = @geom.Path::new()
      p.move_to(@math.Vec2::new(0.0, 0.0))
      p.line_to(@math.Vec2::new(100.0, 0.0))
      p
    },
    fill=None,
    stroke=Some((@math.Color::white(), 2.0)),
  )
  let anim = Animation::show_creation(duration=2.0) // linear easing
  // Halfway: only the left half of the stroke is drawn.
  match anim.at(line, 1.0).bbox() {
    Some(b) => assert_true((b.width() - 50.0).abs() < 1.0)
    None => abort("expected bbox")
  }
  // Nothing drawn at p = 0; the original mobject returns at p = 1.
  assert_eq(anim.at(line, 0.0).bbox(), None)
  assert_eq(anim.at(line, 2.0), line)
}

///|
test "unwrite retreats from the start" {
  let line = @mobject.Mobject::vmobject(
    {
      let p = @geom.Path::new()
      p.move_to(@math.Vec2::new(0.0, 0.0))
      p.line_to(@math.Vec2::new(100.0, 0.0))
      p
    },
    fill=None,
    stroke=Some((@math.Color::white(), 2.0)),
  )
  let anim = Animation::unwrite(duration=2.0)
  match anim.at(line, 1.0).bbox() {
    Some(b) => {
      assert_true((b.min.x - 50.0).abs() < 1.0)
      assert_true((b.width() - 50.0).abs() < 1.0)
    }
    None => abort("expected bbox")
  }
  assert_eq(anim.at(line, 2.0).bbox(), None)
}

///|
test "move_along_path displaces by the path point" {
  let track = @geom.Path::new()
  track.move_to(@math.Vec2::new(0.0, 0.0))
  track.line_to(@math.Vec2::new(100.0, 0.0))
  let dot = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(5.0, 5.0), 1.0),
  )
  let anim = Animation::move_along_path(track, duration=1.0, easing=linear)
  match anim.at(dot, 1.0).bbox() {
    Some(b) => {
      let c = b.center()
      assert_true((c.x - 105.0).abs() < 1.0e-9 && (c.y - 5.0).abs() < 1.0e-9)
    }
    None => abort("expected bbox")
  }
}

///|
test "indicate pulses scale and color, endpoints exact" {
  let rect = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(-1.0, -1.0), 2.0, 2.0),
  )
  let anim = Animation::indicate(duration=1.0) // there_and_back easing
  assert_eq(anim.at(rect, 0.0), rect)
  assert_eq(anim.at(rect, 1.0), rect)
  // Mid-pulse: bbox grew, fill lerped toward yellow.
  match anim.at(rect, 0.5) {
    VMobject(fill=Some(c), ..) =>
      // white -> yellow: blue channel collapses, green dips toward 0.85
      assert_true(c.b < 0.01 && c.g < 0.95 && c.g > 0.8)
    _ => abort("expected vmobject")
  }
  match anim.at(rect, 0.5).bbox() {
    Some(b) => assert_true(b.width() > 2.1)
    None => abort("expected bbox")
  }
}

///|
test "circumscribe overlays a rectangle mid-animation" {
  let dot = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0),
  )
  let anim = Animation::circumscribe(duration=2.0)
  match anim.at(dot, 1.0) {
    Group(children) => assert_eq(children.length(), 2) // base + rect overlay
    _ => abort("expected group")
  }
  // Endpoints leave the base untouched.
  assert_eq(anim.at(dot, 0.0), dot)
  assert_eq(anim.at(dot, 2.0), dot)
}

///|
test "flash and focus_on are pure overlays" {
  let dot = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0),
  )
  let flash = Animation::flash(@math.Vec2::new(0.0, 0.0), duration=1.0)
  let focus = Animation::focus_on(@math.Vec2::new(5.0, 5.0), duration=1.0)
  for anim in [flash, focus] {
    assert_eq(anim.at(dot, 0.0), dot)
    assert_eq(anim.at(dot, 1.0), dot)
    match anim.at(dot, 0.5) {
      Group(children) => assert_true(children.length() >= 2)
      _ => abort("expected overlay group")
    }
  }
}

///|
test "fade_in_and_shift starts offset and transparent" {
  let rect = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 1.0),
  )
  let anim = Animation::fade_in_and_shift(
    @math.Vec2::new(0.0, 10.0),
    duration=1.0,
    easing=linear,
  )
  match anim.at(rect, 0.0) {
    VMobject(fill=Some(c), ..) => assert_eq(c.a, 0.0)
    _ => abort("expected vmobject")
  }
  match anim.at(rect, 0.0).bbox() {
    Some(b) => assert_eq(b.min.y, 10.0) // fully offset
    None => abort("expected bbox")
  }
  assert_eq(anim.at(rect, 1.0), rect)
}

///|
test "spin_in_from_nothing grows while unwinding" {
  let rect = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(-1.0, -0.5), 2.0, 1.0),
  )
  let anim = Animation::spin_in_from_nothing(duration=1.0, easing=linear)
  assert_eq(anim.at(rect, 1.0), rect)
  // Midway: half scale plus half the rotation still unwinding.
  match anim.at(rect, 0.5).bbox() {
    Some(b) => assert_true(b.width() < 1.5 && b.height() > 0.5)
    None => abort("expected bbox")
  }
}

///|
test "add_lagged staggers identical animations" {
  let bases = [
    @mobject.Mobject::vmobject(
      @geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0),
    ),
    @mobject.Mobject::vmobject(
      @geom.Path::circle(@math.Vec2::new(3.0, 0.0), 1.0),
    ),
    @mobject.Mobject::vmobject(
      @geom.Path::circle(@math.Vec2::new(6.0, 0.0), 1.0),
    ),
  ]
  let scene = Scene::new()
  scene.add_lagged(bases, fn(_i) { Animation::fade_in(duration=1.0) }, lag=0.5)
  assert_eq(scene.layers.length(), 3)
  assert_eq(scene.duration(), 2.0) // last layer: 2*0.5 wait + 1.0 fade
}
