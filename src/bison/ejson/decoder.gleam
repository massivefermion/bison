import gleam/int
import gleam/map
import gleam/float
import gleam/result
import gleam/option
import gleam/dynamic
import gleam/bit_array
import gleam/json
import bison/md5
import bison/bson
import bison/uuid
import bison/custom
import bison/generic
import bison/object_id
import birl
import birl/duration

pub fn from_canonical(doc: String) {
  json.decode(
    doc,
    fn(data) {
      case dynamic.map(dynamic.string, value)(data) {
        Ok(map) -> Ok(map.to_list(map))
        Error(error) -> Error(error)
      }
    },
  )
}

fn document(dyn) {
  dynamic.decode1(
    bson.Document,
    fn(data) {
      case dynamic.map(dynamic.string, value)(data) {
        Ok(map) -> Ok(map.to_list(map))
        Error(error) -> Error(error)
      }
    },
  )(dyn)
}

fn value(dyn) {
  case
    dynamic.optional(dynamic.any([
      int,
      bool,
      double,
      min,
      max,
      oid,
      date,
      code,
      binary,
      regex,
      timestamp,
      typed_int,
      typed_long,
      typed_double,
      string,
      array,
      document,
    ]))(dyn)
  {
    Ok(option.Some(value)) -> Ok(value)
    Ok(option.None) -> Ok(bson.Null)
    Error(error) -> Error(error)
  }
}

fn array(dyn) {
  dynamic.decode1(bson.Array, dynamic.list(value))(dyn)
}

fn int(dyn) {
  dynamic.decode1(bson.Int32, dynamic.int)(dyn)
}

fn double(dyn) {
  dynamic.decode1(bson.Double, dynamic.float)(dyn)
}

fn bool(dyn) {
  dynamic.decode1(bson.Boolean, dynamic.bool)(dyn)
}

fn string(dyn) {
  dynamic.decode1(bson.String, dynamic.string)(dyn)
}

fn code(dyn) {
  dynamic.decode1(bson.JS, dynamic.field("$code", dynamic.string))(dyn)
}

fn oid(dyn) {
  dynamic.decode1(
    bson.ObjectId,
    dynamic.field(
      "$oid",
      fn(v) {
        v
        |> dynamic.string
        |> result.map(fn(s) {
          object_id.from_string(s)
          |> result.replace_error([
            dynamic.DecodeError("object id", "not object id", []),
          ])
        })
        |> result.flatten
      },
    ),
  )(dyn)
}

fn date(dyn) {
  dynamic.decode1(
    bson.DateTime,
    dynamic.field(
      "$date",
      fn(v) {
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
      },
    ),
  )(dyn)
}

fn timestamp(dyn) {
  case dynamic.field("$timestamp", document)(dyn) {
    Ok(bson.Document([#("i", bson.Int32(i)), #("t", bson.Int32(t))])) ->
      Ok(bson.Timestamp(t, i))
    _ -> Error([dynamic.DecodeError("timestamp", "not timestamp", [])])
  }
}

fn regex(dyn) {
  case dynamic.field("$regularExpression", document)(dyn) {
    Ok(bson.Document([
      #("pattern", bson.String(pattern)),
      #("options", bson.String(options)),
    ])) -> Ok(bson.Regex(pattern, options))
    _ -> Error([dynamic.DecodeError("timestamp", "not timestamp", [])])
  }
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
  case dynamic.field("$binary", document)(dyn) {
    Ok(bson.Document([
      #("base64", bson.String(base64)),
      #("subType", bson.String(sub_type)),
    ])) ->
      case bit_array.base64_decode(base64) {
        Ok(decoded) ->
          case sub_type {
            "00" ->
              case generic.from_bit_array(decoded) {
                Ok(generic) -> Ok(bson.Binary(bson.Generic(generic)))
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
                Ok(uuid) -> Ok(bson.Binary(bson.UUID(uuid)))
                Error(Nil) ->
                  Error([
                    dynamic.DecodeError("uuid binary", "not uuid binary", []),
                  ])
              }

            "05" ->
              case md5.from_bit_array(decoded) {
                Ok(md5) -> Ok(bson.Binary(bson.MD5(md5)))
                Error(Nil) ->
                  Error([
                    dynamic.DecodeError("md5 binary", "not md5 binary", []),
                  ])
              }
            _ ->
              case int.parse(sub_type) {
                Ok(code) ->
                  case custom.from_bit_array_with_code(code, decoded) {
                    Ok(custom) -> Ok(bson.Binary(bson.Custom(custom)))
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

        Error(Nil) -> Error([dynamic.DecodeError("binary", "not binary", [])])
      }
    _ -> Error([dynamic.DecodeError("binary", "not binary", [])])
  }
}
