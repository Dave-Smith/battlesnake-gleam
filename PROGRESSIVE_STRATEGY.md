# Progressive Strategy - Phase 1 Implementation

## Overview

The snake now adapts its strategy based on game phase, optimizing for different priorities at different stages of the game.

## Game Phases

### **Early Game** (Turns 1-75)
**Priority: Growth & Survival**

**Strategy:**
- Aggressively seek food to build length advantage
- Accept moderate risk for food (higher food weights)
- Lower priority on space control (space is plentiful)
- Disable expensive Voronoi calculations

**Key Weight Changes:**
```gleam
weight_early_game_food: 300.0        (was 250)
weight_food_health: 350.0            (was 300)
weight_competitive_length: 200.0     (was 150)
weight_flood_fill: 3.0               (was 5.0 - less important early)
enable_voronoi_control: False        (disabled - expensive, less useful)
weight_center_control: 30.0          (was 50 - less critical early)
weight_tail_chasing: 50.0            (was 80 - less important with space)
```

**Rationale:**
- Early length advantage compounds over the game
- Board is spacious, less risk of getting trapped
- Voronoi calculation is expensive with many snakes
- Center position less critical when space is available

---

### **Mid Game** (Turns 76+, 2+ opponents)
**Priority: Positioning & Efficiency**

**Strategy:**
- Only eat when health drops below 30
- Prioritize center control for strategic advantage
- Enable Voronoi for territory analysis
- Balance space control with positioning

**Key Weight Changes:**
```gleam
enable_early_game_food: False        (turn off aggressive food seeking)
health_threshold: 30                 (was 35 - more conservative)
weight_flood_fill: 5.0               (standard - important but not critical)
enable_voronoi_control: True         (enabled - useful for positioning)
weight_voronoi_control: 20.0         (was 15 - more emphasis)
weight_center_control: 60.0          (was 50 - more important)
weight_center_penalty: -30.0         (was -20 - avoid walls more)
```

**Rationale:**
- Ceding position for food can be costly mid-game
- Center control provides strategic options
- Voronoi helps identify opponents to target
- Space starting to matter more

---

### **Late Game** (1-2 opponents OR >40% board occupied)
**Priority: Survival**

**Strategy:**
- CRITICAL: Avoid traps and dead ends
- Maximize flood fill to ensure escape routes
- Tail chase to create space and partition opponents
- Maintain center control for flexibility
- Length advantage less important than staying alive

**Key Weight Changes:**
```gleam
weight_flood_fill: 8.0               (was 5.0 - CRITICAL to avoid traps)
weight_tail_chasing: 120.0           (was 80 - create escape routes)
tail_chasing_health_threshold: 60    (was 50 - chase more often)
tail_chasing_space_threshold: 40     (was 30 - chase when tighter)
weight_center_control: 80.0          (was 50 - maximize options)
weight_voronoi_control: 25.0         (was 15 - territory is key)
health_threshold: 25                 (was 35 - only eat when desperate)
enable_competitive_length: False     (disabled - survival > length)
```

**Rationale:**
- One wrong move in late game = death
- Flood fill prevents getting boxed in
- Tail chasing creates space and can trap opponents
- Center gives most escape options
- Eating can expose us to danger - avoid unless critical

---

## Phase Detection Logic

### Turn-Based
```gleam
turn <= 75 → EarlyGame
turn > 75 → MidGame or LateGame
```

### Opponent-Based
```gleam
0-2 opponents → LateGame (regardless of turn)
3+ opponents → EarlyGame or MidGame (depends on turn)
```

### Density-Based
```gleam
board_density > 40% → LateGame (cramped space)
board_density <= 40% → EarlyGame or MidGame
```

**Board density calculation:**
```gleam
occupied_tiles = sum of all snake lengths
board_size = width × height
density = (occupied_tiles / board_size) × 100
```

### Examples

**Example 1: Turn 20, 4 opponents, 15% density**
→ **EarlyGame** (turn < 75, plenty of space)

**Example 2: Turn 100, 3 opponents, 30% density**
→ **MidGame** (turn > 75, 3+ opponents, space OK)

**Example 3: Turn 50, 2 opponents, 25% density**
→ **LateGame** (only 2 opponents, even if early)

**Example 4: Turn 90, 4 opponents, 45% density**
→ **LateGame** (density > 40%, cramped)

---

## Logging

Phase transitions are logged:

```
[INFO] Game phase: EARLY GAME | turn=5
[INFO] Game phase: EARLY GAME | turn=50
[INFO] Game phase: MID GAME | turn=76
[INFO] Game phase: LATE GAME | turn=120
```

Watch for phase changes to understand strategy shifts.

---

## Testing

### Test Early Game Behavior (Turns 1-75)

**Expected:**
- Snake aggressively pursues food
- Takes calculated risks for food
- Less concerned about center position
- Voronoi disabled in heuristic logs

**Logs to check:**
```bash
grep "EARLY GAME" logs.txt
grep "early_game_food:" logs.txt | grep -v ":0"  # Should be active
grep "voronoi_control:" logs.txt                 # Should be 0
```

### Test Mid Game Behavior (Turns 76-120, 3+ opponents)

**Expected:**
- More conservative about food
- Centers itself on board
- Uses Voronoi for positioning
- Only eats when health < 30

**Logs to check:**
```bash
grep "MID GAME" logs.txt
grep "early_game_food:" logs.txt                 # Should be 0 after turn 75
grep "voronoi_control:" logs.txt | grep -v ":0" # Should be active
grep "center_control:" logs.txt                  # Should be positive
```

### Test Late Game Behavior (1-2 opponents OR cramped)

**Expected:**
- Highly defensive
- Maximizes flood fill scores
- Tail chases frequently
- Avoids food unless health critical

**Logs to check:**
```bash
grep "LATE GAME" logs.txt
grep "flood_fill:" logs.txt                      # Should be high values
grep "tail_chasing:" logs.txt | grep -v ":0"    # Should be active
grep "competitive_length:" logs.txt              # Should be 0 (disabled)
```

---

## Performance Impact

**Minimal - this is just configuration switching:**
- Phase detection: < 0.1ms (simple calculations)
- No additional simulations
- No new heuristics
- Same overall computation

**The only change:** Different weights applied to existing heuristics.

---

## Tuning

If snake behavior needs adjustment:

### Too Aggressive Early Game
```gleam
// In early_game_config():
weight_early_game_food: 250.0  // Reduce from 300
weight_flood_fill: 4.0         // Increase from 3.0
```

### Too Conservative Mid Game
```gleam
// In mid_game_config():
health_threshold: 35           // Increase from 30
weight_center_control: 50.0    // Reduce from 60
```

### Dies in Late Game
```gleam
// In late_game_config():
weight_flood_fill: 10.0        // Increase from 8.0
health_threshold: 20           // Reduce from 25 (eat less)
```

### Adjust Phase Transitions
```gleam
// In adaptive_config.gleam detect_phase():
turn if turn <= 50 -> EarlyGame  // End early game sooner
turn if turn <= 100 -> EarlyGame // Extend early game longer
```

---

## Next Steps (Phase 2)

After testing Phase 1, implement:
- **Phase 2**: Opponent AI heuristics (simple scoring for predicting moves)
- **Phase 3**: Single opponent simulation (depth 1)
- **Phase 4**: Deeper opponent simulation (depth 3)

---

**Status:** ✅ Phase 1 Complete
**Risk:** Low (no simulation changes)
**Testing:** Monitor phase transitions and strategy adaptation
**Files changed:** 2 (adaptive_config.gleam, heuristic_config.gleam)
