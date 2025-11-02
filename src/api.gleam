import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}

pub type Coord {
  Coord(x: Int, y: Int)
}

pub fn coord_to_json(coord: Coord) -> json.Json {
  json.object([
    #("x", json.int(coord.x)),
    #("y", json.int(coord.y)),
  ])
}

fn coord_decoder() -> decode.Decoder(Coord) {
  use x <- decode.field("x", decode.int)
  use y <- decode.field("y", decode.int)
  decode.success(Coord(x, y))
}

pub fn coord_from_json(json_string: String) -> Result(Coord, json.DecodeError) {
  json.parse(json_string, coord_decoder())
}

pub type Snake {
  Snake(
    id: String,
    name: String,
    health: Int,
    body: List(Coord),
    head: Coord,
    length: Int,
  )
}

pub fn snake_to_json(snake: Snake) -> json.Json {
  json.object([
    #("id", json.string(snake.id)),
    #("name", json.string(snake.name)),
    #("health", json.int(snake.health)),
    #("body", json.array(snake.body, of: coord_to_json)),
    #("head", coord_to_json(snake.head)),
    #("length", json.int(snake.length)),
  ])
}

fn snake_decoder() -> decode.Decoder(Snake) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use health <- decode.field("health", decode.int)
  use body <- decode.field("body", decode.list(coord_decoder()))
  use head <- decode.field("head", coord_decoder())
  use length <- decode.field("length", decode.int)
  decode.success(Snake(id, name, health, body, head, length))
}

pub fn snake_from_json(json_string: String) -> Result(Snake, json.DecodeError) {
  json.parse(json_string, snake_decoder())
}

pub type Board {
  Board(
    height: Int,
    width: Int,
    food: List(Coord),
    hazards: List(Coord),
    snakes: List(Snake),
  )
}

pub fn board_to_json(board: Board) -> json.Json {
  json.object([
    #("height", json.int(board.height)),
    #("width", json.int(board.width)),
    #("food", json.array(board.food, of: coord_to_json)),
    #("hazards", json.array(board.hazards, of: coord_to_json)),
    #("snakes", json.array(board.snakes, of: snake_to_json)),
  ])
}

fn board_decoder() -> decode.Decoder(Board) {
  use height <- decode.field("height", decode.int)
  use width <- decode.field("width", decode.int)
  use food <- decode.field("food", decode.list(coord_decoder()))
  use hazards <- decode.field("hazards", decode.list(coord_decoder()))
  use snakes <- decode.field("snakes", decode.list(snake_decoder()))
  decode.success(Board(height, width, food, hazards, snakes))
}

pub fn board_from_json(json_string: String) -> Result(Board, json.DecodeError) {
  json.parse(json_string, board_decoder())
}

pub type IndexResponse {
  IndexResponse(
    apiversion: String,
    author: String,
    color: String,
    head: String,
    tail: String,
    version: String,
  )
}

pub fn index_response_to_json(res: IndexResponse) -> json.Json {
  json.object([
    #("apiversion", json.string(res.apiversion)),
    #("author", json.string(res.author)),
    #("color", json.string(res.color)),
    #("head", json.string(res.head)),
    #("tail", json.string(res.tail)),
    #("version", json.string(res.version)),
  ])
}

fn index_response_decoder() -> decode.Decoder(IndexResponse) {
  use apiversion <- decode.field("apiversion", decode.string)
  use author <- decode.field("author", decode.string)
  use color <- decode.field("color", decode.string)
  use head <- decode.field("head", decode.string)
  use tail <- decode.field("tail", decode.string)
  use version <- decode.field("version", decode.string)
  decode.success(IndexResponse(apiversion, author, color, head, tail, version))
}

pub fn index_response_from_json(
  json_string: String,
) -> Result(IndexResponse, json.DecodeError) {
  json.parse(json_string, index_response_decoder())
}

pub type MoveResponse {
  MoveResponse(move: String, shout: Option(String))
}

pub fn move_response_to_json(res: MoveResponse) -> json.Json {
  json.object([
    #("move", json.string(res.move)),
    #("shout", case res.shout {
      Some(s) -> json.string(s)
      None -> json.null()
    }),
  ])
}

fn move_response_decoder() -> decode.Decoder(MoveResponse) {
  use move <- decode.field("move", decode.string)
  use shout <- decode.field("shout", decode.optional(decode.string))
  decode.success(MoveResponse(move, shout))
}

pub fn move_response_from_json(
  json_string: String,
) -> Result(MoveResponse, json.DecodeError) {
  json.parse(json_string, move_response_decoder())
}

pub type Game {
  Game(id: String)
}

pub fn game_to_json(game: Game) -> json.Json {
  json.object([
    #("id", json.string(game.id)),
  ])
}

fn game_decoder() -> decode.Decoder(Game) {
  use id <- decode.field("id", decode.string)
  decode.success(Game(id))
}

pub fn game_from_json(json_string: String) -> Result(Game, json.DecodeError) {
  json.parse(json_string, game_decoder())
}

pub type GameState {
  GameState(game: Game, turn: Int, board: Board, you: Snake)
}

pub fn game_state_to_json(state: GameState) -> json.Json {
  json.object([
    #("game", game_to_json(state.game)),
    #("turn", json.int(state.turn)),
    #("board", board_to_json(state.board)),
    #("you", snake_to_json(state.you)),
  ])
}

fn game_state_decoder() -> decode.Decoder(GameState) {
  use game <- decode.field("game", game_decoder())
  use turn <- decode.field("turn", decode.int)
  use board <- decode.field("board", board_decoder())
  use you <- decode.field("you", snake_decoder())
  decode.success(GameState(game, turn, board, you))
}

pub fn game_state_from_json(
  json_string: String,
) -> Result(GameState, json.DecodeError) {
  json.parse(json_string, game_state_decoder())
}
