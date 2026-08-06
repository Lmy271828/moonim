///|
/// RGBA color, channels in [0, 1].
pub(all) struct Color {
  r : Double
  g : Double
  b : Double
  a : Double
} derive(Eq, @debug.Debug)

///|
pub fn Color::new(
  r : Double,
  g : Double,
  b : Double,
  a? : Double = 1.0,
) -> Color {
  { r, g, b, a }
}

///|
pub fn Color::white() -> Color {
  Color::new(1.0, 1.0, 1.0)
}

///|
pub fn Color::black() -> Color {
  Color::new(0.0, 0.0, 0.0)
}

///|
pub fn Color::red() -> Color {
  Color::new(1.0, 0.0, 0.0)
}

///|
pub fn Color::green() -> Color {
  Color::new(0.0, 0.7, 0.0)
}

///|
pub fn Color::blue() -> Color {
  Color::new(0.0, 0.3, 1.0)
}

///|
pub fn Color::yellow() -> Color {
  Color::new(1.0, 0.85, 0.0)
}

///|
fn clamp01(x : Double) -> Double {
  if x < 0.0 {
    0.0
  } else if x > 1.0 {
    1.0
  } else {
    x
  }
}

///|
pub fn Color::lerp(self : Color, other : Color, t : Double) -> Color {
  {
    r: self.r + (other.r - self.r) * t,
    g: self.g + (other.g - self.g) * t,
    b: self.b + (other.b - self.b) * t,
    a: self.a + (other.a - self.a) * t,
  }
}

///|
fn hex_digit(n : Int) -> String {
  match n {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "a"
    11 => "b"
    12 => "c"
    13 => "d"
    14 => "e"
    _ => "f"
  }
}

///|
fn byte_hex(v : Double) -> String {
  let b = (clamp01(v) * 255.0 + 0.5).to_int()
  hex_digit(b / 16) + hex_digit(b % 16)
}

///|
/// CSS hex color, e.g. "#ff8800". Alpha is exported separately via `opacity()`.
pub fn Color::to_hex(self : Color) -> String {
  "#" + byte_hex(self.r) + byte_hex(self.g) + byte_hex(self.b)
}

///|
/// Alpha channel clamped to [0, 1], for SVG *-opacity attributes.
pub fn Color::opacity(self : Color) -> Double {
  clamp01(self.a)
}
