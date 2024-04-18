import gleam/bit_array
import gleam/dict
import gleam/dynamic
import gleam/float
import gleam/int
import gleam/list
import gleam/result

import bison/bson
import bison/custom
import bison/generic
import bison/md5
import bison/object_id
import bison/uuid

import birl
import birl/duration
import juno

pub fn from_canonical(doc: String) {
  use doc <- result.then(
    juno.decode_object(doc, [
      oid,
      date,
      timestamp,
      regex,
      min,
      max,
      typed_int,
      typed_long,
      typed_double,
      binary,
      code,
    ]),
  )
  let assert bson.Document(doc) = map_value(doc)
  Ok(doc)
}

fn map_value(value) {
  case value {
    juno.Null -> bson.Null
    juno.Custom(value) -> value
    juno.Int(value) -> bson.Int64(value)
    juno.Bool(value) -> bson.Boolean(value)
    juno.Float(value) -> bson.Double(value)
    juno.String(value) -> bson.String(value)
    juno.Array(values) -> bson.Array(list.map(values, map_value))
    juno.Object(value) ->
      bson.Document(
        dict.from_list(
          list.map(dict.to_list(value), fn(kv) { #(kv.0, map_value(kv.1)) }),
        ),
      )
  }
}

fn code(dyn) {
  dynamic.decode1(bson.JS, dynamic.field("$code", dynamic.string))(dyn)
}

fn oid(dyn) {
  dynamic.decode1(
    bson.ObjectId,
    dynamic.field("$oid", fn(v) {
      v
      |> dynamic.string
      |> result.map(fn(s) {
        object_id.from_string(s)
        |> result.replace_error([
          dynamic.DecodeError("object id", "not object id", []),
        ])
      })
      |> result.flatten
    }),
  )(dyn)
}

fn date(dyn) {
  dynamic.decode1(
    bson.DateTime,
    dynamic.field("$date", fn(v) {
      v
      |> typed_long
      |> result.map(fn(n) {
        case n {
          bson.Int64(n) ->
            Ok(birl.add(birl.unix_epoch, duration.Duration(n * 1000)))
          _ -> Error([dynamic.DecodeError("long", "not long", [])])
        }
      })
      |> result.flatten
    }),
  )(dyn)
}

fn timestamp(dyn) {
  dynamic.decode2(
    bson.Timestamp,
    dynamic.field("$timestamp", dynamic.field("t", dynamic.int)),
    dynamic.field("$timestamp", dynamic.field("i", dynamic.int)),
  )(dyn)
}

fn regex(dyn) {
  dynamic.decode2(
    bson.Regex,
    dynamic.field(
      "$regularExpression",
      dynamic.field("pattern", dynamic.string),
    ),
    dynamic.field(
      "$regularExpression",
      dynamic.field("options", dynamic.string),
    ),
  )(dyn)
}

fn min(dyn) {
  dyn
  |> dynamic.field("$minKey", dynamic.int)
  |> result.map(fn(s) {
    case s {
      1 -> Ok(bson.Min)
      _ -> Error([dynamic.DecodeError("1", int.to_string(s), [])])
    }
  })
  |> result.flatten
}

fn max(dyn) {
  dyn
  |> dynamic.field("$maxKey", dynamic.int)
  |> result.map(fn(s) {
    case s {
      1 -> Ok(bson.Max)
      _ -> Error([dynamic.DecodeError("1", int.to_string(s), [])])
    }
  })
  |> result.flatten
}

fn typed_int(dyn) {
  dyn
  |> dynamic.field("$numberInt", dynamic.string)
  |> result.map(fn(s) {
    case int.parse(s) {
      Ok(n) -> Ok(bson.Int32(n))
      _ -> Error([dynamic.DecodeError("Integer", s, [])])
    }
  })
  |> result.flatten
}

fn typed_long(dyn) {
  dyn
  |> dynamic.field("$numberLong", dynamic.string)
  |> result.map(fn(s) {
    case int.parse(s) {
      Ok(n) -> Ok(bson.Int64(n))
      _ -> Error([dynamic.DecodeError("Integer", s, [])])
    }
  })
  |> result.flatten
}

fn typed_double(dyn) {
  dyn
  |> dynamic.field("$numberDouble", dynamic.string)
  |> result.map(fn(s) {
    case s {
      "NaN" -> Ok(bson.NaN)
      "infinity" -> Ok(bson.Infinity)
      "-infinity" -> Ok(bson.NegativeInfinity)
      _ ->
        case float.parse(s) {
          Ok(f) -> Ok(bson.Double(f))
          Error(Nil) ->
            Error([
              dynamic.DecodeError(
                "Floating point number, NaN, Infinity or -Infinity",
                s,
                [],
              ),
            ])
        }
    }
  })
  |> result.flatten
}

fn binary(dyn) {
  dynamic.decode1(
    bson.Binary,
    dynamic.field("$binary", fn(v) {
      v
      |> dynamic.dict(dynamic.string, dynamic.string)
      |> result.map(fn(bin_doc) {
        case dict.get(bin_doc, "base64"), dict.get(bin_doc, "subType") {
          Ok(base64), Ok(sub_type) ->
            case bit_array.base64_decode(base64) {
              Ok(decoded) ->
                case sub_type {
                  "00" ->
                    case generic.from_bit_array(decoded) {
                      Ok(generic) -> Ok(bson.Generic(generic))
                      Error(Nil) ->
                        Error([
                          dynamic.DecodeError(
                            "generic binary",
                            "not generic binary",
                            [],
                          ),
                        ])
                    }

                  "04" ->
                    case uuid.from_bit_array(decoded) {
                      Ok(uuid) -> Ok(bson.UUID(uuid))
                      Error(Nil) ->
                        Error([
                          dynamic.DecodeError(
                            "uuid binary",
                            "not uuid binary",
                            [],
                          ),
                        ])
                    }

                  "05" ->
                    case md5.from_bit_array(decoded) {
                      Ok(md5) -> Ok(bson.MD5(md5))
                      Error(Nil) ->
                        Error([
                          dynamic.DecodeError(
                            "md5 binary",
                            "not md5 binary",
                            [],
                          ),
                        ])
                    }

                  _ ->
                    case int.parse(sub_type) {
                      Ok(code) ->
                        case custom.from_bit_array_with_code(code, decoded) {
                          Ok(custom) -> Ok(bson.Custom(custom))
                          Error(Nil) ->
                            Error([
                              dynamic.DecodeError(
                                "valid custom binary code",
                                "invalid custom binary code",
                                [],
                              ),
                            ])
                        }

                      Error(Nil) ->
                        Error([
                          dynamic.DecodeError(
                            "valid custom binary code",
                            "invalid custom binary code",
                            [],
                          ),
                        ])
                    }
                }

              _ -> Error([dynamic.DecodeError("binary", "not binary", [])])
            }
          _, _ -> Error([dynamic.DecodeError("binary", "not binary", [])])
        }
      })
      |> result.flatten
    }),
  )(dyn)
}
