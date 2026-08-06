///|
/// A minimal LRU cache keyed by `Int` structural hashes.
///
/// This is the deliberate simplification documented in docs/design.md:
/// keys are declared explicitly at a handful of expensive call sites
/// (formula rendering, triangulation), instead of comemo-style automatic
/// dependency tracking, which MoonBit's macro infrastructure cannot
/// express yet.
pub(all) struct LruCache[V] {
  store : Map[Int, (V, Int)]
  capacity : Int
  mut tick : Int
}

///|
pub fn[V] LruCache::new(capacity : Int) -> LruCache[V] {
  { store: Map([]), capacity, tick: 0 }
}

///|
pub fn[V] LruCache::length(self : LruCache[V]) -> Int {
  self.store.length()
}

///|
/// Look up `key`; on a miss, run `compute`, store and return the result.
/// Evicts the least recently used entry when `capacity` is reached.
pub fn[V] LruCache::get_or(
  self : LruCache[V],
  key : Int,
  compute : () -> V,
) -> V {
  self.tick += 1
  match self.store.get(key) {
    Some((v, _)) => {
      self.store.set(key, (v, self.tick))
      v
    }
    None => {
      let v = compute()
      if self.capacity > 0 && self.store.length() >= self.capacity {
        self.evict_oldest()
      }
      self.store.set(key, (v, self.tick))
      v
    }
  }
}

///|
fn[V] LruCache::evict_oldest(self : LruCache[V]) -> Unit {
  let mut oldest_key = -1
  let mut oldest_tick = 2147483647
  self.store.each(fn(k, entry) {
    let (_, t) = entry
    if t < oldest_tick {
      oldest_tick = t
      oldest_key = k
    }
  })
  if oldest_key >= 0 {
    self.store.remove(oldest_key)
  }
}

///|
/// Polynomial string hash (mod a large prime) for building cache keys.
/// Deterministic across runs and targets.
pub fn hash_string(s : String) -> Int {
  let modulus = 1000000007
  s.fold(init=0, fn(acc, c) { (acc * 131 + c.to_int()) % modulus })
}

///|
/// Combine two hash values into one.
pub fn hash_combine(h1 : Int, h2 : Int) -> Int {
  (h1 * 1000003 + h2) % 1000000007
}
