import gleam/bit_array
import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/pair
import gleam/result

import bison/bson
import bison/custom
import bison/generic
import bison/kind
import bison/md5
import bison/object_id
import bison/uuid

import birl
import birl/duration

pub fn decode(binary: BitArray) -> Result(dict.Dict(String, bson.Value), Nil) {
  case decode_document(binary) {
    Ok(bson.Document(doc)) -> Ok(doc)
    _ -> Error(Nil)
  }
}

fn decode_document(binary: BitArray) -> Result(bson.Value, Nil) {
  let total_size = bit_array.byte_size(binary)
  let last_byte = bit_array.slice(binary, total_size, -1)
  case last_byte {
    Ok(<<0>>) -> {
      case binary {
        <<given_size:32-little-int, rest:bits>> ->
          case total_size == given_size {
            True -> {
              use body <- result.then(bit_array.slice(
                rest,
                0,
                total_size - 4 - 1,
              ))
              use body <- result.then(decode_body(body, dict.new()))
              body
              |> bson.Document
              |> Ok
            }
            False -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn decode_body(
  binary: BitArray,
  storage: dict.Dict(String, bson.Value),
) -> Result(dict.Dict(String, bson.Value), Nil) {
  use <- bool.guard(bit_array.byte_size(binary) == 0, Ok(storage))

  case binary {
    <<code:8, binary:bits>> -> {
      use #(key, rest) <- result.then(consume_till_zero(binary, <<>>))
      use key <- result.then(bit_array.to_string(key))

      case kind.Kind(code: <<code>>) {
        k if k == kind.min -> recurse_with_new_kv(rest, storage, key, bson.Min)
        k if k == kind.max -> recurse_with_new_kv(rest, storage, key, bson.Max)
        k if k == kind.null ->
          recurse_with_new_kv(rest, storage, key, bson.Null)

        k if k == kind.int32 -> {
          case rest {
            <<value:32-little-signed, rest:bits>> ->
              recurse_with_new_kv(rest, storage, key, bson.Int32(value))
            _ -> Error(Nil)
          }
        }

        k if k == kind.int64 -> {
          case rest {
            <<value:64-little-signed, rest:bits>> ->
              recurse_with_new_kv(rest, storage, key, bson.Int64(value))
            _ -> Error(Nil)
          }
        }

        k if k == kind.double -> {
          case rest {
            <<"NaN":utf8, rest:bits>> ->
              recurse_with_new_kv(rest, storage, key, bson.NaN)
            <<"Infinity":utf8, rest:bits>> ->
              recurse_with_new_kv(rest, storage, key, bson.Infinity)
            <<"-Infinity":utf8, rest:bits>> ->
              recurse_with_new_kv(rest, storage, key, bson.NegativeInfinity)
            <<value:little-float, rest:bits>> ->
              recurse_with_new_kv(rest, storage, key, bson.Double(value))
            _ -> Error(Nil)
          }
        }

        k if k == kind.timestamp -> {
          case rest {
            <<counter:32-little-unsigned, stamp:32-little-unsigned, rest:bits>> ->
              recurse_with_new_kv(
                rest,
                storage,
                key,
                bson.Timestamp(stamp, counter),
              )
            _ -> Error(Nil)
          }
        }

        k if k == kind.object_id -> {
          case rest {
            <<value:96-bits, rest:bits>> -> {
              use oid <- result.then(object_id.from_bit_array(value))
              recurse_with_new_kv(rest, storage, key, bson.ObjectId(oid))
            }
            _ -> Error(Nil)
          }
        }

        k if k == kind.boolean -> {
          case rest {
            <<value:8, rest:bits>> -> {
              use value <- decode_boolean(value)
              recurse_with_new_kv(rest, storage, key, bson.Boolean(value))
            }
            _ -> Error(Nil)
          }
        }

        k if k == kind.datetime -> {
          case rest {
            <<value:64-little-signed, rest:bits>> -> {
              let value =
                birl.add(
                  birl.unix_epoch,
                  duration.accurate_new([#(value, duration.MilliSecond)]),
                )
              recurse_with_new_kv(rest, storage, key, bson.DateTime(value))
            }
            _ -> Error(Nil)
          }
        }

        k if k == kind.regex -> {
          use #(pattern_bytes, rest) <- result.then(
            consume_till_zero(rest, <<>>),
          )
          use #(options_bytes, rest) <- result.then(
            consume_till_zero(rest, <<>>),
          )
          use pattern <- result.then(bit_array.to_string(pattern_bytes))
          use options <- result.then(bit_array.to_string(options_bytes))
          recurse_with_new_kv(rest, storage, key, bson.Regex(pattern, options))
        }

        k if k == kind.string -> {
          case rest {
            <<given_size:32-little-int, rest:bits>> -> {
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
            _ -> Error(Nil)
          }
        }

        k if k == kind.js -> {
          case rest {
            <<given_size:32-little-int, rest:bits>> -> {
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
            _ -> Error(Nil)
          }
        }

        k if k == kind.document || k == kind.array -> {
          case rest {
            <<doc_size:32-little-int, _:bits>> -> {
              use doc <- result.then(bit_array.slice(rest, 0, doc_size))
              use doc <- result.then(decode_document(doc))
              case doc {
                bson.Document(doc) -> {
                  use doc <- result.then(case k {
                    k if k == kind.document ->
                      doc
                      |> bson.Document
                      |> Ok

                    k if k == kind.array -> {
                      use doc <- result.then(
                        list.try_map(dict.to_list(doc), fn(item) {
                          use first <- result.then(int.parse(item.0))
                          Ok(#(first, item.1))
                        }),
                      )
                      doc
                      |> list.sort(fn(a, b) { int.compare(a.0, b.0) })
                      |> list.map(pair.second)
                      |> bson.Array
                      |> Ok
                    }

                    _ -> Error(Nil)
                  })
                  case
                    bit_array.slice(
                      rest,
                      doc_size,
                      bit_array.byte_size(rest) - doc_size,
                    )
                  {
                    Ok(rest) -> recurse_with_new_kv(rest, storage, key, doc)
                    Error(Nil) -> Error(Nil)
                  }
                }
                _ -> Error(Nil)
              }
            }
            _ -> Error(Nil)
          }
        }

        k if k == kind.binary -> {
          case rest {
            <<byte_size:32-little-int, sub_code:8, rest:bits>> -> {
              let given_size = byte_size * 8
              case rest {
                <<value:size(given_size)-bits, rest:bits>> ->
                  case kind.SubKind(code: <<sub_code>>) {
                    sub_kind if sub_kind == kind.generic -> {
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

                    sub_kind if sub_kind == kind.md5 -> {
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

                    sub_kind if sub_kind == kind.uuid -> {
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
                _ -> Error(Nil)
              }
            }

            _ -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn consume_till_zero(
  binary: BitArray,
  storage: BitArray,
) -> Result(#(BitArray, BitArray), Nil) {
  case binary {
    <<ch:8, rest:bits>> ->
      case ch {
        0 -> Ok(#(storage, rest))
        _ -> consume_till_zero(rest, bit_array.append(storage, <<ch>>))
      }
    _ -> Error(Nil)
  }
}

fn recurse_with_new_kv(rest, storage, key, value) {
  decode_body(rest, dict.insert(storage, key, value))
}

fn decode_boolean(value, rest) {
  case value {
    0 -> rest(False)
    1 -> rest(True)
    _ -> Error(Nil)
  }
}
