///|
/// Expand a polyline into a stroke outline polygon of the given `width`,
/// using averaged vertex normals (bevel-style joins; miter limits are not
/// implemented yet). The result is a closed ring suitable for `triangulate`.
pub fn stroke_outline(
  points : Array[@math.Vec2],
  width : Double,
  closed? : Bool = false,
) -> Array[@math.Vec2] {
  let n = points.length()
  let half = width / 2.0
  if n < 2 {
    return []
  }
  // Per-vertex normals.
  let normals : Array[@math.Vec2] = []
  for i in 0..<n {
    if closed {
      let prev = points[(i + n - 1) % n]
      let next = points[(i + 1) % n]
      let n1 = (points[i] - prev).normal()
      let n2 = (next - points[i]).normal()
      normals.push((n1 + n2).normal())
    } else if i == 0 {
      normals.push((points[1] - points[0]).normal())
    } else if i == n - 1 {
      normals.push((points[n - 1] - points[n - 2]).normal())
    } else {
      let n1 = (points[i] - points[i - 1]).normal()
      let n2 = (points[i + 1] - points[i]).normal()
      normals.push((n1 + n2).normal())
    }
  }
  let left : Array[@math.Vec2] = []
  let right : Array[@math.Vec2] = []
  for i in 0..<n {
    left.push(points[i] + normals[i].scale(half))
    right.push(points[i] - normals[i].scale(half))
  }
  // Closed ring: left side forward, right side backward.
  let outline : Array[@math.Vec2] = []
  for p in left {
    outline.push(p)
  }
  for i in 0..<n {
    outline.push(right[n - 1 - i])
  }
  outline
}
