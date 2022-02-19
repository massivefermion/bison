import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/bit_string

pub opaque type ObjectId {
  ObjectId(BitString)
}

pub fn to_bit_string(id: ObjectId) -> BitString {
  case id {
    ObjectId(value) -> value
  }
}

pub fn to_string(id: ObjectId) -> String {
  case id {
    ObjectId(value) ->
      value
      |> to_string_internal("")
  }
}

pub fn from_string(id: String) -> Result(ObjectId, Nil) {
  case id
  |> string.length == 24 {
    True -> {
      let codes =
        id
        |> string.to_graphemes
        |> list.map(fn(char) {
          let <<code>> =
            char
            |> bit_string.from_string
          code
        })
        |> list.map(fn(code) {
          code
          |> to_digit
        })
      case codes
      |> list.any(fn(item) { result.is_error(item) }) {
        False -> {
          let value =
            codes
            |> list.map(fn(item) {
              case item {
                Ok(char) -> char
              }
            })
            |> list.sized_chunk(2)
            |> list.map(fn(pair) {
              let [a, b] = pair
              <<a:4, b:4>>
            })
            |> bit_string.concat
          Ok(ObjectId(value))
        }
        True -> Error(Nil)
      }
    }
    False -> Error(Nil)
  }
}

pub fn from_bit_string(id: BitString) -> Result(ObjectId, Nil) {
  case bit_string.byte_size(id) == 12 {
    True -> Ok(ObjectId(id))
    False -> Error(Nil)
  }
}

fn to_string_internal(remaining: BitString, storage: String) -> String {
  let <<low:4, high:4, remaining:binary>> = remaining

  let new_storage =
    storage
    |> string.append(to_char(low))
    |> string.append(to_char(high))

  case bit_string.byte_size(remaining) == 0 {
    True -> new_storage
    False -> to_string_internal(remaining, new_storage)
  }
}

fn to_digit(char: Int) -> Result(Int, Nil) {
  case char >= 48 && char <= 57 {
    True -> Ok(char - 48)
    False ->
      case char >= 65 && char <= 70 {
        True -> Ok(char - 55)
        False ->
          case char >= 97 && char <= 102 {
            True -> Ok(char - 87)
            False -> Error(Nil)
          }
      }
  }
}

fn to_char(digit: Int) -> String {
  let ch = case digit < 10 {
    True -> digit + 48
    False -> digit + 87
  }
  case bit_string.to_string(<<ch>>) {
    Ok(ch) -> ch
  }
}
