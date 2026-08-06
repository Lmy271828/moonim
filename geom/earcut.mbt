// Portions of this file are ported from mapbox/earcut
// (https://github.com/mapbox/earcut), ISC License.
// Copyright (c) 2015, Mapbox. See docs/porting.md for the full license text
// and the porting scope. Deviation from the original: this is a plain
// O(n^2) ear-clipping pass over a single polygon ring; hole handling and
// the z-order hashing optimization are not ported yet.

///|
/// Signed area of a polygon ring (positive for counter-clockwise).
pub fn signed_area(poly : Array[@math.Vec2]) -> Double {
  let n = poly.length()
  let mut sum = 0.0
  for i in 0..<n {
    let j = (i + 1) % n
    sum += poly[i].cross(poly[j])
  }
  sum / 2.0
}

///|
fn point_in_triangle(
  a : @math.Vec2,
  b : @math.Vec2,
  c : @math.Vec2,
  p : @math.Vec2,
) -> Bool {
  let d1 = (b - a).cross(p - a)
  let d2 = (c - b).cross(p - b)
  let d3 = (a - c).cross(p - c)
  let has_neg = d1 < 0.0 || d2 < 0.0 || d3 < 0.0
  let has_pos = d1 > 0.0 || d2 > 0.0 || d3 > 0.0
  !(has_neg && has_pos)
}

///|
/// Triangulate a simple polygon (single ring, no holes) by ear clipping.
/// Returns triples of vertex indices into `poly`, in counter-clockwise
/// winding. Degenerate or self-intersecting input may produce fewer than
/// `n - 2` triangles.
pub fn triangulate(poly : Array[@math.Vec2]) -> Array[(Int, Int, Int)] {
  let n = poly.length()
  let triangles : Array[(Int, Int, Int)] = []
  if n < 3 {
    return triangles
  }
  // Index ring in counter-clockwise order.
  let indices : Array[Int] = []
  if signed_area(poly) > 0.0 {
    for i in 0..<n {
      indices.push(i)
    }
  } else {
    for i in 0..<n {
      indices.push(n - 1 - i)
    }
  }
  let mut remaining = n
  let mut cursor = 0
  let mut stall = 0
  while remaining > 2 && stall < remaining {
    let i_prev = indices[(cursor + remaining - 1) % remaining]
    let i_cur = indices[cursor % remaining]
    let i_next = indices[(cursor + 1) % remaining]
    let a = poly[i_prev]
    let b = poly[i_cur]
    let c = poly[i_next]
    // Convex corner? (ring is CCW)
    if (b - a).cross(c - b) <= 0.0 {
      cursor += 1
      stall += 1
      continue
    }
    // Ear must not contain any other vertex.
    let mut is_ear = true
    for k in 0..<remaining {
      let i = indices[k]
      if i != i_prev && i != i_cur && i != i_next {
        if point_in_triangle(a, b, c, poly[i]) {
          is_ear = false
          break
        }
      }
    }
    if is_ear {
      triangles.push((i_prev, i_cur, i_next))
      indices.remove(cursor % remaining) |> ignore
      remaining -= 1
      stall = 0
    } else {
      cursor += 1
      stall += 1
    }
  }
  triangles
}
