import gleam/list
import gleam/queue
import gleam/bit_array

pub opaque type Generic {
  Generic(BitArray)
}

pub fn to_string(generic: Generic) -> Result(String, Nil) {
  case generic {
    Generic(data) -> bit_array.to_string(data)
  }
}

pub fn to_int_list(generic: Generic) -> List(Int) {
  case generic {
    Generic(data) -> to_int_list_internal(data, queue.new())
  }
}

pub fn to_bit_array(generic: Generic) -> BitArray {
  case generic {
    Generic(data) -> data
  }
}

pub fn from_string(data: String) -> Generic {
  Generic(bit_array.from_string(data))
}

pub fn from_int_list(data: List(Int)) -> Generic {
  data
  |> list.fold(<<>>, fn(acc, code) { bit_array.append(acc, <<code>>) })
  |> Generic
}

pub fn from_bit_array(data: BitArray) -> Result(Generic, Nil) {
  case bit_size(data) % 8 {
    0 -> Ok(Generic(data))
    _ -> Error(Nil)
  }
}

fn to_int_list_internal(
  remaining: BitArray,
  storage: queue.Queue(Int),
) -> List(Int) {
  let <<num:8, remaining:bytes>> = remaining

  let new_storage = queue.push_back(storage, num)

  case bit_array.byte_size(remaining) == 0 {
    True -> queue.to_list(new_storage)
    False -> to_int_list_internal(remaining, new_storage)
  }
}

@external(erlang, "erlang", "bit_size")
fn bit_size(a: BitArray) -> Int
