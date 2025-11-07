# Head-to-Head Collision Bug

## Problem Description

**Current behavior**: `get_safe_moves` and heuristics only check opponent snakes' CURRENT positions, not where they might move NEXT turn.

**Result**: We can move into a tile that an opponent also moves into, causing a head-to-head collision that we lose (if they're same size or larger).

## Example Scenario

```
Turn N:
  Our head: (5, 5)
  Opponent head: (7, 5), length: 5
  
Our possible moves:
  Right: (6, 5)  ← We choose this
  
Opponent's possible moves:
  Left: (6, 5)   ← They choose this
  
Turn N+1:
  COLLISION at (6, 5)
  Both snakes die (or we die if they're longer/same size)
```

**Current code doesn't detect this** because:
1. `get_safe_moves` only checks if (6,5) is occupied by opponent's body NOW
2. `avoid_adjacent_heads_score` only checks if opponent's current head (7,5) is adjacent to our new position (6,5)

## Root Cause Analysis

### Issue 1: `avoid_adjacent_heads_score` checks wrong positions

[heuristics.gleam:207-234](file:///Users/dave/git/gleam-snake/src/heuristics.gleam#L207-L234)

```gleam
fn avoid_adjacent_heads_score(state: GameState, config: HeuristicConfig) -> Float {
  let our_head = state.you.head
  let adjacent_coords = [
    api.Coord(our_head.x + 1, our_head.y),
    api.Coord(our_head.x - 1, our_head.y),
    api.Coord(our_head.x, our_head.y + 1),
    api.Coord(our_head.x, our_head.y - 1),
  ]

  list.fold(opponent_snakes, 0.0, fn(acc, opponent) {
    case list.any(adjacent_coords, fn(coord) { coord == opponent.head }) {
      // ^^^ This checks if opponent.head is adjacent to OUR new position
      // But opponent.head is their CURRENT position, not where they WILL be
```

**Problem**: After simulation, `state.you.head` is our NEW position, but `opponent.head` is still their OLD position (simulation doesn't move opponents in `simulate_game_state`).

### Issue 2: `simulate_game_state` doesn't move opponents

[game_state.gleam:139-163](file:///Users/dave/git/gleam-snake/src/game_state.gleam#L139-L163)

```gleam
pub fn simulate_game_state(current_state: GameState, our_move: String) -> GameState {
  let our_snake = current_state.you
  let updated_our_snake = simulate_move(our_snake, our_move)

  let updated_other_snakes =
    list.map(current_state.board.snakes, fn(s) {
      case s.id == updated_our_snake.id {
        True -> updated_our_snake
        False -> api.Snake(..s, health: s.health - 1)  // ← Only decrements health!
      }
    })
```

**Problem**: Opponents stay in place. This is intentional for simplicity, but breaks head collision detection.

## Solutions

### Option A: Add "Danger Zone" Heuristic (Recommended)

Create a new heuristic that penalizes moving into tiles that opponents COULD move into.

**Advantages**:
- Doesn't require simulating opponent moves (expensive)
- Works with current minimax structure
- Can tune aggressiveness via weights

**Implementation**:
```gleam
/// Penalize moving into tiles that an opponent could also move into next turn
fn head_collision_danger_score(state: GameState, config: HeuristicConfig) -> Float {
  let our_head = state.you.head
  let our_length = state.you.length
  let opponent_snakes = 
    list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

  list.fold(opponent_snakes, 0.0, fn(acc, opponent) {
    // Get all tiles opponent COULD move to from their CURRENT position
    let opponent_possible_moves = [
      api.Coord(opponent.head.x + 1, opponent.head.y),
      api.Coord(opponent.head.x - 1, opponent.head.y),
      api.Coord(opponent.head.x, opponent.head.y + 1),
      api.Coord(opponent.head.x, opponent.head.y - 1),
    ]
    
    // Check if OUR new head position is in their danger zone
    case list.contains(opponent_possible_moves, our_head) {
      True -> {
        // Penalize based on length comparison
        case our_length > opponent.length {
          True -> acc +. config.weight_head_collision_danger_longer  // e.g., +20.0 (slight reward, we win)
          False -> acc +. config.weight_head_collision_danger_equal  // e.g., -500.0 (heavy penalty)
        }
      }
      False -> acc
    }
  })
}
```

**Config additions**:
```gleam
pub type HeuristicConfig {
  HeuristicConfig(
    // ... existing fields ...
    enable_head_collision_danger: Bool,
    weight_head_collision_danger_longer: Float,   // +20.0 or +50.0
    weight_head_collision_danger_equal: Float,    // -500.0
  )
}
```

### Option B: Fix `avoid_adjacent_heads_score`

**Problem with current logic**: It checks if opponent's current head is adjacent to us, but since `simulate_game_state` doesn't move opponents, this checks the wrong positions.

**Better approach**: Check if any opponent's possible next positions overlap with tiles adjacent to us.

```gleam
fn avoid_adjacent_heads_score(state: GameState, config: HeuristicConfig) -> Float {
  let our_head = state.you.head
  let our_length = state.you.length
  let opponent_snakes = 
    list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

  let our_adjacent_coords = [
    api.Coord(our_head.x + 1, our_head.y),
    api.Coord(our_head.x - 1, our_head.y),
    api.Coord(our_head.x, our_head.y + 1),
    api.Coord(our_head.x, our_head.y - 1),
  ]

  list.fold(opponent_snakes, 0.0, fn(acc, opponent) {
    // Get where opponent COULD move from their CURRENT position
    let opponent_possible_next = [
      api.Coord(opponent.head.x + 1, opponent.head.y),
      api.Coord(opponent.head.x - 1, opponent.head.y),
      api.Coord(opponent.head.x, opponent.head.y + 1),
      api.Coord(opponent.head.x, opponent.head.y - 1),
    ]
    
    // Check if any of opponent's possible moves are adjacent to us
    let has_overlap = list.any(opponent_possible_next, fn(opp_next) {
      list.contains(our_adjacent_coords, opp_next)
    })
    
    case has_overlap {
      True -> {
        case our_length > opponent.length {
          True -> acc +. config.weight_avoid_adjacent_heads_longer
          False -> acc +. config.weight_avoid_adjacent_heads
        }
      }
      False -> acc
    }
  })
}
```

**Problem with this approach**: Still doesn't catch the SAME TILE collision (both moving to (6,5)).

### Option C: Hybrid Approach (Best)

Combine both:
1. Keep `avoid_adjacent_heads_score` for general "stay away from opponent heads" strategy
2. Add `head_collision_danger_score` specifically for same-tile collisions

This gives two layers of protection:
- Layer 1: Don't move adjacent to where opponents could be
- Layer 2: Don't move into a tile an opponent could also move into

## Recommended Implementation

**Step 1**: Add the new heuristic
```gleam
// In heuristics.gleam after avoid_adjacent_heads_score

/// D. Head Collision Danger - heavily penalize moving into tiles opponents could also move into
fn head_collision_danger_score(state: GameState, config: HeuristicConfig) -> Float {
  let our_head = state.you.head
  let our_length = state.you.length
  let opponent_snakes = 
    list.filter(state.board.snakes, fn(s) { s.id != state.you.id })

  list.fold(opponent_snakes, 0.0, fn(acc, opponent) {
    let opponent_possible_moves = [
      api.Coord(opponent.head.x + 1, opponent.head.y),
      api.Coord(opponent.head.x - 1, opponent.head.y),
      api.Coord(opponent.head.x, opponent.head.y + 1),
      api.Coord(opponent.head.x, opponent.head.y - 1),
    ]
    
    case list.contains(opponent_possible_moves, our_head) {
      True -> {
        case our_length > opponent.length {
          True -> acc +. config.weight_head_collision_danger_longer
          False -> acc +. config.weight_head_collision_danger_equal
        }
      }
      False -> acc
    }
  })
}
```

**Step 2**: Add to config
```gleam
// In heuristic_config.gleam
pub type HeuristicConfig {
  HeuristicConfig(
    // ... existing ...
    enable_head_collision_danger: Bool,
    weight_head_collision_danger_longer: Float,
    weight_head_collision_danger_equal: Float,
  )
}

pub fn default_config() -> HeuristicConfig {
  HeuristicConfig(
    // ... existing ...
    enable_head_collision_danger: True,
    weight_head_collision_danger_longer: 30.0,    // Small reward if we're longer
    weight_head_collision_danger_equal: -600.0,   // Heavy penalty if equal/shorter
  )
}
```

**Step 3**: Add to evaluate_board
```gleam
// In heuristics.gleam evaluate_board
let scores = [
  // ... existing heuristics ...
  #("head_collision_danger", case config.enable_head_collision_danger {
    True -> head_collision_danger_score(state, config)
    False -> 0.0
  }),
]
```

**Step 4**: Add to evaluate_board_detailed (for logging)

## Testing

Create a test case:
```gleam
// Two snakes of equal length heading toward each other
// Should penalize the collision move heavily
pub fn head_collision_test() {
  let state = GameState(
    you: Snake(head: Coord(5, 5), length: 5, ...),
    board: Board(
      snakes: [
        Snake(head: Coord(5, 5), length: 5, ...),  // Us
        Snake(head: Coord(7, 5), length: 5, ...),  // Opponent
      ],
      ...
    ),
    ...
  )
  
  // Simulate moving right: our new head = (6, 5)
  let new_state = simulate_game_state(state, "right")
  
  // Opponent's possible moves from (7, 5):
  // Left: (6, 5) ← COLLISION
  
  let score = head_collision_danger_score(new_state, default_config())
  
  // Should be -600.0 (heavy penalty)
  should.equal(score, -600.0)
}
```

## Priority

**HIGH** - This is a game-losing bug that causes unnecessary deaths in head-to-head scenarios.

---

**Estimated effort**: 30 minutes to implement Option C (hybrid approach)
