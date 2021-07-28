%%%-------------------------------------------------------------------
%%% @author Elioz & Yanir
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

%part one work

start()->
  Number_Od_Workers = 4,
  register(main,self()),
  Server_Pid = spawn(fun() ->server(start,Number_Od_Workers,self()) end),
  %%%%%%%test:
  %Server = node(),
  %Input = "Helmer Strik",
  %[Server_Pid!node() || I <- [1,2,3,4]],
  %Worker = for_which_worker(Input),
  %Server_Pid!{local_request_with_input,Worker,self(),Input,1,[Input]},


  %%%%%%

  wait_until_workers_finish(Number_Od_Workers),



  get_input_from_customer(Server_Pid).


wait_until_workers_finish(0)->ok_continue_with_work;
wait_until_workers_finish(I)->
  receive
    broadcast_finish_to_read_file->
      wait_until_workers_finish(I - 1)
  end.


get_input_from_customer(Server_Pid)->
  Input = "Helmer Strik", %change
  Server = node(),
  Worker = for_which_worker(Input),
  Server_Pid!{local_request_with_input,Worker,self(),Input,1,[Input]},

  Res = receive
          {final_result_for_request,{Answer,Root}}->Answer
        end,
  Res.


first_letter(Element)->hd(string:lowercase(Element)). %Give the first letter in word, but only lowercase

for_which_worker(Element)->
  First_Letter = first_letter(Element),
  if
    ((First_Letter >= 97) and (First_Letter =< 102))  -> worker1;%worker1 is responsible on letters a - f
    ((First_Letter >= 103) and (First_Letter =< 108))  -> worker2;%worker2 is responsible on letters g - l
    ((First_Letter >= 109) and (First_Letter =< 115))  -> worker3;%worker3 is responsible on letters m - s
    ((First_Letter >= 116) and (First_Letter =< 122))  ->worker4;%worker4 is  responsible on letters t - z
    true -> worker1
  end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%server:
server(start,Number_Od_Workers,Main_Pid)->
  register(node(),self()),
  List_Of_Nodes = get_nodes_from_workers(Number_Od_Workers,[],Number_Od_Workers),
  main!List_Of_Nodes,
  [Worker1,Worker2,Worker3,Worker4] = List_Of_Nodes,


  server(Worker1,Worker2,Worker3,Worker4).

server(Worker1,Worker2,Worker3,Worker4)->
  receive
    broadcast_finish_to_read_file->
      main!broadcast_finish_to_read_file;
    {request_input,worker1,Source_Pid,Input}->
      {Worker1,Worker1}!{request_input,node(),Source_Pid,Input,0};
    {request_input,worker2,Source_Pid,Input}->
      {Worker2,Worker2}!{request_input,node(),Source_Pid,Input,0};
    {request_input,worker3,Source_Pid,Input}->
      {Worker3,Worker3}!{request_input,node(),Source_Pid,Input,0};
    {request_input,worker4,Source_Pid,Input}->
      {Worker4,Worker4}!{request_input,node(),Source_Pid,Input,0};
    {local_request_with_input,worker1,Source_Pid,Input,Depth,Fathers}->
      {Worker1,Worker1}!{incoming_input,node(),Source_Pid,Input,Depth,Fathers};
    {local_request_with_input,worker2,Source_Pid,Input,Depth,Fathers}->
      io:format("get this ~n"),
      {Worker2,Worker2}!{incoming_input,node(),Source_Pid,Input,Depth,Fathers};
    {local_request_with_input,worker3,Source_Pid,Input,Depth,Fathers}->
      {Worker3,Worker3}!{incoming_input,node(),Source_Pid,Input,Depth,Fathers};
    {local_request_with_input,worker4,Source_Pid,Input,Depth,Fathers}->
      {Worker4,Worker4}!{incoming_input,node(),Source_Pid,Input,Depth,Fathers};
    {mission_accomplished,Source_Pid,{Res,Root}}->
      io:format("Result = ~p ~n",[Res]),
      Source_Pid!{final_result_for_request,{Res,Root}}

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
  P = spawn(fun()-> g() end),
  Server = node(),
  Worker = worker2,
  Input = 10,
  register(x,self()),
  P!{local_request_with_input},
  ok.


g()->
  %register(x,self()),
  receive
    {local_request_with_input}->
      io:format("yesss")

  end.


