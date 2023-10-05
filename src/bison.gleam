import bison/encoder
import bison/decoder

pub fn encode(doc) {
  encoder.encode(doc)
}

pub fn decode(data) {
  decoder.decode(data)
}
