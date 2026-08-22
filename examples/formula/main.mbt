///|
/// Typeset "\frac{x^2}{2}" with the built-in MiniTex renderer and print
/// the result as an SVG document.
fn main {
  let renderer = @tex.MiniTex::new()
  match renderer.render_symbols("\\frac{x^2}{2}", 48.0) {
    Ok(symbols) => {
      let m = @mobject.Mobject::tex("\\frac{x^2}{2}", symbols)
      match m.bbox() {
        Some(b) => {
          let shifted = m.transform(
            @math.Mat3::translate(100.0 - b.min.x, 100.0 - b.min.y),
          )
          println(@svg.render_svg(shifted))
        }
        None => println("empty outline")
      }
    }
    Err(_) => println("render error")
  }
}
