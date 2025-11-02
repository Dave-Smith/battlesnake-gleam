import api.{
  type GameState, game_state_from_json, index_response_to_json,
  move_response_to_json,
}
import game_state.{get_safe_moves}
import gleam/bit_array
import gleam/bytes_tree
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/string
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
          io.println("Game started: " <> game_state.game.id)
          empty_response()
        }
        Error(_) -> {
          io.println("Failed to parse /start request body")
          empty_response()
        }
      }
    }

    Post, "/move" -> {
      case parse_game_state(req) {
        Ok(game_state) -> {
          io.println("Move request for turn " <> string.inspect(game_state.turn))
          let safe_moves = get_safe_moves(game_state)
          let my_move = case safe_moves {
            [] -> {
              io.println("No safe moves available! Choosing random move.")
              case list.shuffle(["up", "down", "left", "right"]) {
                [m, ..] -> m
                [] -> "up"
              }
            }
            moves -> {
              case list.shuffle(moves) {
                [m, ..] -> m
                [] -> "up"
              }
            }
          }
          let move_response =
            api.MoveResponse(move: my_move, shout: Some("Gleam snake!"))
          json_response(json.to_string(move_response_to_json(move_response)))
        }
        Error(_) -> {
          io.println(
            "Failed to parse /move request body, returning fallback move",
          )
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
          io.println("Game ended: " <> game_state.game.id)
          empty_response()
        }
        Error(_) -> {
          io.println("Failed to parse /end request body")
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
  io.println("Battlesnake server started on port 8080")
}
