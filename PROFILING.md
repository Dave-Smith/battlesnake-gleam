# Profiling Gleam Snake Performance

## Quick Start: Using fprof (Recommended)

### Step 1: Add Profiling Hook

Create `src/profiler.gleam`:

```gleam
//// Profiling utilities

import gleam/dynamic
import gleam/erlang/atom

pub type FprofResult {
  FprofResult(ok: dynamic.Dynamic)
}

@external(erlang, "fprof", "trace")
pub fn fprof_trace(options: List(#(atom.Atom, dynamic.Dynamic))) -> FprofResult

@external(erlang, "fprof", "profile")
pub fn fprof_profile() -> FprofResult

@external(erlang, "fprof", "analyse")
pub fn fprof_analyse(options: List(#(atom.Atom, dynamic.Dynamic))) -> FprofResult

@external(erlang, "fprof", "stop")
pub fn fprof_stop() -> atom.Atom

pub fn start_profiling() -> Nil {
  let start_atom = atom.create_from_string("start")
  fprof_trace([#(start_atom, dynamic.from(Nil))])
  Nil
}

pub fn stop_and_analyze() -> Nil {
  fprof_stop()
  fprof_profile()
  
  let dest_atom = atom.create_from_string("dest")
  let file = dynamic.from("fprof_analysis.txt")
  fprof_analyse([#(dest_atom, file)])
  
  Nil
}
```

### Step 2: Instrument Your Code

Add profiling to snake_app.gleam:

```gleam
Post, "/move" -> {
  case parse_game_state(req) {
    Ok(game_state) -> {
      // START PROFILING
      profiler.start_profiling()
      
      let request_start = log.get_monotonic_time()
      // ... your existing move logic ...
      let result = minimax.choose_move(...)
      
      // STOP PROFILING
      profiler.stop_and_analyze()
      
      // ... rest of handler
    }
  }
}
```

### Step 3: Run and Analyze

```bash
# Build and run
gleam run

# Make a move request (triggers profiling)
curl -X POST http://localhost:8080/move -d @test_request.json

# Check the output
cat fprof_analysis.txt | head -100
```

**Look for:**
- Functions with high `ACC` (accumulated time)
- Functions called many times (`CNT` column)
- Functions with high `OWN` time (excluding children)

---

## Alternative: Using :observer (Visual)

### Step 1: Start Interactive Shell

```bash
gleam run -m snake_app
```

### Step 2: In Another Terminal

```bash
# Connect to running process
erl -name debugger@127.0.0.1 -setcookie gleam

# In Erlang shell:
> observer:start().
```

### Step 3: Attach to Process

- In Observer window: Menu → Nodes → Connect
- Select your gleam process
- Click "Applications" tab
- Make requests and watch CPU/memory

---

## Alternative: Simple Timing Instrumentation

Quickest approach - add timing to suspected bottlenecks:

### In heuristics.gleam:

```gleam
pub fn evaluate_board(state: GameState, config: HeuristicConfig) -> Float {
  let start = log.get_monotonic_time()
  
  // Cache flood fill result
  let ff_start = log.get_monotonic_time()
  let cached_space = case config.enable_flood_fill {
    True -> pathfinding.flood_fill(state.you.head, state.board, state.board.snakes)
    False -> 0
  }
  let ff_end = log.get_monotonic_time()
  
  // ... rest of heuristics ...
  
  let end = log.get_monotonic_time()
  log.debug_with_fields("evaluate_board timing", [
    #("total_ms", int.to_string(end - start)),
    #("flood_fill_ms", int.to_string(ff_end - ff_start)),
  ])
  
  // ... return score
}
```

### In pathfinding.gleam:

```gleam
pub fn flood_fill(start: Coord, board: Board, snakes: List(Snake)) -> Int {
  let start_time = log.get_monotonic_time()
  
  let result = flood_fill_helper([start], set.from_list([start]), board, snakes)
  
  let end_time = log.get_monotonic_time()
  log.debug_with_fields("flood_fill", [
    #("ms", int.to_string(end_time - start_time)),
    #("tiles", int.to_string(result)),
  ])
  
  result
}
```

### In minimax.gleam:

```gleam
pub fn minimax(..., opponent_sim_depth: Int) -> Float {
  let is_simulating = opponent_sim_depth > 0
  
  case is_simulating && depth == 6 {  // Top level
    True -> log.debug("Opponent simulation ACTIVE")
    False -> Nil
  }
  
  // ... rest of minimax
}
```

---

## Likely Bottlenecks (Based on Code Review)

### 1. **Flood Fill** (Highest Probability)

**Evidence:**
- Called multiple times per evaluation (flood_fill_score, tail_chasing, food_safety)
- O(n²) list.append in BFS queue
- With opponent sim: 3x more evaluations = 3x more flood fills

**How to verify:**
```gleam
// Add counter in pathfinding.gleam
pub fn flood_fill(...) {
  io.println("FLOOD_FILL_CALLED")  // Count these in logs
  // ... existing code
}
```

**Check:**
```bash
grep "FLOOD_FILL_CALLED" logs.txt | wc -l
# If > 100 per move, this is the bottleneck
```

### 2. **Opponent Move Branching**

**Evidence:**
- Branch factor: 3 moves × 3 opponent moves = 9 branches per ply
- First 3 plies: 9 × 27 × 81 = ~20,000 nodes (even with pruning ~10,000)
- Each needs evaluation

**How to verify:**
```gleam
// In branch_on_opponent_moves:
io.println("OPP_BRANCH")  // Count branches
```

**Check:**
```bash
grep "OPP_BRANCH" logs.txt | wc -l
# Number of times we branched on opponent moves
```

### 3. **Heuristic Evaluation**

**Evidence:**
- Each node evaluation runs 10+ heuristics
- Some do expensive operations (flood fill, voronoi, sorting)
- With 10,000 nodes: 10,000 × 2ms = 20 seconds (if unoptimized)

**How to verify:**
Add counter in evaluate_board:
```gleam
pub fn evaluate_board(...) {
  io.println("EVAL")
  // ... existing
}
```

---

## Quick Performance Test

### Disable Features One at a Time

**Test 1: Disable opponent simulation**
```gleam
// In minimax.gleam choose_move:
let opponent_sim_depth = 0  // Force disable
```

Run game, check timing. If back to 50ms → opponent sim is the issue.

**Test 2: Disable flood fill**
```gleam
// In adaptive_config early_game_config:
enable_flood_fill: False,
enable_tail_chasing: False,  // Also uses flood fill
enable_food_safety: False,   // Also uses flood fill
```

Run game, check timing. If much faster → flood fill is the bottleneck.

**Test 3: Reduce depth**
```gleam
// In snake_app.gleam calculate_dynamic_depth:
fn calculate_dynamic_depth(_: GameState) -> Int {
  3  // Force low depth
}
```

Run game, check timing. If fast → depth is too high with opponent sim.

---

## Expected Bottleneck Rankings

Based on code analysis:

**1. Flood Fill (90% probability)**
- O(n²) list operations
- Called 3-5 times per evaluation
- With 10,000 nodes: 30,000-50,000 flood fills

**2. Opponent Branching (80% probability)**
- 9x branch factor for 3 plies
- Expected 10,000+ node evaluations
- Each evaluation has overhead

**3. Opponent Prediction (20% probability)**
- find_nearest_opponent called many times
- May allocate repeatedly

---

## Immediate Action Items

**Before profiling, try these quick wins:**

### 1. Reduce Opponent Sim Depth to 2
```gleam
let opponent_sim_depth = int.min(depth, 2)  // Was 3
```

Expected: 9x branch factor for 2 plies instead of 3
Savings: ~300ms → ~150ms

### 2. Reduce Main Depth When Opponent Sim Active
```gleam
fn calculate_dynamic_depth(game_state: GameState) -> Int {
  let num_snakes = list.length(game_state.board.snakes)
  
  case num_snakes {
    1 -> 8   // Was 10
    2 -> 6   // Was 9
    _ -> 4   // Was 5-7
  }
}
```

Expected: Fewer plies overall
Savings: ~500ms → ~200ms

### 3. Disable Flood Fill in Opponent Prediction Config
```gleam
// In opponent_prediction_config():
enable_flood_fill: False,  // Opponent doesn't need this
weight_flood_fill: 0.0,
```

Expected: Faster opponent evaluations
Savings: Small but compounds (maybe 50-100ms)

---

## Profiling Commands Summary

**Simplest (timing instrumentation):**
```bash
# Add log.get_monotonic_time() around suspected code
# Check logs for ms values
grep "timing" logs.txt
```

**Most detailed (fprof):**
```bash
# Add profiler.gleam
# Instrument /move handler
# Check fprof_analysis.txt for function times
cat fprof_analysis.txt | grep -A5 "flood_fill"
```

**Visual (observer):**
```bash
# Start observer GUI
# Watch live CPU/memory during moves
observer:start()
```

---

**My recommendation:** Start with **quick wins** above (reduce depths), then add **simple timing logs** if still slow, only use **fprof** if you need detailed analysis.

Based on the code, I'm 90% confident the issue is:
1. Flood fill being called too many times
2. Opponent branching creating 10,000+ node evaluations
3. Depths too high for opponent simulation mode

Want me to implement the quick wins first?
