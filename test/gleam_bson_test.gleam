import gleeunit
import gleam/list
import bson/types
import bson/decoder
import bson/encoder
import bson/object_id
import gleeunit/should

const bson = <<
  45, 1, 0, 0, 7, 95, 105, 100, 0, 97, 62, 12, 151, 23, 70, 138, 110, 75, 252, 100,
  109, 3, 100, 97, 116, 97, 0, 243, 0, 0, 0, 2, 116, 105, 116, 108, 101, 0, 11, 0,
  0, 0, 70, 111, 117, 110, 100, 97, 116, 105, 111, 110, 0, 2, 73, 83, 66, 78, 0,
  14, 0, 0, 0, 48, 45, 53, 53, 51, 45, 50, 57, 51, 51, 53, 45, 52, 0, 16, 112, 117,
  98, 108, 105, 115, 104, 101, 100, 0, 159, 7, 0, 0, 16, 112, 97, 103, 101, 115,
  0, 255, 0, 0, 0, 4, 103, 101, 110, 114, 101, 0, 51, 0, 0, 0, 2, 48, 0, 16, 0, 0,
  0, 115, 99, 105, 101, 110, 99, 101, 32, 102, 105, 99, 116, 105, 111, 110, 0, 2,
  49, 0, 16, 0, 0, 0, 112, 111, 108, 105, 116, 105, 99, 97, 108, 32, 100, 114, 97,
  109, 97, 0, 0, 3, 97, 117, 116, 104, 111, 114, 0, 100, 0, 0, 0, 2, 110, 97, 109,
  101, 0, 13, 0, 0, 0, 73, 115, 97, 97, 99, 32, 65, 115, 105, 109, 111, 118, 0, 16,
  98, 111, 114, 110, 0, 128, 7, 0, 0, 8, 97, 108, 105, 118, 101, 63, 0, 0, 10, 114,
  101, 108, 105, 103, 105, 111, 110, 0, 1, 104, 101, 105, 103, 104, 116, 0, 0, 0,
  0, 0, 0, 0, 252, 63, 4, 97, 99, 116, 105, 118, 101, 0, 19, 0, 0, 0, 16, 48, 0,
  147, 7, 0, 0, 16, 49, 0, 200, 7, 0, 0, 0, 0, 0, 2, 109, 101, 116, 97, 100, 97,
  116, 97, 0, 16, 0, 0, 0, 103, 108, 101, 97, 109, 95, 98, 115, 111, 110, 95, 116,
  101, 115, 116, 0, 0,
>>

pub fn main() {
  gleeunit.main()
}

pub fn encoder_test() {
  let id = case encoder.object_id("613e0c9717468a6e4bfc646d") {
    Ok(id) -> id
  }

  let author =
    encoder.document([
      #("name", encoder.string("Isaac Asimov")),
      #("born", encoder.integer(1920)),
      #("alive?", encoder.boolean(False)),
      #("religion", encoder.null()),
      #("height", encoder.double(1.75)),
      #(
        "active",
        encoder.array(
          [1939, 1992]
          |> list.map(fn(item) { encoder.integer(item) }),
        ),
      ),
    ])

  let book =
    encoder.document([
      #("title", encoder.string("Foundation")),
      #("ISBN", encoder.string("0-553-29335-4")),
      #("published", encoder.integer(1951)),
      #("pages", encoder.integer(255)),
      #(
        "genre",
        encoder.array(
          ["science fiction", "political drama"]
          |> list.map(fn(item) { encoder.string(item) }),
        ),
      ),
      #("author", author),
    ])

  let bson_doc =
    encoder.document([
      #("_id", id),
      #("data", book),
      #("metadata", encoder.string("gleam_bson_test")),
    ])

  bson_doc
  |> should.equal(types.Entity(kind: types.document, value: bson))
}

pub fn decoder_test() {
  let id = case object_id.from_string("613e0c9717468a6e4bfc646d") {
    Ok(id) -> id
  }

  let doc =
    types.Document([
      #("metadata", types.Str("gleam_bson_test")),
      #(
        "data",
        types.Document([
          #(
            "author",
            types.Document([
              #(
                "active",
                types.Array([types.Integer(1939), types.Integer(1992)]),
              ),
              #("height", types.Double(1.75)),
              #("religion", types.Null),
              #("alive?", types.Boolean(False)),
              #("born", types.Integer(1920)),
              #("name", types.Str("Isaac Asimov")),
            ]),
          ),
          #(
            "genre",
            types.Array([
              types.Str("science fiction"),
              types.Str("political drama"),
            ]),
          ),
          #("pages", types.Integer(255)),
          #("published", types.Integer(1951)),
          #("ISBN", types.Str("0-553-29335-4")),
          #("title", types.Str("Foundation")),
        ]),
      ),
      #("_id", types.ObjectId(id)),
    ])

  decoder.decode(bson)
  |> should.equal(Ok(doc))
}
