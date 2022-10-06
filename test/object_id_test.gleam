import gleeunit/should
import bson/object_id

const string_id = "633eb709917585842c7345c7"

pub fn from_string_test() {
  object_id.from_string(string_id)
  |> should.be_ok
}

pub fn to_string_test() {
  assert Ok(generated_id) = object_id.from_string(string_id)
  generated_id
  |> object_id.to_string
  |> should.equal(string_id)
}

pub fn new_id_test() {
  object_id.new()
  |> object_id.to_string
  |> object_id.from_string
  |> should.be_ok
}
