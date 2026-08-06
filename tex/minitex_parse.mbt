///|
/// Abstract syntax of the supported formula subset.
priv enum Node {
  Glyph(Char)
  Frac(Array[Node], Array[Node])
  Script(base~ : Array[Node], sup~ : Array[Node]?, sub~ : Array[Node]?)
}

///|
/// A laid-out rectangle: either a glyph placeholder or a fraction rule.
/// Glyph boxes stand in for real glyph outlines until the glyph-data
/// module lands (documented in docs/design.md and README "功能边界").
priv struct Box {
  x : Double
  y : Double
  w : Double
  h : Double
}

///|
priv struct Parser {
  chars : Array[Char]
  mut pos : Int
}

///|
fn Parser::new(s : String) -> Parser {
  {
    chars: s.fold(init=[], fn(acc, c) {
      acc.push(c)
      acc
    }),
    pos: 0,
  }
}

///|
fn Parser::peek(self : Parser) -> Char? {
  if self.pos < self.chars.length() {
    Some(self.chars[self.pos])
  } else {
    None
  }
}

///|
/// Parse a braced group `{ ... }` or a single atom.
fn Parser::parse_group(self : Parser) -> Result[Array[Node], RenderError] {
  match self.peek() {
    Some('{') => {
      self.pos += 1
      self.parse_expr()
    }
    Some(_) =>
      match self.parse_atom() {
        Some(node) => Ok([node])
        None => Err(UnsupportedSyntax("expected atom"))
      }
    None => Err(UnsupportedSyntax("unexpected end of formula"))
  }
}

///|
/// Read a control word after a backslash, e.g. `\frac` -> "frac".
fn Parser::read_command(self : Parser) -> String {
  self.pos += 1 // consume '\\'
  let buf = StringBuilder::new()
  while self.peek() is Some(c) && is_ascii_letter(c) {
    buf.write_char(c)
    self.pos += 1
  }
  buf.to_string()
}

///|
fn is_ascii_letter(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
/// One glyph-producing atom: a character or a known command.
fn Parser::parse_atom(self : Parser) -> Node? {
  match self.peek() {
    Some('\\') => {
      let cmd = self.read_command()
      match greek_letter(cmd) {
        Some(c) => Some(Glyph(c))
        None => None // structural commands are handled by the caller
      }
    }
    Some(c) if c != '{' && c != '}' && c != '^' && c != '_' => {
      self.pos += 1
      Some(Glyph(c))
    }
    _ => None
  }
}

///|
/// Map a small set of Greek letter commands to Unicode code points.
/// The MiniTex glyph boxes make no visual distinction yet, but the
/// mapping keeps the parsed AST faithful for future glyph backends.
fn greek_letter(name : String) -> Char? {
  match name {
    "alpha" => Some('α')
    "beta" => Some('β')
    "gamma" => Some('γ')
    "delta" => Some('δ')
    "epsilon" => Some('ε')
    "theta" => Some('θ')
    "lambda" => Some('λ')
    "mu" => Some('μ')
    "pi" => Some('π')
    "sigma" => Some('σ')
    "phi" => Some('φ')
    "omega" => Some('ω')
    _ => None
  }
}

///|
/// Parse a sequence of terms up to a closing brace or end of input.
fn Parser::parse_expr(self : Parser) -> Result[Array[Node], RenderError] {
  let nodes : Array[Node] = []
  while true {
    match self.peek() {
      None => break
      Some('}') => {
        self.pos += 1
        break
      }
      Some('\\') => {
        // Peek at the command name without consuming it yet.
        let save = self.pos
        let cmd = self.read_command()
        if cmd == "frac" {
          let num = self.parse_group()
          let den = match num {
            Ok(_) => self.parse_group()
            Err(e) => Err(e)
          }
          match (num, den) {
            (Ok(n), Ok(d)) => nodes.push(Frac(n, d))
            (Err(e), _) => return Err(e)
            (_, Err(e)) => return Err(e)
          }
        } else {
          self.pos = save
          match self.parse_atom() {
            Some(node) => nodes.push(node)
            None => return Err(UnsupportedSyntax("unknown command: \\" + cmd))
          }
        }
      }
      Some(_) =>
        match self.parse_atom() {
          Some(atom) => nodes.push(parse_scripts(self, atom))
          None => return Err(UnsupportedSyntax("unexpected character"))
        }
    }
  }
  Ok(nodes)
}

///|
/// Attach trailing `^` / `_` scripts to an atom.
fn parse_scripts(parser : Parser, atom : Node) -> Node {
  let mut sup : Array[Node]? = None
  let mut sub : Array[Node]? = None
  let mut found = false
  while true {
    match parser.peek() {
      Some('^') => {
        parser.pos += 1
        match parser.parse_group() {
          Ok(group) => {
            sup = Some(group)
            found = true
          }
          Err(_) => break
        }
      }
      Some('_') => {
        parser.pos += 1
        match parser.parse_group() {
          Ok(group) => {
            sub = Some(group)
            found = true
          }
          Err(_) => break
        }
      }
      _ => break
    }
  }
  if found {
    Script(base=[atom], sup~, sub~)
  } else {
    atom
  }
}

///|
/// Lay out a node sequence at the given em size. Returns the advance width
/// and the boxes, with y = 0 at the baseline (TeX-style box model).
fn layout(nodes : Array[Node], size : Double) -> (Double, Array[Box]) {
  let boxes : Array[Box] = []
  let mut x = 0.0
  let gap = 0.08 * size
  for node in nodes {
    match node {
      Glyph(c) =>
        if c == ' ' {
          // Spaces advance without drawing a box.
          x += 0.3 * size
        } else {
          // Placeholder glyph box: half-em wide, one em tall.
          boxes.push({ x, y: 0.0, w: 0.5 * size, h: size })
          x += 0.5 * size + gap
        }
      Frac(num, den) => {
        let inner = size * 0.75
        let (wn, bn) = layout(num, inner)
        let (wd, bd) = layout(den, inner)
        let w = (if wn > wd { wn } else { wd }) + 0.3 * size
        // Numerator above, denominator below, centered.
        place(boxes, bn, x + (w - wn) / 2.0, 0.85 * size)
        place(boxes, bd, x + (w - wd) / 2.0, -1.05 * size)
        // Fraction rule.
        boxes.push({ x, y: 0.3 * size, w, h: 0.05 * size })
        x += w + gap
      }
      Script(base~, sup~, sub~) => {
        let (wb, bb) = layout(base, size)
        place(boxes, bb, x, 0.0)
        let script_size = size * 0.65
        let mut script_w = 0.0
        match sup {
          Some(group) => {
            let (ws, bs) = layout(group, script_size)
            place(boxes, bs, x + wb, 0.7 * size)
            if ws > script_w {
              script_w = ws
            }
          }
          None => ()
        }
        match sub {
          Some(group) => {
            let (ws, bs) = layout(group, script_size)
            place(boxes, bs, x + wb, -0.5 * size)
            if ws > script_w {
              script_w = ws
            }
          }
          None => ()
        }
        x += wb + script_w + gap
      }
    }
  }
  (x, boxes)
}

///|
/// Copy `src` boxes into `dst`, offset by (dx, dy).
fn place(dst : Array[Box], src : Array[Box], dx : Double, dy : Double) -> Unit {
  for b in src {
    dst.push({ x: b.x + dx, y: b.y + dy, w: b.w, h: b.h })
  }
}
