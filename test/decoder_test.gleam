import gleeunit/should
import values
import bson.{decode}

pub fn decoder_test() {
  let doc = values.get_doc()

  decode(values.bson)
  |> should.equal(Ok(doc))
}
