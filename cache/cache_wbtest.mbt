///|
test "cache hit computes once" {
  let cache : LruCache[Int] = LruCache::new(8)
  let mut calls = 0
  let compute = fn() {
    calls += 1
    42
  }
  assert_eq(cache.get_or(7, compute), 42)
  assert_eq(cache.get_or(7, compute), 42)
  assert_eq(calls, 1)
}

///|
test "lru eviction drops the oldest entry" {
  let cache : LruCache[Int] = LruCache::new(2)
  ignore(cache.get_or(1, fn() { 10 }))
  ignore(cache.get_or(2, fn() { 20 }))
  ignore(cache.get_or(1, fn() { 10 })) // touch key 1; key 2 is now oldest
  ignore(cache.get_or(3, fn() { 30 })) // evicts key 2
  assert_eq(cache.length(), 2)
  assert_true(cache.store.get(2) is None)
  assert_true(cache.store.get(1) is Some(_))
}

///|
test "hash_string is deterministic and order-sensitive" {
  assert_eq(hash_string("moonim"), hash_string("moonim"))
  assert_true(hash_string("ab") != hash_string("ba"))
}
