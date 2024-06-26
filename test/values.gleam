import gleam/dict
import gleam/dynamic
import gleeunit/should

import bison/bson
import bison/decoders
import bison/object_id

import birl

pub const bson = <<
  52, 1, 0, 0, 7, 95, 105, 100, 0, 97, 62, 12, 151, 23, 70, 138, 110, 75, 252,
  100, 109, 3, 100, 97, 116, 97, 0, 255, 0, 0, 0, 2, 73, 83, 66, 78, 0, 14, 0, 0,
  0, 48, 45, 53, 53, 51, 45, 50, 57, 51, 51, 53, 45, 52, 0, 3, 97, 117, 116, 104,
  111, 114, 0, 109, 0, 0, 0, 4, 97, 99, 116, 105, 118, 101, 0, 19, 0, 0, 0, 16,
  48, 0, 147, 7, 0, 0, 16, 49, 0, 200, 7, 0, 0, 0, 8, 97, 108, 105, 118, 101, 63,
  0, 0, 9, 98, 105, 114, 116, 104, 100, 97, 116, 101, 0, 0, 116, 191, 166, 144,
  254, 255, 255, 1, 104, 101, 105, 103, 104, 116, 0, 0, 0, 0, 0, 0, 0, 252, 63,
  2, 110, 97, 109, 101, 0, 13, 0, 0, 0, 73, 115, 97, 97, 99, 32, 65, 115, 105,
  109, 111, 118, 0, 10, 114, 101, 108, 105, 103, 105, 111, 110, 0, 0, 4, 103,
  101, 110, 114, 101, 0, 54, 0, 0, 0, 2, 48, 0, 16, 0, 0, 0, 115, 99, 105, 101,
  110, 99, 101, 32, 102, 105, 99, 116, 105, 111, 110, 0, 2, 49, 0, 19, 0, 0, 0,
  112, 111, 108, 105, 116, 105, 99, 97, 108, 32, 116, 104, 114, 105, 108, 108,
  101, 114, 0, 0, 16, 112, 97, 103, 101, 115, 0, 255, 0, 0, 0, 16, 112, 117, 98,
  108, 105, 115, 104, 101, 100, 0, 159, 7, 0, 0, 2, 116, 105, 116, 108, 101, 0,
  11, 0, 0, 0, 70, 111, 117, 110, 100, 97, 116, 105, 111, 110, 0, 0, 2, 109, 101,
  116, 97, 100, 97, 116, 97, 0, 11, 0, 0, 0, 98, 105, 115, 111, 110, 95, 116,
  101, 115, 116, 0, 0,
>>

pub const ejson = "{\"_id\":{\"$oid\":\"613e0c9717468a6e4bfc646d\"},\"data\":{\"ISBN\":\"0-553-29335-4\",\"author\":{\"active\":[{\"$numberInt\":\"1939\"},{\"$numberInt\":\"1992\"}],\"alive?\":false,\"birthdate\":{\"$date\":{\"$numberLong\":\"-1577750400000\"}},\"height\":{\"$numberDouble\":\"1.75\"},\"name\":\"Isaac Asimov\",\"religion\":null},\"genre\":[\"science fiction\",\"political thriller\"],\"pages\":{\"$numberInt\":\"255\"},\"published\":{\"$numberInt\":\"1951\"},\"title\":\"Foundation\"},\"metadata\":\"bison_test\"}"

pub fn get_doc() -> dict.Dict(String, bson.Value) {
  let id =
    object_id.from_string("613e0c9717468a6e4bfc646d")
    |> should.be_ok

  let author_birthdate = birl.set_day(birl.unix_epoch, birl.Day(1920, 1, 2))

  dict.from_list([
    #("_id", bson.ObjectId(id)),
    #("metadata", bson.String("bison_test")),
    #(
      "data",
      bson.Document(
        dict.from_list([
          #("title", bson.String("Foundation")),
          #("published", bson.Int32(1951)),
          #("pages", bson.Int32(255)),
          #(
            "genre",
            bson.Array([
              bson.String("science fiction"),
              bson.String("political thriller"),
            ]),
          ),
          #(
            "author",
            bson.Document(
              dict.from_list([
                #("name", bson.String("Isaac Asimov")),
                #("birthdate", bson.DateTime(author_birthdate)),
                #("alive?", bson.Boolean(False)),
                #("active", bson.Array([bson.Int32(1939), bson.Int32(1992)])),
                #("height", bson.Double(1.75)),
                #("religion", bson.Null),
              ]),
            ),
          ),
          #("ISBN", bson.String("0-553-29335-4")),
        ]),
      ),
    ),
  ])
}

pub type Author {
  Author(
    name: String,
    birthdate: birl.Time,
    alive: Bool,
    active: List(Int),
    height: Float,
    religion: Nil,
  )
}

pub type Novel {
  Novel(
    title: String,
    published: Int,
    pages: Int,
    genre: List(String),
    isbn: String,
    author: Author,
  )
}

pub type Doc {
  Doc(id: object_id.ObjectId, metadata: String, novel: Novel)
}

pub fn get_decoder() {
  let author_decoder =
    dynamic.decode6(
      Author,
      dynamic.field("name", decoders.string),
      dynamic.field("birthdate", decoders.time),
      dynamic.field("alive?", decoders.bool),
      dynamic.field("active", decoders.list(decoders.int)),
      dynamic.field("height", decoders.float),
      dynamic.field("religion", decoders.nil),
    )

  let novel_decoder =
    dynamic.decode6(
      Novel,
      dynamic.field("title", decoders.string),
      dynamic.field("published", decoders.int),
      dynamic.field("pages", decoders.int),
      dynamic.field("genre", decoders.list(decoders.string)),
      dynamic.field("ISBN", decoders.string),
      dynamic.field("author", decoders.wrap(author_decoder)),
    )

  dynamic.decode3(
    Doc,
    dynamic.field("_id", decoders.object_id),
    dynamic.field("metadata", decoders.string),
    dynamic.field("data", decoders.wrap(novel_decoder)),
  )
}

pub fn get_typed_doc() {
  let id =
    object_id.from_string("613e0c9717468a6e4bfc646d")
    |> should.be_ok

  let author_birthdate = birl.set_day(birl.unix_epoch, birl.Day(1920, 1, 2))

  Doc(
    id,
    "bison_test",
    Novel(
      "Foundation",
      1951,
      255,
      ["science fiction", "political thriller"],
      "0-553-29335-4",
      Author("Isaac Asimov", author_birthdate, False, [1939, 1992], 1.75, Nil),
    ),
  )
}
