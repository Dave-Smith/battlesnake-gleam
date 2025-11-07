import adaptive_config
import api.{
  type GameState, game_state_from_json, index_response_to_json,
  move_response_to_json,
}
import game_state.{get_safe_moves, simulate_game_state}
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/float
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import heuristics
import log
import minimax
import mist
import system

fn json_response(body: String) -> Response(mist.ResponseData) {
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
  |> response.set_header("content-type", "application/json")
}

fn empty_response() -> Response(mist.ResponseData) {
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.new()))
}

fn float_to_string(f: Float) -> String {
  let rounded = float.round(f)
  let int_part = float.truncate(f)
  case int.to_float(rounded) == f {
    True -> int.to_string(int_part)
    False -> {
      let decimal_part =
        float.truncate({ f -. int.to_float(int_part) } *. 100.0)
      int.to_string(int_part)
      <> "."
      <> int.to_string(int.absolute_value(decimal_part))
    }
  }
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
    2 -> 8
    _ ->
      case board_density > 40 {
        True -> 5
        False -> 6
      }
  }
}

fn handle_request(req: Request(mist.Connection)) -> Response(mist.ResponseData) {
  case req.method, req.path {
    Get, "/" -> {
      let response_data =
        api.IndexResponse(
          apiversion: "1",
          author: "gleam-in-the-simulation",
          color: "#ffffff",
          head: "crystal-power",
          tail: "crystal-power",
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
          let _ = system.force_gc()
          log.info_with_fields("Move request received", [
            #("turn", int.to_string(game_state.turn)),
            #("num_snakes", int.to_string(list.length(game_state.board.snakes))),
            #("num_food", int.to_string(list.length(game_state.board.food))),
          ])
          let config = adaptive_config.get_adaptive_config(game_state)
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

              // Calculate depth-0 scores AND cache simulations for tie-breaking
              let depth_0_data =
                list.map(safe_moves, fn(move) {
                  let simulated_state = simulate_game_state(game_state, move)
                  let score = heuristics.evaluate_board(simulated_state, config)
                  #(move, simulated_state, score)
                })

              // Extract just scores for minimax
              let depth_0_scores =
                list.map(depth_0_data, fn(triple) {
                  let #(move, _, score) = triple
                  #(move, score)
                })

              // DEBUG: Log depth-0 heuristic scores (reusing cached simulations)
              log.info_with_fields("=== DEPTH 0 EVALUATION ===", [
                #("turn", int.to_string(game_state.turn)),
              ])
              list.each(depth_0_data, fn(triple) {
                let #(move, simulated_state, total_score) = triple
                let detailed_scores =
                  heuristics.evaluate_board_detailed(simulated_state, config)
                log.log_heuristic_scores(move, detailed_scores, total_score)
              })

              // Run minimax with depth-0 scores for tie-breaking
              log.info_with_fields("=== MINIMAX EVALUATION ===", [
                #("depth", int.to_string(depth)),
              ])
              let result =
                minimax.choose_move(game_state, depth, config, depth_0_scores)

              // DEBUG: Log final minimax scores
              let minimax_scores =
                list.map(safe_moves, fn(move) {
                  let next_state = simulate_game_state(game_state, move)
                  let score =
                    minimax.minimax(
                      next_state,
                      depth - 1,
                      False,
                      -999_999.0,
                      999_999.0,
                      config,
                    )
                  log.info_with_fields("Minimax score", [
                    #("move", move),
                    #("score", float_to_string(score)),
                  ])
                  #(move, score)
                })

              log.info_with_fields("=== FINAL DECISION ===", [
                #("chosen_move", result.move),
                #("chosen_score", float_to_string(result.score)),
              ])

              #(result.move, result.score)
            }
          }

          log.log_move_decision(game_state.turn, my_move, score, safe_moves)

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
