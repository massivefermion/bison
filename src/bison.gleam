import gleam/dict
import gleam/dynamic

import bison/bson
import bison/decoder
import bison/encoder

pub fn encode(doc) {
  encoder.encode(doc)
}

pub fn encode_list(doc) {
  encoder.encode_list(doc)
}

pub fn decode(binary) {
  decoder.decode(binary)
}

pub fn to_custom_type(
  doc: dict.Dict(String, bson.Value),
  decoder: dynamic.Decoder(a),
) {
  doc
  |> dynamic.from
  |> decoder
}
