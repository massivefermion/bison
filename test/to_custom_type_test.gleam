import bison.{decode, to_custom_type}
import gleeunit/should
import values

pub fn decoder_test() {
  let typed_doc = values.get_typed_doc()

  values.bson
  |> decode
  |> should.be_ok
  |> to_custom_type(values.get_decoder())
  |> should.be_ok
  |> should.equal(typed_doc)
}
