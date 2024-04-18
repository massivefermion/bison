import gleam/dynamic
import gleam/result

import bison/bson
import bison/object_id

import birl
import birl/duration

pub fn min(dyn) {
  case dynamic.from(bson.Min) == dyn {
    True -> Ok(bson.Min)
    False -> Error([dynamic.DecodeError("Min", dynamic.classify(dyn), [])])
  }
}

pub fn max(dyn) {
  case dynamic.from(bson.Max) == dyn {
    True -> Ok(bson.Max)
    False -> Error([dynamic.DecodeError("Max", dynamic.classify(dyn), [])])
  }
}

pub fn nan(dyn) {
  case dynamic.from(bson.NaN) == dyn {
    True -> Ok(bson.NaN)
    False -> Error([dynamic.DecodeError("NaN", dynamic.classify(dyn), [])])
  }
}

pub fn nil(dyn) {
  case dynamic.from(bson.Null) == dyn {
    True -> Ok(Nil)
    False -> Error([dynamic.DecodeError("Null", dynamic.classify(dyn), [])])
  }
}

pub fn infinity(dyn) {
  case dynamic.from(bson.Infinity) == dyn {
    True -> Ok(bson.Infinity)
    False -> Error([dynamic.DecodeError("Infinity", dynamic.classify(dyn), [])])
  }
}

pub fn negative_infinity(dyn) {
  case dynamic.from(bson.NegativeInfinity) == dyn {
    True -> Ok(bson.NegativeInfinity)
    False ->
      Error([
        dynamic.DecodeError("Negative Infinity", dynamic.classify(dyn), []),
      ])
  }
}

pub fn js(dyn) {
  wrap(dynamic.string)(dyn)
}

pub fn string(dyn) {
  wrap(dynamic.string)(dyn)
}

pub fn int(dyn) {
  wrap(dynamic.int)(dyn)
}

pub fn float(dyn) {
  wrap(dynamic.float)(dyn)
}

pub fn bool(dyn) {
  wrap(dynamic.bool)(dyn)
}

pub fn bit_array(dyn) {
  {
    dynamic.any([dynamic.element(2, dynamic.bit_array), wrap(dynamic.bit_array)])
    |> wrap
    |> wrap
  }(dyn)
}

pub fn time(dyn) {
  use value <- result.then({ wrap(dynamic.element(1, dynamic.int)) }(dyn))

  Ok(birl.add(
    birl.unix_epoch,
    duration.accurate_new([#(value, duration.MicroSecond)]),
  ))
}

pub fn object_id(dyn) {
  use value <- result.then({ wrap(dynamic.element(1, dynamic.bit_array)) }(dyn))

  result.replace_error(object_id.from_bit_array(value), [
    dynamic.DecodeError("object id", "bit array", []),
  ])
}

pub fn timestamp(dyn) {
  use timestamp <- result.then(dynamic.element(1, dynamic.int)(dyn))
  use counter <- result.then(dynamic.element(2, dynamic.int)(dyn))
  Ok(#(timestamp, counter))
}

pub fn regex(dyn) {
  use pattern <- result.then(dynamic.element(1, dynamic.string)(dyn))
  use options <- result.then(dynamic.element(2, dynamic.string)(dyn))
  Ok(#(pattern, options))
}

pub fn list(value_decoder) {
  wrap(dynamic.list(value_decoder))
}

pub fn dict(value_decoder) {
  wrap(dynamic.dict(dynamic.string, value_decoder))
}

pub fn wrap(decoder) {
  dynamic.element(1, decoder)
}
