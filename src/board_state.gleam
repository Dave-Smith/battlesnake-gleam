/// Functions for checking the validity of tiles on the game board.
import api.{type Board, type Coord, type Snake}
import gleam/deque
import gleam/list
import gleam/set

pub fn is_valid_tile(coord: Coord, board: Board, snakes: List(Snake)) -> Bool {
  coord.x >= 0
  && coord.y >= 0
  && coord.x < board.width
  && coord.y < board.height
  && !is_occupied_by_snake(coord, snakes)
}

fn is_occupied_by_snake(coord: Coord, snakes: List(Snake)) -> Bool {
  is_occupied_by_snake_without_tail(coord, snakes)
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

/// Checks if a coordinate is occupied by any snake's body excluding the last tail segment.
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
