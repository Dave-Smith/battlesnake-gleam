//// Structured Logging Module

import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string

pub type LogLevel {
  Debug
  Info
  Warning
  Error
}

fn level_to_string(level: LogLevel) -> String {
  case level {
    Debug -> "DEBUG"
    Info -> "INFO"
    Warning -> "WARN"
    Error -> "ERROR"
  }
}

pub fn log(level: LogLevel, message: String, fields: List(#(String, String))) -> Nil {
  let level_str = level_to_string(level)
  let fields_str = case fields {
    [] -> ""
    _ -> {
      let field_parts =
        list.map(fields, fn(pair) {
          let #(key, value) = pair
          key <> "=" <> value
        })
      " | " <> string.join(field_parts, ", ")
    }
  }
  io.println("[" <> level_str <> "] " <> message <> fields_str)
}

pub fn info(message: String) -> Nil {
  log(Info, message, [])
}

pub fn info_with_fields(message: String, fields: List(#(String, String))) -> Nil {
  log(Info, message, fields)
}

pub fn debug(message: String) -> Nil {
  log(Debug, message, [])
}

pub fn debug_with_fields(message: String, fields: List(#(String, String))) -> Nil {
  log(Debug, message, fields)
}

pub fn warning(message: String) -> Nil {
  log(Warning, message, [])
}

pub fn error(message: String) -> Nil {
  log(Error, message, [])
}

pub fn log_move_decision(
  turn: Int,
  chosen_move: String,
  score: Float,
  safe_moves: List(String),
) -> Nil {
  info_with_fields("Move decision", [
    #("turn", int.to_string(turn)),
    #("move", chosen_move),
    #("score", float_to_string(score)),
    #("safe_moves", string.join(safe_moves, ",")),
  ])
}

pub fn log_heuristic_scores(
  move: String,
  scores: List(#(String, Float)),
  total: Float,
) -> Nil {
  let score_parts =
    list.map(scores, fn(pair) {
      let #(name, value) = pair
      name <> ":" <> float_to_string(value)
    })
  debug_with_fields("Heuristic breakdown", [
    #("move", move),
    #("scores", string.join(score_parts, ", ")),
    #("total", float_to_string(total)),
  ])
}

fn float_to_string(f: Float) -> String {
  let rounded = float.round(f)
  let int_part = float.truncate(f)
  case int.to_float(rounded) == f {
    True -> int.to_string(int_part)
    False -> {
      let decimal_part = float.truncate({ f -. int.to_float(int_part) } *. 100.0)
      int.to_string(int_part) <> "." <> int.to_string(int.absolute_value(decimal_part))
    }
  }
}
