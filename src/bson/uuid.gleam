import gleam/list
import gleam/string
import gleam/bit_string

pub opaque type UUID {
  UUID(BitString)
}

pub fn to_string(uuid: UUID) -> String {
  case uuid {
    UUID(value) ->
      value
      |> to_string_internal("")
  }
}

pub fn to_int_list(uuid: UUID) -> List(Int) {
  case uuid {
    UUID(value) ->
      value
      |> to_int_list_internal([])
  }
}

pub fn to_bit_string(uuid: UUID) -> BitString {
  case uuid {
    UUID(value) -> value
  }
}

pub fn from_string(uuid: String) -> Result(UUID, Nil) {
  case uuid
  |> string.length {
    32 | 36 ->
      case uuid
      |> string.to_graphemes
      |> list.filter(fn(char) { char != "-" })
      |> list.try_map(to_digit) {
        Ok(codes) -> {
          let value =
            codes
            |> list.sized_chunk(2)
            |> list.map(fn(pair) {
              let [high, low] = pair
              <<high:4, low:4>>
            })
            |> bit_string.concat
          Ok(UUID(value))
        }
        Error(Nil) -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

pub fn from_int_list(uuid: List(Int)) -> Result(UUID, Nil) {
  case uuid
  |> list.length {
    16 ->
      case uuid
      |> list.try_fold(
        <<>>,
        fn(acc, code) {
          case code >= 0 && code <= 255 {
            True ->
              Ok(
                acc
                |> bit_string.append(<<code>>),
              )
            False -> Error(Nil)
          }
        },
      ) {
        Ok(uuid) -> Ok(UUID(uuid))
        Error(Nil) -> Error(Nil)
      }

    32 ->
      case uuid
      |> list.try_map(fn(code) {
        case code >= 0 && code <= 15 {
          True -> Ok(code)
          False -> Error(Nil)
        }
      }) {
        Ok(codes) ->
          Ok(UUID(
            codes
            |> list.sized_chunk(2)
            |> list.map(fn(pair) {
              let [high, low] = pair
              let <<num:8>> = <<high:4, low:4>>
              num
            })
            |> list.fold(
              <<>>,
              fn(acc, code) {
                acc
                |> bit_string.append(<<code>>)
              },
            ),
          ))
        Error(Nil) -> Error(Nil)
      }

    _ -> Error(Nil)
  }
}

pub fn from_bit_string(uuid: BitString) -> Result(UUID, Nil) {
  case bit_string.byte_size(uuid) == 16 {
    True -> Ok(UUID(uuid))
    False -> Error(Nil)
  }
}

fn to_string_internal(remaining: BitString, storage: String) -> String {
  let <<high:4, low:4, remaining:binary>> = remaining

  let new_storage =
    storage
    |> string.append(to_char(high))
    |> string.append(to_char(low))

  let new_storage = case new_storage
  |> string.length {
    8 | 13 | 18 | 23 ->
      new_storage
      |> string.append("-")

    _ -> new_storage
  }

  case bit_string.byte_size(remaining) == 0 {
    True -> new_storage
    False -> to_string_internal(remaining, new_storage)
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

fn to_digit(char: String) -> Result(Int, Nil) {
  let <<code>> =
    char
    |> bit_string.from_string

  case code {
    code if code >= 48 && code <= 57 -> {
      let <<_:4, num:4>> =
        char
        |> bit_string.from_string
      Ok(num)
    }

    code if code >= 65 && code <= 70 || code >= 97 && code <= 102 -> {
      let <<_:5, additive:3>> =
        char
        |> bit_string.from_string
      Ok(9 + additive)
    }

    _ -> Error(Nil)
  }
}

fn to_char(digit: Int) -> String {
  let ch = case digit < 10 {
    True -> digit + 48
    False -> digit + 87
  }
  assert Ok(digit) = bit_string.to_string(<<ch>>)
  digit
}
