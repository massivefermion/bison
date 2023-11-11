import gleam/int
import gleam/bool
import gleam/list
import gleam/pair
import gleam/result
import gleam/bit_array
import bison/md5
import bison/uuid
import bison/bson
import bison/custom
import bison/generic
import bison/object_id
import bison/kind as bison_kind
import birl/time
import birl/duration

pub fn decode(data: BitArray) -> Result(List(#(String, bson.Value)), Nil) {
  case decode_document(data) {
    Ok(bson.Document(doc)) -> Ok(doc)
    _ -> Error(Nil)
  }
}

fn decode_document(data: BitArray) -> Result(bson.Value, Nil) {
  let total_size = bit_array.byte_size(data)
  let last_byte = bit_array.slice(data, total_size, -1)
  case last_byte {
    Ok(<<0>>) -> {
      let <<given_size:32-little-int, rest:bits>> = data
      case total_size == given_size {
        True -> {
          use body <- result.then(bit_array.slice(rest, 0, total_size - 4 - 1))
          use body <- result.then(decode_body(body, []))
          body
          |> bson.Document
          |> Ok
        }
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn decode_body(
  data: BitArray,
  storage: List(#(String, bson.Value)),
) -> Result(List(#(String, bson.Value)), Nil) {
  use <- bool.guard(bit_array.byte_size(data) == 0, Ok(storage))

  let <<code:8, data:bits>> = data
  use #(key, rest) <- result.then(consume_till_zero(data, <<>>))
  use key <- result.then(bit_array.to_string(key))

  let kind = bison_kind.Kind(code: <<code>>)
  case kind {
    kind if kind == bison_kind.min ->
      recurse_with_new_kv(rest, storage, key, bson.Min)
    kind if kind == bison_kind.max ->
      recurse_with_new_kv(rest, storage, key, bson.Max)
    kind if kind == bison_kind.null ->
      recurse_with_new_kv(rest, storage, key, bson.Null)

    kind if kind == bison_kind.int32 -> {
      let <<value:32-little-signed, rest:bits>> = rest
      recurse_with_new_kv(rest, storage, key, bson.Int32(value))
    }

    kind if kind == bison_kind.int64 -> {
      let <<value:64-little-signed, rest:bits>> = rest
      recurse_with_new_kv(rest, storage, key, bson.Int64(value))
    }

    kind if kind == bison_kind.double -> {
      let <<value:little-float, rest:bits>> = rest
      recurse_with_new_kv(rest, storage, key, bson.Double(value))
    }

    kind if kind == bison_kind.timestamp -> {
      let <<counter:32-little-unsigned, stamp:32-little-unsigned, rest:bits>> =
        rest
      recurse_with_new_kv(rest, storage, key, bson.Timestamp(stamp, counter))
    }

    kind if kind == bison_kind.object_id -> {
      let <<value:96-bits, rest:bits>> = rest
      use oid <- result.then(object_id.from_bit_array(value))
      recurse_with_new_kv(rest, storage, key, bson.ObjectId(oid))
    }

    kind if kind == bison_kind.boolean -> {
      let <<value:8, rest:bits>> = rest
      use value <- decode_boolean(value)
      recurse_with_new_kv(rest, storage, key, bson.Boolean(value))
    }

    kind if kind == bison_kind.datetime -> {
      let <<value:64-little-signed, rest:bits>> = rest
      let value =
        time.add(
          time.unix_epoch,
          duration.accurate_new([#(value, duration.MilliSecond)]),
        )
      recurse_with_new_kv(rest, storage, key, bson.DateTime(value))
    }

    kind if kind == bison_kind.regex -> {
      use #(pattern_bytes, rest) <- result.then(consume_till_zero(rest, <<>>))
      use #(options_bytes, rest) <- result.then(consume_till_zero(rest, <<>>))
      use pattern <- result.then(bit_array.to_string(pattern_bytes))
      use options <- result.then(bit_array.to_string(options_bytes))
      recurse_with_new_kv(rest, storage, key, bson.Regex(#(pattern, options)))
    }

    kind if kind == bison_kind.string -> {
      let <<given_size:32-little-int, rest:bits>> = rest
      use #(str, rest) <- result.then(consume_till_zero(rest, <<>>))
      let str_size = bit_array.byte_size(str)
      case given_size == str_size + 1 {
        True -> {
          use str <- result.then(bit_array.to_string(str))
          recurse_with_new_kv(rest, storage, key, bson.String(str))
        }
        False -> Error(Nil)
      }
    }

    kind if kind == bison_kind.js -> {
      let <<given_size:32-little-int, rest:bits>> = rest
      use #(str, rest) <- result.then(consume_till_zero(rest, <<>>))
      let str_size = bit_array.byte_size(str)
      case given_size == str_size + 1 {
        True -> {
          use str <- result.then(bit_array.to_string(str))
          recurse_with_new_kv(rest, storage, key, bson.JS(str))
        }
        False -> Error(Nil)
      }
    }

    kind if kind == bison_kind.document || kind == bison_kind.array -> {
      let <<doc_size:32-little-int, _:bits>> = rest
      use doc <- result.then(bit_array.slice(rest, 0, doc_size))
      use doc <- result.then(decode_document(doc))
      let assert bson.Document(doc) = doc
      use doc <- result.then(case kind {
        kind if kind == bison_kind.document ->
          doc
          |> bson.Document
          |> Ok

        kind if kind == bison_kind.array -> {
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
          |> bson.Array
          |> Ok
        }

        _ -> Error(Nil)
      })
      case
        bit_array.slice(rest, doc_size, bit_array.byte_size(rest) - doc_size)
      {
        Ok(rest) -> recurse_with_new_kv(rest, storage, key, doc)
        Error(Nil) -> Error(Nil)
      }
    }

    kind if kind == bison_kind.binary -> {
      let <<byte_size:32-little-int, sub_code:8, rest:bits>> = rest
      let given_size = byte_size * 8
      let <<value:size(given_size)-bits, rest:bits>> = rest
      let sub_kind = bison_kind.SubKind(code: <<sub_code>>)
      case sub_kind {
        sub_kind if sub_kind == bison_kind.generic -> {
          use value <- result.then(generic.from_bit_array(value))

          recurse_with_new_kv(
            rest,
            storage,
            key,
            value
            |> bson.Generic
            |> bson.Binary,
          )
        }

        sub_kind if sub_kind == bison_kind.md5 -> {
          use value <- result.then(md5.from_bit_array(value))

          recurse_with_new_kv(
            rest,
            storage,
            key,
            value
            |> bson.MD5
            |> bson.Binary,
          )
        }

        sub_kind if sub_kind == bison_kind.uuid -> {
          use value <- result.then(uuid.from_bit_array(value))

          recurse_with_new_kv(
            rest,
            storage,
            key,
            value
            |> bson.UUID
            |> bson.Binary,
          )
        }

        _ if sub_code >= 0x80 -> {
          use value <- result.then(custom.from_bit_array_with_code(
            sub_code,
            value,
          ))

          recurse_with_new_kv(
            rest,
            storage,
            key,
            value
            |> bson.Custom
            |> bson.Binary,
          )
        }

        _ -> Error(Nil)
      }
    }

    _ -> Error(Nil)
  }
}

fn consume_till_zero(
  data: BitArray,
  storage: BitArray,
) -> Result(#(BitArray, BitArray), Nil) {
  case bit_array.byte_size(data) {
    0 -> Error(Nil)
    _ -> {
      let <<ch:8, rest:bits>> = data
      case ch {
        0 -> Ok(#(storage, rest))
        _ -> consume_till_zero(rest, bit_array.append(storage, <<ch>>))
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
