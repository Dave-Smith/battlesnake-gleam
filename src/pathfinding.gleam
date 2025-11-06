//// Pathfinding Utility Functions

import api.{type Board, type Coord, type Snake}
import game_state
import gleam/deque
import gleam/list
import gleam/set.{type Set}

/// Performs a flood fill from a starting coordinate to count accessible safe tiles.
/// Returns the number of tiles reachable without hitting walls or snake bodies.
pub fn flood_fill(start: Coord, board: Board, snakes: List(Snake)) -> Int {
  flood_fill_helper(
    deque.from_list([start]),
    set.from_list([start]),
    board,
    snakes,
  )
}

fn flood_fill_helper(
  q: deque.Deque(Coord),
  visited: Set(Coord),
  board: Board,
  snakes: List(Snake),
) -> Int {
  case deque.pop_front(q) {
    Error(Nil) -> set.size(visited)
    Ok(#(current, rest)) -> {
      let neighbors = get_valid_neighbors(current, board, snakes, visited)
      let new_visited =
        list.fold(neighbors, visited, fn(acc, coord) { set.insert(acc, coord) })
      let new_queue =
        list.fold(neighbors, rest, fn(acc, item) { deque.push_back(acc, item) })
      flood_fill_helper(new_queue, new_visited, board, snakes)
    }
  }
}

fn get_valid_neighbors(
  coord: Coord,
  board: Board,
  snakes: List(Snake),
  visited: Set(Coord),
) -> List(Coord) {
  let possible = [
    api.Coord(coord.x, coord.y + 1),
    api.Coord(coord.x, coord.y - 1),
    api.Coord(coord.x - 1, coord.y),
    api.Coord(coord.x + 1, coord.y),
  ]

  list.filter(possible, fn(c) {
    is_valid_tile(c, board, snakes) && !set.contains(visited, c)
  })
}

fn is_valid_tile(coord: Coord, board: Board, snakes: List(Snake)) -> Bool {
  coord.x >= 0
  && coord.y >= 0
  && coord.x < board.width
  && coord.y < board.height
  && !is_occupied_by_snake(coord, snakes)
}

fn is_occupied_by_snake(coord: Coord, snakes: List(Snake)) -> Bool {
  game_state.is_occupied_by_snake_without_tail(coord, snakes)
}

/// Performs BFS to find the shortest path distance to a target.
/// Returns the distance in moves, or -1 if unreachable.
pub fn bfs_distance(
  start: Coord,
  target: Coord,
  board: Board,
  snakes: List(Snake),
) -> Int {
  bfs_helper(
    deque.from_list([#(start, 0)]),
    set.from_list([start]),
    target,
    board,
    snakes,
  )
}

fn bfs_helper(
  q: deque.Deque(#(Coord, Int)),
  visited: Set(Coord),
  target: Coord,
  board: Board,
  snakes: List(Snake),
) -> Int {
  case deque.pop_front(q) {
    Error(_) -> -1
    Ok(#(current, rest)) -> {
      let #(coord, distance) = current
      case coord == target {
        True -> distance
        False -> {
          let neighbors = get_valid_neighbors(coord, board, snakes, visited)
          let new_queue =
            list.fold(neighbors, rest, fn(acc, n) {
              deque.push_back(acc, #(n, distance + 1))
            })
          let new_visited =
            list.fold(neighbors, visited, fn(acc, coord) {
              set.insert(acc, coord)
            })
          bfs_helper(new_queue, new_visited, target, board, snakes)
        }
      }
    }
  }
}

/// Optimized Voronoi-like territory calculation using Manhattan distance.
/// Samples strategic tiles instead of checking every tile on the board.
/// Returns the count of sampled tiles we can reach before any opponent.
/// Complexity: O(sample_size × N) instead of O(W² × H² × N)
pub fn voronoi_territory_fast(
  start: Coord,
  opponent_heads: List(Coord),
  board: Board,
) -> Int {
  let sample_tiles = get_strategic_sample_tiles(board)

  list.fold(sample_tiles, 0, fn(acc, tile) {
    let our_distance = manhattan_distance(start, tile)

    let we_are_closest =
      list.all(opponent_heads, fn(opp_head) {
        manhattan_distance(opp_head, tile) > our_distance
      })

    case we_are_closest {
      True -> acc + 1
      False -> acc
    }
  })
}

/// Returns a strategic sample of tiles to check for territory control.
/// Instead of checking all tiles (expensive), we sample:
/// - Center region tiles
/// - Grid pattern across board
/// This gives ~20-30 tiles instead of 100-121 on standard boards.
fn get_strategic_sample_tiles(board: Board) -> List(Coord) {
  let center_x = board.width / 2
  let center_y = board.height / 2

  let center_tiles = [
    api.Coord(center_x, center_y),
    api.Coord(center_x - 1, center_y),
    api.Coord(center_x + 1, center_y),
    api.Coord(center_x, center_y - 1),
    api.Coord(center_x, center_y + 1),
    api.Coord(center_x - 2, center_y),
    api.Coord(center_x + 2, center_y),
    api.Coord(center_x, center_y - 2),
    api.Coord(center_x, center_y + 2),
  ]

  let grid_tiles =
    list.flat_map(list.range(1, board.width - 2), fn(x) {
      case x % 2 {
        0 ->
          list.filter_map(list.range(1, board.height - 2), fn(y) {
            case y % 2 {
              0 -> Ok(api.Coord(x, y))
              _ -> Error(Nil)
            }
          })
        _ -> []
      }
    })

  list.append(center_tiles, grid_tiles)
  |> list.filter(fn(coord) {
    coord.x >= 0
    && coord.y >= 0
    && coord.x < board.width
    && coord.y < board.height
  })
}

fn manhattan_distance(a: Coord, b: Coord) -> Int {
  let dx = case a.x > b.x {
    True -> a.x - b.x
    False -> b.x - a.x
  }
  let dy = case a.y > b.y {
    True -> a.y - b.y
    False -> b.y - a.y
  }
  dx + dy
}
