///|
test "render simple expression" {
  let tex = MiniTex::new()
  match tex.render("x^2", 1.0) {
    Ok(path) =>
      match path.bbox() {
        Some(b) => assert_true(b.height() > 1.0) // base + raised script
        None => abort("expected bbox")
      }
    Err(_) => abort("unexpected error")
  }
}

///|
test "fraction is taller than a single glyph" {
  let tex = MiniTex::new()
  match (tex.render("\\frac{1}{2}", 1.0), tex.render("1", 1.0)) {
    (Ok(frac), Ok(one)) =>
      match (frac.bbox(), one.bbox()) {
        (Some(f), Some(o)) => assert_true(f.height() > 2.0 * o.height())
        _ => abort("expected bboxes")
      }
    _ => abort("unexpected error")
  }
}

///|
test "greek letters parse" {
  let tex = MiniTex::new()
  assert_true(tex.render("\\alpha + \\beta", 1.0) is Ok(_))
}

///|
test "scripts attach to command atoms, not just characters" {
  // Regression: \alpha^2 used to fail because the \\ branch of parse_expr
  // skipped parse_scripts, leaving '^' to error out as a stray character.
  let tex = MiniTex::new()
  match (tex.render("\\alpha^2", 1.0), tex.render("\\alpha", 1.0)) {
    (Ok(with_sup), Ok(plain)) =>
      match (with_sup.bbox(), plain.bbox()) {
        (Some(ws), Some(p)) => assert_true(ws.height() > p.height())
        _ => abort("expected bboxes")
      }
    _ => abort("unexpected error")
  }
}

///|
test "unknown command is rejected" {
  let tex = MiniTex::new()
  assert_eq(
    tex.render("\\ce{H2O}", 1.0),
    Err(UnsupportedSyntax("unknown command: \\ce")),
  )
}

///|
test "empty formula and unbalanced braces" {
  let tex = MiniTex::new()
  assert_eq(tex.render("", 1.0), Err(EmptyFormula))
  assert_eq(tex.render("\\frac{1}{2", 1.0), Err(UnbalancedBraces))
}

///|
priv struct Counting {
  mut calls : Int
}

///|
impl FormulaRenderer for Counting with fn render(self, _formula, _size) {
  self.calls += 1
  Ok(@geom.Path::new())
}

///|
test "cached renderer computes each (formula, size) key only once" {
  let c = CachedRenderer::new(Counting::{ calls: 0 }, 8)
  ignore(c.render("x^2", 1.0))
  ignore(c.render("x^2", 1.0)) // same key: cache hit
  ignore(c.render("x^2", 2.0)) // different size: miss
  ignore(c.render("y", 1.0)) // different formula: miss
  assert_eq(c.inner.calls, 3)
}

///|
test "render_symbols keeps labels in layout order" {
  let tex = MiniTex::new()
  match tex.render_symbols("\\frac{x}{2}", 1.0) {
    Ok(symbols) => {
      let labels = symbols.map(fn(s) { s.0 })
      assert_eq(labels, ["x", "2", "\\frac"])
    }
    Err(_) => abort("unexpected error")
  }
}

///|
test "render outline equals union of symbol outlines" {
  let tex = MiniTex::new()
  match (tex.render("x^2", 1.0), tex.render_symbols("x^2", 1.0)) {
    (Ok(outline), Ok(symbols)) => {
      let mut total = 0
      for s in symbols {
        total += s.1.segments.length()
      }
      assert_eq(outline.segments.length(), total)
    }
    _ => abort("unexpected error")
  }
}

///|
test "embedded glyphs produce real outlines and advances" {
  let tex = MiniTex::new()
  // A covered glyph is drawn with cubic curves, not a rectangle.
  match tex.render("x", 1.0) {
    Ok(path) =>
      assert_true(
        path.segments.iter().any(fn(s) { s is @geom.CubicTo(_, _, _) }),
      )
    Err(_) => abort("unexpected error")
  }
  // Real font advances: "m" is much wider than "i".
  match (tex.render("i", 1.0), tex.render("m", 1.0)) {
    (Ok(narrow), Ok(wide)) =>
      match (narrow.bbox(), wide.bbox()) {
        (Some(bn), Some(bw)) => assert_true(bw.width() > 2.0 * bn.width())
        _ => abort("expected bboxes")
      }
    _ => abort("unexpected error")
  }
}

///|
test "characters outside the glyph subset fall back to placeholder boxes" {
  let tex = MiniTex::new()
  match tex.render("中", 1.0) {
    Ok(path) => assert_eq(path.segments.length(), 5) // M + 3L + Z rectangle
    Err(_) => abort("unexpected error")
  }
}
