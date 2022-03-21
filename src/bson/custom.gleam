pub const min_binary_custom_code = 0x80

pub const max_binary_custom_code = 0xff

pub opaque type Custom {
  Custom(code: BitString, value: BitString)
}

pub fn to_bit_string_with_code(custom: Custom) {
  case custom {
    Custom(code: <<code>>, value: value) -> #(code, value)
  }
}

pub fn from_bit_string_with_code(code: Int, value: BitString) {
  case code <= max_binary_custom_code && code >= min_binary_custom_code {
    True -> Ok(Custom(code: <<code>>, value: value))
    False -> Error(Nil)
  }
}
