import bison.{decode}
import gleeunit/should
import values

pub fn decoder_test() {
  let doc = values.get_doc()

  decode(values.bson)
  |> should.be_ok
  |> should.equal(doc)
}
