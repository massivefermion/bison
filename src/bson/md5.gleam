import gleam/list
import gleam/queue
import gleam/string
import gleam/bit_string

pub opaque type MD5 {
  MD5(BitString)
}

pub fn to_string(md5: MD5) -> String {
  case md5 {
    MD5(value) -> to_string_internal(value, "")
  }
}

pub fn to_int_list(md5: MD5) -> List(Int) {
  case md5 {
    MD5(value) -> to_int_list_internal(value, queue.new())
  }
}

pub fn to_bit_string(md5: MD5) -> BitString {
  case md5 {
    MD5(value) -> value
  }
}

pub fn from_string(md5: String) -> Result(MD5, Nil) {
  case string.length(md5) == 32 {
    True ->
      case
        md5
        |> string.to_graphemes
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
          |> MD5
          |> Ok
        Error(Nil) -> Error(Nil)
      }
    False -> Error(Nil)
  }
}

pub fn from_int_list(md5: List(Int)) -> Result(MD5, Nil) {
  case list.length(md5) {
    16 ->
      case
        list.try_fold(
          md5,
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
        Ok(md5) -> Ok(MD5(md5))
        Error(Nil) -> Error(Nil)
      }

    32 ->
      case
        list.try_map(
          md5,
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
          |> MD5
          |> Ok
        Error(Nil) -> Error(Nil)
      }

    _ -> Error(Nil)
  }
}

pub fn from_bit_string(md5: BitString) -> Result(MD5, Nil) {
  case bit_string.byte_size(md5) {
    16 -> Ok(MD5(md5))
    _ -> Error(Nil)
  }
}

fn to_string_internal(remaining: BitString, storage: String) -> String {
  let <<high:4, low:4, remaining:binary>> = remaining

  let new_storage =
    storage
    |> string.append(to_char(high))
    |> string.append(to_char(low))

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
