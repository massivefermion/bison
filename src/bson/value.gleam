import bson/md5.{MD5}
import bson/uuid.{UUID}
import bson/custom.{Custom}
import bson/generic.{Generic}
import bson/object_id.{ObjectId}
import birl/time.{DateTime}

/// if you're not familiar with type `DateTime`, see [birl](https://hex.pm/packages/birl)!
pub type Value {
  Min
  Max
  Null
  JS(String)
  Str(String)
  Int32(Int)
  Int64(Int)
  Double(Float)
  Boolean(Bool)
  Binary(Binary)
  Timestamp(Int)
  Array(List(Value))
  ObjectId(ObjectId)
  DateTime(DateTime)
  Regex(#(String, String))
  Document(List(#(String, Value)))
}

pub type Binary {
  MD5(MD5)
  UUID(UUID)
  Custom(Custom)
  Generic(Generic)
}
