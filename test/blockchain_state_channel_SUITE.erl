-module(blockchain_state_channel_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([all/0, init_per_testcase/2, end_per_testcase/2]).

-export([
    basic_test/1
]).

-include("blockchain.hrl").

%%--------------------------------------------------------------------
%% COMMON TEST CALLBACK FUNCTIONS
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @public
%% @doc
%%   Running tests for this suite
%% @end
%%--------------------------------------------------------------------
all() ->
    [
        basic_test
    ].

%%--------------------------------------------------------------------
%% TEST CASE SETUP
%%--------------------------------------------------------------------

init_per_testcase(TestCase, Config0) ->
    BaseDir = "data/blockchain_state_channel_SUITE/" ++ erlang:atom_to_list(TestCase),
    [{base_dir, BaseDir} |Config0].

%%--------------------------------------------------------------------
%% TEST CASE TEARDOWN
%%--------------------------------------------------------------------
end_per_testcase(_TestCase, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
basic_test(Config) ->
    meck:new(blockchain_swarm, [passthrough]),
    meck:expect(blockchain_swarm, keys, fun() ->
        #{public := PubKey, secret := PrivKey} = libp2p_crypto:generate_keys(ecc_compact),
        SigFun = libp2p_crypto:mk_sig_fun(PrivKey),
        {ok, PubKey, SigFun, undefined}
    end),

    BaseDir = proplists:get_value(base_dir, Config),
    {ok, Sup} = blockchain_state_channel_sup:start_link([BaseDir]),

    ?assert(erlang:is_process_alive(Sup)),
    ?assertEqual({ok, 0}, blockchain_state_channel_server:credits()),
    ?assertEqual({ok, 0}, blockchain_state_channel_server:nonce()),

    ok = blockchain_state_channel_server:burn(10),
    ?assertEqual({ok, 10}, blockchain_state_channel_server:credits()),
    ?assertEqual({ok, 0}, blockchain_state_channel_server:nonce()),

    #{public := PubKey0, secret := PrivKey0} = libp2p_crypto:generate_keys(ecc_compact),
    PubKeyBin0 = libp2p_crypto:pubkey_to_bin(PubKey0),
    SigFun0 = libp2p_crypto:mk_sig_fun(PrivKey0),
    Req0 = blockchain_dcs_payment_req:new(PubKeyBin0, 1, <<>>),
    Req1 = blockchain_dcs_payment_req:sign(Req0, SigFun0),
    ok = blockchain_state_channel_server:payment_req(Req1),

    ?assertEqual({ok, 9}, blockchain_state_channel_server:credits()),
    ?assertEqual({ok, 1}, blockchain_state_channel_server:nonce()),

    true = erlang:exit(Sup, normal),
    ?assert(meck:validate(blockchain_swarm)),
    meck:unload(blockchain_swarm),
    ok.
