//// Minimax Algorithm with Alpha-Beta Pruning

import api.{type GameState, type Snake}
import game_state.{
  get_safe_moves, simulate_game_state, simulate_game_state_with_opponent,
}
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/string
import heuristic_config.{type HeuristicConfig, cheap_config_from}
import heuristics
import log
import opponent_ai
import pathfinding

pub type MinimaxResult {
  MinimaxResult(move: String, score: Float)
}

/// Public interface for choosing the best move using Minimax
/// Now accepts optional depth-0 scores for tie-breaking
pub fn choose_move(
  state: GameState,
  depth: Int,
  config: HeuristicConfig,
  depth_0_scores: List(#(String, Float)),
  deadline_ms: Int,
) -> MinimaxResult {
  let start_time = log.get_monotonic_time()
  let safe_moves = get_safe_moves(state)

  let result = case safe_moves {
    [] -> MinimaxResult(move: "up", score: -999_999.0)
    [single] -> MinimaxResult(move: single, score: 0.0)
    moves -> {
      // Filter moves that lead to sufficient space
      let min_space = state.you.length
      let moves_with_space =
        list.filter_map(moves, fn(move) {
          let next_state = simulate_game_state(state, move)
          let space_available =
            pathfinding.flood_fill(
              next_state.you.head,
              next_state.board,
              next_state.board.snakes,
            )
          case space_available >= min_space {
            True -> Ok(move)
            False -> Error(Nil)
          }
        })

      // Use space-filtered moves if available, otherwise fall back to basic safe moves
      let evaluated_moves = case moves_with_space {
        [] -> moves
        filtered -> filtered
      }

      // Determine opponent simulation depth (2 plies max for performance)
      let opponent_sim_depth = int.min(depth, 2)

      let move_scores =
        list.map(evaluated_moves, fn(move) {
          let next_state = simulate_game_state(state, move)
          let score =
            minimax(
              next_state,
              depth - 1,
              False,
              -999_999.0,
              999_999.0,
              config,
              opponent_sim_depth - 1,
              deadline_ms,
            )
          #(move, score)
        })

      let tie_breaker = calculate_tie_breaker(state.you.id, state.turn)

      // Threshold for considering scores "close enough" to use depth-0 tie-breaker
      let convergence_threshold = 50.0

      case
        list.sort(move_scores, fn(a, b) {
          let #(move_a, score_a) = a
          let #(move_b, score_b) = b

          let score_diff = float.absolute_value(score_a -. score_b)

          // If scores are very close, use depth-0 score as tie-breaker
          case score_diff <. convergence_threshold {
            True -> {
              // Get depth-0 scores for these moves
              let depth_0_a = case
                list.find(depth_0_scores, fn(pair) {
                  let #(m, _) = pair
                  m == move_a
                })
              {
                Ok(#(_, score)) -> score
                Error(_) -> 0.0
              }

              let depth_0_b = case
                list.find(depth_0_scores, fn(pair) {
                  let #(m, _) = pair
                  m == move_b
                })
              {
                Ok(#(_, score)) -> score
                Error(_) -> 0.0
              }

              // Prefer higher depth-0 score when minimax scores converge
              case float.compare(depth_0_b, depth_0_a) {
                order.Eq -> {
                  // Still tied, use random tie-breaker
                  let bias_a = get_move_bias(move_a, tie_breaker)
                  let bias_b = get_move_bias(move_b, tie_breaker)
                  float.compare(bias_b, bias_a)
                }
                other -> other
              }
            }
            False -> {
              // Scores divergent enough, use minimax score
              case float.compare(score_b, with: score_a) {
                order.Eq -> {
                  let bias_a = get_move_bias(move_a, tie_breaker)
                  let bias_b = get_move_bias(move_b, tie_breaker)
                  float.compare(bias_b, bias_a)
                }
                other -> other
              }
            }
          }
        })
      {
        [#(best_move, best_score), ..] ->
          MinimaxResult(move: best_move, score: best_score)
        [] -> MinimaxResult(move: "up", score: -999_999.0)
      }
    }
  }

  let end_time = log.get_monotonic_time()
  log.info_with_fields("Minimax complete", [
    #("depth", int.to_string(depth)),
    #("duration_ms", int.to_string(end_time - start_time)),
    #("moves_evaluated", int.to_string(list.length(safe_moves))),
  ])
  result
}

fn calculate_tie_breaker(snake_id: String, turn: Int) -> Int {
  let id_hash = string_hash(snake_id)
  { id_hash + turn * 7 } % 100
}

fn string_hash(s: String) -> Int {
  string.to_graphemes(s)
  |> list.fold(0, fn(acc, char) {
    let char_val = case string.pop_grapheme(char) {
      Ok(#(c, _)) ->
        case c {
          "a" | "A" -> 1
          "b" | "B" -> 2
          "c" | "C" -> 3
          "d" | "D" -> 4
          "e" | "E" -> 5
          "f" | "F" -> 6
          "g" | "G" -> 7
          "h" | "H" -> 8
          "i" | "I" -> 9
          "0" -> 10
          "1" -> 11
          "2" -> 12
          "3" -> 13
          "4" -> 14
          "5" -> 15
          "6" -> 16
          "7" -> 17
          "8" -> 18
          "9" -> 19
          "-" -> 20
          _ -> 0
        }
      Error(_) -> 0
    }
    acc * 31 + char_val
  })
}

fn get_move_bias(move: String, tie_breaker: Int) -> Float {
  let base = case move {
    "up" -> 0.1
    "down" -> 0.2
    "left" -> 0.3
    "right" -> 0.4
    _ -> 0.0
  }
  base +. int.to_float(tie_breaker) /. 1000.0
}

/// Core recursive Minimax function with alpha-beta pruning
/// Now includes opponent simulation and a deadline-based cutoff.
pub fn minimax(
  state: GameState,
  depth: Int,
  is_maximizing: Bool,
  alpha: Float,
  beta: Float,
  config: HeuristicConfig,
  opponent_sim_depth: Int,
  deadline_ms: Int,
) -> Float {
  let now = log.get_monotonic_time()
  case now >= deadline_ms {
    True -> heuristics.evaluate_board(state, cheap_config_from(config))
    False ->
      case depth == 0 {
        True -> heuristics.evaluate_board(state, config)
        False -> {
          let safe_moves = get_safe_moves(state)

          case safe_moves {
            [] -> heuristics.evaluate_board(state, config)
            moves ->
              case is_maximizing {
                True ->
                  maximize_score(
                    state,
                    moves,
                    depth,
                    alpha,
                    beta,
                    config,
                    -999_999.0,
                    opponent_sim_depth,
                    deadline_ms,
                  )
                False ->
                  minimize_score(
                    state,
                    moves,
                    depth,
                    alpha,
                    beta,
                    config,
                    999_999.0,
                    opponent_sim_depth,
                    deadline_ms,
                  )
              }
          }
        }
      }
  }
}

fn maximize_score(
  state: GameState,
  moves: List(String),
  depth: Int,
  alpha: Float,
  beta: Float,
  config: HeuristicConfig,
  current_max: Float,
  opponent_sim_depth: Int,
  deadline_ms: Int,
) -> Float {
  let now = log.get_monotonic_time()
  case now >= deadline_ms {
    True -> current_max
    False ->
      case moves {
        [] -> current_max
        [move, ..rest] -> {
          // Simulate opponent if within simulation depth threshold
          let score =
            case opponent_sim_depth > 0 {
              True -> {
                // Find and predict nearest opponent's move
                let opponents =
                  list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

                case opponent_ai.find_nearest_opponent(state.you.head, opponents) {
                  Ok(nearest_opponent) -> {
                    // Predict opponent's best move
                    let opponent_moves =
                      get_safe_moves(api.GameState(..state, you: nearest_opponent))

                    // Branch on opponent moves (minimizing for opponent)
                    branch_on_opponent_moves(
                      state,
                      move,
                      nearest_opponent,
                      opponent_moves,
                      depth,
                      alpha,
                      beta,
                      config,
                      opponent_sim_depth,
                      deadline_ms,
                    )
                  }
                  Error(_) -> {
                    // No opponents, use regular simulation
                    let next_state = simulate_game_state(state, move)
                    minimax(
                      next_state,
                      depth - 1,
                      False,
                      alpha,
                      beta,
                      config,
                      0,
                      deadline_ms,
                    )
                  }
                }
              }
              False -> {
                // No opponent simulation, use regular frozen opponent
                let next_state = simulate_game_state(state, move)
                minimax(
                  next_state,
                  depth - 1,
                  False,
                  alpha,
                  beta,
                  config,
                  0,
                  deadline_ms,
                )
              }
            }

          let new_max = float.max(current_max, score)
          let new_alpha = float.max(alpha, new_max)

          case float.compare(new_alpha, with: beta) {
            order.Gt | order.Eq -> new_max
            order.Lt ->
              maximize_score(
                state,
                rest,
                depth,
                new_alpha,
                beta,
                config,
                new_max,
                opponent_sim_depth,
                deadline_ms,
              )
          }
        }
      }
  }
}

/// Branch on opponent's possible moves, taking worst case for us (opponent minimizes our score)
fn branch_on_opponent_moves(
  state: GameState,
  our_move: String,
  opponent: Snake,
  opponent_moves: List(String),
  depth: Int,
  alpha: Float,
  beta: Float,
  config: HeuristicConfig,
  opponent_sim_depth: Int,
  deadline_ms: Int,
) -> Float {
  let now = log.get_monotonic_time()
  case now >= deadline_ms {
    True -> heuristics.evaluate_board(state, cheap_config_from(config))
    False ->
      case opponent_moves {
        [] -> {
          // Opponent has no safe moves, use regular simulation
          let next_state = simulate_game_state(state, our_move)
          minimax(
            next_state,
            depth - 1,
            False,
            alpha,
            beta,
            config,
            0,
            deadline_ms,
          )
        }
        moves -> {
          // Evaluate all opponent moves, take the worst for us (minimizing)
          list.fold(moves, 999_999.0, fn(min_score, opp_move) {
            let next_state =
              simulate_game_state_with_opponent(state, our_move, opponent, opp_move)
            let score =
              minimax(
                next_state,
                depth - 1,
                False,
                alpha,
                beta,
                config,
                opponent_sim_depth - 1,
                deadline_ms,
              )
            float.min(min_score, score)
          })
        }
      }
  }
}

fn minimize_score(
  state: GameState,
  moves: List(String),
  depth: Int,
  alpha: Float,
  beta: Float,
  config: HeuristicConfig,
  current_min: Float,
  opponent_sim_depth: Int,
  deadline_ms: Int,
) -> Float {
  let now = log.get_monotonic_time()
  case now >= deadline_ms {
    True -> current_min
    False ->
      case moves {
        [] -> current_min
        [move, ..rest] -> {
          let next_state = simulate_game_state(state, move)
          let score =
            minimax(
              next_state,
              depth - 1,
              True,
              alpha,
              beta,
              config,
              opponent_sim_depth,
              deadline_ms,
            )
          let new_min = float.min(current_min, score)
          let new_beta = float.min(beta, new_min)

          case float.compare(new_beta, with: alpha) {
            order.Lt -> new_min
            order.Gt | order.Eq ->
              minimize_score(
                state,
                rest,
                depth,
                alpha,
                new_beta,
                config,
                new_min,
                opponent_sim_depth,
                deadline_ms,
              )
          }
        }
      }
  }
}
