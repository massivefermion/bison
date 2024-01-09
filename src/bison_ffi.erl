-module(bison_ffi).

-export([hash/1, get_hostname/0, get_pid/0]).

hash(Binary) -> crypto:hash(sha256, Binary).

get_hostname() ->
    case inet:gethostname() of
        {ok, Hostname} -> Hostname
    end.

get_pid() ->
    list_to_integer(os:getpid()).
