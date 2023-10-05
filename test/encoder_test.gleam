import gleeunit/should
import values
import bison.{encode}

pub fn encoder_test() {
  let doc = values.get_doc()

  encode(doc)
  |> should.equal(values.bson)
}
