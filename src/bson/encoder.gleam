import gleam/int
import gleam/list
import bson/types
import bson/object_id
import gleam/bit_string

pub fn array(list: List(types.Entity)) -> types.Entity {
  case list
  |> list.index_map(fn(index, item) {
    #(
      index
      |> int.to_string,
      item,
    )
  })
  |> document {
    types.Entity(kind: _, value: value) ->
      types.Entity(kind: types.array, value: value)
  }
}

pub fn document(list: List(#(String, types.Entity))) -> types.Entity {
  let doc =
    list
    |> list.map(fn(kv) { encode_kv(kv) })
    |> bit_string.concat

  let size = bit_string.byte_size(doc) + 5
  types.Entity(
    kind: types.document,
    value: [<<size:32-little>>, doc, <<0>>]
    |> bit_string.concat,
  )
}

pub fn string(value: String) -> types.Entity {
  let length = bit_string.byte_size(<<value:utf8>>) + 1
  types.Entity(kind: types.string, value: <<length:32-little, value:utf8, 0>>)
}

pub fn double(value: Float) -> types.Entity {
  types.Entity(kind: types.double, value: <<value:little-float>>)
}

pub fn null() -> types.Entity {
  types.Entity(kind: types.null, value: <<>>)
}

pub fn boolean(value: Bool) -> types.Entity {
  case value {
    True -> types.Entity(kind: types.boolean, value: <<1>>)
    False -> types.Entity(kind: types.boolean, value: <<0>>)
  }
}

pub fn integer(value: Int) -> types.Entity {
  case value < types.int32_max && value > types.int32_min {
    True -> types.Entity(kind: types.int32, value: <<value:32-little>>)
    False -> types.Entity(kind: types.int64, value: <<value:64-little>>)
  }
}

pub fn object_id(value: String) -> Result(types.Entity, Nil) {
  case object_id.from_string(value) {
    Ok(value) ->
      Ok(types.Entity(
        kind: types.object_id,
        value: value
        |> object_id.to_bit_string,
      ))
    Error(Nil) -> Error(Nil)
  }
}

fn encode_kv(pair: #(String, types.Entity)) -> BitString {
  let key = <<pair.0:utf8, 0>>

  case pair.1 {
    types.Entity(kind: kind, value: value) ->
      [kind.code, key, value]
      |> bit_string.concat
  }
}
