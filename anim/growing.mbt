///|
/// Scale up from zero around the bbox center (Manim `GrowFromCenter`).
/// Mobjects without a bbox grow around the origin.
pub fn Animation::grow_from_center(
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      let center = match start.bbox() {
        Some(b) => b.center()
        None => @math.Vec2::new(0.0, 0.0)
      }
      start.scale_about(center, p)
    },
    duration~,
    easing~,
  )
}

///|
/// Scale up from zero around `point` (Manim `GrowFromPoint`).
pub fn Animation::grow_from_point(
  point : @math.Vec2,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) { start.scale_about(point, p) },
    duration~,
    easing~,
  )
}

///|
/// Scale down to zero around the bbox center (Manim `ShrinkToCenter`).
pub fn Animation::shrink_to_center(
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      let center = match start.bbox() {
        Some(b) => b.center()
        None => @math.Vec2::new(0.0, 0.0)
      }
      start.scale_about(center, 1.0 - p)
    },
    duration~,
    easing~,
  )
}

///|
/// Scale in place toward `factor` times the original size, around the bbox
/// center (Manim `ScaleInPlace`).
pub fn Animation::scale_in_place(
  factor : Double,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      let center = match start.bbox() {
        Some(b) => b.center()
        None => @math.Vec2::new(0.0, 0.0)
      }
      start.scale_about(center, 1.0 + (factor - 1.0) * p)
    },
    duration~,
    easing~,
  )
}

///|
/// Rotate by `angle` (radians) around `about`, defaulting to the bbox
/// center (Manim `Rotate`). Pair with `easing=linear` for manimlib's
/// continuous `Rotating`.
pub fn Animation::rotate(
  angle : Double,
  about? : @math.Vec2,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      let center = match about {
        Some(c) => c
        None =>
          match start.bbox() {
            Some(b) => b.center()
            None => @math.Vec2::new(0.0, 0.0)
          }
      }
      let mat = @math.Mat3::translate(center.x, center.y)
        .mul(@math.Mat3::rotate(angle * p))
        .mul(@math.Mat3::translate(-center.x, -center.y))
      start.transform(mat)
    },
    duration~,
    easing~,
  )
}

///|
/// Grow from zero while unwinding `angle` of rotation (Manim
/// SpinInFromNothing): the mobject spins in from nothing around its own
/// bbox center.
pub fn Animation::spin_in_from_nothing(
  angle? : Double = @core_math.PI,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p, _env) {
      let center = match start.bbox() {
        Some(b) => b.center()
        None => @math.Vec2::new(0.0, 0.0)
      }
      let mat = @math.Mat3::translate(center.x, center.y)
        .mul(@math.Mat3::rotate(angle * (1.0 - p)))
        .mul(@math.Mat3::scale(p, p))
        .mul(@math.Mat3::translate(-center.x, -center.y))
      start.transform(mat)
    },
    duration~,
    easing~,
  )
}
