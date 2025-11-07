//// Adaptive Configuration Module
//// Dynamically adjusts heuristic weights based on game phase and opponent behavior

import api.{type GameState}
import gleam/float
import gleam/int
import gleam/list
import heuristic_config.{type HeuristicConfig}
import log

/// Represents the current phase of the game
pub type GamePhase {
  EarlyGame  // Turns 1-75, focus on growth and survival
  MidGame    // Turns 76+, 2+ opponents, focus on positioning
  LateGame   // 1-2 opponents or cramped space, focus on survival
}

/// Detects the current game phase based on turn number and opponent count
pub fn detect_phase(state: GameState) -> GamePhase {
  let num_opponents =
    list.length(list.filter(state.board.snakes, fn(s) { s.id != state.you.id }))

  let board_size = state.board.width * state.board.height
  let occupied_tiles =
    list.fold(state.board.snakes, 0, fn(acc, snake) { acc + snake.length })
  let board_density = occupied_tiles * 100 / board_size

  // Late game: 1-2 opponents OR cramped space (>40% occupied)
  case num_opponents, board_density {
    0, _ | 1, _ | 2, _ if board_density > 40 -> LateGame
    _, density if density > 40 -> LateGame
    _, _ ->
      case state.turn {
        turn if turn <= 75 -> EarlyGame
        _ -> MidGame
      }
  }
}

/// Returns an adapted configuration based on game phase
pub fn get_adaptive_config(state: GameState) -> HeuristicConfig {
  let phase = detect_phase(state)

  let phase_config = case phase {
    EarlyGame -> {
      log.info_with_fields("Game phase: EARLY GAME", [
        #("turn", int.to_string(state.turn)),
      ])
      heuristic_config.early_game_config()
    }
    MidGame -> {
      log.info_with_fields("Game phase: MID GAME", [
        #("turn", int.to_string(state.turn)),
      ])
      heuristic_config.mid_game_config()
    }
    LateGame -> {
      log.info_with_fields("Game phase: LATE GAME", [
        #("turn", int.to_string(state.turn)),
      ])
      heuristic_config.late_game_config()
    }
  }

  phase_config
}
