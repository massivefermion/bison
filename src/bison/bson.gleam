import gleam/dict.{type Dict}

import bison/custom.{type Custom}
import bison/generic.{type Generic}
import bison/md5.{type MD5}
import bison/object_id.{type ObjectId}
import bison/uuid.{type UUID}

import birl.{type Time}

/// if you're not familiar with type `Time`, see [birl](https://hex.pm/packages/birl)!
pub type Value {
  Min
  Max
  NaN
  Null
  Infinity
  JS(String)
  Int32(Int)
  Int64(Int)
  Double(Float)
  Boolean(Bool)
  Binary(Binary)
  String(String)
  DateTime(Time)
  NegativeInfinity
  Array(List(Value))
  ObjectId(ObjectId)
  Timestamp(Int, Int)
  Regex(String, String)
  Document(Dict(String, Value))
}

pub type Binary {
  MD5(MD5)
  UUID(UUID)
  Custom(Custom)
  Generic(Generic)
}
