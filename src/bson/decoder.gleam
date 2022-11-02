import bson/md5
import gleam/int
import bson/uuid
import gleam/pair
import gleam/list
import bson/custom
import bson/generic
import bson/object_id
import gleam/bit_string
import bson/types.{
  array, binary, boolean, datetime, document, double, generic as generic_kind,
  int32, int64, js, max, md5 as md5_kind, min, null, object_id as object_id_kind,
  regex, string, timestamp, uuid as uuid_kind,
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
  case last_byte {
    Ok(<<0>>) -> {
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
    _ -> Error(Nil)
  }
}

fn decode_body(
  data: BitString,
  storage: List(#(String, types.Value)),
) -> Result(List(#(String, types.Value)), Nil) {
  case bit_string.byte_size(data) {
    0 -> Ok(storage)
    _ -> {
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
            sub_kind if sub_kind == generic_kind -> {
              try value = generic.from_bit_string(value)
              decode_body(
                rest,
                storage
                |> list.reverse
                |> list.prepend(#(key, types.Binary(types.Generic(value))))
                |> list.reverse,
              )
            }
            sub_kind if sub_kind == md5_kind -> {
              try value = md5.from_bit_string(value)
              decode_body(
                rest,
                storage
                |> list.reverse
                |> list.prepend(#(key, types.Binary(types.MD5(value))))
                |> list.reverse,
              )
            }
            sub_kind if sub_kind == uuid_kind -> {
              try value = uuid.from_bit_string(value)
              decode_body(
                rest,
                storage
                |> list.reverse
                |> list.prepend(#(key, types.Binary(types.UUID(value))))
                |> list.reverse,
              )
            }
            _ if sub_code >= 0x80 -> {
              try value = custom.from_bit_string_with_code(sub_code, value)
              decode_body(
                rest,
                storage
                |> list.reverse
                |> list.prepend(#(key, types.Binary(types.Custom(value))))
                |> list.reverse,
              )
            }
            _ -> Error(Nil)
          }
        }
        kind if kind == double -> {
          let <<value:little-float, rest:bit_string>> = rest
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.Double(value)))
            |> list.reverse,
          )
        }
        kind if kind == object_id_kind -> {
          let <<value:96-bit_string, rest:bit_string>> = rest
          try oid = object_id.from_bit_string(value)
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.ObjectId(oid)))
            |> list.reverse,
          )
        }
        kind if kind == boolean -> {
          let <<value:8, rest:bit_string>> = rest
          case value {
            1 ->
              decode_body(
                rest,
                storage
                |> list.reverse
                |> list.prepend(#(key, types.Boolean(True)))
                |> list.reverse,
              )
            0 ->
              decode_body(
                rest,
                storage
                |> list.reverse
                |> list.prepend(#(key, types.Boolean(False)))
                |> list.reverse,
              )
            _ -> Error(Nil)
          }
        }
        kind if kind == null ->
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.Null))
            |> list.reverse,
          )
        kind if kind == min ->
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.Min))
            |> list.reverse,
          )
        kind if kind == max ->
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.Max))
            |> list.reverse,
          )
        kind if kind == int32 -> {
          let <<value:32-little, rest:bit_string>> = rest
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.Integer(value)))
            |> list.reverse,
          )
        }
        kind if kind == int64 -> {
          let <<value:64-little, rest:bit_string>> = rest
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.Integer(value)))
            |> list.reverse,
          )
        }
        kind if kind == datetime -> {
          let <<value:64-little, rest:bit_string>> = rest
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.DateTime(value)))
            |> list.reverse,
          )
        }
        kind if kind == timestamp -> {
          let <<value:64-little-unsigned, rest:bit_string>> = rest
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.Timestamp(value)))
            |> list.reverse,
          )
        }
        kind if kind == regex -> {
          try pattern_bytes = consume_till_zero(rest, <<>>)
          let pattern_size = { bit_string.byte_size(pattern_bytes) + 1 } * 8
          let <<_:size(pattern_size), rest:bit_string>> = rest
          try options_bytes = consume_till_zero(rest, <<>>)
          let options_size = { bit_string.byte_size(options_bytes) + 1 } * 8
          let <<_:size(options_size), rest:bit_string>> = rest
          try pattern = bit_string.to_string(pattern_bytes)
          try options = bit_string.to_string(options_bytes)
          decode_body(
            rest,
            storage
            |> list.reverse
            |> list.prepend(#(key, types.Regex(#(pattern, options))))
            |> list.reverse,
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
              decode_body(
                rest,
                storage
                |> list.reverse
                |> list.prepend(#(key, types.Str(str)))
                |> list.reverse,
              )
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
              decode_body(
                rest,
                storage
                |> list.reverse
                |> list.prepend(#(key, types.JS(str)))
                |> list.reverse,
              )
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
                list.try_map(
                  doc,
                  fn(item) {
                    try first =
                      item
                      |> pair.first
                      |> int.parse
                    Ok(#(first, pair.second(item)))
                  },
                )
              types.Array(
                list.sort(
                  doc,
                  fn(a, b) {
                    let a_index = pair.first(a)
                    let b_index = pair.first(b)
                    int.compare(a_index, b_index)
                  },
                )
                |> list.map(pair.second),
              )
              |> Ok
            }
            _ -> Error(Nil)
          }
          case doc_size == bit_string.byte_size(rest) {
            True ->
              storage
              |> list.reverse
              |> list.prepend(#(key, doc))
              |> list.reverse
              |> Ok
            False ->
              case
                bit_string.slice(
                  rest,
                  doc_size,
                  bit_string.byte_size(rest) - doc_size,
                )
              {
                Ok(rest) ->
                  decode_body(
                    rest,
                    storage
                    |> list.reverse
                    |> list.prepend(#(key, doc))
                    |> list.reverse,
                  )
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
  case bit_string.byte_size(data) {
    0 -> Error(Nil)
    _ -> {
      let <<ch:8, rest:bit_string>> = data
      case ch {
        0 -> Ok(storage)
        _ -> consume_till_zero(rest, bit_string.append(storage, <<ch>>))
      }
    }
  }
}
