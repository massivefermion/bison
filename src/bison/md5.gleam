import gleam/bit_array
import gleam/list
import gleam/queue
import gleam/string

pub opaque type MD5 {
  MD5(BitArray)
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

pub fn to_bit_array(md5: MD5) -> BitArray {
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
            let assert [high, low] = pair
            <<high:4, low:4>>
          })
          |> bit_array.concat
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
        list.try_fold(md5, <<>>, fn(acc, code) {
          case code >= 0 && code <= 255 {
            True -> Ok(bit_array.append(acc, <<code>>))
            False -> Error(Nil)
          }
        })
      {
        Ok(md5) -> Ok(MD5(md5))
        Error(Nil) -> Error(Nil)
      }

    32 ->
      case
        list.try_map(md5, fn(code) {
          case code >= 0 && code <= 15 {
            True -> Ok(code)
            False -> Error(Nil)
          }
        })
      {
        Ok(codes) ->
          codes
          |> list.sized_chunk(2)
          |> list.map(fn(pair) {
            let assert [high, low] = pair
            let assert <<num:8>> = <<high:4, low:4>>
            num
          })
          |> list.fold(<<>>, fn(acc, code) { bit_array.append(acc, <<code>>) })
          |> MD5
          |> Ok
        Error(Nil) -> Error(Nil)
      }

    _ -> Error(Nil)
  }
}

pub fn from_bit_array(md5: BitArray) -> Result(MD5, Nil) {
  case bit_array.byte_size(md5) {
    16 -> Ok(MD5(md5))
    _ -> Error(Nil)
  }
}

fn to_string_internal(remaining: BitArray, storage: String) -> String {
  let assert <<high:4, low:4, remaining:bytes>> = remaining

  let new_storage =
    storage
    |> string.append(to_char(high))
    |> string.append(to_char(low))

  case bit_array.byte_size(remaining) {
    0 -> new_storage
    _ -> to_string_internal(remaining, new_storage)
  }
}

fn to_int_list_internal(
  remaining: BitArray,
  storage: queue.Queue(Int),
) -> List(Int) {
  let assert <<num:8, remaining:bytes>> = remaining
  let new_storage = queue.push_back(storage, num)
  case bit_array.byte_size(remaining) {
    0 -> queue.to_list(new_storage)
    _ -> to_int_list_internal(remaining, new_storage)
  }
}

fn to_digit(char: String) -> Result(Int, Nil) {
  let assert <<code>> = bit_array.from_string(char)

  case code {
    code if code >= 48 && code <= 57 -> {
      let assert <<_:4, num:4>> = bit_array.from_string(char)
      Ok(num)
    }

    code if code >= 65 && code <= 70 || code >= 97 && code <= 102 -> {
      let assert <<_:5, additive:3>> = bit_array.from_string(char)
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
  let assert Ok(digit) = bit_array.to_string(<<ch>>)
  digit
}
