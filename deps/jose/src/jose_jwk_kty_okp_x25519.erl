%% -*- mode: erlang; tab-width: 4; indent-tabs-mode: 1; st-rulers: [70] -*-
%% vim: ts=4 sw=4 ft=erlang noet
%%%-------------------------------------------------------------------
%%% @author Andrew Bennett <andrew@pixid.com>
%%% @copyright 2014-2016, Andrew Bennett
%%% @doc
%%%
%%% @end
%%% Created :  15 Jan 2016 by Andrew Bennett <andrew@pixid.com>
%%%-------------------------------------------------------------------
-module(jose_jwk_kty_okp_x25519).
-behaviour(jose_jwk).
-behaviour(jose_jwk_kty).
-behaviour(jose_jwk_use_enc).

%% jose_jwk callbacks
-export([from_map/1]).
-export([to_key/1]).
-export([to_map/2]).
-export([to_public_map/2]).
-export([to_thumbprint_map/2]).
%% jose_jwk_kty callbacks
-export([generate_key/1]).
-export([generate_key/2]).
-export([key_encryptor/3]).
%% jose_jwk_use_enc callbacks
-export([block_encryptor/2]).
-export([derive_key/2]).
%% API
-export([from_okp/1]).
-export([from_openssh_key/1]).
-export([to_okp/1]).
-export([to_openssh_key/2]).

%% Macros
-define(crv, <<"X25519">>).
-define(secretbytes, 32).
-define(publickeybytes, 32).
-define(secretkeybytes, 64).

%% Types
-type publickey() :: << _:256 >>.
-type secretkey() :: << _:512 >>.
-type key() :: publickey() | secretkey().

-export_type([key/0]).

%%====================================================================
%% jose_jwk callbacks
%%====================================================================

from_map(F = #{ <<"kty">> := <<"OKP">>, <<"crv">> := ?crv, <<"d">> := D, <<"x">> := X }) ->
	<< Secret:?secretbytes/binary >> = base64url:decode(D),
	<< PK:?publickeybytes/binary >> = base64url:decode(X),
	SK = << Secret/binary, PK/binary >>,
	{SK, maps:without([<<"crv">>, <<"d">>, <<"kty">>, <<"x">>], F)};
from_map(F = #{ <<"kty">> := <<"OKP">>, <<"crv">> := ?crv, <<"x">> := X }) ->
	<< PK:?publickeybytes/binary >> = base64url:decode(X),
	{PK, maps:without([<<"crv">>, <<"kty">>, <<"x">>], F)}.

to_key(PK = << _:?publickeybytes/binary >>) ->
	PK;
to_key(SK = << _:?secretkeybytes/binary >>) ->
	SK.

to_map(PK = << _:?publickeybytes/binary >>, F) ->
	F#{
		<<"crv">> => ?crv,
		<<"kty">> => <<"OKP">>,
		<<"x">> => base64url:encode(PK)
	};
to_map(<< Secret:?secretbytes/binary, PK:?publickeybytes/binary >>, F) ->
	F#{
		<<"crv">> => ?crv,
		<<"d">> => base64url:encode(Secret),
		<<"kty">> => <<"OKP">>,
		<<"x">> => base64url:encode(PK)
	}.

to_public_map(PK = << _:?publickeybytes/binary >>, F) ->
	to_map(PK, F);
to_public_map(<< _:?secretbytes/binary, PK:?publickeybytes/binary >>, F) ->
	to_public_map(PK, F).

to_thumbprint_map(K, F) ->
	maps:with([<<"crv">>, <<"kty">>, <<"x">>], to_public_map(K, F)).

%%====================================================================
%% jose_jwk_kty callbacks
%%====================================================================

generate_key(Seed = << _:?secretbytes/binary >>) ->
	{PK, SK} = jose_curve25519:x25519_keypair(Seed),
	{<< SK/binary, PK/binary >>, #{}};
generate_key({okp, 'X25519', Seed = << _:?secretbytes/binary >>}) ->
	generate_key(Seed);
generate_key({okp, 'X25519'}) ->
	{PK, SK} = jose_curve25519:x25519_keypair(),
	{<< SK/binary, PK/binary >>, #{}}.

generate_key(KTY, Fields)
		when is_binary(KTY)
		andalso (byte_size(KTY) =:= ?publickeybytes
			orelse byte_size(KTY) =:= ?secretkeybytes) ->
	{NewKTY, OtherFields} = generate_key({okp, 'X25519'}),
	{NewKTY, maps:merge(maps:remove(<<"kid">>, Fields), OtherFields)}.

key_encryptor(KTY, Fields, Key) ->
	jose_jwk_kty:key_encryptor(KTY, Fields, Key).

%%====================================================================
%% jose_jwk_use_enc callbacks
%%====================================================================

block_encryptor(_KTY, Fields=#{ <<"alg">> := ALG, <<"enc">> := ENC, <<"use">> := <<"enc">> }) ->
	Folder = fun
		(K, V, F)
				when K =:= <<"apu">>
				orelse K =:= <<"apv">>
				orelse K =:= <<"epk">> ->
			maps:put(K, V, F);
		(_K, _V, F) ->
			F
	end,
	maps:fold(Folder, #{
		<<"alg">> => ALG,
		<<"enc">> => ENC
	}, Fields);
block_encryptor(KTY, Fields) ->
	block_encryptor(KTY, maps:merge(Fields, #{
		<<"alg">> => <<"ECDH-ES">>,
		<<"enc">> => case jose_jwa:is_block_cipher_supported({aes_gcm, 128}) of
			false -> <<"A128CBC-HS256">>;
			true  -> <<"A128GCM">>
		end,
		<<"use">> => <<"enc">>
	})).

derive_key(<< _:?secretbytes/binary, PK:?publickeybytes/binary >>, SK = << _:?secretkeybytes/binary >>) ->
	derive_key(PK, SK);
derive_key(PK = << _:?publickeybytes/binary >>, << Secret:?secretbytes/binary, _:?publickeybytes/binary >>) ->
	jose_curve25519:x25519_shared_secret(Secret, PK).

%%====================================================================
%% API functions
%%====================================================================

from_okp({'X25519', SK = << Secret:?secretbytes/binary, PK:?publickeybytes/binary >>}) ->
	case jose_curve25519:x25519_secret_to_public(Secret) of
		PK ->
			{SK, #{}};
		_ ->
			erlang:error(badarg)
	end;
from_okp({'X25519', PK = << _:?publickeybytes/binary >>}) ->
	{PK, #{}}.

from_openssh_key({<<"ssh-x25519">>, _PK, SK, Comment}) ->
	{KTY, OtherFields} = from_okp({'X25519', SK}),
	case Comment of
		<<>> ->
			{KTY, OtherFields};
		_ ->
			{KTY, maps:merge(#{ <<"kid">> => Comment }, OtherFields)}
	end.

to_okp(SK = << _:?secretkeybytes/binary >>) ->
	{'X25519', SK};
to_okp(PK = << _:?publickeybytes/binary >>) ->
	{'X25519', PK}.

to_openssh_key(SK = << _:?secretbytes/binary, PK:?publickeybytes/binary >>, F) ->
	Comment = maps:get(<<"kid">>, F, <<>>),
	jose_jwk_openssh_key:to_binary([[{{<<"ssh-x25519">>, PK}, {<<"ssh-x25519">>, PK, SK, Comment}}]]).

%%%-------------------------------------------------------------------
%%% Internal functions
%%%-------------------------------------------------------------------