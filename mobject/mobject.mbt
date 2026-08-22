///|
/// A labeled symbol outline inside a `Tex` node: the glyph-level structure
/// that `Animation::transform_matching` matches on (docs/design.md §3.1,
/// layer L1). Never rendered directly — rendering uses the Tex outline.
pub(all) struct Symbol {
  label : String
  outline : @geom.Path
} derive(Eq, @debug.Debug)

///|
/// The scene graph node. Rendering traversal, bounding boxes and animation
/// targets are all pattern matches over this ADT — adding a new variant is
/// a compile-time-checked change everywhere.
pub(all) enum Mobject {
  /// A vectorized object: a path plus paint.
  VMobject(
    path~ : @geom.Path,
    fill~ : @math.Color?,
    stroke~ : (@math.Color, Double)?
  )
  /// A group of sub-mobjects; transforms propagate recursively.
  Group(Array[Mobject])
  /// A typeset formula. `outline` is the renderer-independent vector
  /// outline produced by a `FormulaRenderer` (see package `tex`);
  /// `symbols` carries the labeled glyph-level structure for part
  /// matching (empty for renderers that do not expose labels).
  Tex(formula~ : String, outline~ : @geom.Path, symbols~ : Array[Symbol])
} derive(Eq, @debug.Debug)

///|
/// Plain vector mobject with a white fill by default.
pub fn Mobject::vmobject(
  path : @geom.Path,
  fill? : @math.Color? = Some(@math.Color::white()),
  stroke? : (@math.Color, Double)? = None,
) -> Mobject {
  VMobject(path~, fill~, stroke~)
}

///|
/// Build a Tex mobject from labeled symbol outlines (as produced by
/// `MiniTex::render_symbols`); the node outline is the union of all
/// symbol outlines, in order.
pub fn Mobject::tex(
  formula : String,
  symbols : Array[(String, @geom.Path)],
) -> Mobject {
  let outline = @geom.Path::new()
  let syms : Array[Symbol] = []
  for pair in symbols {
    let (label, path) = pair
    for seg in path.segments {
      outline.segments.push(seg)
    }
    syms.push({ label, outline: path })
  }
  Tex(formula~, outline~, symbols=syms)
}

///|
pub fn Mobject::group(children : Array[Mobject]) -> Mobject {
  Group(children)
}

///|
/// Sub-mobjects of a Group; empty for leaves.
pub fn Mobject::submobjects(self : Mobject) -> Array[Mobject] {
  match self {
    Group(children) => children
    _ => []
  }
}

///|
/// Recursive bounding box. Stroke width is ignored (documented
/// approximation: it only widens the box by half the stroke width).
pub fn Mobject::bbox(self : Mobject) -> @math.BBox? {
  match self {
    VMobject(path~, ..) => path.bbox()
    Tex(outline~, ..) => outline.bbox()
    Group(children) => {
      let mut acc : @math.BBox? = None
      for child in children {
        match (acc, child.bbox()) {
          (Some(a), Some(b)) => acc = Some(a.union(b))
          (None, Some(b)) => acc = Some(b)
          _ => ()
        }
      }
      acc
    }
  }
}

///|
/// Apply an affine transform, returning a new mobject. The formula text of
/// a Tex node is preserved; only its cached outline is transformed.
pub fn Mobject::transform(self : Mobject, m : @math.Mat3) -> Mobject {
  match self {
    VMobject(path~, fill~, stroke~) =>
      VMobject(path=path.transform(m), fill~, stroke~)
    Tex(formula~, outline~, symbols~) =>
      Tex(
        formula~,
        outline=outline.transform(m),
        symbols=symbols.map(fn(s) {
          { label: s.label, outline: s.outline.transform(m) }
        }),
      )
    Group(children) => {
      let mapped : Array[Mobject] = []
      for child in children {
        mapped.push(child.transform(m))
      }
      Group(mapped)
    }
  }
}

///|
/// Translate so the bbox center lands at `target`. No-op for empty mobjects.
pub fn Mobject::move_center_to(self : Mobject, target : @math.Vec2) -> Mobject {
  match self.bbox() {
    Some(b) => {
      let c = b.center()
      self.transform(@math.Mat3::translate(target.x - c.x, target.y - c.y))
    }
    None => self
  }
}
