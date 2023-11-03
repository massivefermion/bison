![bison](https://raw.githubusercontent.com/massivefermion/bison/main/logo.png)

[![Package Version](https://img.shields.io/hexpm/v/bison)](https://hex.pm/packages/bison)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/bison/)

# bison (formerly gleam_bson)

bson encoder and decoder for gleam

## 🦬 Quick start

```sh
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```

## 🦬 Installation

```sh
gleam add bison
```

## 🦬 Roadmap

- [x] support encoding and decoding basic bson types (null, string, int32, int64, double, boolean, objectId, array, document).
- [x] support encoding and decoding min, max, timestamp, datetime, javascript and regex bson types.
- [x] support encoding and decoding the generic, md5, uuid and user-defined binary subtypes.
- [x] support generating new object-ids
- [ ] support encoding and decoding decimal128 bson type.
- [ ] support encoding and decoding encrypted binary subtype.

## 🦬 Usage

### Encoding

```gleam
import gleam/list
import gleam/result
import bison/md5
import bison/bson
import bison.{encode}
import bison/object_id

fn calf_to_bson(calf: Calf) -> Result(BitString, Nil) {
  use id <- result.then(object_id.from_string(calf.id))
  use checksum <- result.then(md5.from_string(calf.checksum))

  Ok(encode([
    #("id", bson.ObjectId(id)),
    #("name", bson.Str(calf.name)),
    #("age", bson.Int32(calf.age)),
    #("birthdate", bson.DateTime(calf.birthdate)),
    #("checksum", bson.Binary(bson.MD5(checksum))),
    #("nicknames", bson.Array(list.map(calf.nicknames, bson.Str))),
  ]))
}
```

### Decoding

```gleam
import gleam/list
import gleam/result
import bison/md5
import bison/bson
import bison.{decode}
import bison/object_id

fn calf_from_bson(data: BitString) -> Result(Calf, Nil) {
  use doc <- result.then(decode(data))

  let [
    #("id", bson.ObjectId(id)),
    #("name", bson.Str(name)),
    #("age", bson.Int32(age)),
    #("nicknames", bson.Array(nicknames)),
    #("birthdate", bson.DateTime(birthdate)),
    #("checksum", bson.Binary(bson.MD5(checksum))),
  ] = doc

  Ok(Calf(
    id: object_id.to_string(id),
    name: name,
    age: age,
    nicknames: list.map(
      nicknames,
      fn(n) {
        let assert bson.Str(n) = n
        n
      },
    ),
    birthdate: birthdate,
    checksum: md5.to_string(checksum),
  ))
}
```
