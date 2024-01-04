![bison](https://raw.githubusercontent.com/massivefermion/bison/main/banner.png)

[![Package Version](https://img.shields.io/hexpm/v/bison)](https://hex.pm/packages/bison)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/bison/)

# bison

BSON encoder and decoder for Gleam

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
- [ ] support encoding and decoding relaxed EJSON.

## <img width=32 src="https://raw.githubusercontent.com/massivefermion/bison/main/icon.png"> Usage

### Encoding

```gleam
import gleam/dict
import gleam/list
import gleam/result
import bison
import bison/md5
import bison/bson
import bison/object_id

fn calf_to_bson(calf: Calf) -> Result(BitArray, Nil) {
  use id <- result.then(object_id.from_string(calf.id))
  use checksum <- result.then(md5.from_string(calf.checksum))

  [
    #("id", bson.ObjectId(id)),
    #("age", bson.Int32(calf.age)),
    #("name", bson.String(calf.name)),
    #("weight", bson.Double(calf.weight)),
    #("birthdate", bson.DateTime(calf.birthdate)),
    #("is_healthy", bson.Boolean(calf.is_healthy)),
    #("checksum", bson.Binary(bson.MD5(checksum))),
    #("nicknames", bson.Array(list.map(calf.nicknames, bson.String))),
  ]
  |> dict.from_list
  |> bison.encode
  |> Ok
}
```

### Strict Decoding

```gleam
import gleam/dict
import gleam/dynamic
import bison
import bison/bson
import bison/decoders

pub type Habitat {
  Habitat(kind: String, location: String)
}

pub type Species {
  Species(alternative_name: String, weight_range: List(Int), habitat: Habitat)
}

pub type ExtantBisons {
  ExtantBisons(buffalo: Species, wisent: Species)
}

pub fn extant_bisons_from_bson(binary: BitArray) -> Result(ExtantBisons, List(dynamic.DecodeError)) {
  let habitat_decoder =
    dynamic.decode2(
      Habitat,
      dynamic.field("kind", decoders.string),
      dynamic.field("location", decoders.string),
    )

  let species_decoder =
    dynamic.decode3(
      Species,
      dynamic.field("alternative name", decoders.string),
      dynamic.field("weight range", decoders.list(decoders.int)),
      dynamic.field("habitat", decoders.wrap(habitat_decoder)),
    )

  let decoder =
    dynamic.decode2(
      ExtantBisons,
      dynamic.field("Buffalo", decoders.wrap(species_decoder)),
      dynamic.field("Wisent", decoders.wrap(species_decoder)),
    )
    
  bison.strict_decode(binary, decoder)
}
```

### Dict Decoding

```gleam
import gleam/dict
import gleam/list
import gleam/result
import bison
import bison/md5
import bison/bson
import bison/object_id

fn calf_from_bson(binary: BitArray) -> Result(Calf, Nil) {
  use doc <- result.then(bison.decode(binary))

  case
    [
      dict.get(doc, "id"),
      dict.get(doc, "age"),
      dict.get(doc, "name"),
      dict.get(doc, "weight"),
      dict.get(doc, "nicknames"),
      dict.get(doc, "birthdate"),
      dict.get(doc, "is_healthy"),
      dict.get(doc, "checksum"),
    ]
  {
    [
      Ok(bson.ObjectId(id)),
      Ok(bson.Int32(age)),
      Ok(bson.String(name)),
      Ok(bson.Double(weight)),
      Ok(bson.Array(nicknames)),
      Ok(bson.DateTime(birthdate)),
      Ok(bson.Boolean(is_healthy)),
      Ok(bson.Binary(bson.MD5(checksum))),
    ] ->
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

    _ -> Error(Nil)
  }
}
```
