import gleeunit/should
import values
import bison.{strict_decode}

pub fn decoder_test() {
  let typed_doc = values.get_typed_doc()

  strict_decode(values.bson, values.get_decoder())
  |> should.be_ok
  |> should.equal(typed_doc)
}
