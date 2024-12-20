import gleam/bit_array
import gleam/deque
import gleam/list

pub opaque type Generic {
  Generic(BitArray)
}

pub fn to_string(generic: Generic) -> Result(String, Nil) {
  case generic {
    Generic(binary) -> bit_array.to_string(binary)
  }
}

pub fn to_int_list(generic: Generic) -> List(Int) {
  case generic {
    Generic(binary) -> to_int_list_internal(binary, deque.new())
  }
}

pub fn to_bit_array(generic: Generic) -> BitArray {
  case generic {
    Generic(binary) -> binary
  }
}

pub fn from_string(binary: String) -> Generic {
  Generic(bit_array.from_string(binary))
}

pub fn from_int_list(binary: List(Int)) -> Generic {
  binary
  |> list.fold(<<>>, fn(acc, code) { bit_array.append(acc, <<code>>) })
  |> Generic
}

pub fn from_bit_array(binary: BitArray) -> Result(Generic, Nil) {
  case bit_array.bit_size(binary) % 8 {
    0 -> Ok(Generic(binary))
    _ -> Error(Nil)
  }
}

fn to_int_list_internal(
  remaining: BitArray,
  storage: deque.Deque(Int),
) -> List(Int) {
  let assert <<num:8, remaining:bytes>> = remaining
  let new_storage = deque.push_back(storage, num)
  case bit_array.byte_size(remaining) == 0 {
    True -> deque.to_list(new_storage)
    False -> to_int_list_internal(remaining, new_storage)
  }
}
