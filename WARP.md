# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Project: Gleam Battlesnake AI (Erlang/BEAM target)

What you’ll likely need first
- Build: `gleam build`
- Format (lint-equivalent):
  - Write: `gleam format`
  - Check (CI-friendly): `gleam format --check`
- Test (all): `gleam test`
  - Note: gleeunit does not currently provide a built-in single-test filter. Common practice is to temporarily isolate the test (e.g., comment out others or move focused checks into a separate test module) and run `gleam test`.
- Run locally (HTTP server on 8080):
  - `gleam run` (starts the Mist web server defined in `src/snake_app.gleam`)
- Exercise the API locally:
  - Index: `curl http://localhost:8080/`
  - Start: `curl -X POST http://localhost:8080/start -d '{}' -H 'Content-Type: application/json'`
  - Move (example payload from VALIDATION_PLAN): see `VALIDATION_PLAN.md` “Step 3” for a full JSON body; quick smoke:
    `curl -X POST http://localhost:8080/move -H 'Content-Type: application/json' -d '{"game":{"id":"test"},"turn":0,"board":{"width":11,"height":11,"food":[],"snakes":[],"hazards":[]},"you":{"id":"you","name":"You","health":90,"body":[{"x":1,"y":1}],"head":{"x":1,"y":1},"length":1}}'`
- Play locally with the Battlesnake CLI (see `notes.md`):
  - Install once: `go install github.com/BattlesnakeOfficial/rules/cli/battlesnake@latest`
  - Run a local game against itself with a map view:
    `battlesnake play -W 11 -H 11 --name 'dave1' --url http://localhost:8080 --name 'dave2' --url http://localhost:8080 --viewmap`

High-level architecture
- HTTP server and request flow (`src/snake_app.gleam`)
  - Uses Mist to expose the Battlesnake API:
    - GET `/` returns static snake metadata (color, head, tail, etc.).
    - POST `/start` logs game start.
    - POST `/move` computes a move and returns `{ move, shout }`.
    - POST `/end` logs game end.
  - Parses request bodies with `parse_game_state` and JSON decoders from `api.gleam`.
  - Computes search depth dynamically (`calculate_dynamic_depth`) based on snakes alive and board density:
    - 1 snake: depth 10; 2 snakes: depth 8; crowded boards (>40%): depth 5; otherwise depth 6.
  - Per-move pipeline: read request → build adaptive heuristic config → find safe moves → run Minimax → log timing and decision → respond.

- Core domain types and codecs (`src/api.gleam`)
  - Defines `Coord`, `Snake`, `Board`, `Game`, `GameState`, and API response types, with explicit JSON encoders/decoders (via `gleam/json` + `gleam/dynamic/decode`).
  - Centralizes all wire formats used by the HTTP layer and the AI.

- Game mechanics helpers (`src/game_state.gleam`)
  - Spatial helpers: bounds checks, body/head occupancy checks, Manhattan distance.
  - Move generation: `get_safe_moves` filters moves using bounds + body occupancy next turn.
  - Lightweight simulation: `simulate_move` and `simulate_game_state` update snake/body/health to advance the state for tree search.

- Search algorithm (`src/minimax.gleam`)
  - Minimax with alpha-beta pruning: `minimax`, `maximize_score`, `minimize_score`.
  - Entry point `choose_move` evaluates each safe move by simulating the next state and scoring subtrees.
  - Deterministic tie-breaking prevents identical snakes from mirroring: `string_hash` + per-move bias via `get_move_bias` (bias order up/down/left/right with a tiny per-turn/per-id addition).
  - Emits timing and evaluation metrics to logs.

- Heuristic evaluation system
  - Configuration (`src/heuristic_config.gleam`): toggles and weights for all heuristics, with `default_config`, and curated variants `aggressive_config` and `defensive_config`.
  - Adaptive configuration (`src/adaptive_config.gleam`): derives a config each turn using `heuristics.detect_food_competition` to switch off territory control and prioritize growth when food competition is detected.
  - Scoring (`src/heuristics.gleam`):
    - Safety: boundary, self-collision, head-to-head (length-aware).
    - Space: flood-fill tile count.
    - Positioning: center control vs wall penalty (early game emphasis).
    - Food: seek when below threshold and penalize “unsafe food” that reduces reachable space.
    - Tail chasing: when healthy and space-constrained.
    - Territory: optimized Voronoi-style control using distance sampling.
    - Competitive length: proactively seek food when tied/behind to maintain head-to-head advantage.
    - `evaluate_board` and `evaluate_board_detailed` aggregate these into a total score.

- Pathfinding & spatial analysis (`src/pathfinding.gleam`)
  - `flood_fill` to count reachable tiles (excludes next-turn tails for realism via `is_occupied_by_snake_without_tail`).
  - `bfs_distance` for shortest path estimates when needed.
  - `voronoi_territory_fast` computes sampled territorial control using Manhattan distance and a strategic tile sampler (`get_strategic_sample_tiles`) for speed.

- Structured logging (`src/log.gleam`)
  - Levelled logs with simple field lists; includes helpers for timing, move decisions, and heuristic breakdowns.

What’s in the docs here
- `README.md`
  - Strategy: Minimax (+ alpha-beta) guided by configurable heuristics; dynamic depth; tie-breaking; space/food/position control; performance constraints (sub-500ms per move) and optimizations (sampling, Manhattan distance, minimal logging).
  - Endpoints and expected behavior are spelled out; Matches the server in `snake_app.gleam`.
  - Deployment notes for Fly.io (CLI usage: `fly launch`, `fly deploy`).
- `HEURISTICS.md`
  - Authoritative reference for all heuristics, weights, and tuning guidelines. Includes default/aggressive/defensive/adaptive configs and performance notes.
- `VALIDATION_PLAN.md`
  - Concrete validation steps and performance targets. Includes a ready-to-use `/move` payload and local game/testing recipes.
- `notes.md`
  - Practical local testing commands for the Battlesnake CLI and observations about food-competitive opponents that inform the adaptive config.

Where to change things quickly
- Heuristic behavior/weights: edit `src/heuristic_config.gleam` and `src/heuristics.gleam`; adaptive behavior in `src/adaptive_config.gleam`.
- Depth selection: `calculate_dynamic_depth` in `src/snake_app.gleam`.
- Server/API behavior: handlers in `src/snake_app.gleam`; wire types/JSON in `src/api.gleam`.
- Spatial logic: `src/game_state.gleam` and `src/pathfinding.gleam`.
- Logs and timing: `src/log.gleam`.

Testing notes specific to this repo
- Tests are in `test/` and use gleeunit. Example module exists: `test/snake_app_test.gleam`.
- Add focused tests by creating additional `test/*.gleam` modules (see `VALIDATION_PLAN.md` for an example `pathfinding_test.gleam`).
- Run with `gleam test`.

CI/CD and deployment
- No CI config present in this repo; use `gleam format --check`, `gleam build`, and `gleam test` as basic steps.
- Deployment: Fly.io as per `README.md` (generate `fly.toml` via `fly launch`, then `fly deploy`).
