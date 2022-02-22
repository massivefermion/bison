# gleam_bson

A bson encoder and decoder written in gleam

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

- [x] support encoding and decoding basic bson types (null, string, int32, int64, double, boolean, objectId, array, document)
- [ ] support encoding and decoding other bson types
- [ ] support generating new objectIds

## Usage

### Encoding

```gleam
import myapp.{Cat}
import gleam/list
import bson/types
import bson.{encode}
import bson/object_id.{from_string}

fn cat_to_bson(cat: Cat) -> Result(BitString, Nil) {
  case from_string(cat.id) {
    Ok(id) ->
      Ok(encode([
        #("id", types.ObjectId(id)),
        #("name", types.Str(cat.name)),
        #("lives", types.Integer(cat.lives)),
        #(
          "nicknames",
          types.Array(
            cat.nicknames
            |> list.map(fn(n) { types.Str(n) }),
          ),
        ),
      ]))

    Error(Nil) -> Error(Nil)
  }
}
```

### Decoding

```gleam
import myapp.{Cat}
import gleam/list
import bson/types
import bson.{decode}
import bson/object_id.{to_string}

fn cat_from_bson(data: BitString) -> Result(Cat, Nil) {
  case decode(data) {
    Ok(doc) -> {
      let [
        #("id", types.ObjectId(id)),
        #("name", types.Str(name)),
        #("lives", types.Integer(lives)),
        #("nicknames", types.Array(nicknames)),
      ] = doc

      Ok(Cat(
        id: id
        |> to_string,
        name: name,
        lives: lives,
        nicknames: nicknames
        |> list.map(fn(n) {
          case n {
            types.Str(n) -> n
          }
        }),
      ))
    }

    Error(Nil) -> Error(Nil)
  }
}
```
