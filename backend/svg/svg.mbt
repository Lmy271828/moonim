///|
/// Render a mobject tree to a standalone SVG document of `width` x
/// `height` pixels. Scene coordinates are y-up; a single root group
/// transform flips to SVG's y-down, so path data stays in scene space.
pub fn render_svg(
  m : @mobject.Mobject,
  width? : Double = 960.0,
  height? : Double = 540.0,
) -> String {
  let sb = StringBuilder()
  sb.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \{num(width)} \{num(height)}\">\n",
  )
  sb.write_string("<rect width=\"100%\" height=\"100%\" fill=\"#000000\"/>\n")
  sb.write_string("<g transform=\"translate(0 \{num(height)}) scale(1 -1)\">\n")
  render_mobject(sb, m)
  sb.write_string("</g>\n</svg>\n")
  sb.to_string()
}

///|
fn num(x : Double) -> String {
  x.to_string()
}

///|
fn render_mobject(sb : StringBuilder, m : @mobject.Mobject) -> Unit {
  match m {
    VMobject(path~, fill~, stroke~) => {
      sb.write_string("<path d=\"")
      sb.write_string(path_d(path))
      sb.write_string("\"")
      match fill {
        Some(c) =>
          sb.write_string(
            " fill=\"\{c.to_hex()}\" fill-opacity=\"\{num(c.opacity())}\"",
          )
        None => sb.write_string(" fill=\"none\"")
      }
      match stroke {
        Some((c, w)) =>
          sb.write_string(
            " stroke=\"\{c.to_hex()}\" stroke-width=\"\{num(w)}\" stroke-opacity=\"\{num(c.opacity())}\"",
          )
        None => sb.write_string(" stroke=\"none\"")
      }
      sb.write_string("/>\n")
    }
    Tex(outline~, ..) =>
      render_mobject(
        sb,
        VMobject(path=outline, fill=Some(@math.Color::white()), stroke=None),
      )
    Group(children) =>
      for child in children {
        render_mobject(sb, child)
      }
  }
}

///|
/// SVG path data for a path, in scene coordinates.
pub fn path_d(path : @geom.Path) -> String {
  let sb = StringBuilder()
  for seg in path.segments {
    match seg {
      MoveTo(p) => sb.write_string("M \{num(p.x)} \{num(p.y)} ")
      LineTo(p) => sb.write_string("L \{num(p.x)} \{num(p.y)} ")
      CubicTo(c1, c2, p) =>
        sb.write_string(
          "C \{num(c1.x)} \{num(c1.y)} \{num(c2.x)} \{num(c2.y)} \{num(p.x)} \{num(p.y)} ",
        )
      Close => sb.write_string("Z ")
    }
  }
  sb.to_string()
}
