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

pub fn to_bit_string(binary: Binary) -> BitString {
  case binary {
    Generic(data) -> data
  }
}

pub fn from_string(data: String) -> Binary {
  Generic(bit_string.from_string(data))
}

pub fn from_bit_string(data: BitString) -> Result(Binary, Nil) {
  case bit_size(data) % 8 {
    0 -> Ok(Generic(data))
    _ -> Error(Nil)
  }
}
