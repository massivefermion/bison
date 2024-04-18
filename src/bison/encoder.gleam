import gleam/bit_array
import gleam/dict
import gleam/int
import gleam/list

import bison/bson
import bison/custom
import bison/generic
import bison/kind
import bison/md5
import bison/object_id
import bison/uuid

import birl
import birl/duration

pub fn encode(doc: dict.Dict(String, bson.Value)) -> BitArray {
  case document(doc) {
    #(_, value) -> value
  }
}

pub fn encode_list(doc: List(#(String, bson.Value))) -> BitArray {
  case document_from_list(doc) {
    #(_, value) -> value
  }
}

fn document(doc: dict.Dict(String, bson.Value)) -> Entity {
  let doc =
    dict.fold(doc, <<>>, fn(acc, key, value) {
      bit_array.append(acc, encode_kv(#(key, value)))
    })

  let size = bit_array.byte_size(doc) + 5
  #(kind.document, bit_array.concat([<<size:32-little>>, doc, <<0>>]))
}

fn document_from_list(doc: List(#(String, bson.Value))) -> Entity {
  let doc =
    list.fold(doc, <<>>, fn(acc, kv) {
      bit_array.append(acc, encode_kv(#(kv.0, kv.1)))
    })

  let size = bit_array.byte_size(doc) + 5
  #(kind.document, bit_array.concat([<<size:32-little>>, doc, <<0>>]))
}

fn encode_kv(pair: #(String, bson.Value)) -> BitArray {
  let key = <<pair.0:utf8, 0>>

  let #(kind, value) = case pair.1 {
    bson.NaN -> nan()
    bson.Min -> min()
    bson.Max -> max()
    bson.Null -> null()
    bson.Infinity -> infinity()
    bson.JS(value) -> js(value)
    bson.Int32(value) -> int32(value)
    bson.Int64(value) -> int64(value)
    bson.Array(value) -> array(value)
    bson.Double(value) -> double(value)
    bson.String(value) -> string(value)
    bson.Boolean(value) -> boolean(value)
    bson.Document(value) -> document(value)
    bson.DateTime(value) -> datetime(value)
    bson.ObjectId(value) -> object_id(value)
    bson.Binary(bson.MD5(value)) -> md5(value)
    bson.NegativeInfinity -> negative_infinity()
    bson.Binary(bson.UUID(value)) -> uuid(value)
    bson.Binary(bson.Custom(value)) -> custom(value)
    bson.Binary(bson.Generic(value)) -> generic(value)
    bson.Regex(pattern, options) -> regex(pattern, options)
    bson.Timestamp(stamp, counter) -> timestamp(stamp, counter)
  }

  bit_array.concat([kind.code, key, value])
}

fn null() -> Entity {
  #(kind.null, <<>>)
}

fn nan() -> Entity {
  #(kind.double, <<"NaN":utf8>>)
}

fn infinity() -> Entity {
  #(kind.double, <<"Infinity":utf8>>)
}

fn negative_infinity() -> Entity {
  #(kind.double, <<"-Infinity":utf8>>)
}

fn min() -> Entity {
  #(kind.min, <<>>)
}

fn max() -> Entity {
  #(kind.max, <<>>)
}

fn js(value: String) -> Entity {
  let length = bit_array.byte_size(<<value:utf8>>) + 1
  #(kind.js, <<length:32-little, value:utf8, 0>>)
}

fn string(value: String) -> Entity {
  let length = bit_array.byte_size(<<value:utf8>>) + 1
  #(kind.string, <<length:32-little, value:utf8, 0>>)
}

fn array(value: List(bson.Value)) -> Entity {
  case
    list.index_map(value, fn(item, index) { #(int.to_string(index), item) })
    |> dict.from_list
    |> document
  {
    #(_, value) -> #(kind.array, value)
  }
}

fn boolean(value: Bool) -> Entity {
  case value {
    True -> #(kind.boolean, <<1>>)
    False -> #(kind.boolean, <<0>>)
  }
}

fn double(value: Float) -> Entity {
  #(kind.double, <<value:little-float>>)
}

fn int32(value: Int) -> Entity {
  case value >= kind.int32_min && value <= kind.int32_max {
    True -> #(kind.int32, <<value:32-little>>)
    False -> int64(value)
  }
}

fn int64(value: Int) -> Entity {
  case value >= kind.int64_min && value <= kind.int64_max {
    True -> #(kind.int64, <<value:64-little>>)
    False ->
      value
      |> int.to_float
      |> double
  }
}

fn datetime(value: birl.Time) -> Entity {
  let duration.Duration(value) = birl.difference(value, birl.unix_epoch)
  let value = value / 1000
  #(kind.datetime, <<value:64-little>>)
}

fn object_id(value: object_id.ObjectId) -> Entity {
  #(kind.object_id, object_id.to_bit_array(value))
}

fn timestamp(stamp: Int, counter: Int) -> Entity {
  #(kind.timestamp, <<counter:32-little, stamp:32-little>>)
}

fn md5(value: md5.MD5) -> Entity {
  let value = md5.to_bit_array(value)
  let length = bit_array.byte_size(value)

  #(kind.binary, bit_array.concat([<<length:32-little>>, kind.md5.code, value]))
}

fn uuid(value: uuid.UUID) -> Entity {
  let value = uuid.to_bit_array(value)
  let length = bit_array.byte_size(value)

  #(
    kind.binary,
    bit_array.concat([<<length:32-little>>, kind.uuid.code, value]),
  )
}

fn custom(value: custom.Custom) -> Entity {
  let #(code, value) = custom.to_bit_array_with_code(value)
  let length = bit_array.byte_size(value)

  #(kind.binary, bit_array.concat([<<length:32-little>>, <<code>>, value]))
}

fn generic(value: generic.Generic) -> Entity {
  let value = generic.to_bit_array(value)
  let length = bit_array.byte_size(value)

  #(
    kind.binary,
    bit_array.concat([<<length:32-little>>, kind.generic.code, value]),
  )
}

fn regex(pattern: String, options: String) -> Entity {
  #(kind.regex, bit_array.concat([<<pattern:utf8, 0, options:utf8, 0>>]))
}

type Entity =
  #(kind.Kind, BitArray)
