import bson/md5
import gleam/int
import gleam/pair
import gleam/list
import bson/custom
import bson/generic
import bson/object_id
import gleam/bit_string
import bson/types.{
  array, binary, boolean, datetime, document, double, generic, int32, int64, js,
  max, md5, min, null, object_id, string, timestamp,
}

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
        True -> {
          try body = bit_string.slice(rest, 0, total_size - 4 - 1)
          try body = decode_body(body, [])
          Ok(types.Document(body))
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
      try key = consume_till_zero(data, <<>>)
      let key_size = bit_string.byte_size(key)
      try key = bit_string.to_string(key)
      try rest = bit_string.slice(data, key_size + 1, total_size - key_size - 1)
      let kind = types.Kind(code: <<code>>)
      case kind {
        kind if kind == binary -> {
          let <<byte_size:32-little-int, sub_code:8, rest:bit_string>> = rest
          let given_size = byte_size * 8
          let <<value:size(given_size)-bit_string, rest:bit_string>> = rest
          let sub_kind = types.SubKind(code: <<sub_code>>)
          case sub_kind {
            sub_kind if sub_kind == generic -> {
              try value = generic.from_bit_string(value)
              decode_body(
                rest,
                list.append(
                  storage,
                  [#(key, types.Binary(types.Generic(value)))],
                ),
              )
            }
            sub_kind if sub_kind == md5 -> {
              try value = md5.from_bit_string(value)
              decode_body(
                rest,
                list.append(storage, [#(key, types.Binary(types.MD5(value)))]),
              )
            }
            _ if sub_code >= 0x80 -> {
              try value = custom.from_bit_string_with_code(sub_code, value)
              decode_body(
                rest,
                list.append(
                  storage,
                  [#(key, types.Binary(types.Custom(value)))],
                ),
              )
            }
            _ -> Error(Nil)
          }
        }
        kind if kind == double -> {
          let <<value:little-float, rest:bit_string>> = rest
          decode_body(rest, list.append(storage, [#(key, types.Double(value))]))
        }
        kind if kind == object_id -> {
          let <<value:96-bit_string, rest:bit_string>> = rest
          try oid = object_id.from_bit_string(value)
          decode_body(rest, list.append(storage, [#(key, types.ObjectId(oid))]))
        }
        kind if kind == boolean -> {
          let <<value:8, rest:bit_string>> = rest
          case value {
            1 ->
              decode_body(
                rest,
                list.append(storage, [#(key, types.Boolean(True))]),
              )
            0 ->
              decode_body(
                rest,
                list.append(storage, [#(key, types.Boolean(False))]),
              )
            _ -> Error(Nil)
          }
        }
        kind if kind == null ->
          decode_body(rest, list.append(storage, [#(key, types.Null)]))
        kind if kind == min ->
          decode_body(rest, list.append(storage, [#(key, types.Min)]))
        kind if kind == max ->
          decode_body(rest, list.append(storage, [#(key, types.Max)]))
        kind if kind == int32 -> {
          let <<value:32-little, rest:bit_string>> = rest
          decode_body(
            rest,
            list.append(storage, [#(key, types.Integer(value))]),
          )
        }
        kind if kind == int64 -> {
          let <<value:64-little, rest:bit_string>> = rest
          decode_body(
            rest,
            list.append(storage, [#(key, types.Integer(value))]),
          )
        }
        kind if kind == datetime -> {
          let <<value:64-little, rest:bit_string>> = rest
          decode_body(
            rest,
            list.append(storage, [#(key, types.DateTime(value))]),
          )
        }
        kind if kind == timestamp -> {
          let <<value:64-little-unsigned, rest:bit_string>> = rest
          decode_body(
            rest,
            list.append(storage, [#(key, types.Timestamp(value))]),
          )
        }
        kind if kind == string -> {
          let <<given_size:32-little-int, rest:bit_string>> = rest
          try str = consume_till_zero(rest, <<>>)
          let str_size = bit_string.byte_size(str)
          case given_size == str_size + 1 {
            True -> {
              try str = bit_string.to_string(str)
              try rest =
                bit_string.slice(
                  rest,
                  str_size + 1,
                  bit_string.byte_size(rest) - str_size - 1,
                )
              decode_body(rest, list.append(storage, [#(key, types.Str(str))]))
            }
            False -> Error(Nil)
          }
        }
        kind if kind == js -> {
          let <<given_size:32-little-int, rest:bit_string>> = rest
          try str = consume_till_zero(rest, <<>>)
          let str_size = bit_string.byte_size(str)
          case given_size == str_size + 1 {
            True -> {
              try str = bit_string.to_string(str)
              try rest =
                bit_string.slice(
                  rest,
                  str_size + 1,
                  bit_string.byte_size(rest) - str_size - 1,
                )
              decode_body(rest, list.append(storage, [#(key, types.JS(str))]))
            }
            False -> Error(Nil)
          }
        }
        kind if kind == document || kind == array -> {
          let <<doc_size:32-little-int, _:bit_string>> = rest
          try doc = bit_string.slice(rest, 0, doc_size)
          try types.Document(doc) = decode_document(doc)
          try doc = case kind {
            kind if kind == document -> Ok(types.Document(doc))
            kind if kind == array -> {
              try doc =
                doc
                |> list.try_map(fn(item) {
                  try first =
                    item
                    |> pair.first
                    |> int.parse
                  Ok(#(
                    first,
                    item
                    |> pair.second,
                  ))
                })
              Ok(types.Array(
                doc
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
            _ -> Error(Nil)
          }
          case doc_size == bit_string.byte_size(rest) {
            True -> Ok(list.append(storage, [#(key, doc)]))
            False ->
              case bit_string.slice(
                rest,
                doc_size,
                bit_string.byte_size(rest) - doc_size,
              ) {
                Ok(rest) ->
                  decode_body(rest, list.append(storage, [#(key, doc)]))
                Error(Nil) -> Error(Nil)
              }
          }
        }
        _ -> Error(Nil)
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
