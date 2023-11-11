![bison](https://raw.githubusercontent.com/massivefermion/bison/main/banner.png)

[![Package Version](https://img.shields.io/hexpm/v/bison)](https://hex.pm/packages/bison)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/bison/)

# bison (formerly gleam_bson)

bson encoder and decoder for gleam

## <img width=32 src="https://raw.githubusercontent.com/massivefermion/bison/main/icon.png"> Quick start

```sh
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```

## <img width=32 src="https://raw.githubusercontent.com/massivefermion/bison/main/icon.png"> Installation

```sh
gleam add bison
```

## <img width=32 src="https://raw.githubusercontent.com/massivefermion/bison/main/icon.png"> Roadmap

- [x] support encoding and decoding basic bson types (null, string, int32, int64, double, boolean, objectId, array, document).
- [x] support encoding and decoding min, max, timestamp, datetime, javascript and regex bson types.
- [x] support encoding and decoding the generic, md5, uuid and user-defined binary subtypes.
- [x] support generating new object-ids
- [ ] support encoding and decoding decimal128 bson type.
- [ ] support encoding and decoding encrypted binary subtype.

## <img width=32 src="https://raw.githubusercontent.com/massivefermion/bison/main/icon.png"> Usage

### Encoding

```gleam
import gleam/list
import gleam/result
import bison/md5
import bison/bson
import bison.{encode}
import bison/object_id

fn calf_to_bson(calf: Calf) -> Result(BitArray, Nil) {
  use id <- result.then(object_id.from_string(calf.id))
  use checksum <- result.then(md5.from_string(calf.checksum))

  Ok(encode([
    #("id", bson.ObjectId(id)),
    #("age", bson.Int32(calf.age)),
    #("name", bson.String(calf.name)),
    #("weight", bson.Double(calf.weight)),
    #("birthdate", bson.DateTime(calf.birthdate)),
    #("is_healthy", bson.Boolean(calf.is_healthy)),
    #("checksum", bson.Binary(bson.MD5(checksum))),
    #("nicknames", bson.Array(list.map(calf.nicknames, bson.String))),
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

fn calf_from_bson(data: BitArray) -> Result(Calf, Nil) {
  use doc <- result.then(decode(data))

  let [
    #("id", bson.ObjectId(id)),
    #("age", bson.Int32(age)),
    #("name", bson.String(name)),
    #("weight", bson.Double(weight)),
    #("nicknames", bson.Array(nicknames)),
    #("birthdate", bson.DateTime(birthdate)),
    #("is_healthy", bson.Boolean(is_healthy)),
    #("checksum", bson.Binary(bson.MD5(checksum))),
  ] = doc

  Ok(Calf(
    id: object_id.to_string(id),
    age: age,
    name: name,
    weight: weight,
    nicknames: list.map(
      nicknames,
      fn(n) {
        let assert bson.String(n) = n
        n
      },
    ),
    birthdate: birthdate,
    is_healthy: is_healthy,
    checksum: md5.to_string(checksum),
  ))
}

```
