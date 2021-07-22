%%%-------------------------------------------------------------------
%%% @author elioz
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 20.  Jul 2021 1:32 PM
%%%-------------------------------------------------------------------
-module(master).
-author("Elioz & Yanir").

%% API
-export([start/0,f/0]).

start()->
  Number_Od_Workers = 4,
  register(main,self()),
  Server_Pid = spawn(fun() ->server(start,Number_Od_Workers) end),


  ok.

get_input_from_customer()->
  Input = bla, %change
  Server = node(),
  First_Letter = first_letter(Input),
  if
    ((First_Letter >= 97) and (First_Letter =< 102))  -> %send to computer that responsible on letters a - f
      Server!{request_input,worker1,Input},
      1;
    ((First_Letter >= 103) and (First_Letter =< 108))  ->%send to computer that responsible on letters g - l
      Server!{request_input,worker2,Input},
      1;
    ((First_Letter >= 109) and (First_Letter =< 115))  -> %send to computer that responsible on letters m - s
      Server!{request_input,worker3,Input},
      1;
    ((First_Letter >= 116) and (First_Letter =< 122))  ->%send to computer that responsible on letters t - z
      Server!{request_input,worker4,Input},
      1;
    true -> error
  end.

%request

first_letter(Element)->hd(string:lowercase(Element)). %Give the first letter in word, but only lowercase
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%server:
server(start,Number_Od_Workers)->
  register(node(),self()),
  List_Of_Nodes = get_nodes_from_workers(Number_Od_Workers,[],Number_Od_Workers),
  main!List_Of_Nodes,
  [Worker1,Worker2,Worker3,Worker4] = List_Of_Nodes,


  server(Worker1,Worker2,Worker3,Worker4).

server(Worker1,Worker2,Worker3,Worker4)->
  receive
    {request_input,worker1,Input}->
      {Worker1,Worker1}!{request_input,node(),Input,0};
    {request_input,worker2,Input}->
      {Worker2,Worker2}!{request_input,node(),Input,0};
    {request_input,worker3,Input}->
      {Worker3,Worker3}!{request_input,node(),Input,0};
    {request_input,worker4,Input}->
      {Worker4,Worker4}!{request_input,node(),Input,0}

  end,
  server(Worker1,Worker2,Worker3,Worker4).



get_nodes_from_workers(0,List_Of_Nodes,Number_Od_Workers)->
  [{lists:nth(X,List_Of_Nodes),lists:nth(X,List_Of_Nodes)}![X,List_Of_Nodes,node()] || X <- lists:seq(1,Number_Od_Workers)],
  List_Of_Nodes;

get_nodes_from_workers(I,List_Of_Nodes,Number_Od_Workers)->
  Node = receive
           X->X
         end,
  get_nodes_from_workers(I - 1,List_Of_Nodes ++ [Node],Number_Od_Workers).



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%General functions:

index_of(Item, List) -> index_of(Item, List, 1).  %%Function that find the index of element in list
index_of(_, [], _)  -> not_found;
index_of(Item, [Item|_], Index) -> Index;
index_of(Item, [_|Tl], Index) -> index_of(Item, Tl, Index+1).





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%tests:


f()->
  register(node(),self()),
  P = spawn(fun()-> g() end),
  L = receive
        X->X
      end,
  io:format("Yesss ~p ~n",[L]).

g()->
  S = node(),
  S!hello.


