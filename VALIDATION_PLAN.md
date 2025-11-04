# Validation Plan for Recent Changes

## Summary of Static Review Findings

### Critical Issues
1. **Competitive Length Logic**: Seeks food even when 1 longer than opponent (should only seek when tied or shorter)
2. **Voronoi Territory**: No collision detection (might overestimate accessible tiles)

### Minor Issues
3. **String Hash Coverage**: Limited character support in tie-breaker hash function
4. **Code Duplication**: Identical food-seeking logic in competitive_length_score

---

## Validation Steps

### Step 1: Build & Type Check
```bash
gleam build
```
**Expected**: Clean build with no compilation errors.

---

### Step 2: Unit Test Voronoi Sampling

Create a test to verify `get_strategic_sample_tiles` generates valid coordinates:

```bash
# Create test file
cat > test/pathfinding_test.gleam << 'EOF'
import pathfinding
import api
import gleam/list
import gleeunit/should

pub fn strategic_tiles_bounds_test() {
  let board = api.Board(width: 11, height: 11, food: [], snakes: [], hazards: [])
  let tiles = pathfinding.get_strategic_sample_tiles(board)
  
  // All tiles should be within bounds
  list.each(tiles, fn(coord) {
    should.be_true(coord.x >= 0 && coord.x < 11)
    should.be_true(coord.y >= 0 && coord.y < 11)
  })
  
  // Should have reasonable sample size (15-30 tiles)
  let count = list.length(tiles)
  should.be_true(count >= 15 && count <= 30)
}
EOF

gleam test
```

**Expected**: Test passes, confirming coordinates are valid.

---

### Step 3: Test Competitive Length Behavior

Create a game state where snake is 1 longer than opponent:

```bash
# Run local game with snake_app
gleam run

# Use Battlesnake CLI or curl to send test request:
curl -X POST http://localhost:8080/move \
  -H "Content-Type: application/json" \
  -d '{
    "game": {"id": "test"},
    "turn": 10,
    "board": {
      "width": 11,
      "height": 11,
      "food": [{"x": 5, "y": 5}],
      "snakes": [
        {
          "id": "you",
          "name": "You",
          "health": 80,
          "body": [{"x": 1, "y": 1}, {"x": 1, "y": 2}, {"x": 1, "y": 3}, {"x": 1, "y": 4}],
          "head": {"x": 1, "y": 1},
          "length": 4
        },
        {
          "id": "opp",
          "name": "Opponent",
          "health": 80,
          "body": [{"x": 9, "y": 9}, {"x": 9, "y": 8}, {"x": 9, "y": 7}],
          "head": {"x": 9, "y": 9},
          "length": 3
        }
      ],
      "hazards": []
    },
    "you": {
      "id": "you",
      "name": "You",
      "health": 80,
      "body": [{"x": 1, "y": 1}, {"x": 1, "y": 2}, {"x": 1, "y": 3}, {"x": 1, "y": 4}],
      "head": {"x": 1, "y": 1},
      "length": 4
    }
  }'
```

**Check Logs For**:
- `competitive_length` heuristic score should be **150.0** (not 0.0)
- This indicates the bug: snake seeks food despite being 1 longer

**Expected After Fix**: Score should be 0.0 when 1 longer.

---

### Step 4: Test Tie-Breaking Determinism

Run two identical snakes against each other:

```bash
# Deploy snake twice with different IDs
# Test in Battlesnake arena or local engine

# Check logs for:
# - Different tie_breaker values for each snake
# - Different move choices in symmetric positions
```

**Expected**: Snakes make different moves when board is symmetric.

---

### Step 5: Performance Benchmarking

Test response times with Voronoi optimization:

```bash
# Run game with 4 snakes on 11x11 board
# Monitor logs for:

grep "Minimax complete" logs.txt | grep "duration_ms"
grep "Move request complete" logs.txt | grep "duration_ms"
```

**Expected Performance**:
- Minimax duration: < 100ms for depth 5-7
- Total request duration: < 200ms
- Voronoi calculation: < 5ms (not explicitly logged, but part of minimax)

---

### Step 6: Integration Test - Full Game

Run a complete game locally:

```bash
# Using Battlesnake CLI
battlesnake play --name "GleamSnake" --url http://localhost:8080 --width 11 --height 11

# Watch for:
# 1. No crashes or timeouts
# 2. Voronoi scores appearing in heuristic breakdown
# 3. Competitive length kicking in when appropriate
# 4. Tie-breaking preventing repetitive moves
```

**Success Criteria**:
- Snake survives to late game
- No 500ms+ response times
- Logical move choices based on heuristic logs

---

## Recommended Fixes

### Fix 1: Competitive Length Logic

**File**: [src/heuristics.gleam](file:///Users/dave/git/gleam-snake/src/heuristics.gleam#L384-L406)

**Change**:
```gleam
case length_diff {
  diff if diff >= 2 -> 0.0  // 2+ longer, no need for food
  diff if diff == 1 -> 0.0  // 1 longer, slight advantage is enough
  diff if diff == 0 -> {    // Tied, moderate priority
    // ... use weight_competitive_length (150.0)
  }
  _ -> {                    // Shorter, critical priority
    // ... use weight_competitive_length_critical (250.0)
  }
}
```

### Fix 2: Enhance String Hash

**File**: [src/minimax.gleam](file:///Users/dave/git/gleam-snake/src/minimax.gleam#L76-L108)

**Add fallback** for unhandled characters:
```gleam
let char_val = case string.pop_grapheme(char) {
  Ok(#(c, _)) -> case c {
    // ... existing cases ...
    _ -> {
      // Fallback: use Unicode code point modulo
      string.to_utf_codepoints(c)
      |> list.first
      |> result.unwrap(string.utf_codepoint(0))
      |> string.utf_codepoint_to_int
      |> fn(code) { code % 26 }
    }
  }
  Error(_) -> 0
}
```

### Fix 3: Add Voronoi Collision Check (Optional)

**File**: [src/pathfinding.gleam](file:///Users/dave/git/gleam-snake/src/pathfinding.gleam#L111-L130)

**Consider**: Add basic collision check, but may slow down calculation:
```gleam
pub fn voronoi_territory_fast(
  start: Coord,
  opponent_heads: List(Coord),
  board: Board,
  snakes: List(Snake),  // Add parameter
) -> Int {
  let sample_tiles = get_strategic_sample_tiles(board)
  
  list.fold(sample_tiles, 0, fn(acc, tile) {
    // Only count if tile is not occupied
    case is_valid_tile(tile, board, snakes) {
      False -> acc
      True -> {
        let our_distance = manhattan_distance(start, tile)
        let we_are_closest = list.all(opponent_heads, fn(opp_head) {
          manhattan_distance(opp_head, tile) > our_distance
        })
        case we_are_closest {
          True -> acc + 1
          False -> acc
        }
      }
    }
  })
}
```

**Trade-off**: More accurate but slower (still should be < 10ms).

---

## Testing Checklist

- [ ] Clean build passes
- [ ] Coordinate bounds test passes
- [ ] Competitive length bug reproduced
- [ ] Competitive length fix applied and verified
- [ ] Tie-breaking shows variation between identical snakes
- [ ] Response times under 200ms
- [ ] Full game completes without crashes
- [ ] Heuristic scores appear logical in logs

---

## Notes

- Monitor `[INFO] Heuristic breakdown` logs to see individual heuristic contributions
- Use `turn`, `move`, and `score` fields to track decision quality
- Compare pre-fix and post-fix behavior in identical game states
