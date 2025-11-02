//// Pathfinding Utility Functions

import api.{type Board, type Coord, type Snake}
import gleam/list
import gleam/set.{type Set}

/// Performs a flood fill from a starting coordinate to count accessible safe tiles.
/// Returns the number of tiles reachable without hitting walls or snake bodies.
pub fn flood_fill(start: Coord, board: Board, snakes: List(Snake)) -> Int {
  flood_fill_helper([start], set.from_list([start]), board, snakes)
}

fn flood_fill_helper(
  queue: List(Coord),
  visited: Set(Coord),
  board: Board,
  snakes: List(Snake),
) -> Int {
  case queue {
    [] -> set.size(visited)
    [current, ..rest] -> {
      let neighbors = get_valid_neighbors(current, board, snakes, visited)
      let new_visited = list.fold(neighbors, visited, fn(acc, coord) {
        set.insert(acc, coord)
      })
      flood_fill_helper(list.append(rest, neighbors), new_visited, board, snakes)
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
  list.any(snakes, fn(s) {
    let body_without_tail = case list.reverse(s.body) {
      [_, ..rest] -> list.reverse(rest)
      [] -> []
    }
    list.any(body_without_tail, fn(body_coord) { body_coord == coord })
  })
}

/// Performs BFS to find the shortest path distance to a target.
/// Returns the distance in moves, or -1 if unreachable.
pub fn bfs_distance(
  start: Coord,
  target: Coord,
  board: Board,
  snakes: List(Snake),
) -> Int {
  bfs_helper([#(start, 0)], set.from_list([start]), target, board, snakes)
}

fn bfs_helper(
  queue: List(#(Coord, Int)),
  visited: Set(Coord),
  target: Coord,
  board: Board,
  snakes: List(Snake),
) -> Int {
  case queue {
    [] -> -1
    [#(current, distance), ..rest] -> {
      case current == target {
        True -> distance
        False -> {
          let neighbors = get_valid_neighbors(current, board, snakes, visited)
          let new_queue =
            list.append(
              rest,
              list.map(neighbors, fn(n) { #(n, distance + 1) }),
            )
          let new_visited = list.fold(neighbors, visited, fn(acc, coord) {
            set.insert(acc, coord)
          })
          bfs_helper(new_queue, new_visited, target, board, snakes)
        }
      }
    }
  }
}

/// Computes Voronoi territory for a starting position against opponents.
/// Returns the count of tiles this position can reach before any opponent.
pub fn voronoi_territory(
  start: Coord,
  opponent_heads: List(Coord),
  board: Board,
  snakes: List(Snake),
) -> Int {
  let all_tiles = get_all_empty_tiles(board, snakes)

  list.fold(all_tiles, 0, fn(acc, tile) {
    let our_distance = bfs_distance(start, tile, board, snakes)

    case our_distance {
      -1 -> acc
      our_dist -> {
        let opponent_can_reach_faster =
          list.any(opponent_heads, fn(opp_head) {
            let opp_distance = bfs_distance(opp_head, tile, board, snakes)
            case opp_distance {
              -1 -> False
              opp_dist -> opp_dist <= our_dist
            }
          })

        case opponent_can_reach_faster {
          True -> acc
          False -> acc + 1
        }
      }
    }
  })
}

fn get_all_empty_tiles(board: Board, snakes: List(Snake)) -> List(Coord) {
  let all_coords =
    list.flat_map(list.range(0, board.width - 1), fn(x) {
      list.map(list.range(0, board.height - 1), fn(y) { api.Coord(x, y) })
    })

  list.filter(all_coords, fn(coord) { is_valid_tile(coord, board, snakes) })
}
