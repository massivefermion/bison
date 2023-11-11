import bison/md5.{type MD5}
import bison/uuid.{type UUID}
import bison/custom.{type Custom}
import bison/generic.{type Generic}
import bison/object_id.{type ObjectId}
import birl/time.{type DateTime}

/// if you're not familiar with type `DateTime`, see [birl](https://hex.pm/packages/birl)!
pub type Value {
  Min
  Max
  Null
  JS(String)
  Int32(Int)
  Int64(Int)
  Double(Float)
  Boolean(Bool)
  Binary(Binary)
  String(String)
  Array(List(Value))
  ObjectId(ObjectId)
  DateTime(DateTime)
  Timestamp(Int, Int)
  Regex(#(String, String))
  Document(List(#(String, Value)))
}

pub type Binary {
  MD5(MD5)
  UUID(UUID)
  Custom(Custom)
  Generic(Generic)
}
