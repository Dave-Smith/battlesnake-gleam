//// Opponent AI Prediction Module
//// Simple heuristic-based prediction of opponent moves

import api.{type Coord, type GameState, type Snake}
import game_state.{get_safe_moves, manhattan_distance, simulate_game_state}
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import heuristic_config
import heuristics

/// Result of opponent move prediction
pub type OpponentPrediction {
  OpponentPrediction(
    opponent: Snake,
    predicted_move: String,
    score: Float,
    all_moves: List(#(String, Float)),
  )
}

/// Find the nearest opponent by Manhattan distance (head to head)
pub fn find_nearest_opponent(
  our_head: Coord,
  opponents: List(Snake),
) -> Result(Snake, Nil) {
  case opponents {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let nearest =
        list.fold(
          rest,
          #(first, manhattan_distance(our_head, first.head)),
          fn(best, opponent) {
            let #(_, best_dist) = best
            let dist = manhattan_distance(our_head, opponent.head)
            case dist < best_dist {
              True -> #(opponent, dist)
              False -> best
            }
          },
        )
      let #(nearest_snake, _) = nearest
      Ok(nearest_snake)
    }
  }
}

/// Predict what move an opponent is likely to make
/// Uses simplified heuristics: safety, flood fill, food
pub fn predict_opponent_move(
  opponent: Snake,
  state: GameState,
) -> OpponentPrediction {
  // Create a modified game state where the opponent is "you"
  let opponent_perspective_state = api.GameState(..state, you: opponent)

  // Get opponent's safe moves
  let safe_moves = get_safe_moves(opponent_perspective_state)

  // Use simplified config for opponent prediction
  let config = heuristic_config.opponent_prediction_config()

  // Evaluate each move from opponent's perspective
  let move_scores =
    list.map(safe_moves, fn(move) {
      let simulated = simulate_game_state(opponent_perspective_state, move)
      let score = heuristics.evaluate_board(simulated, config)
      #(move, score)
    })

  // Pick the highest-scoring move (opponent plays optimally)
  let predicted = case
    list.sort(move_scores, fn(a, b) {
      let #(_, score_a) = a
      let #(_, score_b) = b
      float.compare(score_b, score_a)
    })
  {
    [#(best_move, best_score), ..] ->
      OpponentPrediction(
        opponent: opponent,
        predicted_move: best_move,
        score: best_score,
        all_moves: move_scores,
      )
    [] ->
      // No safe moves, predict random direction
      OpponentPrediction(
        opponent: opponent,
        predicted_move: "up",
        score: -999_999.0,
        all_moves: [],
      )
  }

  predicted
}

/// Predict the nearest opponent's move
pub fn predict_nearest_opponent_move(
  state: GameState,
) -> Result(OpponentPrediction, Nil) {
  let opponents =
    list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

  case find_nearest_opponent(state.you.head, opponents) {
    Ok(nearest) -> Ok(predict_opponent_move(nearest, state))
    Error(_) -> Error(Nil)
  }
}

/// Get distance to nearest opponent
pub fn distance_to_nearest_opponent(state: GameState) -> Int {
  let opponents =
    list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

  case find_nearest_opponent(state.you.head, opponents) {
    Ok(nearest) -> manhattan_distance(state.you.head, nearest.head)
    Error(_) -> 999
  }
}
