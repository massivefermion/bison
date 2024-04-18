import gleam/bit_array
import gleam/int
import gleam/iterator
import gleam/list
import gleam/option
import gleam/order
import gleam/queue
import gleam/string

import birl
import birl/duration

pub opaque type ObjectId {
  ObjectId(BitArray)
}

pub fn new() -> ObjectId {
  from_datetime(birl.utc_now())
}

/// see [birl](https://hex.pm/packages/birl)!
pub fn from_datetime(datetime: birl.Time) -> ObjectId {
  let moment = birl.to_unix(datetime)
  let assert Ok(counter) = int.modulo(birl.monotonic_now(), 0xffffff)

  let assert <<machine_id:size(24), _:bits>> = hash(get_hostname())

  let assert Ok(id) =
    from_bit_array(<<
      moment:big-32,
      machine_id:big-24,
      get_pid():big-16,
      counter:big-24,
    >>)

  id
}

/// see [birl](https://hex.pm/packages/birl)!
pub fn to_datetime(id: ObjectId) -> birl.Time {
  let assert ObjectId(<<timestamp:big-32, _:bits>>) = id
  birl.from_unix(timestamp)
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
  to_datetime(a)
  |> birl.range(option.map(b, to_datetime), s)
  |> iterator.map(from_datetime)
}

pub fn compare(a: ObjectId, b: ObjectId) -> order.Order {
  let assert ObjectId(<<moment_a:big-32, _:big-24, _:big-16, counter_a:big-24>>) =
    a
  let assert ObjectId(<<moment_b:big-32, _:big-24, _:big-16, counter_b:big-24>>) =
    b

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
            let assert [high, low] = pair
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
        list.try_fold(id, <<>>, fn(acc, code) {
          case code >= 0 && code <= 255 {
            True -> Ok(bit_array.append(acc, <<code>>))
            False -> Error(Nil)
          }
        })
      {
        Ok(id) -> Ok(ObjectId(id))
        Error(Nil) -> Error(Nil)
      }

    24 ->
      case
        list.try_map(id, fn(code) {
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

@external(erlang, "bison_ffi", "get_pid")
fn get_pid() -> Int

@external(erlang, "bison_ffi", "hash")
fn hash(binary: BitArray) -> BitArray

@external(erlang, "bison_ffi", "get_hostname")
fn get_hostname() -> BitArray
