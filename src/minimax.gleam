//// Minimax Algorithm with Alpha-Beta Pruning

import api.{type GameState}
import game_state.{get_safe_moves, simulate_game_state}
import gleam/float
import gleam/list
import gleam/order
import heuristic_config.{type HeuristicConfig}
import heuristics

pub type MinimaxResult {
  MinimaxResult(move: String, score: Float)
}

/// Public interface for choosing the best move using Minimax
pub fn choose_move(
  state: GameState,
  depth: Int,
  config: HeuristicConfig,
) -> MinimaxResult {
  let safe_moves = get_safe_moves(state)

  case safe_moves {
    [] -> MinimaxResult(move: "up", score: -999_999.0)
    [single] -> MinimaxResult(move: single, score: 0.0)
    moves -> {
      let move_scores =
        list.map(moves, fn(move) {
          let next_state = simulate_game_state(state, move)
          let score =
            minimax(next_state, depth - 1, False, -999_999.0, 999_999.0, config)
          #(move, score)
        })

      case
        list.sort(move_scores, fn(a, b) {
          let #(_, score_a) = a
          let #(_, score_b) = b
          float.compare(score_b, with: score_a)
        })
      {
        [#(best_move, best_score), ..] ->
          MinimaxResult(move: best_move, score: best_score)
        [] -> MinimaxResult(move: "up", score: -999_999.0)
      }
    }
  }
}

/// Core recursive Minimax function with alpha-beta pruning
pub fn minimax(
  state: GameState,
  depth: Int,
  is_maximizing: Bool,
  alpha: Float,
  beta: Float,
  config: HeuristicConfig,
) -> Float {
  case depth == 0 {
    True -> heuristics.evaluate_board(state, config)
    False -> {
      let safe_moves = get_safe_moves(state)

      case safe_moves {
        [] -> heuristics.evaluate_board(state, config)
        moves ->
          case is_maximizing {
            True ->
              maximize_score(state, moves, depth, alpha, beta, config, alpha)
            False ->
              minimize_score(state, moves, depth, alpha, beta, config, beta)
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
) -> Float {
  case moves {
    [] -> current_max
    [move, ..rest] -> {
      let next_state = simulate_game_state(state, move)
      let score = minimax(next_state, depth - 1, False, alpha, beta, config)
      let new_max = float.max(current_max, score)
      let new_alpha = float.max(alpha, new_max)

      case float.compare(new_alpha, with: beta) {
        order.Gt | order.Eq -> new_max
        order.Lt ->
          maximize_score(state, rest, depth, new_alpha, beta, config, new_max)
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
) -> Float {
  case moves {
    [] -> current_min
    [move, ..rest] -> {
      let next_state = simulate_game_state(state, move)
      let score = minimax(next_state, depth - 1, True, alpha, beta, config)
      let new_min = float.min(current_min, score)
      let new_beta = float.min(beta, new_min)

      case float.compare(new_beta, with: alpha) {
        order.Lt -> new_min
        order.Gt | order.Eq ->
          minimize_score(state, rest, depth, alpha, new_beta, config, new_min)
      }
    }
  }
}
