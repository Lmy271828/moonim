///|
/// An animation: a duration, an easing curve, and an update rule mapping
/// (state at animation start, eased progress in [0, 1]) to the current
/// state. Animations are pure — the same (start, t) always yields the same
/// mobject, which is what makes frame caching and time scrubbing sound.
pub(all) struct Animation {
  duration : Double
  easing : (Double) -> Double
  update : (@mobject.Mobject, Double) -> @mobject.Mobject
}

///|
pub fn Animation::new(
  update : (@mobject.Mobject, Double) -> @mobject.Mobject,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  { duration, easing, update }
}

///|
/// Morph the start state into `to` over `duration` seconds.
/// Requires the two mobjects to be structurally lerp-compatible (same
/// variant and segment counts) for a smooth morph; otherwise the
/// transition is discrete (see `Interpolable for Mobject`).
pub fn Animation::transform_to(
  to : @mobject.Mobject,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p) { Interpolable::lerp(start, to, p) },
    duration~,
    easing~,
  )
}

///|
/// Hold the current state for `duration` seconds.
pub fn Animation::wait(duration~ : Double) -> Animation {
  Animation::new(fn(start, _p) { start }, duration~, easing=linear)
}

///|
/// Apply an affine transform over time (relative to the start state).
pub fn Animation::apply_matrix(
  m : @math.Mat3,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
) -> Animation {
  Animation::new(
    fn(start, p) { start.transform(identity_lerp(m, p)) },
    duration~,
    easing~,
  )
}

///|
fn identity_lerp(m : @math.Mat3, p : Double) -> @math.Mat3 {
  let id = @math.Mat3::identity()
  {
    a: id.a + (m.a - id.a) * p,
    b: id.b + (m.b - id.b) * p,
    c: id.c + (m.c - id.c) * p,
    d: id.d + (m.d - id.d) * p,
    tx: id.tx + (m.tx - id.tx) * p,
    ty: id.ty + (m.ty - id.ty) * p,
  }
}

///|
/// State of the animation at absolute time `t` (seconds since its start),
/// clamped to [0, duration].
pub fn Animation::at(
  self : Animation,
  start : @mobject.Mobject,
  t : Double,
) -> @mobject.Mobject {
  let progress = if self.duration <= 0.0 {
    1.0
  } else {
    let p = t / self.duration
    if p < 0.0 {
      0.0
    } else if p > 1.0 {
      1.0
    } else {
      p
    }
  }
  (self.update)(start, (self.easing)(progress))
}
