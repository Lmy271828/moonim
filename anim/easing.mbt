///|
fn clamp01(t : Double) -> Double {
  if t < 0.0 {
    0.0
  } else if t > 1.0 {
    1.0
  } else {
    t
  }
}

///|
pub fn linear(t : Double) -> Double {
  clamp01(t)
}

///|
pub fn ease_in_out_quad(t : Double) -> Double {
  let t = clamp01(t)
  if t < 0.5 {
    2.0 * t * t
  } else {
    1.0 - 2.0 * (1.0 - t) * (1.0 - t)
  }
}

///|
/// Smoothstep (3t^2 - 2t^3): the default rate function, matching Manim's
/// `smooth`.
pub fn smooth(t : Double) -> Double {
  let t = clamp01(t)
  t * t * (3.0 - 2.0 * t)
}
