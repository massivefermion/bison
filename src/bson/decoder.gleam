import gleam/list
import gleam/pair
import gleam/result
import gleam/bit_string
import bson/md5
import gleam/int
import bson/uuid
import bson/custom
import bson/generic
import bson/object_id
import bson/types.{
  array, binary, boolean, datetime, document, double, generic as generic_kind,
  int32, int64, js, max, md5 as md5_kind, min, null, object_id as object_id_kind,
  regex, string, timestamp, uuid as uuid_kind,
}

pub fn decode(data: BitString) -> Result(List(#(String, types.Value)), Nil) {
  case decode_document(data) {
    Ok(types.Document(doc)) -> Ok(doc)
    _ -> Error(Nil)
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
          use body <- result.then(bit_string.slice(rest, 0, total_size - 4 - 1))
          use body <- result.then(decode_body(body, []))
          body
          |> types.Document
          |> Ok
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
      use key <- result.then(consume_till_zero(data, <<>>))
      let key_size = bit_string.byte_size(key)
      use key <- result.then(bit_string.to_string(key))
      use rest <- result.then(bit_string.slice(
        data,
        key_size + 1,
        total_size - key_size - 1,
      ))
      let kind = types.Kind(code: <<code>>)
      case kind {
        kind if kind == binary -> {
          let <<byte_size:32-little-int, sub_code:8, rest:bit_string>> = rest
          let given_size = byte_size * 8
          let <<value:size(given_size)-bit_string, rest:bit_string>> = rest
          let sub_kind = types.SubKind(code: <<sub_code>>)
          case sub_kind {
            sub_kind if sub_kind == generic_kind -> {
              use value <- result.then(generic.from_bit_string(value))
              recurse_with_new_kv(
                rest,
                storage,
                key,
                value
                |> types.Generic
                |> types.Binary,
              )
            }
            sub_kind if sub_kind == md5_kind -> {
              use value <- result.then(md5.from_bit_string(value))
              recurse_with_new_kv(
                rest,
                storage,
                key,
                value
                |> types.MD5
                |> types.Binary,
              )
            }
            sub_kind if sub_kind == uuid_kind -> {
              use value <- result.then(uuid.from_bit_string(value))
              recurse_with_new_kv(
                rest,
                storage,
                key,
                value
                |> types.UUID
                |> types.Binary,
              )
            }
            _ if sub_code >= 0x80 -> {
              use value <- result.then(custom.from_bit_string_with_code(
                sub_code,
                value,
              ))
              recurse_with_new_kv(
                rest,
                storage,
                key,
                value
                |> types.Custom
                |> types.Binary,
              )
            }
            _ -> Error(Nil)
          }
        }
        kind if kind == double -> {
          let <<value:little-float, rest:bit_string>> = rest
          recurse_with_new_kv(rest, storage, key, types.Double(value))
        }
        kind if kind == object_id_kind -> {
          let <<value:96-bit_string, rest:bit_string>> = rest
          use oid <- result.then(object_id.from_bit_string(value))
          recurse_with_new_kv(rest, storage, key, types.ObjectId(oid))
        }
        kind if kind == boolean -> {
          let <<value:8, rest:bit_string>> = rest
          use value <- decode_boolean(value)
          recurse_with_new_kv(rest, storage, key, types.Boolean(value))
        }
        kind if kind == null ->
          recurse_with_new_kv(rest, storage, key, types.Null)
        kind if kind == min ->
          recurse_with_new_kv(rest, storage, key, types.Min)
        kind if kind == max ->
          recurse_with_new_kv(rest, storage, key, types.Max)
        kind if kind == int32 -> {
          let <<value:32-little, rest:bit_string>> = rest
          recurse_with_new_kv(rest, storage, key, types.Integer(value))
        }
        kind if kind == int64 -> {
          let <<value:64-little, rest:bit_string>> = rest
          recurse_with_new_kv(rest, storage, key, types.Integer(value))
        }
        kind if kind == datetime -> {
          let <<value:64-little, rest:bit_string>> = rest
          recurse_with_new_kv(rest, storage, key, types.DateTime(value))
        }
        kind if kind == timestamp -> {
          let <<value:64-little-unsigned, rest:bit_string>> = rest
          recurse_with_new_kv(rest, storage, key, types.Timestamp(value))
        }
        kind if kind == regex -> {
          use pattern_bytes <- result.then(consume_till_zero(rest, <<>>))
          let pattern_size = { bit_string.byte_size(pattern_bytes) + 1 } * 8
          let <<_:size(pattern_size), rest:bit_string>> = rest
          use options_bytes <- result.then(consume_till_zero(rest, <<>>))
          let options_size = { bit_string.byte_size(options_bytes) + 1 } * 8
          let <<_:size(options_size), rest:bit_string>> = rest
          use pattern <- result.then(bit_string.to_string(pattern_bytes))
          use options <- result.then(bit_string.to_string(options_bytes))
          recurse_with_new_kv(
            rest,
            storage,
            key,
            types.Regex(#(pattern, options)),
          )
        }
        kind if kind == string -> {
          let <<given_size:32-little-int, rest:bit_string>> = rest
          use str <- result.then(consume_till_zero(rest, <<>>))
          let str_size = bit_string.byte_size(str)
          case given_size == str_size + 1 {
            True -> {
              use str <- result.then(bit_string.to_string(str))
              use rest <- result.then(bit_string.slice(
                rest,
                str_size + 1,
                bit_string.byte_size(rest) - str_size - 1,
              ))
              recurse_with_new_kv(rest, storage, key, types.Str(str))
            }
            False -> Error(Nil)
          }
        }
        kind if kind == js -> {
          let <<given_size:32-little-int, rest:bit_string>> = rest
          use str <- result.then(consume_till_zero(rest, <<>>))
          let str_size = bit_string.byte_size(str)
          case given_size == str_size + 1 {
            True -> {
              use str <- result.then(bit_string.to_string(str))
              use rest <- result.then(bit_string.slice(
                rest,
                str_size + 1,
                bit_string.byte_size(rest) - str_size - 1,
              ))
              recurse_with_new_kv(rest, storage, key, types.JS(str))
            }
            False -> Error(Nil)
          }
        }
        kind if kind == document || kind == array -> {
          let <<doc_size:32-little-int, _:bit_string>> = rest
          use doc <- result.then(bit_string.slice(rest, 0, doc_size))
          use doc <- result.then(decode_document(doc))
          let assert types.Document(doc) = doc
          use doc <- result.then(case kind {
            kind if kind == document ->
              doc
              |> types.Document
              |> Ok
            kind if kind == array -> {
              use doc <- result.then(list.try_map(
                doc,
                fn(item) {
                  use first <- result.then(int.parse(item.0))
                  Ok(#(first, item.1))
                },
              ))
              doc
              |> list.sort(fn(a, b) { int.compare(a.0, b.0) })
              |> list.map(pair.second)
              |> types.Array
              |> Ok
            }
            _ -> Error(Nil)
          })
          case
            bit_string.slice(
              rest,
              doc_size,
              bit_string.byte_size(rest) - doc_size,
            )
          {
            Ok(rest) -> recurse_with_new_kv(rest, storage, key, doc)
            Error(Nil) -> Error(Nil)
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

fn recurse_with_new_kv(rest, storage, key, value) {
  decode_body(rest, list.key_set(storage, key, value))
}

fn decode_boolean(value, rest) {
  case value {
    0 -> rest(False)
    1 -> rest(True)
    _ -> Error(Nil)
  }
}
