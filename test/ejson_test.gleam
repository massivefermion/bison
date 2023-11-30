import gleeunit/should
import values
import bison/ejson.{from_canonical, to_canonical}

pub fn encoder_test() {
  let doc = values.get_doc()

  to_canonical(doc)
  |> should.equal(values.ejson)
}

pub fn decoder_test() {
  let doc = values.get_doc()

  let decoded =
    from_canonical(values.ejson)
    |> should.be_ok

  decoded
  |> should.equal(doc)
}
