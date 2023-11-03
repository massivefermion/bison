import gleam/int
import gleam/list
import gleam/order
import gleam/queue
import gleam/option
import gleam/string
import gleam/iterator
import gleam/bit_array
import gleam/crypto
import birl/time
import birl/duration

pub opaque type ObjectId {
  ObjectId(BitArray)
}

pub fn new() -> ObjectId {
  from_datetime(time.utc_now())
}

/// see [birl](https://hex.pm/packages/birl)!
pub fn from_datetime(datetime: time.DateTime) -> ObjectId {
  let moment = time.to_unix(datetime)
  let assert Ok(counter) = int.modulo(time.monotonic_now(), 0xffffff)

  let assert Ok(hostname) = get_hostname()
  let <<machine_id:size(24), _:bits>> = crypto.hash(crypto.Sha256, hostname)

  let assert Ok(string_pid) =
    get_pid()
    |> list.fold(<<>>, fn(acc, c) { <<acc:bits, c>> })
    |> bit_array.to_string

  let assert Ok(pid) = int.parse(string_pid)

  let assert Ok(id) =
    <<moment:big-32, machine_id:big-24, pid:big-16, counter:big-24>>
    |> from_bit_array

  id
}

/// see [birl](https://hex.pm/packages/birl)!
pub fn to_datetime(id: ObjectId) -> time.DateTime {
  case id {
    ObjectId(<<timestamp:big-32, _:bits>>) -> time.from_unix(timestamp)
  }
}

/// can be used to create a time range starting from time `a` with step `s`,
/// which is of type `duration.Duration` from package [birl](https://hex.pm/packages/birl)
///
/// if `b` is `option.None` the range will be infinite
pub fn range(
  from a: ObjectId,
  to b: option.Option(ObjectId),
  step s: duration.Duration,
) {
  time.range(to_datetime(a), option.map(b, to_datetime), s)
  |> iterator.map(from_datetime)
}

pub fn compare(a: ObjectId, b: ObjectId) -> order.Order {
  let ObjectId(<<moment_a:big-32, _:big-24, _:big-16, counter_a:big-24>>) = a
  let ObjectId(<<moment_b:big-32, _:big-24, _:big-16, counter_b:big-24>>) = b

  case moment_a == moment_b {
    True ->
      case counter_a == counter_b {
        True -> order.Eq
        False ->
          case counter_a < counter_b {
            True -> order.Lt
            False -> order.Gt
          }
      }
    False ->
      case moment_a < moment_b {
        True -> order.Lt
        False -> order.Gt
      }
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

pub fn to_bit_array(id: ObjectId) -> BitArray {
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
          |> bit_array.concat
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
                bit_array.append(acc, <<code>>)
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
          |> list.fold(<<>>, fn(acc, code) { bit_array.append(acc, <<code>>) })
          |> ObjectId
          |> Ok
        Error(Nil) -> Error(Nil)
      }

    _ -> Error(Nil)
  }
}

pub fn from_bit_array(id: BitArray) -> Result(ObjectId, Nil) {
  case bit_array.byte_size(id) {
    12 -> Ok(ObjectId(id))
    _ -> Error(Nil)
  }
}

fn to_string_internal(remaining: BitArray, storage: String) -> String {
  let <<high:4, low:4, remaining:bytes>> = remaining

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
  let <<num:8, remaining:bytes>> = remaining

  let new_storage = queue.push_back(storage, num)

  case bit_array.byte_size(remaining) {
    0 -> queue.to_list(new_storage)
    _ -> to_int_list_internal(remaining, new_storage)
  }
}

fn to_digit(char: String) -> Result(Int, Nil) {
  let <<code>> = bit_array.from_string(char)

  case code {
    code if code >= 48 && code <= 57 -> {
      let <<_:4, num:4>> = bit_array.from_string(char)
      Ok(num)
    }

    code if code >= 65 && code <= 70 || code >= 97 && code <= 102 -> {
      let <<_:5, additive:3>> = bit_array.from_string(char)
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

@external(erlang, "inet", "gethostname")
fn get_hostname() -> Result(BitArray, Nil)

@external(erlang, "os", "getpid")
fn get_pid() -> List(Int)
