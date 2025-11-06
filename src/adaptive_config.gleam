//// Adaptive Configuration Module
//// Dynamically adjusts heuristic weights based on opponent behavior

import api.{type GameState}
import gleam/float
import heuristic_config.{HeuristicConfig}
import heuristics
import log

/// Returns an adapted configuration based on detected food competition
pub fn get_adaptive_config(state: GameState) -> heuristic_config.HeuristicConfig {
  let base_config = heuristic_config.default_config()
  let competition_score = heuristics.detect_food_competition(state)

  let competition_threshold = 0.5

  case competition_score >. competition_threshold {
    True -> {
      log.info_with_fields(
        "Adaptive config triggered - food competition detected",
        [
          #("competition_score", float.to_string(competition_score)),
        ],
      )

      HeuristicConfig(
        ..base_config,
        enable_center_control: False,
        enable_voronoi_control: False,
        weight_food_health: 500.0,
        weight_competitive_length: 200.0,
        weight_competitive_length_critical: 400.0,
        health_threshold: 70,
        weight_tail_chasing: 40.0,
      )
    }
    False -> base_config
  }
}
