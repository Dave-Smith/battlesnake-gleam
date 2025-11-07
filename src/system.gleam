// Using Erlang FFI
@external(erlang, "erlang", "garbage_collect")
pub fn force_gc() -> Bool
