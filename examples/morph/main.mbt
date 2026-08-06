///|
/// A circle morphs into a square: the classic Manim "Hello Transform".
/// Prints one SVG document per sampled instant to stdout.
fn main {
  let origin = @math.Vec2::new(200.0, 100.0)
  let circle = @mobject.Mobject::vmobject(
    @geom.Path::circle(origin, 100.0),
    fill=Some(@math.Color::blue()),
  )
  let square = @mobject.Mobject::vmobject(
    @geom.Path::rect(origin.scale(0.5), 200.0, 200.0),
    fill=Some(@math.Color::yellow()),
  )
  let scene = @anim.Scene::new()
  scene.add_layer(
    @anim.Layer::new(circle, [
      @anim.Animation::wait(duration=1.0),
      @anim.Animation::transform_to(square, duration=2.0),
      @anim.Animation::wait(duration=1.0),
    ]),
  )
  let frames = [0.0, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
  for t in frames {
    println("===== frame at t = \{t}s =====")
    println(@svg.render_svg(scene.render_at(t)))
  }
  println("scene duration: \{scene.duration()}s")
}
