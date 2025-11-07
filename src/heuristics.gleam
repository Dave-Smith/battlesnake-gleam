//// Heuristic Evaluation Functions

import api.{type GameState}
import game_state.{manhattan_distance}
import gleam/deque
import gleam/int
import gleam/list
import gleam/set
import heuristic_config.{type HeuristicConfig}
import pathfinding

/// Aggregates all heuristic scores for a given game state
pub fn evaluate_board(state: GameState, config: HeuristicConfig) -> Float {
  // Cache flood fill result since it's used by multiple heuristics
  let cached_space = case config.enable_flood_fill {
    True ->
      pathfinding.flood_fill(state.you.head, state.board, state.board.snakes)
    False -> 0
  }

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
      True -> int.to_float(cached_space) *. config.weight_flood_fill
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
    #("tail_chasing", case config.enable_tail_chasing {
      True -> tail_chasing_score(state, config)
      False -> 0.0
    }),
    #("food_safety", case config.enable_food_safety {
      True -> food_safety_score(state, config)
      False -> 0.0
    }),
    #("voronoi_control", case config.enable_voronoi_control {
      True -> voronoi_control_score(state, config)
      False -> 0.0
    }),
    #("competitive_length", case config.enable_competitive_length {
      True -> competitive_length_score(state, config)
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
  // Cache flood fill result since it's used by multiple heuristics
  let cached_space = case config.enable_flood_fill {
    True ->
      pathfinding.flood_fill(state.you.head, state.board, state.board.snakes)
    False -> 0
  }

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
      True -> int.to_float(cached_space) *. config.weight_flood_fill
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
    #("tail_chasing", case config.enable_tail_chasing {
      True -> tail_chasing_score(state, config)
      False -> 0.0
    }),
    #("food_safety", case config.enable_food_safety {
      True -> food_safety_score(state, config)
      False -> 0.0
    }),
    #("voronoi_control", case config.enable_voronoi_control {
      True -> voronoi_control_score(state, config)
      False -> 0.0
    }),
    #("competitive_length", case config.enable_competitive_length {
      True -> competitive_length_score(state, config)
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
  let tail = case deque.pop_front(body) {
    Ok(#(t, _)) -> t
    Error(_) -> head
  }
  case set.contains(state.you.body_coord, head) {
    True ->
      case head == tail {
        True -> 0.0
        False -> config.weight_safety_self_collision
      }
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

/// E. Tail Chasing - follow our tail when healthy and space is limited
fn tail_chasing_score(state: GameState, config: HeuristicConfig) -> Float {
  let our_health = state.you.health
  let our_head = state.you.head
  let our_tail = case deque.pop_back(state.you.body) {
    Ok(#(tail_coord, _)) -> tail_coord
    Error(_) -> our_head
  }

  let accessible_tiles =
    pathfinding.flood_fill(our_head, state.board, state.board.snakes)

  case
    our_health > config.tail_chasing_health_threshold
    && accessible_tiles < config.tail_chasing_space_threshold
  {
    True -> {
      let tail_distance = manhattan_distance(our_head, our_tail)
      let distance_factor = 1.0 /. { int.to_float(tail_distance) +. 1.0 }
      config.weight_tail_chasing *. distance_factor
    }
    False -> 0.0
  }
}

/// F. Food Safety - Simple, efficient food targeting
/// When hungry: reward moving toward closest food ≤10 moves away
/// Also reward moves toward food clusters (multiple food in an area)
fn food_safety_score(state: GameState, config: HeuristicConfig) -> Float {
  let our_head = state.you.head
  let our_health = state.you.health
  let food = state.board.food

  case our_health < config.health_threshold && food != [] {
    True -> {
      // Find closest food
      let food_with_distance =
        list.map(food, fn(food_coord) {
          let distance = manhattan_distance(our_head, food_coord)
          #(food_coord, distance)
        })

      let sorted_food =
        list.sort(food_with_distance, fn(a, b) {
          let #(_, dist_a) = a
          let #(_, dist_b) = b
          int.compare(dist_a, dist_b)
        })

      case sorted_food {
        [#(closest_food, distance), ..] -> {
          case distance <= 10 {
            True -> {
              // Reward moves toward close food
              let distance_score = { 10.0 -. int.to_float(distance) } *. 10.0

              // Bonus for food clusters (count food within 5 tiles of closest food)
              let cluster_count =
                list.filter(food, fn(f) {
                  manhattan_distance(closest_food, f) <= 5
                })
                |> list.length

              let cluster_bonus = int.to_float(cluster_count) *. 5.0

              distance_score +. cluster_bonus
            }
            False -> 0.0
          }
        }
        [] -> 0.0
      }
    }
    False -> 0.0
  }
}

/// G. Voronoi Space Control - maximize territory we can reach before opponents
/// Optimized version using Manhattan distance and strategic tile sampling
fn voronoi_control_score(state: GameState, config: HeuristicConfig) -> Float {
  let our_id = state.you.id
  let our_head = state.you.head
  let opponent_snakes =
    list.filter(state.board.snakes, fn(s) { s.id != our_id })

  case opponent_snakes {
    [] -> 0.0
    opponents -> {
      let opponent_heads = list.map(opponents, fn(s) { s.head })

      let our_controlled =
        pathfinding.voronoi_territory_fast(
          our_head,
          opponent_heads,
          state.board,
        )

      let sample_size = list.length(opponent_heads) * 15
      let control_score =
        int.to_float(our_controlled) /. int.to_float(sample_size)
      config.weight_voronoi_control *. control_score
    }
  }
}

/// I. Food Competition Detection - detect when opponents are aggressively hoarding food
pub fn detect_food_competition(state: GameState) -> Float {
  let our_head = state.you.head
  let our_length = state.you.length
  let food = state.board.food
  let opponent_snakes =
    list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

  case opponent_snakes {
    [] -> 0.0
    opponents -> {
      let num_snakes = list.length(state.board.snakes)
      let food_scarcity_score = case list.length(food) {
        0 -> 1.0
        food_count -> {
          let food_per_snake =
            int.to_float(food_count) /. int.to_float(num_snakes)
          case food_per_snake <. 1.5 {
            True -> 1.0 -. food_per_snake /. 1.5
            False -> 0.0
          }
        }
      }

      let competition_for_food =
        list.fold(food, 0.0, fn(acc, food_coord) {
          let our_distance = manhattan_distance(our_head, food_coord)
          let closer_opponents =
            list.count(opponents, fn(opp) {
              let opp_distance = manhattan_distance(opp.head, food_coord)
              let length_factor =
                int.to_float(opp.length) /. int.to_float(our_length)
              opp_distance < our_distance && length_factor >. 0.9
            })
          acc +. int.to_float(closer_opponents)
        })

      let total_food_positions = int.to_float(list.length(food))
      let competition_ratio = case total_food_positions {
        0.0 -> 0.0
        _ -> competition_for_food /. total_food_positions
      }

      let avg_opponent_length =
        list.fold(opponents, 0, fn(acc, s) { acc + s.length })
        |> int.to_float
        |> fn(total) { total /. int.to_float(list.length(opponents)) }

      let length_dominance = avg_opponent_length /. int.to_float(our_length)

      let final_score =
        { food_scarcity_score *. 0.4 }
        +. { competition_ratio *. 0.4 }
        +. {
          case length_dominance >. 1.1 {
            True -> 0.2
            False -> 0.0
          }
        }

      case final_score >. 1.0 {
        True -> 1.0
        False -> final_score
      }
    }
  }
}

/// H. Competitive Length - maintain length advantage for head-to-head dominance
fn competitive_length_score(state: GameState, config: HeuristicConfig) -> Float {
  let our_length = state.you.length
  let our_health = state.you.health
  let our_head = state.you.head
  let food = state.board.food
  let opponent_snakes =
    list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

  case opponent_snakes {
    [] -> 0.0
    opponents -> {
      let max_opponent_length =
        list.fold(opponents, 0, fn(max_len, snake) {
          case snake.length > max_len {
            True -> snake.length
            False -> max_len
          }
        })

      let length_diff = our_length - max_opponent_length

      case length_diff {
        diff if diff >= 2 -> 0.0
        diff if diff == 1 -> 0.0
        diff if diff == 0 -> {
          case our_health > config.competitive_length_health_min && food != [] {
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
              config.weight_competitive_length *. distance_factor
            }
            False -> 0.0
          }
        }
        _ -> {
          case our_health > config.competitive_length_health_min && food != [] {
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
              config.weight_competitive_length_critical *. distance_factor
            }
            False -> 0.0
          }
        }
      }
    }
  }
}
