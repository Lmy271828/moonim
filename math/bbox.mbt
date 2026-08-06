///|
/// Axis-aligned bounding box.
pub(all) struct BBox {
  min : Vec2
  max : Vec2
} derive(Eq, @debug.Debug)

///|
pub fn BBox::new(min : Vec2, max : Vec2) -> BBox {
  { min, max }
}

///|
/// Bounding box of a point set, `None` for the empty set.
pub fn BBox::from_points(points : Array[Vec2]) -> BBox? {
  if points.is_empty() {
    return None
  }
  let mut min_x = points[0].x
  let mut min_y = points[0].y
  let mut max_x = points[0].x
  let mut max_y = points[0].y
  for p in points {
    if p.x < min_x {
      min_x = p.x
    }
    if p.y < min_y {
      min_y = p.y
    }
    if p.x > max_x {
      max_x = p.x
    }
    if p.y > max_y {
      max_y = p.y
    }
  }
  Some(BBox::new(Vec2::new(min_x, min_y), Vec2::new(max_x, max_y)))
}

///|
pub fn BBox::union(self : BBox, other : BBox) -> BBox {
  {
    min: Vec2::new(
      if self.min.x < other.min.x {
        self.min.x
      } else {
        other.min.x
      },
      if self.min.y < other.min.y {
        self.min.y
      } else {
        other.min.y
      },
    ),
    max: Vec2::new(
      if self.max.x > other.max.x {
        self.max.x
      } else {
        other.max.x
      },
      if self.max.y > other.max.y {
        self.max.y
      } else {
        other.max.y
      },
    ),
  }
}

///|
pub fn BBox::width(self : BBox) -> Double {
  self.max.x - self.min.x
}

///|
pub fn BBox::height(self : BBox) -> Double {
  self.max.y - self.min.y
}

///|
pub fn BBox::center(self : BBox) -> Vec2 {
  Vec2::new((self.min.x + self.max.x) / 2.0, (self.min.y + self.max.y) / 2.0)
}
