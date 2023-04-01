import bson/md5.{MD5}
import bson/uuid.{UUID}
import bson/custom.{Custom}
import bson/generic.{Generic}
import bson/object_id.{ObjectId}
import birl/time.{Time}

pub type Value {
  Min
  Max
  Null
  JS(String)
  Str(String)
  Integer(Int)
  Double(Float)
  Boolean(Bool)
  DateTime(Time)
  Binary(Binary)
  Timestamp(Int)
  Array(List(Value))
  ObjectId(ObjectId)
  Regex(#(String, String))
  Document(List(#(String, Value)))
}

pub type Binary {
  MD5(MD5)
  UUID(UUID)
  Custom(Custom)
  Generic(Generic)
}

pub type Kind {
  Kind(code: BitString)
}

pub type SubKind {
  SubKind(code: BitString)
}

pub const double = Kind(code: <<0x01>>)

pub const string = Kind(code: <<0x02>>)

pub const document = Kind(code: <<0x03>>)

pub const array = Kind(code: <<0x04>>)

pub const binary = Kind(code: <<0x05>>)

pub const object_id = Kind(code: <<0x07>>)

pub const boolean = Kind(code: <<0x08>>)

pub const datetime = Kind(code: <<0x09>>)

pub const null = Kind(code: <<0x0A>>)

pub const regex = Kind(code: <<0x0B>>)

pub const js = Kind(code: <<0x0D>>)

pub const int32 = Kind(code: <<0x10>>)

pub const timestamp = Kind(code: <<0x11>>)

pub const int64 = Kind(code: <<0x12>>)

pub const decimal128 = Kind(code: <<0x13>>)

pub const min = Kind(code: <<0xFF>>)

pub const max = Kind(code: <<0x7F>>)

pub const generic = SubKind(code: <<0x0>>)

pub const md5 = SubKind(code: <<0x5>>)

pub const uuid = SubKind(code: <<0x4>>)

pub const int32_min = -2_147_483_648

pub const int32_max = 2_147_483_647

pub const int64_min = -9_223_372_036_854_775_808

pub const int64_max = 9_223_372_036_854_775_807
