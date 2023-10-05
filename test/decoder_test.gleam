import gleeunit/should
import values
import bison.{decode}

pub fn decoder_test() {
  let doc = values.get_doc()

  decode(values.bson)
  |> should.equal(Ok(doc))
}
