import gleam/int
import gleam/option.{type Option, None, Some}

pub const default_timeout_ms: Int = 500

// NOTE: The Battlesnake engine gives us `timeout_ms` for an entire request.
// We reserve a buffer for JSON decode/encode, logging, HTTP IO, etc.
//
// Heuristic:
// - Buffer is max(50ms, 15% of timeout)
// - Budget is clamped to at least 25ms
pub fn compute_budget_ms(timeout_ms: Int) -> Int {
  let percent_buffer = timeout_ms * 15 / 100
  let buffer_ms = int.max(50, percent_buffer)
  let budget_ms = timeout_ms - buffer_ms
  int.max(25, budget_ms)
}

fn key(game_id: String) -> String {
  "move_time_budget_ms:" <> game_id
}

@external(erlang, "persistent_term", "put")
fn persistent_put(key: String, value: Int) -> Nil

@external(erlang, "persistent_term", "get")
fn persistent_get(key: String, default: Int) -> Int

@external(erlang, "persistent_term", "erase")
fn persistent_erase(key: String) -> Nil

pub fn set_for_game(game_id: String, timeout_ms: Int) -> Int {
  let budget_ms = compute_budget_ms(timeout_ms)
  persistent_put(key(game_id), budget_ms)
  budget_ms
}

pub fn lookup_budget_ms(game_id: String) -> Option(Int) {
  let value = persistent_get(key(game_id), -1)
  case value < 0 {
    True -> None
    False -> Some(value)
  }
}

pub fn clear_for_game(game_id: String) -> Nil {
  persistent_erase(key(game_id))
}
