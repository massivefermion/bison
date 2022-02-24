import gleam/io
import gleam/int
import gleam/pair
import gleam/list
import gleam/result
import gleam/bit_string
import bson/types.{
  array, boolean, document, double, int32, int64, null, object_id, string,
}
import bson/object_id

pub fn decode(data: BitString) -> Result(List(#(String, types.Value)), Nil) {
  case decode_document(data) {
    Ok(types.Document(doc)) -> Ok(doc)
    Error(Nil) -> Error(Nil)
  }
}

fn decode_document(data: BitString) -> Result(types.Value, Nil) {
  let total_size = bit_string.byte_size(data)
  let last_byte = bit_string.slice(data, total_size, -1)
  case last_byte == Ok(<<0>>) {
    True -> {
      let <<given_size:32-little-int, rest:bit_string>> = data
      case total_size == given_size {
        True ->
          case bit_string.slice(rest, 0, total_size - 4 - 1) {
            Ok(body) ->
              case decode_body(body, []) {
                Ok(body) -> Ok(types.Document(body))
                Error(Nil) -> Error(Nil)
              }
            Error(Nil) -> Error(Nil)
          }
        False -> Error(Nil)
      }
    }
    False -> Error(Nil)
  }
}

fn decode_body(
  data: BitString,
  storage: List(#(String, types.Value)),
) -> Result(List(#(String, types.Value)), Nil) {
  case bit_string.byte_size(data) == 0 {
    True -> Ok(storage)
    False -> {
      let <<code:8, data:bit_string>> = data
      let total_size = bit_string.byte_size(data)
      case consume_till_zero(data, <<>>) {
        Ok(key) -> {
          let key_size = bit_string.byte_size(key)
          case bit_string.to_string(key) {
            Ok(key) ->
              case bit_string.slice(
                data,
                key_size + 1,
                total_size - key_size - 1,
              ) {
                Ok(rest) -> {
                  let kind = types.Kind(code: <<code>>)
                  case kind {
                    kind if kind == double -> {
                      let <<value:little-float, rest:bit_string>> = rest
                      decode_body(
                        rest,
                        [#(key, types.Double(value)), ..storage],
                      )
                    }
                    kind if kind == object_id -> {
                      let <<value:96-bit_string, rest:bit_string>> = rest
                      case object_id.from_bit_string(value) {
                        Ok(oid) ->
                          decode_body(
                            rest,
                            [#(key, types.ObjectId(oid)), ..storage],
                          )
                        Error(Nil) -> Error(Nil)
                      }
                    }
                    kind if kind == boolean -> {
                      let <<value:8, rest:bit_string>> = rest
                      case value {
                        1 ->
                          decode_body(
                            rest,
                            [#(key, types.Boolean(True)), ..storage],
                          )
                        0 ->
                          decode_body(
                            rest,
                            [#(key, types.Boolean(False)), ..storage],
                          )
                        _ -> Error(Nil)
                      }
                    }
                    kind if kind == null ->
                      decode_body(rest, [#(key, types.Null), ..storage])
                    kind if kind == int32 -> {
                      let <<value:32-little, rest:bit_string>> = rest
                      decode_body(
                        rest,
                        [#(key, types.Integer(value)), ..storage],
                      )
                    }
                    kind if kind == int64 -> {
                      let <<value:64-little, rest:bit_string>> = rest
                      decode_body(
                        rest,
                        [#(key, types.Integer(value)), ..storage],
                      )
                    }
                    kind if kind == string -> {
                      let <<given_size:32-little-int, rest:bit_string>> = rest
                      case consume_till_zero(rest, <<>>) {
                        Ok(str) -> {
                          let str_size = bit_string.byte_size(str)
                          case given_size == str_size + 1 {
                            True ->
                              case bit_string.to_string(str) {
                                Ok(str) ->
                                  case bit_string.slice(
                                    rest,
                                    str_size + 1,
                                    bit_string.byte_size(rest) - str_size - 1,
                                  ) {
                                    Ok(rest) ->
                                      decode_body(
                                        rest,
                                        [#(key, types.Str(str)), ..storage],
                                      )
                                    Error(Nil) -> Error(Nil)
                                  }
                                Error(Nil) -> Error(Nil)
                              }
                            False -> Error(Nil)
                          }
                        }
                        Error(Nil) -> Error(Nil)
                      }
                    }
                    kind if kind == document || kind == array -> {
                      let <<doc_size:32-little-int, _:bit_string>> = rest
                      case bit_string.slice(rest, 0, doc_size) {
                        Ok(doc) ->
                          case decode_document(doc) {
                            Ok(doc) -> {
                              let doc = case kind {
                                kind if kind == document -> Ok(doc)
                                kind if kind == array ->
                                  case doc {
                                    types.Document(doc) -> {
                                      let list =
                                        doc
                                        |> list.map(fn(item) {
                                          #(
                                            item
                                            |> pair.first
                                            |> int.parse,
                                            item
                                            |> pair.second,
                                          )
                                        })
                                      case list.any(
                                        list,
                                        fn(item) {
                                          result.is_error(
                                            item
                                            |> pair.first,
                                          )
                                        },
                                      ) {
                                        True -> Error(Nil)
                                        False ->
                                          Ok(types.Array(
                                            list
                                            |> list.map(fn(item) {
                                              assert Ok(first) =
                                                item
                                                |> pair.first
                                              #(
                                                first,
                                                item
                                                |> pair.second,
                                              )
                                            })
                                            |> list.sort(fn(a, b) {
                                              let a_index =
                                                a
                                                |> pair.first
                                              let b_index =
                                                b
                                                |> pair.first
                                              int.compare(a_index, b_index)
                                            })
                                            |> list.map(fn(item) {
                                              item
                                              |> pair.second
                                            }),
                                          ))
                                      }
                                    }
                                    _ -> Error(Nil)
                                  }
                                _ -> Error(Nil)
                              }
                              case doc {
                                Ok(doc) ->
                                  case doc_size == bit_string.byte_size(rest) {
                                    True -> Ok([#(key, doc), ..storage])
                                    False ->
                                      case bit_string.slice(
                                        rest,
                                        doc_size,
                                        bit_string.byte_size(rest) - doc_size,
                                      ) {
                                        Ok(rest) ->
                                          decode_body(
                                            rest,
                                            [#(key, doc), ..storage],
                                          )
                                        Error(Nil) -> Error(Nil)
                                      }
                                  }
                                Error(Nil) -> Error(Nil)
                              }
                            }
                            Error(Nil) -> Error(Nil)
                          }
                        Error(Nil) -> Error(Nil)
                      }
                    }
                    _ -> Error(Nil)
                  }
                }
                Error(Nil) -> Error(Nil)
              }
            Error(Nil) -> Error(Nil)
          }
        }
        Error(Nil) -> Error(Nil)
      }
    }
  }
}

fn consume_till_zero(
  data: BitString,
  storage: BitString,
) -> Result(BitString, Nil) {
  case bit_string.byte_size(data) == 0 {
    False -> {
      let <<ch:8, rest:bit_string>> = data
      case ch == 0 {
        True -> Ok(storage)
        False -> consume_till_zero(rest, bit_string.append(storage, <<ch>>))
      }
    }
    True -> Error(Nil)
  }
}
