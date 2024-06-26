import birl
import bison/object_id
import gleam/order
import gleeunit/should

const string_id = "633eb709917585842c7345c7"

const timestamp = 1_665_054_473

const int_list_id = [99, 62, 183, 9, 145, 117, 133, 132, 44, 115, 69, 199]

pub fn from_string_test() {
  object_id.from_string(string_id)
  |> should.be_ok
  |> object_id.to_string
  |> should.equal(string_id)
}

pub fn from_int_list_to_string_test() {
  object_id.from_int_list(int_list_id)
  |> should.be_ok
  |> object_id.to_string
  |> should.equal(string_id)
}

pub fn from_string_to_int_list_test() {
  object_id.from_string(string_id)
  |> should.be_ok
  |> object_id.to_int_list
  |> should.equal(int_list_id)
}

pub fn new_id_test() {
  object_id.new()
  |> object_id.to_string
  |> object_id.from_string
  |> should.be_ok
}

pub fn timestamp_test() {
  object_id.from_string(string_id)
  |> should.be_ok
  |> object_id.to_datetime
  |> should.equal(birl.from_unix(timestamp))
}

pub fn order_test() {
  let a = object_id.new()
  let b = object_id.new()
  object_id.compare(a, b)
  |> should.equal(order.Lt)
}
