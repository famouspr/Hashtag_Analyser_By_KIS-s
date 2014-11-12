-module(twitterminer_riak).

-export([twitter_example/0, twitter_save_pipeline/3, get_riak_hostport/1]).

-record(hostport, {host, port}).

% This file contains example code that connects to Twitter and saves tweets to Riak.
% It would benefit from refactoring it together with twitterminer_source.erl.

keyfind(Key, L) ->
  {Key, V} = lists:keyfind(Key, 1, L),
  V.

%% @doc Get Twitter account keys from a configuration file.
get_riak_hostport(Name) ->
  {ok, Nodes} = application:get_env(twitterminer, riak_nodes),
  {Name, Keys} = lists:keyfind(Name, 1, Nodes),
  #hostport{host=keyfind(host, Keys),
            port=keyfind(port, Keys)}.

%% @doc This example will download a sample of tweets and print it.
twitter_example() ->
  URL = "https://stream.twitter.com/1.1/statuses/sample.json",

  % We get our keys from the twitterminer.config configuration file.
  Keys = twitterminer_source:get_account_keys(account1),

  RHP = get_riak_hostport(riak1),
  {ok, R} = riakc_pb_socket:start(RHP#hostport.host, RHP#hostport.port),

  % Run our pipeline
  P = twitterminer_pipeline:build_link(twitter_save_pipeline(R, URL, Keys)),

  % If the pipeline does not terminate after 60 s, this process will
  % force it.
  T = spawn_link(fun () ->
        receive
          cancel -> ok
        after 60000 -> % Sleep fo 60 s	
            twitterminer_pipeline:terminate(P)
        end
    end),

  Res = twitterminer_pipeline:join(P),
  T ! cancel,
  Res.

%% @doc Create a pipeline that connects to twitter and
%% saves tweets to Riak. We save all messages that have ids,
%% which might include delete notifications etc.
twitter_save_pipeline(R, URL, Keys) ->


  Prod = twitterminer_source:twitter_producer(URL, Keys),

  % Pipelines are constructed 'backwards' - consumer is first, producer is last.
  [
    twitterminer_pipeline:consumer(
      fun(Msg, N) -> save_tweet(R, Msg), N+1 end, 0),
    twitterminer_pipeline:map(
      fun twitterminer_source:decorate_with_id/1),
    twitterminer_source:split_transformer(),
    Prod].

% We save only objects that have ids.
save_tweet(R, {parsed_tweet, _L, B, {id, I}}) ->
io:format("I is ~p~n",[I]),
{L}=jiffy:decode(B),
%io:format("Decoded is ~p~n",[L]),
Bd=decorate(L),
Id=fetch_key(L),

case check(Id) of 
true->
Obj = riakc_obj:new(<<"tweets">>, list_to_binary(Id), Bd),
 io:format("Key is ~p~n",[Id]),
 io:format("Value is ~p~n",[Bd]),
riakc_pb_socket:put(R, Obj, [{w, 0}]);
_->ok
end;
save_tweet(_, _) -> ok.


%checks if a list is empty or not
check(KeyList)->case KeyList of 
[]->false;
_->true 
end.

%%parses valuable data from the List. 
decorate([_|T])-> 

case lists:keysearch(<<"user">>,1,T)of
{value,{_,{O}}}->
case lists:keysearch(<<"lang">>,1,O)of
{value,{Z,Zs}}->Q=[{Z,Zs}]
end
end,

case  lists:keysearch(<<"retweeted_status">>,1,T) of
{value, {_,{Ps}}}->
case lists:keysearch(<<"favorite_count">>,1, Ps)of
{value,{R,Rs}}->case lists:keysearch(<<"retweet_count">>,1,Ps)of
{value,{E,Es}}->[{E,Es},{R,Rs}]++Q
end
end;
_->Q
end.


%%parse the hashtag from the given List.
fetch_key([_|T])->case lists:keysearch(<<"entities">>,1,T)of 
{value,{_,{E}}}->
case lists:keysearch(<<"hashtags">>,1,E)of
{value, {_,Ss}}->hashFormat(Ss)
end
end.

%%cleans up the parsed hashtag so we only get the hashtags and nothing extra
hashFormat(U)->hashFormat(U,[]).
hashFormat([],W)->W;
hashFormat([H|_],W)->case H of
{[{_,R},_]}->[R]++W
end.

