import gleam/result
import gleam/dynamic
import bison/encoder
import bison/decoder

pub fn encode(doc) {
  encoder.encode(doc)
}

pub fn decode(binary) {
  decoder.decode(binary)
}

pub fn strict_decode(binary, decoder) {
  use doc <- result.then(
    decoder.decode(binary)
    |> result.replace_error([dynamic.DecodeError("BSON", "bit array", [])]),
  )

  doc
  |> dynamic.from
  |> decoder
}
