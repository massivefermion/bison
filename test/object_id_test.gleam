import gleeunit/should
import bson/object_id

const string_id = "633eb709917585842c7345c7"

const int_list_id = [99, 62, 183, 9, 145, 117, 133, 132, 44, 115, 69, 199]

pub fn from_string_test() {
  object_id.from_string(string_id)
  |> should.be_ok
}

pub fn from_int_list_to_string_test() {
  assert Ok(generated_id) = object_id.from_int_list(int_list_id)
  generated_id
  |> object_id.to_string
  |> should.equal(string_id)
}

pub fn from_string_to_int_list_test() {
  assert Ok(generated_id) = object_id.from_string(string_id)
  generated_id
  |> object_id.to_int_list
  |> should.equal(int_list_id)
}

pub fn new_id_test() {
  object_id.new()
  |> object_id.to_string
  |> object_id.from_string
  |> should.be_ok
}
