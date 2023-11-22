//// For more information see [here](https://www.mongodb.com/docs/manual/reference/mongodb-extended-json)!

import bison/ejson/encoder
import bison/ejson/decoder

pub fn to_canonical(doc) {
  encoder.to_canonical(doc)
}

pub fn from_canonical(doc) {
  decoder.from_canonical(doc)
}
