# Heuristics Documentation

This document provides comprehensive details on all heuristics used by the Gleam Snake AI, including their configurations, weight values, and impacts on gameplay.

## Table of Contents

1. [Overview](#overview)
2. [Heuristic Configurations](#heuristic-configurations)
3. [Individual Heuristics](#individual-heuristics)
4. [Configuration Parameters](#configuration-parameters)

---

## Overview

The snake's decision-making is powered by 11 distinct heuristics that evaluate board positions. Each heuristic can be enabled/disabled and has associated weight values that determine its influence on move selection. The Minimax algorithm with alpha-beta pruning uses these heuristics to evaluate board states up to 10 moves ahead.

---

## Heuristic Configurations

### `default_config()`

**Purpose**: Balanced configuration suitable for most game scenarios.

**Settings**:
- All heuristics enabled
- Balanced weights prioritizing safety first, then space control, then tactical advantages
- Health threshold: 35 (seeks food when health drops below this)
- Early game turns: 50 (activates center control for first 50 turns)
- Tail chasing triggers: health >50 and accessible space <30 tiles
- Competitive length mode: only when health >50

**Best for**: General play, mixed opponent strategies, standard game conditions.

---

### `aggressive_config()`

**Purpose**: Favors territorial control and head-to-head confrontations when longer.

**Changes from default**:
- `weight_flood_fill`: 5.0 → **3.5** (reduced emphasis on total space)
- `weight_avoid_adjacent_heads_longer`: 20.0 → **50.0** (actively seeks opponent heads when longer)
- `weight_center_control`: 50.0 → **150.0** (strongly prioritizes center board position)
- `competitive_length_health_min`: 50 → **20** (seeks length advantage even at low health)

**Impact**: Snake will be more confrontational, control the center aggressively, and pursue head-to-head encounters when it has a length advantage. Reduces defensive spacing behavior.

**Best for**: Dominating weaker opponents, maintaining board control, 1v1 endgames.

---

### `defensive_config()`

**Purpose**: Prioritizes survival and safety over territorial control.

**Changes from default**:
- `weight_flood_fill`: 5.0 → **2.0** (less emphasis on space control)
- `weight_avoid_adjacent_heads`: -150.0 → **-200.0** (even stronger penalty for being near opponent heads)
- `weight_food_health`: 300.0 → **400.0** (seeks food more aggressively when hungry)

**Impact**: Snake will maintain larger safety margins from opponents, prioritize food collection, and avoid risky confrontations. May cede territory to ensure survival.

**Best for**: Surviving against aggressive opponents, low health situations, crowded boards.

---

### `get_adaptive_config()`

**Purpose**: Dynamically switches to competitive food-seeking mode when food competition is detected.

**Trigger Conditions** (when competition score >0.5):
- Food scarcity: <1.5 food per snake
- Opponents closer to most food sources
- Length disadvantage (opponent avg length >110% of ours)

**Changes from default when triggered**:
- `enable_center_control`: True → **False** (disables center control)
- `enable_voronoi_control`: True → **False** (disables territory calculation)
- `weight_food_health`: 300.0 → **500.0** (aggressive food seeking)
- `weight_competitive_length`: 150.0 → **200.0** (increased length competition)
- `weight_competitive_length_critical`: 250.0 → **400.0** (critical length competition)
- `health_threshold`: 35 → **70** (seeks food earlier)
- `weight_tail_chasing`: 80.0 → **40.0** (reduces tail following to focus on growth)

**Impact**: Snake abandons territorial control in favor of aggressive food collection when opponents are hoarding food. Seeks food at higher health levels and prioritizes length competition.

**Best for**: Matches against food-aggressive opponents, food scarcity situations, comeback scenarios.

---

## Individual Heuristics

### A1. Safety Boundary (`enable_safety_boundary`)

**Weight**: `weight_safety_boundary = -1000.0`

**Purpose**: Prevents moving off the board edges.

**Behavior**: Applies a massive penalty if the snake's head would be outside board boundaries.

**Increasing weight** (e.g., to -2000.0): Even more extreme penalty (redundant, -1000 already eliminates these moves).

**Decreasing weight** (e.g., to -500.0): Still eliminates boundary moves, but might affect tie-breaking in minimax.

**Disabling**: **CRITICAL FAILURE** - Snake will crash into walls immediately. Never disable.

---

### A2. Safety Self-Collision (`enable_safety_self_collision`)

**Weight**: `weight_safety_self_collision = -1000.0`

**Purpose**: Prevents running into our own body segments.

**Behavior**: Applies massive penalty if head would collide with body (except tail on same turn).

**Increasing weight** (e.g., to -2000.0): Redundant, already eliminates self-collisions.

**Decreasing weight** (e.g., to -500.0): Still eliminates self-collisions in practice.

**Disabling**: **CRITICAL FAILURE** - Snake will run into itself. Never disable.

---

### A3. Safety Head Collision (`enable_safety_head_collision`)

**Weights**:
- `weight_safety_head_collision_longer = -800.0` (penalty when opponent is longer/equal)
- `weight_safety_head_collision_shorter = 50.0` (bonus when opponent is shorter)

**Purpose**: Handles head-to-head collision scenarios based on length advantage.

**Behavior**:
- **When opponent longer**: -800 penalty discourages head-to-head
- **When opponent shorter**: +50 bonus encourages aggressive head-to-head

**Increasing longer penalty** (e.g., to -1200.0): More conservative, avoids risky head-to-heads even more strongly.

**Decreasing longer penalty** (e.g., to -400.0): More willing to risk head-to-heads with longer opponents (dangerous).

**Increasing shorter bonus** (e.g., to 150.0): Aggressively seeks head-to-heads when longer.

**Decreasing shorter bonus** (e.g., to 10.0): Less aggressive against shorter opponents.

**Disabling**: Snake won't differentiate head-to-head scenarios by length. May lose winnable confrontations or take losing ones.

---

### B. Flood Fill (`enable_flood_fill`)

**Weight**: `weight_flood_fill = 5.0`

**Purpose**: Maximizes accessible territory to avoid being trapped.

**Behavior**: Counts reachable tiles from current position using BFS. Score = accessible_tiles × 5.0.
- **Optimization**: Result is cached once per board state and reused by multiple heuristics
- **Move Safety**: Moves leading to areas smaller than snake length are filtered before evaluation

**Increasing weight** (e.g., to 10.0): Strongly prioritizes open space, may avoid tight areas even with food.

**Decreasing weight** (e.g., to 2.0): Less emphasis on space control, more willing to enter confined areas.

**Disabling**: Snake loses spatial awareness, may trap itself in dead ends. **High risk** of self-trapping.

**Examples**:
- At 5.0: 50 accessible tiles = +250 score
- At 10.0: 50 accessible tiles = +500 score (doubles influence)
- At 2.0: 50 accessible tiles = +100 score (halves influence)

---

### C1. Avoid Adjacent Heads (`enable_avoid_adjacent_heads`)

**Weights**:
- `weight_avoid_adjacent_heads = -150.0` (penalty when opponent is longer/equal)
- `weight_avoid_adjacent_heads_longer = 20.0` (bonus when we are longer)

**Purpose**: Controls behavior near opponent heads based on length advantage.

**Behavior**:
- **When opponent longer**: -150 penalty for being adjacent to their head
- **When we are longer**: +20 bonus for being adjacent to their head (cuts them off)

**Increasing penalty** (e.g., to -300.0): Much more defensive spacing, avoids opponent heads more strongly.

**Decreasing penalty** (e.g., to -50.0): More willing to engage opponents even when at length disadvantage.

**Increasing bonus** (e.g., to 100.0): Aggressively pursues opponent heads when longer (may overcommit).

**Disabling**: Snake loses tactical awareness of head-to-head positioning. May walk into bad confrontations or miss cutoff opportunities.

---

### C2. Center Control (`enable_center_control`)

**Weights**:
- `weight_center_control = 50.0` (bonus for being in center)
- `weight_center_penalty = -20.0` (penalty for being at walls)

**Purpose**: Controls board positioning, especially in early game.

**Behavior**:
- **Early game** (turn <50) with multiple opponents: +50 for being in center 5×5 area
- **Any time**: -20 for being against walls
- **Disabled** when adaptive config triggers (food competition mode)

**Increasing center bonus** (e.g., to 150.0): Strongly prioritizes center (see aggressive_config).

**Decreasing center bonus** (e.g., to 20.0): Less emphasis on center positioning.

**Increasing wall penalty** (e.g., to -50.0): Strongly avoids edges even when food is there.

**Disabling**: Snake doesn't prioritize center control. May start games at edges (disadvantageous in crowded games).

---

### D. Food Health (`enable_food_health`)

**Weight**: `weight_food_health = 300.0`

**Purpose**: Seeks food when health is low.

**Behavior**: When health < threshold (default 35), seeks nearest food with inverse distance weighting.
- Score = 300.0 × (1 / (distance + 1))
- Closer food = higher score

**Increasing weight** (e.g., to 500.0): More aggressive food seeking (see adaptive_config when competing).

**Decreasing weight** (e.g., to 150.0): Less emphasis on food, may starve in food-scarce games.

**Disabling**: **HIGH RISK** - Snake will starve unless manually controlled. May ignore food until too late.

**Examples**:
- Food 2 tiles away: 300 × (1/3) = +100 score
- Food 5 tiles away: 300 × (1/6) = +50 score
- At 500 weight and 2 tiles: 500 × (1/3) = +166 score

---

### E. Tail Chasing (`enable_tail_chasing`)

**Weight**: `weight_tail_chasing = 80.0`

**Purpose**: Follows own tail when healthy but space-constrained to create escape routes.

**Behavior**: Activates when health >50 AND accessible space <30 tiles.
- Score = 80.0 × (1 / (tail_distance + 1))
- Creates safe path by following tail until space opens up

**Increasing weight** (e.g., to 150.0): More strongly follows tail in tight spaces.

**Decreasing weight** (e.g., to 40.0): Less tail-following, may get trapped more easily (see adaptive_config).

**Disabling**: Snake may not follow tail in confined spaces, higher risk of self-trapping.

**Examples**:
- Tail 1 tile away: 80 × (1/2) = +40 score
- Tail 4 tiles away: 80 × (1/5) = +16 score

---

### F. Food Safety (`enable_food_safety`)

**Purpose**: Efficient food targeting with cluster awareness.

**Behavior**: When health < threshold:
- Finds closest food within 10 moves (Manhattan distance)
- Rewards moves toward that food: `(10 - distance) × 10.0`
- Bonus for food clusters: `cluster_count × 5.0` (food within 5 tiles of target)
- **Optimization**: O(F) distance checks instead of O(F × board_size) flood fills

**Increasing distance limit** (e.g., to 15): Considers more distant food as viable targets.

**Decreasing distance limit** (e.g., to 5): Only targets very close food, may starve in sparse games.

**Disabling**: Snake loses food-seeking behavior when hungry. **HIGH RISK** - will likely starve.

**Examples**:
- Food 2 tiles away, 3 food in cluster: (10-2)×10 + 3×5 = 80 + 15 = +95 score
- Food 8 tiles away, solo: (10-8)×10 = +20 score
- Food 11 tiles away: 0 score (too far)

---

### G. Voronoi Control (`enable_voronoi_control`)

**Weight**: `weight_voronoi_control = 15.0`

**Purpose**: Maximizes territory reachable before opponents in 1v1 scenarios.

**Behavior**: Uses optimized Manhattan distance sampling of ~25 strategic tiles to calculate controlled territory.
- Score = 15.0 × (our_controlled_tiles / sample_size)
- Optimized to run in <5ms vs naive BFS approach
- **Disabled** when adaptive config triggers (food competition mode)

**Increasing weight** (e.g., to 30.0): Strongly prioritizes territorial control in endgames.

**Decreasing weight** (e.g., to 5.0): Less emphasis on territory, may lose 1v1 endgames.

**Disabling**: Loses territorial awareness in 1v1 scenarios. May concede space disadvantage in endgames.

**Examples**:
- Controlling 15/25 sampled tiles: 15.0 × 0.6 = +9 score
- Controlling 20/25 sampled tiles: 15.0 × 0.8 = +12 score

---

### H. Competitive Length (`enable_competitive_length`)

**Weights**:
- `weight_competitive_length = 150.0` (when tied in length)
- `weight_competitive_length_critical = 250.0` (when shorter than opponent)

**Purpose**: Maintains length advantage for head-to-head dominance.

**Behavior**: When health >50 and food exists:
- **If tied with longest opponent**: seeks food with 150 × distance_factor
- **If shorter than longest opponent**: seeks food with 250 × distance_factor
- **If longer by 2+**: no bonus (already dominating)

**Increasing weights** (e.g., to 200/400): More aggressive length competition (see adaptive_config).

**Decreasing weights** (e.g., to 50/100): Less emphasis on length advantage, may lose head-to-head opportunities.

**Disabling**: Snake doesn't proactively maintain length advantage. May lose winnable confrontations due to being shorter.

**Examples**:
- Tied, food 3 tiles away: 150 × (1/4) = +37.5 score
- Behind, food 3 tiles away: 250 × (1/4) = +62.5 score

---

## Configuration Parameters

### `health_threshold: Int` (default: 35)

**Purpose**: Health level below which snake seeks food.

**Impact**:
- **Increasing** (e.g., to 70): Seeks food earlier, stays healthier but may over-eat
- **Decreasing** (e.g., to 20): Waits until desperate for food, may starve
- **Adaptive config**: Increases to 70 during food competition

---

### `early_game_turn_threshold: Int` (default: 50)

**Purpose**: Number of turns considered "early game" for center control.

**Impact**:
- **Increasing** (e.g., to 100): Extends center control emphasis
- **Decreasing** (e.g., to 25): Shorter center control period

---

### `tail_chasing_health_threshold: Int` (default: 50)

**Purpose**: Minimum health required to activate tail chasing.

**Impact**:
- **Increasing** (e.g., to 70): Only follows tail when very healthy
- **Decreasing** (e.g., to 30): Follows tail even at low health (may miss food opportunities)

---

### `tail_chasing_space_threshold: Int` (default: 30)

**Purpose**: Maximum accessible tiles that triggers tail chasing.

**Impact**:
- **Increasing** (e.g., to 50): Activates tail chasing in less confined spaces
- **Decreasing** (e.g., to 15): Only follows tail in very tight spaces

---

### `competitive_length_health_min: Int` (default: 50)

**Purpose**: Minimum health to activate competitive length seeking.

**Impact**:
- **Increasing** (e.g., to 70): Only seeks competitive length when very healthy
- **Decreasing** (e.g., to 20): Seeks length advantage even at low health (see aggressive_config)

---

## Tuning Guidelines

### For Aggressive Play
- Increase: `weight_avoid_adjacent_heads_longer`, `weight_center_control`
- Decrease: `competitive_length_health_min`, `weight_flood_fill`
- Use: `aggressive_config()`

### For Defensive Play
- Increase: `weight_avoid_adjacent_heads` (more negative), `weight_food_health`
- Decrease: `weight_flood_fill`, `weight_center_control`
- Use: `defensive_config()`

### For Food-Scarce Games
- Increase: `health_threshold`, `weight_food_health`, `weight_competitive_length`
- Consider: Manually trigger adaptive mode

### For Survival Focus
- Increase: `weight_flood_fill`, `weight_tail_chasing`
- Decrease: `weight_competitive_length`, `weight_voronoi_control`
- Enable: All safety heuristics

### For 1v1 Endgames
- Increase: `weight_voronoi_control`, `weight_avoid_adjacent_heads_longer`
- Use: Depth 9 minimax (automatically configured)

---

## Performance Notes

- **Minimax Depth**: Dynamically adjusted (5-10) based on game state density
- **Flood Fill Caching**: Computed once per board state, reused by multiple heuristics
- **Move Filtering**: Space-unsafe moves (leading to areas < snake length) filtered before minimax
- **Food Targeting**: O(F) distance-based approach instead of O(F × board_size) flood fills
- **Voronoi Optimization**: ~25 tile sampling vs full board (5000x+ faster)
- **Logging**: Minimal per-move logging to stay under 500ms response time
- **Alpha-Beta Pruning**: Dramatically reduces nodes evaluated (up to 90% reduction)

---

## Testing Recommendations

When modifying heuristics:

1. **Run local games**: Use `battlesnake play` to test against known opponents
2. **Monitor logs**: Check which heuristics dominate decision-making
3. **Test edge cases**: Food scarcity, 1v1 endgames, crowded starts
4. **Measure timing**: Ensure moves stay under 500ms (preferably <200ms)
5. **Compare configs**: Run same scenario with different configs to measure impact
