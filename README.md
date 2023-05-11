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
import gleam/list
import gleam/result
import bson/md5
import bson/value
import bson.{encode}
import bson/object_id

fn cat_to_bson(cat: Cat) -> Result(BitString, Nil) {
  use id <- result.then(object_id.from_string(cat.id))
  use checksum <- result.then(md5.from_string(cat.checksum))

  Ok(encode([
    #("id", value.ObjectId(id)),
    #("name", value.Str(cat.name)),
    #("lives", value.Integer(cat.lives)),
    #("nicknames", value.Array(list.map(cat.nicknames, value.Str))),
    #("checksum", value.Binary(value.MD5(checksum))),
    #("name_pattern", value.Regex(#("[a-z][a-z0-9]+", ""))),
  ]))
}
```

### Decoding

```gleam
import gleam/list
import gleam/result
import bson/md5
import bson/value
import bson.{decode}
import bson/object_id

fn cat_from_bson(data: BitString) -> Result(Cat, Nil) {
  use doc <- result.then(decode(data))

  let [
    #("id", value.ObjectId(id)),
    #("name", value.Str(name)),
    #("lives", value.Integer(lives)),
    #("nicknames", value.Array(nicknames)),
    #("checksum", value.Binary(value.MD5(checksum))),
    #("name_pattern", value.Regex(#(pattern, options))),
  ] = doc

  Ok(Cat(
    id: object_id.to_string(id),
    name: name,
    lives: lives,
    nicknames: list.map(
      nicknames,
      fn(n) {
        let assert value.Str(n) = n
        n
      },
    ),
    checksum: md5.to_string(checksum),
  ))
}
```
