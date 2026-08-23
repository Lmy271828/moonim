///|
/// An animated number readout (manimlib `ChangingDecimal`): typesets
/// round(lerp(from, to, p)) with MiniTex each frame. The CachedRenderer
/// makes each distinct number string typeset only once across all frames.
/// The number stays centered on the start mobject's bbox center.
pub fn count(
  from : Double,
  to : Double,
  size? : Double = 48.0,
  color? : @math.Color = @math.Color::white(),
  duration~ : Double,
  easing? : (Double) -> Double = @anim.smooth,
) -> @anim.Animation {
  let renderer = @tex.CachedRenderer::new(@tex.MiniTex::new(), 64)
  @anim.Animation::new(
    fn(start, p, _env) {
      let text = (from + (to - from) * p).round().to_int().to_string()
      let center = match start.bbox() {
        Some(b) => b.center()
        None => @math.Vec2::new(0.0, 0.0)
      }
      match renderer.render(text, size) {
        Ok(path) =>
          @mobject.Mobject::vmobject(path, fill=Some(color)).move_center_to(
            center,
          )
        Err(_) => start
      }
    },
    duration~,
    easing~,
  )
}
