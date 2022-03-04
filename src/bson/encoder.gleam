import gleam/int
import gleam/list
import bson/types
import bson/object_id
import gleam/bit_string

type Entity {
  Entity(kind: types.Kind, value: BitString)
}

pub fn encode(doc: List(#(String, types.Value))) -> BitString {
  case document(doc) {
    Entity(kind: _, value: value) -> value
  }
}

fn document(doc: List(#(String, types.Value))) -> Entity {
  let doc =
    doc
    |> list.reverse
    |> list.map(fn(kv) { encode_kv(kv) })
    |> bit_string.concat

  let size = bit_string.byte_size(doc) + 5
  Entity(
    kind: types.document,
    value: [<<size:32-little>>, doc, <<0>>]
    |> bit_string.concat,
  )
}

fn encode_kv(pair: #(String, types.Value)) -> BitString {
  let key = <<pair.0:utf8, 0>>

  let value = case pair.1 {
    types.Null -> null()
    types.Min -> min()
    types.Max -> max()
    types.JS(value) -> js(value)
    types.Str(value) -> string(value)
    types.Array(value) -> array(value)
    types.Double(value) -> double(value)
    types.Boolean(value) -> boolean(value)
    types.Integer(value) -> integer(value)
    types.Document(value) -> document(value)
    types.DateTime(value) -> datetime(value)
    types.ObjectId(value) -> object_id(value)
    types.Timestamp(value) -> timestamp(value)
  }

  case value {
    Entity(kind: kind, value: value) ->
      [kind.code, key, value]
      |> bit_string.concat
  }
}

fn array(list: List(types.Value)) -> Entity {
  case list
  |> list.index_map(fn(index, item) {
    #(
      index
      |> int.to_string,
      item,
    )
  })
  |> list.reverse
  |> document {
    Entity(kind: _, value: value) -> Entity(kind: types.array, value: value)
  }
}

fn string(value: String) -> Entity {
  let length = bit_string.byte_size(<<value:utf8>>) + 1
  Entity(kind: types.string, value: <<length:32-little, value:utf8, 0>>)
}

fn double(value: Float) -> Entity {
  Entity(kind: types.double, value: <<value:little-float>>)
}

fn null() -> Entity {
  Entity(kind: types.null, value: <<>>)
}

fn boolean(value: Bool) -> Entity {
  case value {
    True -> Entity(kind: types.boolean, value: <<1>>)
    False -> Entity(kind: types.boolean, value: <<0>>)
  }
}

fn integer(value: Int) -> Entity {
  case value < types.int32_max && value > types.int32_min {
    True -> Entity(kind: types.int32, value: <<value:32-little>>)
    False -> Entity(kind: types.int64, value: <<value:64-little>>)
  }
}

fn datetime(value: Int) -> Entity {
  Entity(kind: types.datetime, value: <<value:64-little>>)
}

fn timestamp(value: Int) -> Entity {
  Entity(kind: types.timestamp, value: <<value:64-little>>)
}

fn js(value: String) -> Entity {
  let length = bit_string.byte_size(<<value:utf8>>) + 1
  Entity(kind: types.js, value: <<length:32-little, value:utf8, 0>>)
}

fn min() -> Entity {
  Entity(kind: types.min, value: <<>>)
}

fn max() -> Entity {
  Entity(kind: types.max, value: <<>>)
}

fn object_id(value: object_id.ObjectId) -> Entity {
  Entity(
    kind: types.object_id,
    value: value
    |> object_id.to_bit_string,
  )
}
