import gleam/option.{None, Some}
import move_time_budget

pub fn compute_budget_ms_uses_percent_buffer_over_50ms_test() {
  // 15% of 500ms = 75ms buffer, so 425ms budget
  assert move_time_budget.compute_budget_ms(500) == 425
}

pub fn compute_budget_ms_uses_50ms_min_buffer_test() {
  // 15% of 200ms = 30ms, min buffer is 50ms => 150ms budget
  assert move_time_budget.compute_budget_ms(200) == 150
}

pub fn compute_budget_ms_has_minimum_budget_test() {
  // 60ms timeout - 50ms buffer = 10ms, clamp to 25ms
  assert move_time_budget.compute_budget_ms(60) == 25
}

pub fn set_lookup_clear_roundtrip_test() {
  let game_id = "move_time_budget_test"

  // Ensure a clean slate if tests are re-run.
  move_time_budget.clear_for_game(game_id)

  let stored = move_time_budget.set_for_game(game_id, 500)
  assert stored == 425
  assert move_time_budget.lookup_budget_ms(game_id) == Some(425)

  move_time_budget.clear_for_game(game_id)
  assert move_time_budget.lookup_budget_ms(game_id) == None
}
