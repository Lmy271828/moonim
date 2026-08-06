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
/// State of the whole scene at time `t`.
pub fn Scene::render_at(self : Scene, t : Double) -> @mobject.Mobject {
  let results : Array[@mobject.Mobject] = []
  for layer in self.layers {
    results.push(render_layer_at(layer, t))
  }
  Group(results)
}

///|
fn render_layer_at(layer : Layer, t : Double) -> @mobject.Mobject {
  let mut current = layer.base
  let mut elapsed = 0.0
  for step in layer.steps {
    if t <= elapsed + step.duration {
      return step.at(current, t - elapsed)
    }
    current = step.at(current, step.duration)
    elapsed += step.duration
  }
  current
}
