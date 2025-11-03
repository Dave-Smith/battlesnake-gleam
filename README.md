# Gleam Snake - Battlesnake AI

This repository contains the Gleam-based Battlesnake AI developed for the office tournament. The goal is to create a robust and strategic snake using the functional programming paradigms of Gleam, deployed on Fly.io.

## Strategy Overview

The snake's intelligence is powered by a **Minimax algorithm with alpha-beta pruning**. It evaluates potential moves by considering its own best interests and anticipating opponent's most optimal (worst-case for us) responses. A detailed set of configurable **heuristics** are used to score board states, guiding the Minimax search towards advantageous positions.

Key strategic elements include:
- **Basic Safety:** Prioritizing survival by avoiding walls, self-collision, and dangerous head-to-head encounters.
- **Space Control:** Utilizing flood-fill to assess and maximize available safe territory, avoiding being trapped.
- **Aggression/Defense:** Smartly engaging or avoiding opponents based on length and board position.
- **Food Management:** Eating only when necessary and evaluating the safety of food locations.
- **Board Positioning:** Attempting to control the center of the board, especially in the early game.
- **Dynamic Depth Adjustment:** Intelligently adjusting Minimax search depth based on game state:
  - Depth 10 for solo survival (1 snake remaining)
  - Depth 9 for endgame battles (2 snakes)
  - Depth 5 for crowded boards (>40% density)
  - Depth 7 for normal play (default)
- **Tail Chasing:** Following our own tail when healthy (health >50) and space is limited (<30 accessible tiles) to create escape routes and prevent being boxed in.
- **Food Safety Evaluation:** Before pursuing food, evaluates the safety of eating it by checking if the resulting position would trap us (flood fill drops significantly).
- **Voronoi Space Control:** Calculates territorial control using an optimized algorithm:
  - Uses Manhattan distance instead of expensive BFS pathfinding
  - Samples ~25 strategic tiles (center region + grid pattern) instead of checking all board tiles
  - O(sample_size × N) complexity for sub-5ms performance
  - Maximizes controlled space especially in 1v1 endgames
  - 5000x+ faster than naive implementation to stay within 500ms response timeout
- **Deterministic Tie-Breaking:** Prevents identical snakes from always drawing:
  - Hashes snake ID to create unique but consistent per-snake preferences
  - Adds turn-based variation to break repetitive patterns
  - Tiny bias (0.001-0.1) only affects moves with equal scores
  - Ensures different snakes make different choices in symmetric positions

## Performance Optimization

To maintain sub-500ms response times:
- **Minimal Logging:** Only summary logs per move (not per node evaluation)
- **Non-blocking IO:** Logging uses INFO level only, avoiding thousands of blocking writes
- **Optimized Algorithms:** Manhattan distance, strategic sampling, and alpha-beta pruning

## Tech Stack

- **Language:** Gleam
- **Hosting:** Fly.io

## Development Plan & Heuristics

A comprehensive `GAME_PLAN.md` file details the architecture, specific heuristic definitions, and the approach for future enhancements.

## Getting Started

### Prerequisites

- Gleam (https://gleam.run/news/a-new-way-to-install-gleam/)
- Mix (if targeting Erlang/BEAM) or Node.js/Bun (if targeting JavaScript)
- Fly.io CLI (for deployment)

### Local Development

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/gleam-snake.git
    cd gleam-snake
    ```
2.  **Install dependencies:**
    ```bash
    gleam build
    ```
3.  **Run the application (local server for Battlesnake API):**
    ```bash
    gleam run --module snake_app/main # Or your main module name
    ```
    (Note: This command will need to be adapted once the HTTP server is implemented.)

4.  **Test the Battlesnake locally:**
    You can use a local Battlesnake engine (e.g., `battlesnake play`) or tools like `ngrok` to expose your local server to the Battlesnake game environment for testing.

### Deployment to Fly.io

1.  **Install Fly.io CLI:**
    ```bash
    curl -L https://fly.io/install.sh | sh
    ```
2.  **Log in to Fly.io:**
    ```bash
    fly auth login
    ```
3.  **Create a new Fly.io app (if you haven't already):**
    ```bash
    fly launch
    ```
    Follow the prompts. This will generate a `fly.toml` file.
4.  **Deploy your snake:**
    ```bash
    fly deploy
    ```

## API Endpoints

-   `GET /`: Basic information about the snake (color, head, tail, etc.)
-   `POST /start`: Called at the start of a game.
-   `POST /move`: Called each turn to determine the snake's next move.
-   `POST /end`: Called at the end of a game.

## Contributing

Feel free to open issues or submit pull requests.

---

**Happy Snaking!**