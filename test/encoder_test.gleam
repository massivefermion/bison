import bison.{encode}
import gleeunit/should
import values

pub fn encoder_test() {
  let doc = values.get_doc()

  encode(doc)
  |> should.equal(values.bson)
}
