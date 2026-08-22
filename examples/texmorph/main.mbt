///|
/// Formula morph: "x^2" grows a fraction bar and denominator into
/// "\frac{x^2}{2}", then collapses back. Matched symbols (x, 2) glide to
/// their new positions; the fraction rule and denominator fade in from /
/// out to the other formula's center (see docs/design.md §3.1).
/// Prints one SVG document per sampled instant to stdout.
fn main {
  let renderer = @tex.MiniTex::new()
  match
    (
      renderer.render_symbols("x^2", 48.0),
      renderer.render_symbols("\\frac{x^2}{2}", 48.0),
    ) {
    (Ok(s1), Ok(s2)) => {
      let center = @math.Vec2::new(480.0, 270.0)
      let plain = @mobject.Mobject::tex("x^2", s1).move_center_to(center)
      let frac = @mobject.Mobject::tex("\\frac{x^2}{2}", s2).move_center_to(
        center,
      )
      let scene = @anim.Scene::new()
      scene.add_layer(
        @anim.Layer::new(plain, [
          @anim.Animation::wait(duration=0.5),
          @anim.Animation::transform_matching(frac, duration=2.0),
          @anim.Animation::wait(duration=0.5),
          @anim.Animation::transform_matching(plain, duration=2.0),
        ]),
      )
      let frames = [0.0, 0.5, 1.0, 1.5, 2.5, 3.0, 4.0, 5.0]
      for t in frames {
        println("===== frame at t = \{t}s =====")
        println(@svg.render_svg(scene.render_at(t)))
      }
      println("scene duration: \{scene.duration()}s")
    }
    _ => println("render error")
  }
}
