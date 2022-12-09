import gleam/list
import gleam/queue
import gleam/string
import gleam/bit_string

pub opaque type UUID {
  UUID(BitString)
}

pub fn to_string(uuid: UUID) -> String {
  case uuid {
    UUID(value) -> to_string_internal(value, "")
  }
}

pub fn to_int_list(uuid: UUID) -> List(Int) {
  case uuid {
    UUID(value) -> to_int_list_internal(value, queue.new())
  }
}

pub fn to_bit_string(uuid: UUID) -> BitString {
  case uuid {
    UUID(value) -> value
  }
}

pub fn from_string(uuid: String) -> Result(UUID, Nil) {
  case string.length(uuid) {
    32 | 36 ->
      case
        uuid
        |> string.to_graphemes
        |> list.filter(fn(char) { char != "-" })
        |> list.try_map(to_digit)
      {
        Ok(codes) ->
          codes
          |> list.sized_chunk(2)
          |> list.map(fn(pair) {
            let [high, low] = pair
            <<high:4, low:4>>
          })
          |> bit_string.concat
          |> UUID
          |> Ok
        Error(Nil) -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

pub fn from_int_list(uuid: List(Int)) -> Result(UUID, Nil) {
  case list.length(uuid) {
    16 ->
      case
        list.try_fold(
          uuid,
          <<>>,
          fn(acc, code) {
            case code >= 0 && code <= 255 {
              True ->
                bit_string.append(acc, <<code>>)
                |> Ok
              False -> Error(Nil)
            }
          },
        )
      {
        Ok(uuid) -> Ok(UUID(uuid))
        Error(Nil) -> Error(Nil)
      }

    32 ->
      case
        list.try_map(
          uuid,
          fn(code) {
            case code >= 0 && code <= 15 {
              True -> Ok(code)
              False -> Error(Nil)
            }
          },
        )
      {
        Ok(codes) ->
          codes
          |> list.sized_chunk(2)
          |> list.map(fn(pair) {
            let [high, low] = pair
            let <<num:8>> = <<high:4, low:4>>
            num
          })
          |> list.fold(<<>>, fn(acc, code) { bit_string.append(acc, <<code>>) })
          |> UUID
          |> Ok
        Error(Nil) -> Error(Nil)
      }

    _ -> Error(Nil)
  }
}

pub fn from_bit_string(uuid: BitString) -> Result(UUID, Nil) {
  case bit_string.byte_size(uuid) {
    16 -> Ok(UUID(uuid))
    _ -> Error(Nil)
  }
}

fn to_string_internal(remaining: BitString, storage: String) -> String {
  let <<high:4, low:4, remaining:binary>> = remaining

  let new_storage =
    storage
    |> string.append(to_char(high))
    |> string.append(to_char(low))

  let new_storage = case string.length(new_storage) {
    8 | 13 | 18 | 23 -> string.append(new_storage, "-")
    _ -> new_storage
  }

  case bit_string.byte_size(remaining) {
    0 -> new_storage
    _ -> to_string_internal(remaining, new_storage)
  }
}

fn to_int_list_internal(
  remaining: BitString,
  storage: queue.Queue(Int),
) -> List(Int) {
  let <<num:8, remaining:binary>> = remaining

  let new_storage = queue.push_back(storage, num)

  case bit_string.byte_size(remaining) {
    0 -> queue.to_list(new_storage)
    _ -> to_int_list_internal(remaining, new_storage)
  }
}

fn to_digit(char: String) -> Result(Int, Nil) {
  let <<code>> = bit_string.from_string(char)

  case code {
    code if code >= 48 && code <= 57 -> {
      let <<_:4, num:4>> = bit_string.from_string(char)
      Ok(num)
    }

    code if code >= 65 && code <= 70 || code >= 97 && code <= 102 -> {
      let <<_:5, additive:3>> = bit_string.from_string(char)
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
