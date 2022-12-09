import gleam/int
import gleam/list
import gleam/queue
import gleam/crypto
import gleam/string
import gleam/bit_string

pub opaque type ObjectId {
  ObjectId(BitString)
}

type TimeUnit {
  Second
}

pub fn new() -> ObjectId {
  let moment = now(Second)
  let counter = int.random(0, 0xffffff)

  assert Ok(hostname) = get_hostname()
  let <<machine_id:size(24), _:bit_string>> =
    crypto.hash(crypto.Sha256, hostname)

  assert Ok(string_pid) =
    get_pid()
    |> list.fold(<<>>, fn(acc, c) { <<acc:bit_string, c>> })
    |> bit_string.to_string

  assert Ok(pid) = int.parse(string_pid)

  assert Ok(id) =
    <<moment:big-32, machine_id:big-24, pid:big-16, counter:big-24>>
    |> from_bit_string

  id
}

pub fn get_timestamp(id: ObjectId) {
  case id {
    ObjectId(<<timestamp:big-32, _:bit_string>>) -> timestamp
  }
}

pub fn to_string(id: ObjectId) -> String {
  case id {
    ObjectId(value) -> to_string_internal(value, "")
  }
}

pub fn to_int_list(id: ObjectId) -> List(Int) {
  case id {
    ObjectId(value) -> to_int_list_internal(value, queue.new())
  }
}

pub fn to_bit_string(id: ObjectId) -> BitString {
  case id {
    ObjectId(value) -> value
  }
}

pub fn from_string(id: String) -> Result(ObjectId, Nil) {
  case string.length(id) {
    24 ->
      case
        id
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
          |> ObjectId
          |> Ok
        Error(Nil) -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

pub fn from_int_list(id: List(Int)) -> Result(ObjectId, Nil) {
  case list.length(id) {
    12 ->
      case
        list.try_fold(
          id,
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
        Ok(id) -> Ok(ObjectId(id))
        Error(Nil) -> Error(Nil)
      }

    24 ->
      case
        list.try_map(
          id,
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
          |> ObjectId
          |> Ok
        Error(Nil) -> Error(Nil)
      }

    _ -> Error(Nil)
  }
}

pub fn from_bit_string(id: BitString) -> Result(ObjectId, Nil) {
  case bit_string.byte_size(id) {
    12 -> Ok(ObjectId(id))
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

external fn get_hostname() -> Result(BitString, Nil) =
  "inet" "gethostname"

external fn get_pid() -> List(Int) =
  "os" "getpid"

external fn now(unit: TimeUnit) -> Int =
  "os" "system_time"
