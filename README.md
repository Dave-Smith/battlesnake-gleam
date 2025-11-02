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