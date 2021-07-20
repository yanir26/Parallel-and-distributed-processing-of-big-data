%%%-------------------------------------------------------------------
%%% @author elioz
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 20.  Jul 2021 1:32 PM
%%%-------------------------------------------------------------------
-module(main).
-author("Elioz & Yanir").

%% API
-export([main/1]).

main(I)->
  File = csv_reader:main(["file1.csv"]),
  [string:split(element(2,X),"|",all)||X<-File].



