import gleam/bit_array
import gleam/dict
import gleam/float
import gleam/int
import gleam/json
import gleam/list

import bison/bson
import bison/custom
import bison/generic
import bison/md5
import bison/object_id
import bison/uuid

import birl
import birl/duration

pub fn to_canonical(doc: dict.Dict(String, bson.Value)) {
  doc
  |> document
  |> json.to_string
}

fn document(doc: dict.Dict(String, bson.Value)) {
  doc
  |> dict.to_list
  |> list.map(fn(field) { #(field.0, bson_to_canonical(field.1)) })
  |> json.object
}

fn bson_to_canonical(value: bson.Value) {
  case value {
    bson.Null -> json.null()
    bson.Boolean(b) -> json.bool(b)
    bson.String(s) -> json.string(s)
    bson.Document(doc) -> document(doc)
    bson.Min -> json.object([#("$minKey", json.int(1))])
    bson.Max -> json.object([#("$maxKey", json.int(1))])
    bson.JS(code) -> json.object([#("$code", json.string(code))])
    bson.NaN -> json.object([#("$numberDouble", json.string("NaN"))])
    bson.Array(a) -> json.preprocessed_array(list.map(a, bson_to_canonical))
    bson.Infinity -> json.object([#("$numberDouble", json.string("Infinity"))])

    bson.NegativeInfinity ->
      json.object([#("$numberDouble", json.string("-Infinity"))])

    bson.Int32(n) ->
      json.object([
        #(
          "$numberInt",
          n
            |> int.to_string
            |> json.string,
        ),
      ])

    bson.Int64(n) ->
      json.object([
        #(
          "$numberLong",
          n
            |> int.to_string
            |> json.string,
        ),
      ])

    bson.Double(f) ->
      json.object([
        #(
          "$numberDouble",
          f
            |> float.to_string
            |> json.string,
        ),
      ])

    bson.DateTime(dt) -> {
      let duration.Duration(micro_t) = birl.difference(dt, birl.unix_epoch)
      json.object([
        #(
          "$date",
          json.object([
            #(
              "$numberLong",
              { micro_t / 1000 }
                |> int.to_string
                |> json.string,
            ),
          ]),
        ),
      ])
    }

    bson.Timestamp(stamp, counter) ->
      json.object([
        #(
          "$timestamp",
          json.object([#("t", json.int(stamp)), #("i", json.int(counter))]),
        ),
      ])

    bson.Regex(pattern, options) ->
      json.object([
        #(
          "$regularExpression",
          json.object([
            #("pattern", json.string(pattern)),
            #("options", json.string(options)),
          ]),
        ),
      ])

    bson.ObjectId(id) ->
      json.object([
        #(
          "$oid",
          id
            |> object_id.to_string
            |> json.string,
        ),
      ])

    bson.Binary(bson.MD5(md5)) ->
      json.object([
        #(
          "$binary",
          json.object([
            #(
              "base64",
              md5
                |> md5.to_bit_array
                |> bit_array.base64_encode(True)
                |> json.string,
            ),
            #("subType", json.string("05")),
          ]),
        ),
      ])

    bson.Binary(bson.UUID(uuid)) ->
      json.object([
        #(
          "$binary",
          json.object([
            #(
              "base64",
              uuid
                |> uuid.to_bit_array
                |> bit_array.base64_encode(True)
                |> json.string,
            ),
            #("subType", json.string("04")),
          ]),
        ),
      ])

    bson.Binary(bson.Generic(generic)) ->
      json.object([
        #(
          "$binary",
          json.object([
            #(
              "base64",
              generic
                |> generic.to_bit_array
                |> bit_array.base64_encode(True)
                |> json.string,
            ),
            #("subType", json.string("00")),
          ]),
        ),
      ])

    bson.Binary(bson.Custom(custom)) -> {
      let #(code, value) = custom.to_bit_array_with_code(custom)
      let assert Ok(code) = int.to_base_string(code, 16)
      json.object([
        #(
          "$binary",
          json.object([
            #(
              "base64",
              value
                |> bit_array.base64_encode(True)
                |> json.string,
            ),
            #("subType", json.string(code)),
          ]),
        ),
      ])
    }
  }
}
