import bson/encoder
import bson/decoder

pub fn encode(doc) {
  encoder.encode(doc)
}

pub fn decode(data) {
  decoder.decode(data)
}
