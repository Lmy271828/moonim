///|
/// The built-in subset formula renderer.
///
/// Supported syntax (v0.1): plain characters, `{...}` grouping, `\frac`,
/// superscript `^`, subscript `_`, and a small set of Greek letter
/// commands. Glyphs are drawn as placeholder half-em boxes pending the
/// glyph-data module — the layout itself already follows the TeX box
/// model (baseline, fraction rule, script raises), so swapping in real
/// glyph outlines is a localized change.
pub(all) struct MiniTex {}

///|
pub fn MiniTex::new() -> MiniTex {
  MiniTex::{  }
}

///|
pub impl FormulaRenderer for MiniTex with fn render(self, formula, size) {
  ignore(self)
  if formula.is_empty() {
    return Err(EmptyFormula)
  }
  if not_balanced(formula) {
    return Err(UnbalancedBraces)
  }
  let parser = Parser::new(formula)
  match parser.parse_expr() {
    Err(e) => Err(e)
    Ok(nodes) => {
      let (_, boxes) = layout(nodes, size)
      let path = @geom.Path::new()
      for b in boxes {
        // Glyph/rule boxes as simple line rectangles.
        path.move_to(@math.Vec2::new(b.x, b.y))
        path.line_to(@math.Vec2::new(b.x + b.w, b.y))
        path.line_to(@math.Vec2::new(b.x + b.w, b.y + b.h))
        path.line_to(@math.Vec2::new(b.x, b.y + b.h))
        path.close()
      }
      Ok(path)
    }
  }
}

///|
fn not_balanced(s : String) -> Bool {
  let mut depth = 0
  let mut unbalanced = false
  ignore(
    s.fold(init=0, fn(acc, c) {
      if c == '{' {
        depth = acc + 1
        depth
      } else if c == '}' {
        depth = acc - 1
        if depth < 0 {
          unbalanced = true
        }
        depth
      } else {
        acc
      }
    }),
  )
  unbalanced || depth != 0
}
