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

/// Lightweight configuration used when we are out of time in minimax.
/// Keeps all safety-related heuristics but disables expensive spatial analysis
/// like flood fill, voronoi territory, and tail chasing.
pub fn cheap_config_from(config: HeuristicConfig) -> HeuristicConfig {
  HeuristicConfig(
    ..config,
    enable_flood_fill: False,
    enable_voronoi_control: False,
    enable_tail_chasing: False,
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

/// Simplified opponent prediction config
/// Used to predict likely opponent moves (not full strategy)
/// Focuses on: survival, food, flood fill, avoiding our head
pub fn opponent_prediction_config() -> HeuristicConfig {
  HeuristicConfig(
    // Safety is paramount
    enable_safety_boundary: True,
    enable_safety_self_collision: True,
    enable_safety_head_collision: True,
    weight_safety_boundary: -1000.0,
    weight_safety_self_collision: -1000.0,
    weight_safety_head_collision_longer: -800.0,
    weight_safety_head_collision_shorter: 50.0,
    // Basic space awareness
    enable_flood_fill: True,
    weight_flood_fill: 5.0,
    // Food when hungry
    enable_food_health: True,
    weight_food_health: 300.0,
    health_threshold: 40,
    // Avoid colliding with us
    enable_head_collision_danger: True,
    weight_head_collision_danger_longer: 100.0,
    weight_head_collision_danger_equal: -3000.0,
    // Disable expensive/complex heuristics
    enable_avoid_adjacent_heads: False,
    enable_center_control: False,
    enable_early_game_food: False,
    enable_food_safety: False,
    enable_tail_chasing: False,
    enable_voronoi_control: False,
    enable_competitive_length: False,
    // Unused weights (disabled above)
    weight_avoid_adjacent_heads: 0.0,
    weight_avoid_adjacent_heads_longer: 0.0,
    weight_center_control: 0.0,
    weight_center_penalty: 0.0,
    weight_early_game_food: 0.0,
    weight_food_safety_penalty: 0.0,
    weight_tail_chasing: 0.0,
    weight_voronoi_control: 0.0,
    weight_competitive_length: 0.0,
    weight_competitive_length_critical: 0.0,
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

/// Early Game Configuration (Turns 1-75)
/// Focus: Find food, grow length, stay alive
pub fn early_game_config() -> HeuristicConfig {
  HeuristicConfig(
    ..default_config(),
    // Food is priority
    enable_early_game_food: True,
    weight_early_game_food: 300.0,
    early_game_food_turn_threshold: 75,
    weight_food_health: 350.0,
    // Length advantage is valuable
    enable_competitive_length: True,
    weight_competitive_length: 200.0,
    weight_competitive_length_critical: 350.0,
    // Space is plentiful, lower priority
    weight_flood_fill: 3.0,
    // Voronoi is expensive and less useful early
    enable_voronoi_control: False,
    // Center control matters less early
    enable_center_control: False,
    weight_center_control: 30.0,
    weight_center_penalty: -10.0,
    // Tail chasing less important (space available)
    weight_tail_chasing: 50.0,
  )
}

/// Mid Game Configuration (Turns 76+, 2+ opponents)
/// Focus: Control position, food efficiency, predict threats
pub fn mid_game_config() -> HeuristicConfig {
  HeuristicConfig(
    ..default_config(),
    // Early game food disabled after turn 75
    enable_early_game_food: False,
    // Only eat when necessary
    weight_food_health: 300.0,
    health_threshold: 30,
    // Space control becomes more important
    weight_flood_fill: 5.0,
    // Voronoi valuable for positioning
    enable_voronoi_control: True,
    weight_voronoi_control: 20.0,
    // Center control critical
    enable_center_control: True,
    weight_center_control: 60.0,
    weight_center_penalty: -30.0,
    // Competitive length still matters
    enable_competitive_length: True,
    weight_competitive_length: 150.0,
    weight_competitive_length_critical: 250.0,
    // Tail chasing for positioning
    weight_tail_chasing: 80.0,
  )
}

/// Late Game Configuration (1-2 opponents OR cramped space)
/// Focus: Survival, flood fill, tail chasing, board control
pub fn late_game_config() -> HeuristicConfig {
  HeuristicConfig(
    ..default_config(),
    // No more early game food
    enable_early_game_food: False,
    // Food only when desperate
    weight_food_health: 400.0,
    health_threshold: 25,
    // CRITICAL: Don't get trapped
    weight_flood_fill: 8.0,
    // Tail chasing to create escape routes
    weight_tail_chasing: 120.0,
    tail_chasing_health_threshold: 60,
    tail_chasing_space_threshold: 40,
    // Center control very important
    enable_center_control: True,
    weight_center_control: 80.0,
    weight_center_penalty: -40.0,
    // Voronoi for territory control in endgame
    enable_voronoi_control: True,
    weight_voronoi_control: 25.0,
    // Length less important (staying alive is key)
    enable_competitive_length: False,
  )
}
