///|
/// One animated entity: a base mobject plus a sequence of animations that
/// play one after another.
pub(all) struct Layer {
  base : @mobject.Mobject
  steps : Array[Animation]
}

///|
pub fn Layer::new(base : @mobject.Mobject, steps : Array[Animation]) -> Layer {
  { base, steps }
}

///|
/// A scene: independent layers rendered as a Group. `render_at(t)` is a
/// pure function of time — no mutable playback state — so scrubbing and
/// frame caching are trivially correct.
pub(all) struct Scene {
  layers : Array[Layer]
}

///|
pub fn Scene::new() -> Scene {
  { layers: [] }
}

///|
pub fn Scene::add_layer(self : Scene, layer : Layer) -> Unit {
  self.layers.push(layer)
}

///|
/// Total duration of the longest layer.
pub fn Scene::duration(self : Scene) -> Double {
  let mut total = 0.0
  for layer in self.layers {
    let mut acc = 0.0
    for step in layer.steps {
      acc += step.duration
    }
    if acc > total {
      total = acc
    }
  }
  total
}

///|
/// State of the whole scene at time `t` under the default environment.
pub fn Scene::render_at(self : Scene, t : Double) -> @mobject.Mobject {
  self.render_at_env(t, Env::default())
}

///|
/// State of the whole scene at time `t` under the interaction environment
/// `env` (see `Env`). Still pure: same (scene, t, env), same frame.
pub fn Scene::render_at_env(
  self : Scene,
  t : Double,
  env : Env,
) -> @mobject.Mobject {
  let results : Array[@mobject.Mobject] = []
  for layer in self.layers {
    results.push(render_layer_at(layer, t, env))
  }
  Group(results)
}

///|
fn render_layer_at(layer : Layer, t : Double, env : Env) -> @mobject.Mobject {
  let mut current = layer.base
  let mut elapsed = 0.0
  for step in layer.steps {
    if t <= elapsed + step.duration {
      return step.at_env(current, t - elapsed, env)
    }
    current = step.at_env(current, step.duration, env)
    elapsed += step.duration
  }
  current
}

///|
/// Add one layer per base mobject, each playing `make_anim(i)` after
/// `i * lag` seconds of initial wait (manimlib LaggedStart): the standard
/// staggered-entrance combinator.
pub fn Scene::add_lagged(
  self : Scene,
  bases : Array[@mobject.Mobject],
  make_anim : (Int) -> Animation,
  lag? : Double = 0.1,
) -> Unit {
  for i, base in bases {
    self.add_layer(
      Layer::new(base, [
        Animation::wait(duration=i.to_double() * lag),
        make_anim(i),
      ]),
    )
  }
}
