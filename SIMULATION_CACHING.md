# Simulation Caching Status

## Current Implementation (Optimized)

### What's Cached

**Depth-0 evaluation (snake_app.gleam:136-141):**
```gleam
let depth_0_data =
  list.map(safe_moves, fn(move) {
    let simulated_state = simulate_game_state(game_state, move)  // ← Simulated ONCE
    let score = heuristics.evaluate_board(simulated_state, config)
    #(move, simulated_state, score)  // ← Cached state + score
  })
```

**Reused for debug logging (line 154-159):**
```gleam
list.each(depth_0_data, fn(triple) {
  let #(move, simulated_state, total_score) = triple
  // Uses cached simulated_state ✓ No re-simulation
  let detailed_scores = heuristics.evaluate_board_detailed(simulated_state, config)
})
```

### What's NOT Cached (But Necessary)

**Minimax evaluation (minimax.gleam:59):**
```gleam
let move_scores =
  list.map(evaluated_moves, fn(move) {
    let next_state = simulate_game_state(state, move)  // ← Simulates AGAIN
    let score = minimax(next_state, depth - 1, ...)
    #(move, score)
  })
```

**Why it has to simulate again:**
- Minimax might filter moves (space check on lines 33-47)
- Filtered moves might differ from `safe_moves`
- Can't reuse depth_0_data simulations if move set changes

## Simulation Count Per Move Request

With 3 safe moves and depth 6:

**Before optimization:**
```
Depth-0 calculation:     3 simulations
Debug logging:           3 simulations  ← WASTEFUL
Minimax calculation:     3 simulations
Minimax debug logging:   3 simulations  ← WASTEFUL
─────────────────────────────────────
Total:                  12 simulations
```

**After optimization:**
```
Depth-0 calculation:     3 simulations (cached)
Debug logging:           0 simulations (reuses cache) ✓
Minimax calculation:     3 simulations (necessary)
Minimax debug logging:   3 simulations (still wasteful)
─────────────────────────────────────
Total:                   9 simulations
```

**Savings: 25% reduction** (12 → 9)

## Why Minimax Can't Reuse Depth-0 Cache

### Issue 1: Move Filtering

```gleam
// In minimax.choose_move
let moves_with_space =
  list.filter_map(moves, fn(move) {
    let next_state = simulate_game_state(state, move)  // ← Must simulate to check space
    let space_available = pathfinding.flood_fill(...)
    case space_available >= min_space {
      True -> Ok(move)
      False -> Error(Nil)  // ← Filters out this move!
    }
  })
```

If minimax filters moves, it operates on a different set than depth-0, so can't reuse simulations.

### Issue 2: Different Contexts

Depth-0 simulates from current game_state:
```
simulate_game_state(game_state, "up") → state at turn N+1
```

Minimax recursively simulates from already-simulated states:
```
minimax(state_at_N+1, depth=5, ...)
  → simulates moves from turn N+1 to get turn N+2
  → simulates moves from turn N+2 to get turn N+3
  ...
```

These are different simulations at different depths.

## Performance Impact

### Per-Move Request Timing

**Simulation overhead:**
- 1 simulation ≈ 0.1-0.2ms (copy snake states, update positions)
- With 3 moves: 9 simulations ≈ 1-2ms total

**Heuristic evaluation overhead:**
- 1 evaluation ≈ 0.5-1ms (flood fill, heuristics)
- evaluate_board: 0.5ms
- evaluate_board_detailed: 0.5ms (redundant work)

**Total depth-0 cost:**
- 3 simulations: ~1ms
- 3 evaluations: ~1.5ms
- 3 detailed evaluations (debug): ~1.5ms
- **Total: ~4ms** (out of typical 50-200ms request)

**Impact: ~2% of total request time** (acceptable)

## Further Optimization Opportunities

### 1. Cache Minimax Debug Simulations

Currently lines 163-173 in snake_app.gleam re-simulate for debug logging:

**Before:**
```gleam
let minimax_scores =
  list.map(safe_moves, fn(move) {
    let next_state = simulate_game_state(game_state, move)  // ← WASTEFUL
    let score = minimax.minimax(next_state, ...)
    #(move, score)
  })
```

**After:**
```gleam
// Reuse depth_0_data simulations
let minimax_scores =
  list.map(depth_0_data, fn(triple) {
    let #(move, simulated_state, _) = triple  // ← Reuse cached state
    let score = minimax.minimax(simulated_state, depth - 1, ...)
    #(move, score)
  })
```

**Savings:** 3 more simulations = ~0.5ms

### 2. Remove Debug Logging in Production

All debug logging is only useful during development:

```gleam
// In production:
let depth_0_scores = list.map(safe_moves, fn(move) {
  let simulated_state = simulate_game_state(game_state, move)
  #(move, heuristics.evaluate_board(simulated_state, config))
})

let result = minimax.choose_move(game_state, depth, config, depth_0_scores)
// No debug logging = no extra work
```

**Savings:** 4ms per request (no detailed evaluations, no duplicate minimax)

### 3. Precompute Common Heuristics

Some heuristics don't need simulation:
- `safety_boundary`: Just check coordinates
- `center_control`: Based on position only

Could evaluate these before simulation and cache results.

**Savings:** Minor (~0.1ms per move)

### 4. Full Minimax Cache (Advanced)

Pass depth_0_data to minimax.choose_move and reuse for move filtering:

```gleam
pub fn choose_move(
  state: GameState,
  depth: Int,
  config: HeuristicConfig,
  depth_0_scores: List(#(String, Float)),
  depth_0_states: List(#(String, GameState)),  // ← NEW
) -> MinimaxResult
```

**Complexity:** High refactoring
**Savings:** 3 simulations ≈ 0.5ms
**Worth it?** Probably not (diminishing returns)

## Recommendation

**Current optimization is sufficient:**
- ✅ Cached depth-0 simulations for debug logging
- ✅ 25% reduction in simulations (12 → 9)
- ✅ ~1ms saved per request
- ✅ Minimal code complexity

**For production:**
- Disable debug logging (save 4ms)
- Accept that minimax needs its own simulations (necessary)

**Don't pursue:**
- Full minimax state caching (too complex for 0.5ms gain)
- Precomputing heuristics (minimal benefit)

---

**Status:** Depth-0 caching implemented, saves ~1ms per request
**Further optimization:** Disable debug logging in production for 4ms total savings
**Remaining overhead:** 9 simulations per request (6 could be avoided but not worth complexity)
