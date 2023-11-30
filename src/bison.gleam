import bison/encoder
import bison/decoder

pub fn encode(doc) {
  encoder.encode(doc)
}

pub fn decode(binary) {
  decoder.decode(binary)
}
