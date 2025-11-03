import api.{
  type GameState, game_state_from_json, index_response_to_json,
  move_response_to_json,
}
import game_state.{get_safe_moves}
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/list
import gleam/option.{Some}
import heuristic_config
import heuristics
import log
import minimax
import mist

fn json_response(body: String) -> Response(mist.ResponseData) {
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
  |> response.set_header("content-type", "application/json")
}

fn empty_response() -> Response(mist.ResponseData) {
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.new()))
}

fn parse_game_state(
  req: Request(mist.Connection),
) -> Result(GameState, json.DecodeError) {
  case mist.read_body(req, 1024 * 1024) {
    Ok(read_req) ->
      case bit_array.to_string(read_req.body) {
        Ok(json_string) -> game_state_from_json(json_string)
        Error(_) -> Error(json.UnexpectedByte(""))
      }
    Error(_) -> Error(json.UnexpectedByte(""))
  }
}

fn calculate_dynamic_depth(game_state: GameState) -> Int {
  let num_snakes = list.length(game_state.board.snakes)
  let board_size = game_state.board.width * game_state.board.height
  let num_occupied =
    list.fold(game_state.board.snakes, 0, fn(acc, snake) { acc + snake.length })
  let board_density = num_occupied * 100 / board_size

  case num_snakes {
    1 -> 10
    2 -> 9
    _ ->
      case board_density > 40 {
        True -> 5
        False -> 7
      }
  }
}

fn handle_request(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
  case req.method, req.path {
    Get, "/" -> {
      let response_data =
        api.IndexResponse(
          apiversion: "1",
          author: "your-github-username",
          color: "#888888",
          head: "default",
          tail: "default",
          version: "0.0.1",
        )
      json_response(json.to_string(index_response_to_json(response_data)))
    }

    Post, "/start" -> {
      case parse_game_state(req) {
        Ok(game_state) -> {
          log.info_with_fields("Game started", [
            #("game_id", game_state.game.id),
          ])
          empty_response()
        }
        Error(_) -> {
          log.error("Failed to parse /start request body")
          empty_response()
        }
      }
    }

    Post, "/move" -> {
      case parse_game_state(req) {
        Ok(game_state) -> {
          let request_start = log.get_monotonic_time()
          let config = heuristic_config.default_config()
          let safe_moves = get_safe_moves(game_state)

          let #(my_move, score) = case safe_moves {
            [] -> {
              log.warning("No safe moves available! Choosing random move.")
              case list.shuffle(["up", "down", "left", "right"]) {
                [m, ..] -> #(m, -999_999.0)
                [] -> #("up", -999_999.0)
              }
            }
            _ -> {
              let depth = calculate_dynamic_depth(game_state)
              let result = minimax.choose_move(game_state, depth, config)
              #(result.move, result.score)
            }
          }

          log.log_move_decision(game_state.turn, my_move, score, safe_moves)

          let detailed_scores =
            heuristics.evaluate_board_detailed(game_state, config)
          log.log_heuristic_scores(
            my_move,
            detailed_scores,
            heuristics.evaluate_board(game_state, config),
          )

          let request_end = log.get_monotonic_time()
          log.info_with_fields("Move request complete", [
            #("turn", int.to_string(game_state.turn)),
            #("duration_ms", int.to_string(request_end - request_start)),
          ])

          let move_response =
            api.MoveResponse(move: my_move, shout: Some("Gleam snake!"))
          json_response(json.to_string(move_response_to_json(move_response)))
        }
        Error(_) -> {
          log.error("Failed to parse /move request body")
          let fallback_response =
            api.MoveResponse(move: "up", shout: Some("Error!"))
          json_response(
            json.to_string(move_response_to_json(fallback_response)),
          )
        }
      }
    }

    Post, "/end" -> {
      case parse_game_state(req) {
        Ok(game_state) -> {
          log.info_with_fields("Game ended", [
            #("game_id", game_state.game.id),
          ])
          empty_response()
        }
        Error(_) -> {
          log.error("Failed to parse /end request body")
          empty_response()
        }
      }
    }

    _, _ -> {
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
    }
  }
}

pub fn main() {
  let assert Ok(_) =
    mist.new(handle_request)
    |> mist.port(8080)
    |> mist.start

  log.info("Battlesnake server started on port 8080")
  process.sleep_forever()
}
