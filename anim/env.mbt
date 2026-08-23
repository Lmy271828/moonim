///|
/// Interaction environment for one frame evaluation (design.md
/// 「在线开发与交互外壳」): everything the shell knows that a frame may
/// depend on, gathered into one explicit value so that frame evaluation
/// stays a pure function of (scene, t, env). Extend with new fields as
/// interactions grow (keys held, drag targets, ...); the purity contract
/// is what keeps seek, caching and sharing sound.
pub(all) struct Env {
  /// Pointer position in scene coordinates (y-up); `None` when the
  /// pointer is outside the stage.
  pointer : @math.Vec2?
  /// Whether the primary pointer button is held down this frame.
  pointer_down : Bool
} derive(Eq, @debug.Debug)

///|
/// No interaction: the default environment used by `Scene::render_at`.
pub fn Env::default() -> Env {
  { pointer: None, pointer_down: false }
}
