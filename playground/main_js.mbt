///|
/// Register the playground API on the JS global object.
extern "js" fn register_api(
  render : (String, String, String, Double) -> String,
  duration : (String, String, String) -> Double,
) -> Unit =
  #| (render, duration) => {
  #|   globalThis.moonim = { render, duration };
  #| }

///|
/// Human-readable render error for the playground page.
fn err_msg(e : @tex.RenderError) -> String {
  match e {
    EmptyFormula => "empty formula"
    UnsupportedSyntax(s) => "unsupported syntax: " + s
    UnbalancedBraces => "unbalanced braces"
  }
}

///|
/// Build the scene identified by `scene_id`. `a` / `b` are the formula
/// texts for the tex-driven scenes; morph ignores them.
fn build_scene(
  scene_id : String,
  a : String,
  b : String,
) -> Result[@anim.Scene, String] {
  match scene_id {
    "morph" => {
      let circle = @mobject.Mobject::vmobject(
        @geom.Path::circle(@math.Vec2::new(480.0, 270.0), 120.0),
        fill=Some(@math.Color::blue()),
      )
      let square = @mobject.Mobject::vmobject(
        @geom.Path::rect(@math.Vec2::new(360.0, 150.0), 240.0, 240.0),
        fill=Some(@math.Color::yellow()),
      )
      let scene = @anim.Scene::new()
      scene.add_layer(
        @anim.Layer::new(circle, [
          @anim.Animation::wait(duration=1.0),
          @anim.Animation::transform_to(square, duration=2.0),
          @anim.Animation::wait(duration=1.0),
        ]),
      )
      Ok(scene)
    }
    "formula" => {
      let renderer = @tex.MiniTex::new()
      match renderer.render_symbols(a, 64.0) {
        Err(e) => Err("render error: " + err_msg(e))
        Ok(symbols) => {
          let m = @mobject.Mobject::tex(a, symbols).move_center_to(
            @math.Vec2::new(480.0, 270.0),
          )
          let scene = @anim.Scene::new()
          scene.add_layer(
            @anim.Layer::new(m, [@anim.Animation::wait(duration=1.0)]),
          )
          Ok(scene)
        }
      }
    }
    "texmorph" => {
      let renderer = @tex.MiniTex::new()
      match
        (renderer.render_symbols(a, 64.0), renderer.render_symbols(b, 64.0)) {
        (Err(e), _) => Err("render error in first formula: " + err_msg(e))
        (_, Err(e)) => Err("render error in second formula: " + err_msg(e))
        (Ok(sa), Ok(sb)) => {
          let center = @math.Vec2::new(480.0, 270.0)
          let ma = @mobject.Mobject::tex(a, sa).move_center_to(center)
          let mb = @mobject.Mobject::tex(b, sb).move_center_to(center)
          let scene = @anim.Scene::new()
          scene.add_layer(
            @anim.Layer::new(ma, [
              @anim.Animation::wait(duration=0.5),
              @anim.Animation::transform_matching(mb, duration=2.0),
              @anim.Animation::wait(duration=0.5),
            ]),
          )
          Ok(scene)
        }
      }
    }
    _ => Err("unknown scene: " + scene_id)
  }
}

///|
/// One SVG frame of the scene at time `t`. Errors are reported as an
/// "ERROR: ..." string so the page can display them.
fn render(scene_id : String, a : String, b : String, t : Double) -> String {
  match build_scene(scene_id, a, b) {
    Err(msg) => "ERROR: " + msg
    Ok(scene) => @svg.render_svg(scene.render_at(t))
  }
}

///|
/// Total duration of the scene in seconds (0 on error).
fn duration(scene_id : String, a : String, b : String) -> Double {
  match build_scene(scene_id, a, b) {
    Err(_) => 0.0
    Ok(scene) => scene.duration()
  }
}

///|
fn main {
  register_api(render, duration)
}
