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
/// Smootherstep 6t^5 - 15t^4 + 10t^3 (zero first AND second derivatives
/// at both ends): the default rate function, matching manimlib's `smooth`
/// (`utils/rate_functions.py`).
pub fn smooth(t : Double) -> Double {
  let t = clamp01(t)
  let s = 1.0 - t
  t * t * t * (10.0 * s * s + 5.0 * s * t + t * t)
}

///|
/// Starts fast, eases out — manimlib `rush_into`.
pub fn rush_into(t : Double) -> Double {
  2.0 * smooth(0.5 * clamp01(t))
}

///|
/// Eases in, ends fast — manimlib `rush_from`.
pub fn rush_from(t : Double) -> Double {
  2.0 * smooth(0.5 * (clamp01(t) + 1.0)) - 1.0
}

///|
/// Quarter-circle ease-out — manimlib `slow_into`.
pub fn slow_into(t : Double) -> Double {
  let t = clamp01(t)
  (1.0 - (1.0 - t) * (1.0 - t)).sqrt()
}

///|
/// Two smooth half-speed segments back to back — manimlib `double_smooth`.
pub fn double_smooth(t : Double) -> Double {
  let t = clamp01(t)
  if t < 0.5 {
    0.5 * smooth(2.0 * t)
  } else {
    0.5 * (1.0 + smooth(2.0 * t - 1.0))
  }
}

///|
/// Ramp smoothly up to 1 at t = 0.5 and back down — manimlib
/// `there_and_back`, the workhorse of indication animations.
pub fn there_and_back(t : Double) -> Double {
  let t = clamp01(t)
  let new_t = if t < 0.5 { 2.0 * t } else { 2.0 * (1.0 - t) }
  smooth(new_t)
}

///|
/// Ramp up, hold at 1 for `pause_ratio` of the time, ramp down —
/// manimlib `there_and_back_with_pause`.
pub fn there_and_back_with_pause(
  t : Double,
  pause_ratio? : Double = 1.0 / 3.0,
) -> Double {
  let t = clamp01(t)
  let a = 2.0 / (1.0 - pause_ratio)
  if t < 0.5 - pause_ratio / 2.0 {
    smooth(a * t)
  } else if t < 0.5 + pause_ratio / 2.0 {
    1.0
  } else {
    smooth(a - a * t)
  }
}

///|
/// Oscillate around zero, `wiggles` times, envelope shaped by
/// there_and_back — manimlib `wiggle`.
pub fn wiggle(t : Double, wiggles? : Double = 2.0) -> Double {
  there_and_back(t) * @core_math.sin(wiggles * @core_math.PI * clamp01(t))
}

///|
/// Squeeze `func` into the sub-interval [a, b], holding the endpoints
/// outside it — manimlib `squish_rate_func`.
pub fn squish(
  func : (Double) -> Double,
  a? : Double = 0.4,
  b? : Double = 0.6,
) -> (Double) -> Double {
  fn(t) {
    let t = clamp01(t)
    if a == b {
      a
    } else if t < a {
      func(0.0)
    } else if t > b {
      func(1.0)
    } else {
      func((t - a) / (b - a))
    }
  }
}

///|
/// Reach the target at 80% and hold — manimlib `lingering`.
pub fn lingering(t : Double) -> Double {
  squish(linear, a=0.0, b=0.8)(t)
}

///|
/// 1 - exp(-t / half_life): fast approach, asymptotic tail — manimlib
/// `exponential_decay` (note: not exactly 1 at t = 1 by design).
pub fn exponential_decay(t : Double, half_life? : Double = 0.1) -> Double {
  1.0 - @core_math.exp(-clamp01(t) / half_life)
}
