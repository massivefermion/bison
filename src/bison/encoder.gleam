import gleam/int
import gleam/list
import gleam/dict
import gleam/bit_array
import bison/md5
import bison/uuid
import bison/kind
import bison/bson
import bison/custom
import bison/generic
import bison/object_id
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

type Entity =
  #(kind.Kind, BitArray)

fn document(doc: dict.Dict(String, bson.Value)) -> Entity {
  let doc =
    dict.fold(doc, <<>>, fn(acc, key, value) {
      bit_array.append(acc, encode_kv(#(key, value)))
    })

  let size = bit_array.byte_size(doc) + 5
  #(
    kind.document,
    [<<size:32-little>>, doc, <<0>>]
    |> bit_array.concat,
  )
}

fn document_from_list(doc: List(#(String, bson.Value))) -> Entity {
  let doc =
    list.fold(doc, <<>>, fn(acc, kv) {
      bit_array.append(acc, encode_kv(#(kv.0, kv.1)))
    })

  let size = bit_array.byte_size(doc) + 5
  #(
    kind.document,
    [<<size:32-little>>, doc, <<0>>]
    |> bit_array.concat,
  )
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
    bson.Int32(value) -> int(value, int32, kind.int32_min, kind.int32_max)
    bson.Int64(value) -> int(value, int64, kind.int64_min, kind.int64_max)
  }

  [kind.code, key, value]
  |> bit_array.concat
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

fn int(value: Int, encode_int: fn(Int) -> Entity, min: Int, max: Int) -> Entity {
  case value >= min && value <= max {
    True -> encode_int(value)
    False ->
      value
      |> int.to_float
      |> double
  }
}

fn double(value: Float) -> Entity {
  #(kind.double, <<value:little-float>>)
}

fn int32(value: Int) -> Entity {
  #(kind.int32, <<value:32-little>>)
}

fn int64(value: Int) -> Entity {
  #(kind.int64, <<value:64-little>>)
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

  #(
    kind.binary,
    [<<length:32-little>>, kind.md5.code, value]
    |> bit_array.concat,
  )
}

fn uuid(value: uuid.UUID) -> Entity {
  let value = uuid.to_bit_array(value)
  let length = bit_array.byte_size(value)

  #(
    kind.binary,
    [<<length:32-little>>, kind.uuid.code, value]
    |> bit_array.concat,
  )
}

fn custom(value: custom.Custom) -> Entity {
  let #(code, value) = custom.to_bit_array_with_code(value)
  let length = bit_array.byte_size(value)

  #(
    kind.binary,
    [<<length:32-little>>, <<code>>, value]
    |> bit_array.concat,
  )
}

fn generic(value: generic.Generic) -> Entity {
  let value = generic.to_bit_array(value)
  let length = bit_array.byte_size(value)

  #(
    kind.binary,
    [<<length:32-little>>, kind.generic.code, value]
    |> bit_array.concat,
  )
}

fn regex(pattern: String, options: String) -> Entity {
  #(
    kind.regex,
    [<<pattern:utf8, 0, options:utf8, 0>>]
    |> bit_array.concat,
  )
}
