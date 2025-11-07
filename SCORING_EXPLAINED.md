# Scoring System Explained

## HIGH SCORE = GOOD MOVE ✓

The snake **maximizes** score - higher is better!

```
+500.0  → Excellent move
+100.0  → Good move
   0.0  → Neutral
-100.0  → Bad move
-1000.0 → Terrible move (death)
```

## Why Depth Matters

Your debug logs now show **TWO** sets of scores:

### 1. **Depth 0 Evaluation** (Immediate)
What happens if we make this move RIGHT NOW?

```
=== DEPTH 0 EVALUATION ===
[DEBUG] move=right, early_game_food:250.0, total:250.0
[DEBUG] move=left, flood_fill:60.0, total:60.0
```

### 2. **Minimax Evaluation** (Lookahead)
What happens if we make this move and play out the next 5-9 turns optimally?

```
=== MINIMAX EVALUATION ===
[INFO] Minimax score | move=right, score=-100.0  ← After lookahead, bad!
[INFO] Minimax score | move=left, score=300.0    ← After lookahead, good!
```

### Example: Why Scores Differ

**Turn 5:**
```
Depth 0 (immediate):
  right (toward food): +250.0  ← Good now!
  left: +60.0

Minimax depth 7 (7 turns ahead):
  right: -100.0  ← Leads to trap in 3 moves!
  left: +300.0   ← Opens up space for later

Final choice: LEFT (300.0 > -100.0)
```

**Why?** Minimax sees that going right for food now traps us in a corner after 3 moves, causing death. Going left gives us more space long-term.

## Common Confusions

### "The lowest score was chosen!"

**Most likely:** You're comparing depth-0 scores with the final choice.

```
WRONG comparison:
  Depth 0: right=250, left=60
  Chosen: left
  "Why did it choose lower score (60)?"

CORRECT comparison:
  Minimax: right=-100, left=300
  Chosen: left
  "Chose higher minimax score (300) ✓"
```

### "Food scored 250 but snake went other way"

**Check minimax scores:**
```
=== DEPTH 0 ===
right (food): +250.0

=== MINIMAX ===  
right (food): -400.0  ← Depth-7 sees collision/trap

Snake chose: different move with higher MINIMAX score
```

## Reading the New Debug Logs

**Full example output:**
```
Turn 10:

=== DEPTH 0 EVALUATION ===
[DEBUG] move=up, scores=early_game_food:125.0, flood_fill:60.0, total:185.0
[DEBUG] move=down, scores=early_game_food:250.0, total:250.0
[DEBUG] move=left, scores=flood_fill:80.0, total:80.0
[DEBUG] move=right, scores=flood_fill:50.0, total:50.0

=== MINIMAX EVALUATION === depth=7
[INFO] Minimax score | move=up, score=150.0
[INFO] Minimax score | move=down, score=-200.0   ← Food leads to trap!
[INFO] Minimax score | move=left, score=400.0    ← Best long-term!
[INFO] Minimax score | move=right, score=100.0

=== FINAL DECISION ===
chosen_move=left, chosen_score=400.0
```

**Analysis:**
- Depth 0: `down` scored highest (250.0) - food is attractive now
- Minimax: `left` scored highest (400.0) - better 7 turns from now
- **Snake chose `left`** because it has the highest MINIMAX score ✓

## Debugging Checklist

When you see unexpected moves:

1. ✅ **Check minimax scores** (not depth-0)
   - Look for `[INFO] Minimax score | move=X`
   - The highest minimax score wins

2. ✅ **Verify HIGH score chosen**
   - Compare all minimax scores
   - Confirm chosen move has highest value

3. ✅ **Understand depth-0 vs minimax difference**
   - Depth-0 = immediate reward/penalty
   - Minimax = long-term best play
   - They can disagree!

4. ❌ **Don't compare depth-0 to final choice**
   - This is meaningless
   - Only compare minimax scores

## If Lowest Minimax Score Is Chosen

**This would be a BUG!** Report with:
```
Turn: X
Minimax scores logged:
  up: 100.0
  down: 200.0
  left: -50.0
Chosen: left (-50.0)  ← BUG if this happens!
```

The code at [minimax.gleam:69](file:///Users/dave/git/gleam-snake/src/minimax.gleam#L69) sorts by **descending** order:
```gleam
float.compare(score_b, with: score_a)  // Higher first
```

If lowest is chosen, there's a bug in the sorting logic.

## Performance Note

⚠️ **Current debug logging runs minimax TWICE:**
1. Once in `minimax.choose_move()` (the real decision)
2. Once more for logging (to show you the scores)

This doubles the computation! Only use during debugging.

**To disable:** Comment out the "DEBUG: Log final minimax scores" block in snake_app.gleam.
