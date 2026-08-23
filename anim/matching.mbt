///|
/// Part-matched transform (docs/design.md §3.1, layers L2 and L1): the
/// moonim port of Manim's `TransformMatchingTex`.
///
/// The morph plan pairs source parts to target parts — first by explicit
/// `key_map` label mapping, then by longest common substring of symbol
/// labels, then by shape equivalence — and fades whatever is left:
/// source orphans shrink into the target's center while fading out,
/// target orphans grow from the source's center while fading in.
priv struct MatchPlan {
  // Pre-aligned pairs, so evaluation hits the fast path of `lerp`.
  pairs : Array[(@mobject.Mobject, @mobject.Mobject)]
  start_orphans : Array[@mobject.Mobject]
  target_orphans : Array[@mobject.Mobject]
  start_center : @math.Vec2
  target_center : @math.Vec2
}

///|
/// Morph into `to` by matching parts (symbols for Tex, leaves for groups)
/// instead of requiring whole-structure compatibility. The plan is
/// computed once on first evaluation and memoized: `render_at` replays
/// the update closure every frame, while matching is an expensive,
/// idempotent subcomputation (same argument as the §4 cache layer).
pub fn Animation::transform_matching(
  to : @mobject.Mobject,
  duration~ : Double,
  easing? : (Double) -> Double = smooth,
  key_map? : Map[String, String] = Map([]),
) -> Animation {
  let memo : Ref[MatchPlan?] = { val: None }
  Animation::new(
    fn(start, p) {
      if p <= 0.0 {
        start
      } else if p >= 1.0 {
        // Land exactly on the target, preserving its structure for any
        // animation chained after this one.
        to
      } else {
        let plan = match memo.val {
          Some(plan) => plan
          None => {
            let plan = compute_plan(start, to, key_map)
            memo.val = Some(plan)
            plan
          }
        }
        eval_plan(plan, p)
      }
    },
    duration~,
    easing~,
  )
}

///|
fn compute_plan(
  start : @mobject.Mobject,
  to : @mobject.Mobject,
  key_map : Map[String, String],
) -> MatchPlan {
  let sp = start.parts()
  let tp = to.parts()
  let used_s = Array::make(sp.length(), false)
  let used_t = Array::make(tp.length(), false)
  let raw_pairs : Array[(Int, Int)] = []
  // 1. Explicit user mapping, label to label.
  for from_label, to_label in key_map {
    match
      (find_label(sp, used_s, from_label), find_label(tp, used_t, to_label)) {
      (Some(i), Some(j)) => {
        used_s[i] = true
        used_t[j] = true
        raw_pairs.push((i, j))
      }
      _ => ()
    }
  }
  // 2. Longest common substring over the remaining label sequences.
  match_labels(sp, tp, used_s, used_t, raw_pairs)
  // 3. Greedy shape matching over what is left.
  for i in 0..<sp.length() {
    if used_s[i] {
      continue
    }
    for j in 0..<tp.length() {
      if !used_t[j] && sp[i].mobject.same_shape(tp[j].mobject) {
        used_s[i] = true
        used_t[j] = true
        raw_pairs.push((i, j))
        break
      }
    }
  }
  let pairs : Array[(@mobject.Mobject, @mobject.Mobject)] = []
  for pair in raw_pairs {
    let (i, j) = pair
    pairs.push(aligned_pair(sp[i].mobject, tp[j].mobject))
  }
  let start_orphans : Array[@mobject.Mobject] = []
  let target_orphans : Array[@mobject.Mobject] = []
  for i in 0..<sp.length() {
    if !used_s[i] {
      start_orphans.push(sp[i].mobject)
    }
  }
  for j in 0..<tp.length() {
    if !used_t[j] {
      target_orphans.push(tp[j].mobject)
    }
  }
  {
    pairs,
    start_orphans,
    target_orphans,
    start_center: center_of(start),
    target_center: center_of(to),
  }
}

///|
/// First unused part carrying `label`.
fn find_label(
  parts : Array[@mobject.Part],
  used : Array[Bool],
  label : String,
) -> Int? {
  for i, part in parts {
    if !used[i] && part.label is Some(l) && l == label {
      return Some(i)
    }
  }
  None
}

///|
/// Repeatedly pair the longest run of consecutive equal labels among the
/// unused parts (Manim uses `difflib.SequenceMatcher` the same way), so
/// common formula fragments morph as coherent blocks.
fn match_labels(
  sp : Array[@mobject.Part],
  tp : Array[@mobject.Part],
  used_s : Array[Bool],
  used_t : Array[Bool],
  pairs : Array[(Int, Int)],
) -> Unit {
  while true {
    let mut best_len = 0
    let mut best_i = 0
    let mut best_j = 0
    for i in 0..<sp.length() {
      if used_s[i] || sp[i].label is None {
        continue
      }
      for j in 0..<tp.length() {
        if used_t[j] || tp[j].label is None {
          continue
        }
        let mut k = 0
        while i + k < sp.length() &&
              j + k < tp.length() &&
              !used_s[i + k] &&
              !used_t[j + k] &&
              sp[i + k].label is Some(_) &&
              sp[i + k].label == tp[j + k].label {
          k += 1
        }
        if k > best_len {
          best_len = k
          best_i = i
          best_j = j
        }
      }
    }
    if best_len == 0 {
      break
    }
    for k in 0..<best_len {
      used_s[best_i + k] = true
      used_t[best_j + k] = true
      pairs.push((best_i + k, best_j + k))
    }
  }
}

///|
/// Pre-align the paths of two VMobject parts so evaluation-time lerp
/// takes the pointwise fast path; paints stay with their own side.
fn aligned_pair(
  a : @mobject.Mobject,
  b : @mobject.Mobject,
) -> (@mobject.Mobject, @mobject.Mobject) {
  match (a, b) {
    (
      VMobject(path=p1, fill=f1, stroke=s1),
      VMobject(path=p2, fill=f2, stroke=s2),
    ) =>
      if p1.lerp_compatible(p2) {
        (a, b)
      } else {
        let (pa, pb) = p1.align(p2)
        (
          VMobject(path=pa, fill=f1, stroke=s1),
          VMobject(path=pb, fill=f2, stroke=s2),
        )
      }
    _ => (a, b)
  }
}

///|
fn center_of(m : @mobject.Mobject) -> @math.Vec2 {
  match m.bbox() {
    Some(b) => b.center()
    None => @math.Vec2::new(0.0, 0.0)
  }
}

///|
fn eval_plan(plan : MatchPlan, p : Double) -> @mobject.Mobject {
  let out : Array[@mobject.Mobject] = []
  for pair in plan.pairs {
    let (s, t) = pair
    out.push(Interpolable::lerp(s, t, p))
  }
  for m in plan.start_orphans {
    out.push(fade_out_to_point(m, plan.target_center, p))
  }
  for m in plan.target_orphans {
    out.push(fade_in_from_point(m, plan.start_center, p))
  }
  Group(out)
}

///|
/// Shrink toward `point` while fading out (Manim `FadeOutToPoint`).
fn fade_out_to_point(
  m : @mobject.Mobject,
  point : @math.Vec2,
  p : Double,
) -> @mobject.Mobject {
  m.scale_about(point, 1.0 - p).with_opacity(1.0 - p)
}

///|
/// Grow out of `point` while fading in (Manim `FadeInFromPoint`).
fn fade_in_from_point(
  m : @mobject.Mobject,
  point : @math.Vec2,
  p : Double,
) -> @mobject.Mobject {
  m.scale_about(point, p).with_opacity(p)
}
