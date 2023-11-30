-module(bison_ffi).

-export([hash/1]).

hash(Binary) -> crypto:hash(sha256, Binary).
