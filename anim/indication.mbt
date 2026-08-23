///|
/// Attention-directing indication family (manimlib `indication.py`):
/// overlay animations that leave the base mobject intact (the layer's
/// state becomes Group([base, overlay]) mid-animation and returns to the
/// base at p = 1).

///|
/// Pulse scale and color together (Manim Indicate): there_and_back
/// easing makes it a self-contained "look here" beat.
pub fn Animation::indicate(
  scale_factor? : Double = 1.2,
  color? : @math.Color = @math.Color::yellow(),
  duration~ : Double,
  easing? : (Double) -> Double = there_and_back,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      let center = match start.bbox() {
        Some(b) => b.center()
        None => @math.Vec2::new(0.0, 0.0)
      }
      start
      .scale_about(center, 1.0 + (scale_factor - 1.0) * p)
      .map_colors(fn(c) { c.lerp(color, p) })
    },
    duration~,
    easing~,
  )
}

///|
/// Draw a surrounding rectangle around the mobject, then fade it out
/// (Manim Circumscribe). First half writes the rectangle by arc length,
/// second half fades it.
pub fn Animation::circumscribe(
  color? : @math.Color = @math.Color::yellow(),
  padding? : Double = 12.0,
  stroke_width? : Double = 2.0,
  duration~ : Double,
  easing? : (Double) -> Double = linear,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      let rect = @mobject.Mobject::surrounding_rectangle(
        start,
        padding~,
        color~,
        width=stroke_width,
      )
      if p <= 0.0 || p >= 1.0 {
        return start
      }
      let overlay = if p < 0.5 {
        match rect {
          VMobject(path~, ..) =>
            @mobject.Mobject::vmobject(
              path.trim(0.0, p * 2.0),
              fill=None,
              stroke=Some((color, stroke_width)),
            )
          other => other
        }
      } else {
        rect.with_opacity(1.0 - (p - 0.5) * 2.0)
      }
      @mobject.Mobject::group([start, overlay])
    },
    duration~,
    easing~,
  )
}

///|
/// Lines radiating out of `point` while fading (Manim Flash). Pure
/// overlay: the base mobject passes through untouched.
pub fn Animation::flash(
  point : @math.Vec2,
  color? : @math.Color = @math.Color::yellow(),
  lines? : Int = 8,
  radius? : Double = 120.0,
  stroke_width? : Double = 2.0,
  duration~ : Double,
  easing? : (Double) -> Double = linear,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      if p <= 0.0 || p >= 1.0 {
        return start
      }
      let reach = radius * slow_into(p)
      let alpha = 1.0 - p
      let rays : Array[@mobject.Mobject] = []
      for i in 0..<lines {
        let angle = i.to_double() / lines.to_double() * 2.0 * @core_math.PI
        let u = @math.Vec2::new(@core_math.cos(angle), @core_math.sin(angle))
        rays.push(
          @mobject.Mobject::line(
            point + u.scale(reach * 0.55),
            point + u.scale(reach),
            color~,
            width=stroke_width,
          ).with_opacity(alpha),
        )
      }
      @mobject.Mobject::group([start, Group(rays)])
    },
    duration~,
    easing~,
  )
}

///|
/// A ring and center dot converging onto `point` (Manim FocusOn).
pub fn Animation::focus_on(
  point : @math.Vec2,
  color? : @math.Color = @math.Color::new(0.35, 0.77, 0.87),
  radius? : Double = 120.0,
  duration~ : Double,
  easing? : (Double) -> Double = linear,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      if p <= 0.0 || p >= 1.0 {
        return start
      }
      let ring = @mobject.Mobject::vmobject(
        @geom.Path::circle(point, radius * (1.0 - p)),
        fill=None,
        stroke=Some((color, 2.0)),
      )
      let dot = @mobject.Mobject::vmobject(
        @geom.Path::circle(point, 4.0),
        fill=Some(color),
      )
      @mobject.Mobject::group([start, ring.with_opacity(p), dot.with_opacity(p)])
    },
    duration~,
    easing~,
  )
}
