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
