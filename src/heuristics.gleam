//// Heuristic Evaluation Functions

import api.{type GameState}
import game_state.{manhattan_distance}
import gleam/int
import gleam/list
import heuristic_config.{type HeuristicConfig}
import pathfinding

/// Aggregates all heuristic scores for a given game state
pub fn evaluate_board(state: GameState, config: HeuristicConfig) -> Float {
  let scores = [
    #("safety_boundary", case config.enable_safety_boundary {
      True -> safety_boundary_score(state, config)
      False -> 0.0
    }),
    #("safety_self_collision", case config.enable_safety_self_collision {
      True -> safety_self_collision_score(state, config)
      False -> 0.0
    }),
    #("safety_head_collision", case config.enable_safety_head_collision {
      True -> safety_head_collision_score(state, config)
      False -> 0.0
    }),
    #("flood_fill", case config.enable_flood_fill {
      True -> flood_fill_score(state, config)
      False -> 0.0
    }),
    #("avoid_adjacent_heads", case config.enable_avoid_adjacent_heads {
      True -> avoid_adjacent_heads_score(state, config)
      False -> 0.0
    }),
    #("center_control", case config.enable_center_control {
      True -> center_control_score(state, config)
      False -> 0.0
    }),
    #("food_health", case config.enable_food_health {
      True -> food_health_score(state, config)
      False -> 0.0
    }),
  ]

  list.fold(scores, 0.0, fn(acc, pair) {
    let #(_, score) = pair
    acc +. score
  })
}

/// Returns individual heuristic scores for logging/debugging
pub fn evaluate_board_detailed(
  state: GameState,
  config: HeuristicConfig,
) -> List(#(String, Float)) {
  [
    #("safety_boundary", case config.enable_safety_boundary {
      True -> safety_boundary_score(state, config)
      False -> 0.0
    }),
    #("safety_self_collision", case config.enable_safety_self_collision {
      True -> safety_self_collision_score(state, config)
      False -> 0.0
    }),
    #("safety_head_collision", case config.enable_safety_head_collision {
      True -> safety_head_collision_score(state, config)
      False -> 0.0
    }),
    #("flood_fill", case config.enable_flood_fill {
      True -> flood_fill_score(state, config)
      False -> 0.0
    }),
    #("avoid_adjacent_heads", case config.enable_avoid_adjacent_heads {
      True -> avoid_adjacent_heads_score(state, config)
      False -> 0.0
    }),
    #("center_control", case config.enable_center_control {
      True -> center_control_score(state, config)
      False -> 0.0
    }),
    #("food_health", case config.enable_food_health {
      True -> food_health_score(state, config)
      False -> 0.0
    }),
  ]
}

/// A. Safety Boundary - penalize if head is off board
fn safety_boundary_score(state: GameState, config: HeuristicConfig) -> Float {
  let head = state.you.head
  let board = state.board
  case
    head.x >= 0 && head.y >= 0 && head.x < board.width && head.y < board.height
  {
    True -> 0.0
    False -> config.weight_safety_boundary
  }
}

/// A. Safety Self-Collision - penalize if head hits our own body
fn safety_self_collision_score(
  state: GameState,
  config: HeuristicConfig,
) -> Float {
  let head = state.you.head
  let body = state.you.body
  case list.any(list.drop(body, 1), fn(coord) { coord == head }) {
    True -> config.weight_safety_self_collision
    False -> 0.0
  }
}

/// A. Safety Head Collision - handle head-to-head collisions based on length
fn safety_head_collision_score(
  state: GameState,
  config: HeuristicConfig,
) -> Float {
  let our_head = state.you.head
  let our_length = state.you.length
  let opponent_snakes =
    list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

  list.fold(opponent_snakes, 0.0, fn(acc, opponent) {
    case opponent.head == our_head {
      True -> {
        case our_length > opponent.length {
          True -> acc +. config.weight_safety_head_collision_shorter
          False -> acc +. config.weight_safety_head_collision_longer
        }
      }
      False -> acc
    }
  })
}

/// B. Flood Fill - count accessible tiles from current head position
fn flood_fill_score(state: GameState, config: HeuristicConfig) -> Float {
  let head = state.you.head
  let accessible_tiles =
    pathfinding.flood_fill(head, state.board, state.board.snakes)
  int.to_float(accessible_tiles) *. config.weight_flood_fill
}

/// C. Avoid Adjacent Opponent Heads - penalize being next to opponent heads
fn avoid_adjacent_heads_score(
  state: GameState,
  config: HeuristicConfig,
) -> Float {
  let our_head = state.you.head
  let our_length = state.you.length
  let opponent_snakes =
    list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

  let adjacent_coords = [
    api.Coord(our_head.x + 1, our_head.y),
    api.Coord(our_head.x - 1, our_head.y),
    api.Coord(our_head.x, our_head.y + 1),
    api.Coord(our_head.x, our_head.y - 1),
  ]

  list.fold(opponent_snakes, 0.0, fn(acc, opponent) {
    case list.any(adjacent_coords, fn(coord) { coord == opponent.head }) {
      True -> {
        case our_length > opponent.length {
          True -> acc +. config.weight_avoid_adjacent_heads_longer
          False -> acc +. config.weight_avoid_adjacent_heads
        }
      }
      False -> acc
    }
  })
}

/// C. Center Control - reward being in the center, penalize being near walls
fn center_control_score(state: GameState, config: HeuristicConfig) -> Float {
  let head = state.you.head
  let board = state.board
  let num_opponents =
    list.length(list.filter(state.board.snakes, fn(s) { s.id != state.you.id }))

  let center_x_min = board.width / 2 - 2
  let center_x_max = board.width / 2 + 2
  let center_y_min = board.height / 2 - 2
  let center_y_max = board.height / 2 + 2

  let is_in_center =
    head.x >= center_x_min
    && head.x <= center_x_max
    && head.y >= center_y_min
    && head.y <= center_y_max

  let is_early_game = state.turn < config.early_game_turn_threshold
  let is_near_wall =
    head.x == 0
    || head.x == board.width - 1
    || head.y == 0
    || head.y == board.height - 1

  case is_in_center && is_early_game && num_opponents > 1 {
    True -> config.weight_center_control
    False ->
      case is_near_wall {
        True -> config.weight_center_penalty
        False -> 0.0
      }
  }
}

/// D. Food Health - prioritize food when health is low
fn food_health_score(state: GameState, config: HeuristicConfig) -> Float {
  let our_health = state.you.health
  let our_head = state.you.head
  let food = state.board.food

  case our_health < config.health_threshold && food != [] {
    True -> {
      let nearest_food_distance = case
        list.sort(food, fn(a, b) {
          int.compare(
            manhattan_distance(our_head, a),
            manhattan_distance(our_head, b),
          )
        })
      {
        [nearest, ..] -> manhattan_distance(our_head, nearest)
        [] -> 999
      }
      let distance_factor =
        1.0 /. { int.to_float(nearest_food_distance) +. 1.0 }
      config.weight_food_health *. distance_factor
    }
    False -> 0.0
  }
}
