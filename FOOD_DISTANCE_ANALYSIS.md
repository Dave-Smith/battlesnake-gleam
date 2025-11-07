# Food Distance Factor Analysis

## Problem

With linear distance decay, food at distance 2 vs distance 3 didn't have enough score difference to consistently choose the closer food.

## Solution: Logarithmic Distance Factor

Changed from linear `1/(d+1)` to logarithmic `1/(0.5*d + 0.5)` decay.

### Formula Comparison

**Old (Linear):**
```gleam
distance_factor = 1.0 / (distance + 1.0)
```

**New (Logarithmic):**
```gleam
distance_factor = 1.0 / (0.5 * distance + 0.5)
```

### Score Comparison

With `weight_early_game_food = 250.0`:

| Distance | Old Factor | Old Score | New Factor | New Score | Improvement |
|----------|------------|-----------|------------|-----------|-------------|
| 1        | 0.500      | 125.0     | 1.000      | 250.0     | **+125.0** |
| 2        | 0.333      | 83.3      | 0.667      | 166.75    | **+83.45** |
| 3        | 0.250      | 62.5      | 0.500      | 125.0     | **+62.5** |
| 4        | 0.200      | 50.0      | 0.400      | 100.0     | **+50.0** |
| 5        | 0.167      | 41.75     | 0.333      | 83.3      | **+41.55** |
| 10       | 0.091      | 22.75     | 0.182      | 45.5      | **+22.75** |

### Key Improvements

**Distance 2 vs 3:**
- Old difference: 83.3 - 62.5 = **20.8 points**
- New difference: 166.75 - 125.0 = **41.75 points**
- **Improvement: 2x the differentiation!**

**Distance 1 vs 2:**
- Old difference: 125.0 - 83.3 = **41.7 points**
- New difference: 250.0 - 166.75 = **83.25 points**
- **Improvement: 2x the differentiation!**

## Impact on Strategy

### Before (Linear)

```
Turn 1: Food at (5,5) distance 2, Food at (7,7) distance 3
Scores:
  Move toward (5,5): early_game_food: 83.3
  Move toward (7,7): early_game_food: 62.5
  Difference: 20.8

Other heuristics (flood_fill, center_control, etc.) could easily override this small difference.
```

### After (Logarithmic)

```
Turn 1: Food at (5,5) distance 2, Food at (7,7) distance 3
Scores:
  Move toward (5,5): early_game_food: 166.75
  Move toward (7,7): early_game_food: 125.0
  Difference: 41.75

Much harder for other heuristics to override - snake strongly prefers closer food!
```

## Expected Behavior Changes

### 1. **Early Game (Turn < 50)**
- Snake will now **aggressively** move toward adjacent food (250 points!)
- Distance 1 food is **3x more valuable** than before (250 vs 125)
- Distance 2 food gets **2x the score** (167 vs 83)

### 2. **Food Health (Health < 35)**
With `weight_food_health = 300.0`:

| Distance | Old Score | New Score |
|----------|-----------|-----------|
| 1        | 150.0     | 300.0     |
| 2        | 100.0     | 200.0     |
| 3        | 75.0      | 150.0     |

- Snake will be **much more aggressive** about getting to nearby food when hungry
- Less likely to "wander around" when food is 1-2 tiles away

### 3. **Competitive Length**
With `weight_competitive_length_critical = 250.0`:

When behind in length:
- Distance 1 food: 125 → **250 points** (doubled!)
- Distance 2 food: 83 → **167 points** (doubled!)

## Testing Checklist

Run debug logs and verify:

### ✅ Test 1: Adjacent Food
```
Scenario: Snake at (5,5), Food at (6,5) - distance 1
Expected: early_game_food score = 250.0 (was 125.0)
```

### ✅ Test 2: Food 2 Tiles Away
```
Scenario: Snake at (5,5), Food at (7,5) - distance 2
Expected: early_game_food score = 166.75 (was 83.3)
```

### ✅ Test 3: Multiple Food Options
```
Scenario: 
  Snake at (5,5)
  Food A at (6,5) - distance 1
  Food B at (5,7) - distance 2

Expected scores:
  Move toward A: 250.0
  Move toward B: 166.75
  Difference: 83.25 (should clearly prefer A)
```

### ✅ Test 4: Food vs Safety
```
Scenario:
  Snake at (5,5)
  Food at (6,5) - distance 1
  Opponent at (7,5) - could collide at (6,5)

Expected:
  early_game_food: +250.0
  head_collision_danger: -700.0
  Total: -450.0 (still avoids collision)

Safety still wins! ✓
```

## Potential Issues

### 1. **Too Aggressive?**
If snake dies early by chasing food into dangerous positions:
- Reduce `weight_early_game_food` from 250 to 200
- Or reduce the steepness by changing formula to `1.0 / (0.6 * distance + 0.4)`

### 2. **Ignoring Distant Food Completely?**
Distance 10 food now scores 45.5 (was 22.75). If snake ignores available food:
- Consider capping minimum factor at 0.15 instead of letting it decay to ~0.08

### 3. **Starvation in Late Game?**
After turn 50, `early_game_food` turns off. Snake only seeks food when health < 35.
- Monitor health levels in turns 50-100
- May need to adjust `health_threshold` from 35 to 40-45

## Adjustment Formula

If you need to tune the aggressiveness:

**More aggressive (steeper decay):**
```gleam
1.0 / (0.4 * distance + 0.4)  // Distance 1: 1.0, Distance 2: 0.833, Distance 3: 0.625
```

**Less aggressive (gentler decay):**
```gleam
1.0 / (0.7 * distance + 0.3)  // Distance 1: 1.0, Distance 2: 0.625, Distance 3: 0.476
```

**Current (balanced):**
```gleam
1.0 / (0.5 * distance + 0.5)  // Distance 1: 1.0, Distance 2: 0.667, Distance 3: 0.5
```

## Files Changed

- [heuristics.gleam](file:///Users/dave/git/gleam-snake/src/heuristics.gleam#L26-L33): Added `food_distance_factor` helper
- Updated 4 functions to use new factor:
  - `early_game_food_score`
  - `food_health_score`
  - `competitive_length_score` (2 places)

---

**Status**: Ready for testing with debug logs enabled
**Expected Impact**: High - Snake should now strongly prefer closer food
**Risk**: Medium - May be too aggressive; monitor early game deaths
