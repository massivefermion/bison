import gleam/int
import gleam/list
import gleam/bit_string
import bison/md5
import bison/uuid
import bison/kind
import bison/value
import bison/custom
import bison/generic
import bison/object_id
import birl/time
import birl/duration

type Entity {
  Entity(kind: kind.Kind, value: BitString)
}

pub fn encode(doc: List(#(String, value.Value))) -> BitString {
  case document(doc) {
    Entity(kind: _, value: value) -> value
  }
}

fn document(doc: List(#(String, value.Value))) -> Entity {
  let doc =
    doc
    |> list.map(encode_kv)
    |> bit_string.concat

  let size = bit_string.byte_size(doc) + 5
  Entity(
    kind: kind.document,
    value: [<<size:32-little>>, doc, <<0>>]
    |> bit_string.concat,
  )
}

fn encode_kv(pair: #(String, value.Value)) -> BitString {
  let key = <<pair.0:utf8, 0>>

  let value = case pair.1 {
    value.Null -> null()
    value.Min -> min()
    value.Max -> max()
    value.JS(value) -> js(value)
    value.Str(value) -> string(value)
    value.Array(value) -> array(value)
    value.Int32(value) -> int32(value)
    value.Int64(value) -> int64(value)
    value.Double(value) -> double(value)
    value.Boolean(value) -> boolean(value)
    value.Document(value) -> document(value)
    value.DateTime(value) -> datetime(value)
    value.ObjectId(value) -> object_id(value)
    value.Timestamp(value) -> timestamp(value)
    value.Binary(value.MD5(value)) -> md5(value)
    value.Binary(value.UUID(value)) -> uuid(value)
    value.Binary(value.Custom(value)) -> custom(value)
    value.Binary(value.Generic(value)) -> generic(value)
    value.Regex(#(pattern, options)) -> regex(pattern, options)
  }

  case value {
    Entity(kind: kind, value: value) ->
      [kind.code, key, value]
      |> bit_string.concat
  }
}

fn null() -> Entity {
  Entity(kind: kind.null, value: <<>>)
}

fn min() -> Entity {
  Entity(kind: kind.min, value: <<>>)
}

fn max() -> Entity {
  Entity(kind: kind.max, value: <<>>)
}

fn js(value: String) -> Entity {
  let length = bit_string.byte_size(<<value:utf8>>) + 1
  Entity(kind: kind.js, value: <<length:32-little, value:utf8, 0>>)
}

fn string(value: String) -> Entity {
  let length = bit_string.byte_size(<<value:utf8>>) + 1
  Entity(kind: kind.string, value: <<length:32-little, value:utf8, 0>>)
}

fn array(value: List(value.Value)) -> Entity {
  case
    list.index_map(value, fn(index, item) { #(int.to_string(index), item) })
    |> document
  {
    Entity(kind: _, value: value) -> Entity(kind: kind.array, value: value)
  }
}

fn double(value: Float) -> Entity {
  Entity(kind: kind.double, value: <<value:little-float>>)
}

fn boolean(value: Bool) -> Entity {
  case value {
    True -> Entity(kind: kind.boolean, value: <<1>>)
    False -> Entity(kind: kind.boolean, value: <<0>>)
  }
}

fn int32(value: Int) -> Entity {
  Entity(kind: kind.int32, value: <<value:32-little>>)
}

fn int64(value: Int) -> Entity {
  Entity(kind: kind.int64, value: <<value:64-little>>)
}

fn datetime(value: time.DateTime) -> Entity {
  let duration.Duration(value) = time.difference(value, time.unix_epoch)
  let value = value / 1000
  Entity(kind: kind.datetime, value: <<value:64-little>>)
}

fn object_id(value: object_id.ObjectId) -> Entity {
  Entity(kind: kind.object_id, value: object_id.to_bit_string(value))
}

fn timestamp(value: Int) -> Entity {
  Entity(kind: kind.timestamp, value: <<value:64-little>>)
}

fn md5(value: md5.MD5) -> Entity {
  let value = md5.to_bit_string(value)
  let length = bit_string.byte_size(value)

  Entity(
    kind: kind.binary,
    value: [<<length:32-little>>, kind.md5.code, value]
    |> bit_string.concat,
  )
}

fn uuid(value: uuid.UUID) -> Entity {
  let value = uuid.to_bit_string(value)
  let length = bit_string.byte_size(value)

  Entity(
    kind: kind.binary,
    value: [<<length:32-little>>, kind.uuid.code, value]
    |> bit_string.concat,
  )
}

fn custom(value: custom.Custom) -> Entity {
  let #(code, value) = custom.to_bit_string_with_code(value)
  let length = bit_string.byte_size(value)

  Entity(
    kind: kind.binary,
    value: [<<length:32-little>>, <<code>>, value]
    |> bit_string.concat,
  )
}

fn generic(value: generic.Generic) -> Entity {
  let value = generic.to_bit_string(value)
  let length = bit_string.byte_size(value)

  Entity(
    kind: kind.binary,
    value: [<<length:32-little>>, kind.generic.code, value]
    |> bit_string.concat,
  )
}

fn regex(pattern: String, options: String) -> Entity {
  Entity(
    kind: kind.regex,
    value: [<<pattern:utf8, 0, options:utf8, 0>>]
    |> bit_string.concat,
  )
}
