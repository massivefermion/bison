# gleam_bson

bson encoder and decoder for gleam

## Quick start

```sh
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```

## Installation

```sh
gleam add gleam_bson
```

## Roadmap

- [x] support encoding and decoding basic bson types (null, string, int32, int64, double, boolean, objectId, array, document).
- [x] support encoding and decoding min, max, timestamp, datetime, javascript and regex bson types.
- [x] support encoding and decoding the generic, md5, uuid and user-defined binary subtypes.
- [x] support generating new object-ids
- [ ] support encoding and decoding decimal128 bson type.
- [ ] support encoding and decoding encrypted binary subtype.

## Usage

### Encoding

```gleam
import bson/md5
import gleam/list
import bson/types
import bson.{encode}
import bson/object_id

fn cat_to_bson(cat: Cat) -> Result(BitString, Nil) {
  try id = object_id.from_string(cat.id)
  try checksum = md5.from_string(cat.checksum)

  Ok(encode([
    #("id", types.ObjectId(id)),
    #("name", types.Str(cat.name)),
    #("lives", types.Integer(cat.lives)),
    #(
      "nicknames",
      types.Array(
        cat.nicknames
        |> list.map(types.Str),
      ),
    ),
    #("checksum", types.Binary(types.MD5(checksum))),
    #("name_pattern", types.Regex(#("[a-z][a-z0-9]+", "")))
  ]))
}
```

### Decoding

```gleam
import bson/md5
import gleam/list
import bson/types
import bson.{decode}
import bson/object_id

fn cat_from_bson(data: BitString) -> Result(Cat, Nil) {
  try doc = decode(data)

  let [
    #("id", types.ObjectId(id)),
    #("name", types.Str(name)),
    #("lives", types.Integer(lives)),
    #("nicknames", types.Array(nicknames)),
    #("checksum", types.Binary(types.MD5(checksum))),
    #("name_pattern", types.Regex(#(pattern, options)))
  ] = doc

  Ok(Cat(
    id: id
    |> object_id.to_string,
    name: name,
    lives: lives,
    nicknames: nicknames
    |> list.map(fn(n) {
      assert types.Str(n) = n
      n
    }),
    checksum: checksum
    |> md5.to_string,
  ))
}
```
