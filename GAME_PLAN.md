# Battlesnake AI Game Plan: Gleam Snake

This document outlines the detailed architectural plan, strategic intentions, and specific heuristics for the Gleam-based Battlesnake AI. It serves as a living document for development, review, and future enhancements.

## 1. Overall Intentions

Our primary goal is to develop a sophisticated Battlesnake AI that leverages Gleam's strengths for a robust and maintainable codebase. The core strategy revolves around proactive decision-making through game tree search, balanced with intelligent heuristic evaluation to adapt to diverse game states. We aim for a snake that is both safe and aggressively opportunistic.

## 2. App Architecture

The Battlesnake AI will follow a modular architecture, making it easy to understand, test, and modify.

-   **`snake_app.gleam`**: Entry point for the application, handling HTTP requests and delegating to the AI logic.
-   **`api.gleam`**: Defines the types for incoming Battlesnake API requests and outgoing responses. Handles JSON encoding/decoding.
-   **`game_state.gleam`**: Contains data structures and functions representing heuristics and algorithsm for game play. Includes utility functions for manipulating the game state (e.g., `move_snake`, `is_coord_safe`).
-   **`minimax.gleam`**: Implements the Minimax algorithm with alpha-beta pruning. This module will be responsible for recursively evaluating game states. Does not exist yet.
    -   `minimax(game_state, depth, is_maximizing_player, alpha, beta)`: The core recursive function.
    -   `choose_move(game_state, depth)`: The public interface for selecting the best move.
-   **`heuristics.gleam`**: Contains individual heuristic functions, each responsible for calculating a specific score component for a given game state.
    -   `evaluate_board(game_state, config)`: Aggregates scores from all active heuristics.
    -   `heuristic_config.gleam`: A configuration module (likely a record) to enable/disable heuristics and adjust their weights.
-   **`pathfinding.gleam`**: Contains algorithms like Breadth-First Search (BFS) or Flood Fill, primarily used by heuristics to assess reachable areas and safety.
-   **`logging.gleam`**: A dedicated module for structured logging of AI decisions, scores, and game state details.

## 3. Desired Game Strategy

The AI will employ a Minimax algorithm with alpha-beta pruning to evaluate possible moves to a depth of 7 (configurable). It will consider all our possible safe moves and our opponents' most likely (optimal, i.e., worst for us) responses. The chosen move will be the one that maximizes our long-term score based on the heuristics.

### Minimax Considerations:

-   **Depth:** Start with a depth of 7. This value will be easy to change.
-   **Opponent Modeling:** Assume opponents play optimally to minimize our score (Option A). This means for each of our possible moves, the Minimax will assume the opponent will make the move that is worst for us, and we will choose the move that leads to the least worst outcome.
-   **Move Generation:** Only generate *safe* moves for both our snake and opponents (i.e., not into walls, self, or other snake bodies).

## 4. Heuristics

The following heuristics will be implemented in `heuristics.gleam` and will be highly configurable via `heuristic_config.gleam`. Each heuristic will return a score, and `evaluate_board` will sum these scores with their respective weights.

### A. Basic Safety Heuristics

-   **Stay on Board (`safety_boundary_score`)**:
    -   **Score:** Large negative penalty (-1000) if a move leads off the board.
-   **Avoid Self-Collision (`safety_self_collision_score`)**:
    -   **Score:** Large negative penalty (-1000) if a move leads into our own body.
-   **Avoid Head-on Collisions (`safety_head_collision_score`)**:
    -   **Score:** Large negative penalty (-800) if a move leads into another snake's head, and that snake is *equal to or longer* than us.
    -   **Score:** Small positive bonus (+50) if a move leads into another snake's head, and *we are strictly longer*.

### B. Flood Fill & Space Control Heuristics

-   **Flood Fill Safety (`flood_fill_score`)**:
    -   **Mechanism:** Perform a flood fill (e.g., BFS) from the potential head position after a move to count the number of accessible safe tiles.
    -   **Score:** Directly proportional to the number of accessible tiles. (e.g., `count * weight`). This inherently addresses "am I moving into a dead end, or being boxed in / chased?".
    -   **Intention:** Reward moves that maximize our controllable safe area. This also covers the "Grow Strategically: Focus on Space Control" intention.

### C. Aggression & Positional Heuristics

-   **Avoid Adjacent Opponent Heads (`avoid_adjacent_heads_score`)**:
    -   **Score:** Negative penalty (-150) if a move places our head adjacent to an opponent's head, *unless* we are strictly longer than that opponent.
    -   **Score:** Small positive bonus (+20) if we are strictly longer and the move places our head adjacent to an opponent's head (encouraging aggressive encirclement).
-   **Center Control (`center_control_score`)**:
    -   **Mechanism:** Define a "center" region of the board (e.g., a square of `board_width/2 - 2` to `board_width/2 + 2` for both X and Y).
    -   **Score:** Positive bonus (+100) if our head is in a center square, especially in the early game (e.g., `game_state.turn < 50` and `number_of_opponents_alive > 1`).
    -   **Score:** Small penalty (-20) for being near walls, *unless* this leads to a higher flood fill score.

### D. Food & Health Management Heuristics

-   **Health-Driven Food Seeking (`food_health_score`)**:
    -   **Score:** Significant positive bonus (+300) for moving towards the closest safe food if `our_snake.health < 35`.
    -   **Score:** Neutral (0) if `our_snake.health >= 35`.
-   **Food Safety Evaluation (`food_safety_score`)**:
    -   **Mechanism:** Before assigning a bonus for food, evaluate the safety of the tile *after* eating the food. This can be done by simulating the `game_state` after eating and applying the `flood_fill_score` heuristic to that new state.
    -   **Score:** Penalize (e.g., -50) moving towards food if the resulting flood-fill score is significantly lower than the current flood-fill score, indicating a trapped position.

## 5. Configurability

All heuristics will be designed to be easily configurable:

-   **Weights:** Each heuristic will have an associated weight that can be adjusted in `heuristic_config.gleam` (e.g., `let flood_fill_weight = 1.0`).
-   **On/Off Switches:** A boolean flag for each heuristic to enable or disable it (e.g., `let enable_center_control = True`).

This allows for quick experimentation and tuning without altering the core logic.

## 6. Logging

Verbose logging will be crucial for debugging and analyzing game performance.

-   **Structured Logs:** Log messages in a structured format (e.g., key-value pairs or JSON-like strings).
-   **Move Decisions:** Log the `POST /move` request, the calculated scores for each potential move (up, down, left, right), the chosen move, and the reason for the choice (e.g., "Best move: Up, Score: 120, Flood Fill: 80, Health: 40").
-   **Heuristic Breakdown:** For critical game states, log the individual scores contributed by each heuristic for the top few moves.
-   **Game State Snapshots:** Potentially log snapshots of the `GameState` at specific turns or when critical decisions are made.

## 7. Future Enhancements / Considerations

-   **More Sophisticated Opponent Modeling:** While we start with Option A (optimal opponents), future enhancements could involve training a model or using more complex heuristics to predict opponent moves.
-   **Dynamic Depth Adjustment:** Adjust Minimax depth based on board complexity, number of living snakes, or remaining time.
-   **Aggression Modes:** Implement different "moods" for the snake (e.g., purely defensive, aggressively offensive) that dynamically adjust heuristic weights.
-   **Tail Chasing:** Explicitly implement logic to follow our own tail when needing to create space or secure food.
-   **Advanced Pathfinding:** Use A\* or Dijkstra's for more nuanced pathing, especially for food or escape routes.
-   **Machine Learning Integration:** Potentially use a reinforcement learning approach to learn optimal heuristic weights.

---

This plan provides a solid foundation for developing a competitive Battlesnake AI. We will proceed step-by-step, implementing and testing each component as we go.
