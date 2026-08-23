///|
/// Fade the mobject in from transparent (Manim `FadeIn`).
pub fn Animation::fade_in(
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) { start.with_opacity(p) },
    duration~,
    easing~,
  )
}

///|
/// Fade the mobject out to transparent (Manim `FadeOut`).
pub fn Animation::fade_out(
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) { start.with_opacity(1.0 - p) },
    duration~,
    easing~,
  )
}

///|
/// Grow out of `point` while fading in (Manim `FadeInFromPoint`).
pub fn Animation::fade_in_from_point(
  point : @math.Vec2,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) { start.scale_about(point, p).with_opacity(p) },
    duration~,
    easing~,
  )
}

///|
/// Shrink toward `point` while fading out (Manim `FadeOutToPoint`).
pub fn Animation::fade_out_to_point(
  point : @math.Vec2,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      start.scale_about(point, 1.0 - p).with_opacity(1.0 - p)
    },
    duration~,
    easing~,
  )
}

///|
/// Lerp all paint colors toward `color` (Manim `FadeToColor`).
pub fn Animation::fade_to_color(
  color : @math.Color,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) { start.map_colors(fn(c) { c.lerp(color, p) }) },
    duration~,
    easing~,
  )
}

///|
/// Fade in while drifting in from `direction` (Manim FadeInAndShift):
/// starts offset by `direction` and slides home.
pub fn Animation::fade_in_and_shift(
  direction : @math.Vec2,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      start
      .transform(
        @math.Mat3::translate(direction.x * (1.0 - p), direction.y * (1.0 - p)),
      )
      .with_opacity(p)
    },
    duration~,
    easing~,
  )
}

///|
/// Fade out while drifting along `direction` (Manim FadeOutAndShift).
pub fn Animation::fade_out_and_shift(
  direction : @math.Vec2,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      start
      .transform(@math.Mat3::translate(direction.x * p, direction.y * p))
      .with_opacity(1.0 - p)
    },
    duration~,
    easing~,
  )
}
