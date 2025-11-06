//// Game State Utility Functions

import api.{type Board, type Coord, type GameState, type Snake}
import gleam/deque
import gleam/int
import gleam/list
import gleam/set

/// Calculates the Manhattan distance between two coordinates.
pub fn manhattan_distance(a: Coord, b: Coord) -> Int {
  int.absolute_value(a.x - b.x) + int.absolute_value(a.y - b.y)
}

/// Checks if a coordinate is within the bounds of the game board.
pub fn is_within_bounds(coord: Coord, board: Board) -> Bool {
  coord.x >= 0
  && coord.y >= 0
  && coord.x < board.width
  && coord.y < board.height
}

/// Checks if a coordinate is occupied by any snake's body (including its head and tail).
pub fn is_occupied_by_snake_body(coord: Coord, snakes: List(Snake)) -> Bool {
  list.any(snakes, fn(s) {
    set.contains(s.body_coord, coord)
    //list.any(s.body, fn(body_coord) { body_coord == coord })
  })
}

/// Checks if a coordinate is occupied by any snake's body, excluding its tail if it's about to move.
/// This is important for pathfinding where a snake's tail will be free in the next turn if it moves.
pub fn is_occupied_by_snake_body_next_turn(
  coord: Coord,
  snakes: List(Snake),
) -> Bool {
  is_occupied_by_snake_without_tail(coord, snakes)
}

/// Checks if a coordinate is occupied by any snake's body excluding the tail.
pub fn is_occupied_by_snake_without_tail(
  coord: Coord,
  snakes: List(Snake),
) -> Bool {
  list.any(snakes, fn(s) {
    let body_without_tail = case deque.pop_front(s.body) {
      Ok(#(_, body_without_tail)) -> deque.to_list(body_without_tail)
      Error(_) -> []
    }
    list.any(body_without_tail, fn(body_coord) { body_coord == coord })
  })
}

/// Checks if a coordinate is occupied by an opponent's head.
pub fn is_occupied_by_opponent_head(
  coord: Coord,
  our_snake_id: String,
  snakes: List(Snake),
) -> Bool {
  list.any(snakes, fn(s) { s.id != our_snake_id && s.head == coord })
}

/// Generates a list of all theoretically possible next coordinates from a given coordinate.
/// (Up, Down, Left, Right)
pub fn get_possible_next_coords(from_coord: Coord) -> List(Coord) {
  [
    api.Coord(from_coord.x, from_coord.y + 1),
    api.Coord(from_coord.x, from_coord.y - 1),
    api.Coord(from_coord.x - 1, from_coord.y),
    api.Coord(from_coord.x + 1, from_coord.y),
  ]
}

/// Finds all safe moves (Up, Down, Left, Right) for a given snake in the current game state.
/// A move is safe if it doesn't immediately lead to:
/// - Off the board
/// - Our own body
/// - An opponent's body (considering tail freedom)
pub fn get_safe_moves(game_state: GameState) -> List(String) {
  let our_snake = game_state.you
  let board = game_state.board
  let head = our_snake.head

  let possible_moves = [
    #("up", api.Coord(head.x, head.y + 1)),
    #("down", api.Coord(head.x, head.y - 1)),
    #("left", api.Coord(head.x - 1, head.y)),
    #("right", api.Coord(head.x + 1, head.y)),
  ]

  list.fold(possible_moves, [], fn(acc, pair) {
    let #(name, coord) = pair
    case
      is_within_bounds(coord, board)
      && !is_occupied_by_snake_body_next_turn(coord, board.snakes)
    {
      True -> list.append(acc, [name])
      False -> acc
    }
  })
}

/// Chooses the best move from a list of safe moves by finding the move that gets closest to the nearest food.
pub fn choose_best_move(
  game_state: GameState,
  safe_moves: List(String),
) -> String {
  let head = game_state.you.head
  let food = game_state.board.food

  case food {
    [] ->
      case safe_moves {
        [first, ..] -> first
        [] -> "up"
      }
    _ -> {
      let nearest_food = case
        list.sort(food, fn(a, b) {
          int.compare(manhattan_distance(head, a), manhattan_distance(head, b))
        })
      {
        [nearest, ..] -> nearest
        [] -> head
      }

      let move_coords = [
        #("up", api.Coord(head.x, head.y + 1)),
        #("down", api.Coord(head.x, head.y - 1)),
        #("left", api.Coord(head.x - 1, head.y)),
        #("right", api.Coord(head.x + 1, head.y)),
      ]

      let safe_move_coords =
        list.filter(move_coords, fn(pair) {
          let #(name, _) = pair
          list.contains(safe_moves, name)
        })

      case
        list.sort(safe_move_coords, fn(a, b) {
          let #(_, coord_a) = a
          let #(_, coord_b) = b
          int.compare(
            manhattan_distance(coord_a, nearest_food),
            manhattan_distance(coord_b, nearest_food),
          )
        })
      {
        [#(best_move, _), ..] -> best_move
        [] ->
          case safe_moves {
            [first, ..] -> first
            [] -> "up"
          }
      }
    }
  }
}

/// Simulates a single move for a snake and returns the new snake state.
/// This will be used in the Minimax algorithm to build the game tree.
pub fn simulate_move(snake: Snake, move: String) -> Snake {
  let new_head = case move {
    "up" -> api.Coord(snake.head.x, snake.head.y + 1)
    "down" -> api.Coord(snake.head.x, snake.head.y - 1)
    "left" -> api.Coord(snake.head.x - 1, snake.head.y)
    "right" -> api.Coord(snake.head.x + 1, snake.head.y)
    _ -> snake.head
  }

  let res =
    deque.push_back(snake.body, new_head)
    |> deque.pop_front

  let new_snake = case res {
    Ok(#(_, new_body)) -> new_body
    Error(_) -> snake.body
  }

  let new_health = snake.health - 1

  api.Snake(..snake, head: new_head, body: new_snake, health: new_health)
}

/// Simulates a game state after a given snake makes a move.
/// Returns the updated GameState. This is a simplified version for our snake's move.
pub fn simulate_game_state(
  current_state: GameState,
  our_move: String,
) -> GameState {
  let our_snake = current_state.you
  let updated_our_snake = simulate_move(our_snake, our_move)

  let updated_other_snakes =
    list.map(current_state.board.snakes, fn(s) {
      case s.id == updated_our_snake.id {
        True -> updated_our_snake
        False -> api.Snake(..s, health: s.health - 1)
      }
    })

  let updated_board =
    api.Board(..current_state.board, snakes: updated_other_snakes)

  api.GameState(
    ..current_state,
    turn: current_state.turn + 1,
    board: updated_board,
    you: updated_our_snake,
  )
}
