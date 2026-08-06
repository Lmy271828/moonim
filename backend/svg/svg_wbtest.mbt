///|
test "render circle to svg" {
  let m = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(100.0, 100.0), 50.0),
    fill=Some(@math.Color::blue()),
  )
  let svg = render_svg(m)
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))
  assert_true(svg.contains("C ")) // cubic segments present
  assert_true(svg.contains(@math.Color::blue().to_hex()))
  assert_true(svg.contains("scale(1 -1)")) // y-flip wrapper
}

///|
test "group renders all children" {
  let a = @mobject.Mobject::vmobject(
    @geom.Path::circle(@math.Vec2::new(0.0, 0.0), 1.0),
  )
  let b = @mobject.Mobject::vmobject(
    @geom.Path::rect(@math.Vec2::new(0.0, 0.0), 1.0, 1.0),
  )
  let svg = render_svg(@mobject.Mobject::group([a, b]))
  assert_eq(count_occurrences(svg, "<path"), 2)
}

///|
fn count_occurrences(s : String, pat : String) -> Int {
  let mut count = 0
  let mut view = s
  while view.find(pat) is Some(i) {
    count += 1
    view = view[i + pat.length():].to_owned()
  }
  count
}

///|
test "path data round trip of a rect" {
  let d = path_d(@geom.Path::rect(@math.Vec2::new(0.0, 0.0), 2.0, 2.0))
  assert_true(d.contains("M "))
  assert_true(d.contains("Z"))
}
