-module(bison_ffi).

-export([hash/1]).

hash(Data) -> crypto:hash(sha256, Data).
