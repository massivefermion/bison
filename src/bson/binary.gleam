import gleam/list
import gleam/bit_string

external fn bit_size(BitString) -> Int =
  "erlang" "bit_size"

pub opaque type Binary {
  Generic(BitString)
}

pub fn to_string(binary: Binary) -> Result(String, Nil) {
  case binary {
    Generic(data) -> bit_string.to_string(data)
  }
}

pub fn to_int_list(binary: Binary) -> List(Int) {
  case binary {
    Generic(data) ->
      data
      |> to_int_list_internal([])
  }
}

pub fn to_bit_string(binary: Binary) -> BitString {
  case binary {
    Generic(data) -> data
  }
}

pub fn from_string(data: String) -> Binary {
  Generic(bit_string.from_string(data))
}

pub fn from_int_list(data: List(Int)) -> Binary {
  Generic(
    data
    |> list.fold(
      <<>>,
      fn(acc, code) {
        acc
        |> bit_string.append(<<code>>)
      },
    ),
  )
}

pub fn from_bit_string(data: BitString) -> Result(Binary, Nil) {
  case bit_size(data) % 8 {
    0 -> Ok(Generic(data))
    _ -> Error(Nil)
  }
}

fn to_int_list_internal(remaining: BitString, storage: List(Int)) -> List(Int) {
  let <<num:8, remaining:binary>> = remaining

  let new_storage =
    storage
    |> list.append([num])

  case bit_string.byte_size(remaining) == 0 {
    True -> new_storage
    False -> to_int_list_internal(remaining, new_storage)
  }
}
