# Debugging Heuristic Scoring

## Quick Start

The code now logs **all heuristic scores for every possible move** at depth 0 (immediate evaluation).

### Reading the Logs

After starting the server and making a move request, you'll see logs like:

```
[DEBUG] Heuristic breakdown | move=up, scores=safety_boundary:0.0, safety_self_collision:0.0, safety_head_collision:0.0, flood_fill:45.0, avoid_adjacent_heads:0.0, head_collision_danger:0.0, center_control:0.0, early_game_food:125.3, food_health:0.0, tail_chasing:0.0, food_safety:0.0, voronoi_control:8.5, competitive_length:0.0, total:178.8

[DEBUG] Heuristic breakdown | move=down, scores=safety_boundary:0.0, safety_self_collision:0.0, safety_head_collision:0.0, flood_fill:50.0, avoid_adjacent_heads:0.0, head_collision_danger:0.0, center_control:0.0, early_game_food:200.0, food_health:0.0, tail_chasing:0.0, food_safety:0.0, voronoi_control:12.3, competitive_length:0.0, total:262.3

[DEBUG] Heuristic breakdown | move=left, scores=safety_boundary:0.0, safety_self_collision:-1000.0, ...
```

### What This Shows

**For each safe move**, you'll see:
1. **Individual heuristic scores** - What each heuristic contributes
2. **Total score** - Sum of all heuristics at depth 0

**Key things to look for:**

1. **Why did it avoid food?**
   - Check `early_game_food` score for the move toward food
   - Compare with other heuristic penalties (e.g., `head_collision_danger`, `avoid_adjacent_heads`)

2. **Example Analysis:**
   ```
   Move toward food:
     early_game_food: 250.0
     head_collision_danger: -700.0  ← PENALTY! Opponent could collide
     total: -450.0  ← BAD SCORE
   
   Move away from food:
     early_game_food: 50.0
     head_collision_danger: 0.0
     flood_fill: 60.0
     total: 110.0  ← BETTER SCORE
   ```

   **Conclusion**: Snake avoided food because opponent was nearby and could cause head-to-head collision.

## Filtering Logs

### Show only heuristic breakdowns for a specific turn:
```bash
# Watch live logs
tail -f logs.txt | grep "turn=5"

# Or with docker/fly
fly logs | grep "turn=5"
```

### Show only the chosen move:
```bash
grep "Move decision" logs.txt
```

### Find moves where snake avoided nearby food:
```bash
grep "early_game_food" logs.txt | grep -v "early_game_food:0.0"
```

## Common Debugging Scenarios

### Scenario 1: Snake ignores food when adjacent

**Check:**
1. Look at the heuristic breakdown for the move toward food
2. Is `head_collision_danger` negative? → Opponent nearby
3. Is `avoid_adjacent_heads` negative? → Opponent head too close
4. Is `safety_head_collision` negative? → Would collide with opponent

**Example Log:**
```
Turn 3:
[DEBUG] move=right (toward food), total:-400.0, early_game_food:250.0, head_collision_danger:-700.0
[DEBUG] move=left (away), total:100.0, flood_fill:50.0, center_control:50.0
[INFO] Move decision | turn=3, move=left, score=150.0
```

**Analysis**: Head collision danger (-700) outweighed food seeking (+250), so snake chose safer move.

### Scenario 2: Snake seeks food when health is high

**Check:**
1. `early_game_food` should only be active when turn < 50
2. `food_health` should only be active when health < 35

**Example Log:**
```
Turn 60:
[DEBUG] move=right, early_game_food:0.0, food_health:0.0  ← Both disabled!
```

### Scenario 3: Scores look correct but wrong move chosen

**Issue**: Depth 0 scores are logged, but minimax chooses based on deeper search.

**Solution**: The DEBUG logs show **immediate** evaluation (depth 0). The final move is chosen by minimax at depth 5-9, which looks ahead multiple turns.

A move might score poorly at depth 0 but great at depth 5 (e.g., "sacrifice short-term food for long-term space").

## Performance Impact

⚠️ **WARNING**: This debug logging adds overhead:
- Calls `evaluate_board_detailed` for every safe move (3-4 times per request)
- Adds ~5-10ms per move
- Only use during debugging, not in production

### To Disable Debug Logging

Comment out the debug block in [snake_app.gleam](file:///Users/dave/git/gleam-snake/src/snake_app.gleam#L116-L122):

```gleam
// DEBUG: Log heuristic scores for ALL possible moves
// list.each(safe_moves, fn(move) {
//   let simulated_state = game_state.simulate_game_state(game_state, move)
//   let detailed_scores = heuristics.evaluate_board_detailed(simulated_state, config)
//   let total_score = heuristics.evaluate_board(simulated_state, config)
//   log.log_heuristic_scores(move, detailed_scores, total_score)
// })
```

## Advanced: Log Analysis Script

Create a simple parser to analyze logs:

```bash
#!/bin/bash
# debug_turn.sh - Show all heuristic scores for a specific turn

TURN=$1

echo "=== Turn $TURN Analysis ==="
echo ""

# Show all move evaluations
echo "Depth 0 Evaluations:"
grep "turn=$TURN" logs.txt | grep "Heuristic breakdown" | while read line; do
    move=$(echo "$line" | grep -o "move=[a-z]*" | cut -d= -f2)
    total=$(echo "$line" | grep -o "total:[0-9.-]*" | cut -d: -f2)
    echo "  $move: $total"
done

echo ""
echo "Final Decision:"
grep "turn=$TURN" logs.txt | grep "Move decision"
```

**Usage:**
```bash
chmod +x debug_turn.sh
./debug_turn.sh 5
```

**Output:**
```
=== Turn 5 Analysis ===

Depth 0 Evaluations:
  up: 120.5
  down: -400.0
  left: 200.3
  right: 95.0

Final Decision:
[INFO] Move decision | turn=5, move=up, score=450.2
```

Notice: `up` scored 120.5 at depth 0, but minimax chose it with score 450.2 (after looking ahead).

## What to Report

When you find an issue, provide:

1. **Turn number**
2. **Snake position and health**
3. **Food positions**
4. **Heuristic breakdown for each move**
5. **Which move was chosen**

Example bug report:
```
Turn 3:
Position: (5, 5), Health: 100
Food: (6, 5) - adjacent!
Opponent: (7, 5), length 3 (same as us)

Heuristic scores:
  right (toward food): early_game_food:250.0, head_collision_danger:-700.0, total:-450.0
  left (away): flood_fill:60.0, total:60.0

Chosen: left (score: 150.0 after minimax)

Expected: Should go right because we're in early game and need food
Actual: Avoided food due to collision danger

Analysis: Head collision detection is too aggressive in early game when we need growth
```

---

**Quick Commands:**

```bash
# Stream logs
fly logs -a your-app-name

# Find problematic turns
grep "early_game_food" logs.txt | grep -v ":0.0"

# See all decisions for turn 10
grep "turn=10" logs.txt

# Count how often each heuristic fires
grep "Heuristic breakdown" logs.txt | grep -o "[a-z_]*:[0-9]" | sort | uniq -c
```
