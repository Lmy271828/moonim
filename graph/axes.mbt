///|
/// Axes, number lines and function plots (manimlib `number_line.py` /
/// `coordinate_systems.py` / `functions.py` subset). All builders return
/// ordinary mobjects/paths in scene coordinates (y-up); tick labels are
/// typeset by MiniTex.

///|
/// Tick label text: integral values print without a decimal point,
/// others round to one decimal.
fn tick_label(v : Double) -> String {
  let r = (v * 10.0).round() / 10.0
  let i = r.to_int()
  if (r - i.to_double()).abs() < 1.0e-9 {
    i.to_string()
  } else {
    r.to_string()
  }
}

///|
/// A typeset label centered at `center`; unrenderable text (outside the
/// glyph subset) silently drops to nothing — axes degrade gracefully.
fn label_at(
  renderer : @tex.MiniTex,
  text : String,
  size : Double,
  center : @math.Vec2,
) -> @mobject.Mobject {
  match renderer.render(text, size) {
    Ok(path) => @mobject.Mobject::vmobject(path).move_center_to(center)
    Err(_) => @mobject.Mobject::group([])
  }
}

///|
/// Map data coordinates to scene coordinates: origin + (x * x_unit,
/// y * y_unit), y-up.
pub fn map_point(
  origin : @math.Vec2,
  unit : Double,
  y_unit : Double?,
  x : Double,
  y : Double,
) -> @math.Vec2 {
  let yu = match y_unit {
    Some(u) => u
    None => unit
  }
  @math.Vec2::new(origin.x + x * unit, origin.y + y * yu)
}

///|
/// 2D axes with tick marks and number labels (manimlib `Axes` subset):
/// both axis lines, ticks at every `step`, x labels below the axis and
/// y labels left of it (0 is drawn once, at the origin).
pub fn axes(
  x_min? : Double = -5.0,
  x_max? : Double = 5.0,
  y_min? : Double = -3.0,
  y_max? : Double = 3.0,
  step? : Double = 1.0,
  origin? : @math.Vec2 = @math.Vec2::new(480.0, 270.0),
  unit? : Double = 60.0,
  y_unit? : Double? = None,
  color? : @math.Color = @math.Color::new(0.75, 0.75, 0.8),
  label_size? : Double = 22.0,
) -> @mobject.Mobject {
  let children : Array[@mobject.Mobject] = []
  let p = fn(x, y) { map_point(origin, unit, y_unit, x, y) }
  // Axis lines.
  children.push(@mobject.Mobject::line(p(x_min, 0.0), p(x_max, 0.0), color~))
  children.push(@mobject.Mobject::line(p(0.0, y_min), p(0.0, y_max), color~))
  // Ticks.
  let tick = 5.0
  let mut xv = x_min
  while xv <= x_max + 1.0e-9 {
    let c = p(xv, 0.0)
    children.push(
      @mobject.Mobject::line(
        @math.Vec2::new(c.x, c.y - tick),
        @math.Vec2::new(c.x, c.y + tick),
        color~,
        width=1.5,
      ),
    )
    xv += step
  }
  let mut yv = y_min
  while yv <= y_max + 1.0e-9 {
    let c = p(0.0, yv)
    children.push(
      @mobject.Mobject::line(
        @math.Vec2::new(c.x - tick, c.y),
        @math.Vec2::new(c.x + tick, c.y),
        color~,
        width=1.5,
      ),
    )
    yv += step
  }
  // Labels.
  let renderer = @tex.MiniTex::new()
  xv = x_min
  while xv <= x_max + 1.0e-9 {
    if xv.abs() > 1.0e-9 {
      let c = p(xv, 0.0)
      children.push(
        label_at(
          renderer,
          tick_label(xv),
          label_size,
          @math.Vec2::new(c.x, c.y - 20.0),
        ),
      )
    }
    xv += step
  }
  yv = y_min
  while yv <= y_max + 1.0e-9 {
    if yv.abs() > 1.0e-9 {
      let c = p(0.0, yv)
      children.push(
        label_at(
          renderer,
          tick_label(yv),
          label_size,
          @math.Vec2::new(c.x - 20.0, c.y),
        ),
      )
    }
    yv += step
  }
  children.push(
    label_at(
      renderer,
      "0",
      label_size,
      @math.Vec2::new(origin.x - 14.0, origin.y - 18.0),
    ),
  )
  Group(children)
}

///|
/// A horizontal number line with ticks and labels below (manimlib
/// `NumberLine` subset).
pub fn number_line(
  min? : Double = -5.0,
  max? : Double = 5.0,
  step? : Double = 1.0,
  origin? : @math.Vec2 = @math.Vec2::new(480.0, 270.0),
  unit? : Double = 60.0,
  color? : @math.Color = @math.Color::new(0.75, 0.75, 0.8),
  label_size? : Double = 22.0,
) -> @mobject.Mobject {
  let children : Array[@mobject.Mobject] = []
  let p = fn(x) { map_point(origin, unit, None, x, 0.0) }
  children.push(@mobject.Mobject::line(p(min), p(max), color~))
  let renderer = @tex.MiniTex::new()
  let mut xv = min
  while xv <= max + 1.0e-9 {
    let c = p(xv)
    children.push(
      @mobject.Mobject::line(
        @math.Vec2::new(c.x, c.y - 5.0),
        @math.Vec2::new(c.x, c.y + 5.0),
        color~,
        width=1.5,
      ),
    )
    children.push(
      label_at(
        renderer,
        tick_label(xv),
        label_size,
        @math.Vec2::new(c.x, c.y - 22.0),
      ),
    )
    xv += step
  }
  Group(children)
}

///|
/// Sample `f` over [x_min, x_max] into a path in scene coordinates,
/// following the same data→scene mapping as `axes`. The result is an
/// ordinary path: stroke it, `show_creation` it, or ride it with
/// `move_along_path`.
pub fn plot(
  f : (Double) -> Double,
  x_min~ : Double,
  x_max~ : Double,
  origin? : @math.Vec2 = @math.Vec2::new(480.0, 270.0),
  unit? : Double = 60.0,
  y_unit? : Double? = None,
  samples? : Int = 120,
) -> @geom.Path {
  let path = @geom.Path::new()
  for i in 0..<=samples {
    let x = x_min + (x_max - x_min) * i.to_double() / samples.to_double()
    let sp = map_point(origin, unit, y_unit, x, f(x))
    if i == 0 {
      path.move_to(sp)
    } else {
      path.line_to(sp)
    }
  }
  path
}
