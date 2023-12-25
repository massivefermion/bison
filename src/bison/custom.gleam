pub const min_binary_custom_code = 0x80

pub const max_binary_custom_code = 0xff

pub opaque type Custom {
  Custom(code: BitArray, value: BitArray)
}

pub fn to_bit_array_with_code(custom: Custom) {
  let assert Custom(code: <<code>>, value: value) = custom
  #(code, value)
}

pub fn from_bit_array_with_code(code: Int, value: BitArray) {
  case code <= max_binary_custom_code && code >= min_binary_custom_code {
    True -> Ok(Custom(code: <<code>>, value: value))
    False -> Error(Nil)
  }
}
