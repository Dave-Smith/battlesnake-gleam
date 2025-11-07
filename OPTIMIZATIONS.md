# Performance Optimizations Applied

## List Sort Elimination (O(n log n) → O(n))

### Summary
Replaced all `list.sort` operations used for finding nearest food with O(n) linear scans. This eliminates unnecessary sorting overhead when we only need the minimum distance value.

### Changes Made

#### 1. Added Helper Functions ([heuristics.gleam:14-66](file:///Users/dave/git/gleam-snake/src/heuristics.gleam#L14-L66))

**`find_nearest_food/2`** - O(n) minimum distance finder
- Input: `from: Coord`, `food: List(Coord)`
- Returns: `Int` (distance to nearest food, or 999 if none)
- Algorithm: Single fold over food list tracking minimum distance
- Replaces: O(n log n) sort followed by taking first element

**`find_nearest_safe_food/5`** - O(n) best food finder with safety consideration
- Input: `from: Coord`, `food: List(Coord)`, `current_space: Int`, `board: Board`, `snakes: List(Snake)`
- Returns: `#(Int, Int)` (distance and space_after for best food)
- Algorithm: Map all food to #(distance, space_after), then fold to find minimum by distance (with space as tiebreaker)
- Note: Still calls flood_fill per food item, but eliminates O(n log n) sort

#### 2. Optimized Functions

**food_health_score** ([heuristics.gleam:311-326](file:///Users/dave/git/gleam-snake/src/heuristics.gleam#L311-L326))
- Before: Sorted entire food list by distance
- After: Single pass with `find_nearest_food`
- Savings: O(n log n) → O(n)

**food_safety_score** ([heuristics.gleam:353-399](file:///Users/dave/git/gleam-snake/src/heuristics.gleam#L353-L399))
- Before: Mapped food to #(coord, distance), then sorted
- After: Single fold tracking #(Option(Coord), min_distance)
- Savings: O(n log n) → O(n)

**competitive_length_score** ([heuristics.gleam:520-545](file:///Users/dave/git/gleam-snake/src/heuristics.gleam#L520-L545))
- Before: Sorted food list twice (once for tied case, once for behind case)
- After: Two calls to `find_nearest_food`
- Savings: 2 × O(n log n) → 2 × O(n)

### Performance Impact

**Per Heuristic Evaluation:**
- Typical board: 5-15 food items
- Old: 3-4 sorts × O(n log n) = ~3-4 × 15 log 15 ≈ 180 operations
- New: 3-4 scans × O(n) = ~3-4 × 15 ≈ 60 operations
- **~3x faster** for food lookups

**Per Minimax Search:**
- At depth 7 with 3 moves: ~2,000 node evaluations
- Old: 2,000 × 180 = 360,000 operations
- New: 2,000 × 60 = 120,000 operations
- **~3x reduction** in food-related operations

**Total Request Impact:**
- Estimated savings: 5-15ms per move request
- Greater impact at deeper search depths
- Reduces GC pressure from temporary sorted lists

### Code Quality Improvements

1. **Eliminated Duplicate Code**: Removed identical sorting logic repeated across multiple functions
2. **Clearer Intent**: `find_nearest_food` explicitly states what we're doing
3. **Type Safety**: Helper functions provide compile-time guarantees
4. **Maintainability**: Single place to optimize nearest-food logic

### Verification Steps

```bash
# Verify no more list.sort in heuristics
grep "list\.sort" src/heuristics.gleam
# Should return: (nothing)

# Build to confirm no regressions
gleam build

# Run game and check logs for timing improvements
# Look for reduced "duration_ms" in minimax logs
```

### Future Optimization Opportunities

1. **Precompute Nearest Food Once**: Cache nearest food at start of evaluate_board
2. **Distance Matrix**: For small boards, precompute all pairwise distances
3. **Spatial Indexing**: Use grid-based bucketing for O(1) nearest neighbor lookup

---

## Combined with Other Optimizations

This optimization works best when combined with:
- **Flood Fill Optimization**: Fix O(n²) queue operations (see VALIDATION_PLAN.md)
- **Depth Reduction**: Lower minimax depth in high-density games
- **Logging Reduction**: Disable debug logs and duplicate heuristic computation

Expected total impact: **50-100ms savings** on depth 7+ searches with these optimizations combined.
