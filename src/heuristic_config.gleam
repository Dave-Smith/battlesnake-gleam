//// Heuristic Configuration Module

pub type HeuristicConfig {
  HeuristicConfig(
    enable_safety_boundary: Bool,
    enable_safety_self_collision: Bool,
    enable_safety_head_collision: Bool,
    enable_flood_fill: Bool,
    enable_avoid_adjacent_heads: Bool,
    enable_head_collision_danger: Bool,
    enable_center_control: Bool,
    enable_early_game_food: Bool,
    enable_food_health: Bool,
    enable_food_safety: Bool,
    enable_tail_chasing: Bool,
    enable_voronoi_control: Bool,
    enable_competitive_length: Bool,
    weight_safety_boundary: Float,
    weight_safety_self_collision: Float,
    weight_safety_head_collision_longer: Float,
    weight_safety_head_collision_shorter: Float,
    weight_flood_fill: Float,
    weight_avoid_adjacent_heads: Float,
    weight_avoid_adjacent_heads_longer: Float,
    weight_head_collision_danger_longer: Float,
    weight_head_collision_danger_equal: Float,
    weight_center_control: Float,
    weight_center_penalty: Float,
    weight_early_game_food: Float,
    weight_food_health: Float,
    weight_food_safety_penalty: Float,
    weight_tail_chasing: Float,
    weight_voronoi_control: Float,
    weight_competitive_length: Float,
    weight_competitive_length_critical: Float,
    health_threshold: Int,
    early_game_turn_threshold: Int,
    early_game_food_turn_threshold: Int,
    tail_chasing_health_threshold: Int,
    tail_chasing_space_threshold: Int,
    competitive_length_health_min: Int,
  )
}

/// Default configuration matching the game plan specifications
pub fn default_config() -> HeuristicConfig {
  HeuristicConfig(
    enable_safety_boundary: True,
    enable_safety_self_collision: True,
    enable_safety_head_collision: True,
    enable_flood_fill: True,
    enable_avoid_adjacent_heads: True,
    enable_head_collision_danger: True,
    enable_center_control: True,
    enable_early_game_food: True,
    enable_food_health: True,
    enable_food_safety: True,
    enable_tail_chasing: True,
    enable_voronoi_control: True,
    enable_competitive_length: True,
    weight_safety_boundary: -1000.0,
    weight_safety_self_collision: -1000.0,
    weight_safety_head_collision_longer: -800.0,
    weight_safety_head_collision_shorter: 50.0,
    weight_flood_fill: 5.0,
    weight_avoid_adjacent_heads: -150.0,
    weight_avoid_adjacent_heads_longer: 20.0,
    weight_head_collision_danger_longer: 150.0,
    weight_head_collision_danger_equal: -5000.0,
    weight_center_control: 50.0,
    weight_center_penalty: -20.0,
    weight_early_game_food: 250.0,
    weight_food_health: 300.0,
    weight_food_safety_penalty: -50.0,
    weight_tail_chasing: 80.0,
    weight_voronoi_control: 15.0,
    weight_competitive_length: 150.0,
    weight_competitive_length_critical: 250.0,
    health_threshold: 35,
    early_game_turn_threshold: 50,
    early_game_food_turn_threshold: 100,
    tail_chasing_health_threshold: 50,
    tail_chasing_space_threshold: 30,
    competitive_length_health_min: 50,
  )
}

/// Default opponent configuration matching the game plan specifications
pub fn default_config_opponent() -> HeuristicConfig {
  HeuristicConfig(
    enable_safety_boundary: True,
    enable_safety_self_collision: True,
    enable_safety_head_collision: True,
    enable_flood_fill: True,
    enable_avoid_adjacent_heads: False,
    enable_head_collision_danger: True,
    enable_center_control: False,
    enable_early_game_food: True,
    enable_food_health: False,
    enable_food_safety: False,
    enable_tail_chasing: False,
    enable_voronoi_control: False,
    enable_competitive_length: False,
    weight_safety_boundary: -1000.0,
    weight_safety_self_collision: -1000.0,
    weight_safety_head_collision_longer: -800.0,
    weight_safety_head_collision_shorter: 50.0,
    weight_flood_fill: 5.0,
    weight_avoid_adjacent_heads: -150.0,
    weight_avoid_adjacent_heads_longer: 20.0,
    weight_head_collision_danger_longer: 150.0,
    weight_head_collision_danger_equal: -5000.0,
    weight_center_control: 50.0,
    weight_center_penalty: -20.0,
    weight_early_game_food: 250.0,
    weight_food_health: 300.0,
    weight_food_safety_penalty: -50.0,
    weight_tail_chasing: 80.0,
    weight_voronoi_control: 15.0,
    weight_competitive_length: 150.0,
    weight_competitive_length_critical: 250.0,
    health_threshold: 35,
    early_game_turn_threshold: 50,
    early_game_food_turn_threshold: 100,
    tail_chasing_health_threshold: 50,
    tail_chasing_space_threshold: 30,
    competitive_length_health_min: 50,
  )
}

/// Aggressive configuration that favors space control and aggression
pub fn aggressive_config() -> HeuristicConfig {
  HeuristicConfig(
    ..default_config(),
    weight_flood_fill: 3.5,
    weight_avoid_adjacent_heads_longer: 50.0,
    weight_center_control: 150.0,
    competitive_length_health_min: 20,
  )
}

/// Defensive configuration that prioritizes safety
pub fn defensive_config() -> HeuristicConfig {
  HeuristicConfig(
    ..default_config(),
    weight_flood_fill: 2.0,
    weight_avoid_adjacent_heads: -200.0,
    weight_food_health: 400.0,
  )
}
