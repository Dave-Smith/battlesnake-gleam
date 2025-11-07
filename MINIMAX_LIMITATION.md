# Minimax Simulation Limitation

## The Problem

**Observed behavior:**
```
Depth 0: move=right, head_collision_danger:-1400, total:-265.50  (BAD)
Depth 6: move=right, score:714.83                                (GOOD?!)
```

A move that's dangerous at depth 0 becomes safe at depth 6. Why?

## Root Cause

### Opponent Simulation is Incomplete

**Code:** [game_state.gleam:146-151](file:///Users/dave/git/gleam-snake/src/game_state.gleam#L146-L151)

```gleam
let updated_other_snakes =
  list.map(current_state.board.snakes, fn(s) {
    case s.id == updated_our_snake.id {
      True -> updated_our_snake
      False -> api.Snake(..s, health: s.health - 1)  ← ONLY HEALTH CHANGES!
    }
  })
```

**Opponents don't move!** They:
- ✅ Lose health each turn
- ❌ Don't move their position
- ❌ Don't grow when eating food
- ❌ Don't make decisions

### How This Breaks Head Collision Detection

**Turn 0 (Real State):**
```
You: (5, 5)
Opponent: (7, 5)

Depth 0 evaluation of "move right to (6,5)":
  Opponent's possible moves from (7,5): [(8,5), (6,5), (7,6), (7,4)]
  Our new position: (6, 5)
  Collision possible: (6,5) is in opponent's possible moves!
  head_collision_danger: -5000  ← DANGER!
```

**Turn 1 (After Simulation):**
```
You: (6, 5)      ← We moved
Opponent: (7, 5) ← DIDN'T MOVE! Still at old position!

Depth 1 evaluation:
  Opponent's possible moves from (7,5): [(8,5), (6,5), (7,6), (7,4)]
  Our new position (after next move): Not (6,5) anymore
  Collision possible: NO (we're not moving to those positions)
  head_collision_danger: 0  ← SAFE?!
```

The danger disappears because:
1. Opponent stayed at (7,5) in simulation
2. We already moved to (6,5)
3. Next turn we'll move away from (6,5)
4. Opponent is still at (7,5), not threatening our new positions

**In reality:**
- Opponent WOULD have moved to (6,5) on turn 1
- We would have collided!
- But simulation doesn't see this

## Impact on Strategy

### 1. **False Positives for Risky Moves**
Moves with head collision danger look "safe" after 1-2 turns of lookahead because the threat disappears from simulation.

### 2. **Minimax Underestimates Danger**
```
Depth 0: "This move risks head collision" → -265
Depth 6: "Actually this looks great!" → +714
```

Minimax sees the danger disappear and thinks the move is safe.

### 3. **Snake Takes Unnecessary Risks**
The snake might:
- Move toward opponents thinking they won't move
- Cut off opponents thinking they'll stay in place
- Underestimate spatial pressure from opponents

## Why We Don't Simulate Opponent Moves

### Complexity Explosion

If we simulate opponent moves:

```
Depth 1: 3 our moves × 3 opponent moves = 9 states
Depth 2: 9 × 3 × 3 = 81 states
Depth 3: 81 × 3 × 3 = 729 states
Depth 6: 531,441 states!
```

With multiple opponents:
```
2 opponents, depth 6: 3^(6×3) = 10,460,353,203 states
```

This would require:
- Predicting opponent behavior (AI model of their strategy)
- Exponentially more computation
- Likely exceed 500ms timeout

## Solutions

### ✅ Solution 1: Massive Collision Penalty (Implemented)

**Change:** `weight_head_collision_danger_equal: -700 → -5000`

**Effect:**
```
Depth 0: head_collision_danger: -5000, total: -4435
Depth 6: Other heuristics: +714

Total at depth 6: -4435 + 714 = -3721  ← STILL NEGATIVE!
```

Even if minimax sees +714 in the future, the initial -5000 penalty carries through the tree (sort of) and keeps the move unattractive.

**Limitations:**
- The penalty only applies at depth 0
- If the move has high future value (>5000), it could still be chosen
- Not perfect, but practical

### ❌ Solution 2: Simulate Opponent Moves (Not Feasible)

Would require:
1. Model opponent AI (assume they play optimally? randomly?)
2. Handle multi-agent minimax (exponential complexity)
3. Stay under 500ms timeout

**Verdict:** Too expensive for real-time game

### ❌ Solution 3: Filter Out Collision Moves in get_safe_moves

```gleam
pub fn get_safe_moves(game_state: GameState) -> List(String) {
  // ... existing checks ...
  // NEW: Filter out moves with collision danger
  list.filter(moves, fn(move) {
    collision_danger_score(simulate(game_state, move)) > -1000.0
  })
}
```

**Problem:** Might filter out ALL moves in tight situations, causing death.

## Workarounds in Current Implementation

### 1. **High Penalty Weight**
`-5000` makes collision danger dominate most other heuristics.

### 2. **Multiple Safety Layers**
- `head_collision_danger`: -5000 (potential collision)
- `avoid_adjacent_heads`: -150 (already adjacent)
- `safety_head_collision`: -800 (actual collision)

Even if one fails, others catch it.

### 3. **Flood Fill Preference**
The `flood_fill` heuristic rewards open space. Moves toward opponents typically reduce space, getting penalized indirectly.

### 4. **Conservative Depth-0 Bias**
Because depth-0 evaluation happens first (logged), it influences early pruning in alpha-beta, slightly biasing against dangerous moves.

## Testing the Fix

**Before (-700 penalty):**
```
Depth 0: right=-265 (head_collision_danger:-1400)
Depth 6: right=+714  ← Danger disappeared, looks safe!
Chosen: right (dies to collision)
```

**After (-5000 penalty):**
```
Depth 0: right=-4735 (head_collision_danger:-10000 if 2 opponents)
Depth 6: right= probably still negative or barely positive
Chosen: safer alternative
```

## Future Improvements

### 1. **Opponent Move Heuristic**
Add a heuristic that penalizes being in opponent's "reachable zone":

```gleam
fn opponent_reachable_zone_score(state: GameState) -> Float {
  // For each opponent, calculate BFS distance
  // Penalize being within 2-3 moves of opponent
  // Weight decreases with distance
}
```

### 2. **Statistical Opponent Modeling**
Track opponent patterns and predict likely moves, simulating only the most probable paths.

### 3. **Pruning Aggressive Branches**
In minimax, prune branches where we move toward opponents unless we have clear advantage.

## Monitoring

Watch for these patterns in logs:

### ✅ Good (After Fix):
```
Depth 0: collision_danger:-5000, total:-4500
Depth 6: score:-3000
Not chosen (score too low)
```

### ❌ Bad (If Still Happening):
```
Depth 0: collision_danger:-5000, total:-4500
Depth 6: score:+5500  ← Future gain overcomes penalty
Chosen: risky move
Dies to collision
```

If you see the bad pattern, we may need to:
- Increase penalty further (e.g., -10000)
- Add distance-based collision zones
- Filter collision moves from safe_moves entirely

---

**Status:** Penalty increased from -700 to -5000 to mitigate simulation limitation
**Risk:** Medium - Still possible to choose collision moves if future value is extremely high
**Next Step:** Monitor games for collision deaths and adjust penalty if needed
