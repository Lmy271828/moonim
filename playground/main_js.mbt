///|
/// Millisecond clock for the four-segment attribution timing (design.md
/// 「定位」: scene build / render_at / SVG serialization / DOM update).
extern "js" fn now() -> Double =
  #| () => performance.now()

///|
/// Register the playground API on the JS global object.
extern "js" fn register_api(
  render : (String, String, String, Double) -> String,
  duration : (String, String, String) -> Double,
  prepare : (String, String, String) -> Double,
  frame : (Double, Double, Double, Bool, Bool) -> String,
  last_svg : () -> String,
  last_render_ms : () -> Double,
  last_svg_ms : () -> Double,
) -> Unit =
  #| (render, duration, prepare, frame, last_svg, last_render_ms, last_svg_ms) => {
  #|   globalThis.moonim = { render, duration, prepare, frame, last_svg, last_render_ms, last_svg_ms };
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
/// Typeset `formula` at `size` and center it at `center`.
fn tex_at(
  renderer : @tex.MiniTex,
  formula : String,
  size : Double,
  center : @math.Vec2,
) -> Result[@mobject.Mobject, String] {
  match renderer.render_symbols(formula, size) {
    Err(e) => Err("render error in \{formula}: " + err_msg(e))
    Ok(symbols) =>
      Ok(@mobject.Mobject::tex(formula, symbols).move_center_to(center))
  }
}

///|
/// Standardized benchmark suite (design.md「定位」节的性能判断标准）:
/// deterministic scenes that ignore the formula inputs, so frame-time
/// numbers stay comparable across runs and engine changes.
/// - bench-light:    2 layers, a shape morph + a 3-glyph formula morph
/// - bench-standard: 5 layers, formula morph + axes + grow/rotate/wiggle
/// - bench-heavy:    27 layers, long-formula morph + 25 staggered circles
///   + a continuously rotating frame (the "beyond scope" probe)
fn build_bench(scene_id : String) -> Result[@anim.Scene, String] {
  let scene = @anim.Scene::new()
  let renderer = @tex.MiniTex::new()
  match scene_id {
    "bench-light" => {
      let circle = @mobject.Mobject::vmobject(
        @geom.Path::circle(@math.Vec2::new(320.0, 270.0), 90.0),
        fill=Some(@math.Color::blue()),
      )
      let square = @mobject.Mobject::vmobject(
        @geom.Path::rect(@math.Vec2::new(230.0, 180.0), 180.0, 180.0),
        fill=Some(@math.Color::yellow()),
      )
      scene.add_layer(
        @anim.Layer::new(circle, [
          @anim.Animation::wait(duration=0.5),
          @anim.Animation::transform_to(square, duration=2.0),
          @anim.Animation::wait(duration=0.5),
        ]),
      )
      match
        (
          tex_at(renderer, "x^2", 48.0, @math.Vec2::new(660.0, 270.0)),
          tex_at(renderer, "2x", 48.0, @math.Vec2::new(660.0, 270.0)),
        ) {
        (Ok(ma), Ok(mb)) => {
          scene.add_layer(
            @anim.Layer::new(ma, [
              @anim.Animation::wait(duration=0.5),
              @anim.Animation::transform_matching(mb, duration=2.0),
              @anim.Animation::wait(duration=0.5),
            ]),
          )
          Ok(scene)
        }
        (Err(e), _) | (_, Err(e)) => Err(e)
      }
    }
    "bench-standard" => {
      // 1) formula morph, top center
      match
        (
          tex_at(
            renderer,
            "\\frac{x^2}{2}",
            56.0,
            @math.Vec2::new(480.0, 140.0),
          ),
          tex_at(
            renderer,
            "\\frac{x^3}{3}",
            56.0,
            @math.Vec2::new(480.0, 140.0),
          ),
        ) {
        (Ok(ma), Ok(mb)) =>
          scene.add_layer(
            @anim.Layer::new(ma, [
              @anim.Animation::wait(duration=0.5),
              @anim.Animation::transform_matching(mb, duration=3.0),
              @anim.Animation::wait(duration=1.5),
            ]),
          )
        (Err(e), _) | (_, Err(e)) => return Err(e)
      }
      // 2) axes with ticks, stroked
      let axes_path = @geom.Path::new()
      axes_path.move_to(@math.Vec2::new(120.0, 400.0))
      axes_path.line_to(@math.Vec2::new(840.0, 400.0))
      axes_path.move_to(@math.Vec2::new(480.0, 230.0))
      axes_path.line_to(@math.Vec2::new(480.0, 470.0))
      for i in 0..<=8 {
        let x = 200.0 + i.to_double() * 80.0
        axes_path.move_to(@math.Vec2::new(x, 394.0))
        axes_path.line_to(@math.Vec2::new(x, 406.0))
      }
      let axes = @mobject.Mobject::vmobject(
        axes_path,
        fill=None,
        stroke=Some((@math.Color::new(0.6, 0.6, 0.65), 2.0)),
      )
      scene.add_layer(
        @anim.Layer::new(axes, [
          @anim.Animation::fade_in(duration=1.0),
          @anim.Animation::wait(duration=4.0),
        ]),
      )
      // 3) circle: grow, then pulse
      let circle = @mobject.Mobject::vmobject(
        @geom.Path::circle(@math.Vec2::new(240.0, 330.0), 42.0),
        fill=Some(@math.Color::green()),
      )
      scene.add_layer(
        @anim.Layer::new(circle, [
          @anim.Animation::grow_from_center(duration=1.0),
          @anim.Animation::wait(duration=1.0),
          @anim.Animation::scale_in_place(
            1.4,
            duration=2.0,
            easing=@anim.there_and_back,
          ),
          @anim.Animation::wait(duration=1.0),
        ]),
      )
      // 4) square: fade in, then quarter-turn about its center
      let square = @mobject.Mobject::vmobject(
        @geom.Path::rect(@math.Vec2::new(690.0, 300.0), 60.0, 60.0),
        fill=Some(@math.Color::yellow()),
      )
      scene.add_layer(
        @anim.Layer::new(square, [
          @anim.Animation::fade_in(duration=1.0),
          @anim.Animation::rotate(@core_math.PI / 2.0, duration=2.0),
          @anim.Animation::wait(duration=2.0),
        ]),
      )
      // 5) triangle: fade in, then wiggle (indicate)
      let tri_path = @geom.Path::new()
      tri_path.move_to(@math.Vec2::new(480.0, 280.0))
      tri_path.line_to(@math.Vec2::new(450.0, 330.0))
      tri_path.line_to(@math.Vec2::new(510.0, 330.0))
      tri_path.close()
      let tri = @mobject.Mobject::vmobject(
        tri_path,
        fill=Some(@math.Color::red()),
      )
      scene.add_layer(
        @anim.Layer::new(tri, [
          @anim.Animation::wait(duration=1.0),
          @anim.Animation::fade_in(duration=0.8),
          @anim.Animation::rotate(0.5, duration=2.0, easing=fn(t) {
            @anim.wiggle(t)
          }),
          @anim.Animation::wait(duration=1.2),
        ]),
      )
      Ok(scene)
    }
    "bench-heavy" => {
      // 1) long-formula morph, top center
      match
        (
          tex_at(
            renderer,
            "\\alpha^2+\\beta^2=\\gamma^2",
            40.0,
            @math.Vec2::new(480.0, 130.0),
          ),
          tex_at(
            renderer,
            "\\frac{\\alpha^2+\\beta^2}{\\gamma^2}",
            40.0,
            @math.Vec2::new(480.0, 130.0),
          ),
        ) {
        (Ok(ma), Ok(mb)) =>
          scene.add_layer(
            @anim.Layer::new(ma, [
              @anim.Animation::wait(duration=0.5),
              @anim.Animation::transform_matching(mb, duration=4.0),
              @anim.Animation::wait(duration=1.5),
            ]),
          )
        (Err(e), _) | (_, Err(e)) => return Err(e)
      }
      // 2) 5x5 grid of staggered grow/pulse/fade circles
      for row in 0..<5 {
        for col in 0..<5 {
          let idx = row * 5 + col
          let center = @math.Vec2::new(
            480.0 + (col.to_double() - 2.0) * 72.0,
            360.0 + (row.to_double() - 2.0) * 44.0,
          )
          let fill = if idx % 2 == 0 {
            @math.Color::blue()
          } else {
            @math.Color::green()
          }
          let dot = @mobject.Mobject::vmobject(
            @geom.Path::circle(center, 20.0),
            fill=Some(fill),
          )
          scene.add_layer(
            @anim.Layer::new(dot, [
              @anim.Animation::wait(duration=0.08 * idx.to_double()),
              @anim.Animation::grow_from_center(duration=0.6),
              @anim.Animation::scale_in_place(
                1.25,
                duration=1.2,
                easing=@anim.there_and_back,
              ),
              @anim.Animation::fade_out(duration=0.8),
            ]),
          )
        }
      }
      // 3) continuously rotating stroked frame (Rotating = rotate + linear)
      let frame = @mobject.Mobject::vmobject(
        @geom.Path::rect(@math.Vec2::new(230.0, 230.0), 500.0, 260.0),
        fill=None,
        stroke=Some((@math.Color::blue(), 2.0)),
      )
      scene.add_layer(
        @anim.Layer::new(frame, [
          @anim.Animation::rotate(
            2.0 * @core_math.PI,
            duration=6.0,
            easing=@anim.linear,
          ),
        ]),
      )
      Ok(scene)
    }
    _ => Err("unknown bench scene: " + scene_id)
  }
}

///|
/// Build the scene identified by `scene_id`. `a` / `b` are the formula
/// texts for the tex-driven scenes; morph and the bench scenes ignore them.
fn build_scene(
  scene_id : String,
  a : String,
  b : String,
) -> Result[@anim.Scene, String] {
  match scene_id {
    "bench-light" | "bench-standard" | "bench-heavy" => build_bench(scene_id)
    "write" => {
      // Arc-length creation demo: the formula writes itself (glyph by
      // glyph, layout order), then a dot rides a lap around it.
      let scene = @anim.Scene::new()
      let renderer = @tex.MiniTex::new()
      match tex_at(renderer, a, 56.0, @math.Vec2::new(480.0, 300.0)) {
        Err(e) => Err(e)
        Ok(m) => {
          scene.add_layer(
            @anim.Layer::new(m, [
              @anim.Animation::show_creation(duration=2.5),
              @anim.Animation::wait(duration=2.0),
            ]),
          )
          let dot = @mobject.Mobject::vmobject(
            @geom.Path::circle(@math.Vec2::new(600.0, 300.0), 14.0),
            fill=Some(@math.Color::green()),
          )
          let track = @geom.Path::circle(@math.Vec2::new(480.0, 300.0), 120.0)
          scene.add_layer(
            @anim.Layer::new(dot, [
              @anim.Animation::wait(duration=1.5),
              @anim.Animation::move_along_path(track, duration=3.0),
            ]),
          )
          Ok(scene)
        }
      }
    }
    "pointer" => { // Interaction-env demo (design.md「在线开发与交互外壳」): a dot
      // follows the pointer and a ring reacts to the primary button.
      // Nothing here animates over time — only env drives the frame.
      let scene = @anim.Scene::new()
      let axes_path = @geom.Path::new()
      axes_path.move_to(@math.Vec2::new(60.0, 270.0))
      axes_path.line_to(@math.Vec2::new(900.0, 270.0))
      axes_path.move_to(@math.Vec2::new(480.0, 60.0))
      axes_path.line_to(@math.Vec2::new(480.0, 480.0))
      let axes = @mobject.Mobject::vmobject(
        axes_path,
        fill=None,
        stroke=Some((@math.Color::new(0.4, 0.4, 0.45), 1.5)),
      )
      scene.add_layer(
        @anim.Layer::new(axes, [@anim.Animation::wait(duration=3600.0)]),
      )
      let dot = @mobject.Mobject::vmobject(
        @geom.Path::circle(@math.Vec2::new(480.0, 270.0), 26.0),
        fill=Some(@math.Color::green()),
      )
      scene.add_layer(
        @anim.Layer::new(dot, [
          @anim.Animation::new(
            fn(start, _p, env) {
              match env.pointer {
                Some(p) => start.move_center_to(p)
                None => start
              }
            },
            duration=3600.0,
            easing=@anim.linear,
          ),
        ]),
      )
      let ring = @mobject.Mobject::vmobject(
        @geom.Path::circle(@math.Vec2::new(480.0, 270.0), 44.0),
        fill=None,
        stroke=Some((@math.Color::blue(), 3.0)),
      )
      scene.add_layer(
        @anim.Layer::new(ring, [
          @anim.Animation::new(
            fn(start, _p, env) {
              match env.pointer {
                Some(p) => {
                  let k = if env.pointer_down { 1.35 } else { 1.0 }
                  start.move_center_to(p).scale_about(p, k)
                }
                None => start
              }
            },
            duration=3600.0,
            easing=@anim.linear,
          ),
        ]),
      )
      Ok(scene)
    }
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
/// The prepared scene, keyed by its inputs. `prepare` rebuilds only when
/// the key changes, so per-frame costs exclude scene construction — which
/// is timed and reported separately.
priv struct CachedScene {
  key : (String, String, String)
  result : Result[@anim.Scene, String]
}

///|
let scene_cache : Ref[CachedScene?] = { val: None }

///|
/// (svg, render_ms, svg_ms) of the most recent `frame` call.
let last_frame : Ref[(String, Double, Double)] = { val: ("", 0.0, 0.0) }

///|
/// Build the scene for the given inputs and cache it. Returns the build
/// time in ms, 0.0 on a cache hit, or -1.0 on a build error (the error is
/// kept in the cache and reported by `frame`).
fn prepare(scene_id : String, a : String, b : String) -> Double {
  let key = (scene_id, a, b)
  let hit = match scene_cache.val {
    Some(c) => c.key == key
    None => false
  }
  if hit {
    return 0.0
  }
  let t0 = now()
  let result = build_scene(scene_id, a, b)
  let ms = now() - t0
  scene_cache.val = Some({ key, result })
  match result {
    Ok(_) => ms
    Err(_) => -1.0
  }
}

///|
/// Render one frame of the prepared scene into `last_frame`, under the
/// interaction environment described by the pointer arguments (scene
/// coordinates, y-up). Returns "" on success or "ERROR: ..."; timings are
/// read back via the getters below.
fn frame(
  t : Double,
  px : Double,
  py : Double,
  pointer_active : Bool,
  pointer_down : Bool,
) -> String {
  match scene_cache.val {
    None => "ERROR: no scene prepared"
    Some(c) =>
      match c.result {
        Err(msg) => "ERROR: " + msg
        Ok(scene) => {
          let env : @anim.Env = {
            pointer: if pointer_active {
              Some(@math.Vec2::new(px, py))
            } else {
              None
            },
            pointer_down,
          }
          let t0 = now()
          let m = scene.render_at_env(t, env)
          let t1 = now()
          let svg = @svg.render_svg(m)
          let t2 = now()
          last_frame.val = (svg, t1 - t0, t2 - t1)
          ""
        }
      }
  }
}

///|
fn last_svg() -> String {
  last_frame.val.0
}

///|
fn last_render_ms() -> Double {
  last_frame.val.1
}

///|
fn last_svg_ms() -> Double {
  last_frame.val.2
}

///|
/// One SVG frame of the scene at time `t`. Errors are reported as an
/// "ERROR: ..." string so the page can display them. Kept for backward
/// compatibility; the page prefers the prepare/frame split so that scene
/// construction is not paid per frame.
fn render(scene_id : String, a : String, b : String, t : Double) -> String {
  ignore(prepare(scene_id, a, b))
  match frame(t, 0.0, 0.0, false, false) {
    "" => last_svg()
    err => err
  }
}

///|
/// Total duration of the scene in seconds (0 on error).
fn duration(scene_id : String, a : String, b : String) -> Double {
  ignore(prepare(scene_id, a, b))
  match scene_cache.val {
    Some({ result: Ok(scene), .. }) => scene.duration()
    _ => 0.0
  }
}

///|
fn main {
  register_api(
    render, duration, prepare, frame, last_svg, last_render_ms, last_svg_ms,
  )
}
