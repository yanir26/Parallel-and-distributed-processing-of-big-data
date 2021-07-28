
%%%-------------------------------------------------------------------
%%% @author Elioz & Yanir
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 20.  Jul 2021 1:32 PM
%%%-------------------------------------------------------------------
-module(worker).
-author("Elioz & Yanir").

%% API
-export([start/0,f/2,g/1]).

%part one work

start()->
  Node_Of_Master = 'master@elioz-VirtualBox', %%%%change
  register(main,self()),
  Server_Pid = spawn(fun() ->server(start,Node_Of_Master) end),
  List_Of_Command_From_Master = receive
                                  X->X
                                end,
  MY_ID = lists:nth(1,List_Of_Command_From_Master),
  Number_Of_Worker = length(lists:nth(2,List_Of_Command_From_Master)),


  Pid_Sending_Process = spawn(fun() -> read_file_and_send_the_data(MY_ID) end),
  Structure = get_data_and_organized_it(Number_Of_Worker),

  %will wait to input to search
  Manage_Of_Requests_Pid = spawn(fun() -> manage_requests_fun(Structure,[]) end),
  register(manage_requests,Manage_Of_Requests_Pid),


  Structure.
  %ok.





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%server:
server(start,Master)->
  register(node(),self()),
  {Master,Master}!node(),
  List_Of_Command_From_Master = construction_from_master(),
  main!List_Of_Command_From_Master,
  [Worker1,Worker2,Worker3,Worker4] = lists:nth(2,List_Of_Command_From_Master),
  server(Worker1,Worker2,Worker3,Worker4,Master).

server(Worker1,Worker2,Worker3,Worker4,Master)->
  receive
    {localUpdate,worker1,Element,Rest_Of_Line} ->
      {Worker1,Worker1}!{remoteUpdate,Element,Rest_Of_Line};
    {localUpdate,worker2,Element,Rest_Of_Line} ->
      {Worker2,Worker2}!{remoteUpdate,Element,Rest_Of_Line};
    {localUpdate,worker3,Element,Rest_Of_Line} ->
      {Worker3,Worker3}!{remoteUpdate,Element,Rest_Of_Line};
    {localUpdate,worker4,Element,Rest_Of_Line} ->
      {Worker4,Worker4}!{remoteUpdate,Element,Rest_Of_Line};
    {remoteUpdate,Element,Rest_Of_Line}->
      main!{organize,Element,Rest_Of_Line};
    local_finish_to_read_file ->
      {Worker1,Worker1}!broadcast_finish_to_read_file,
      {Worker2,Worker2}!broadcast_finish_to_read_file,
      {Worker3,Worker3}!broadcast_finish_to_read_file,
      {Worker4,Worker4}!broadcast_finish_to_read_file,
      {Master,Master}!broadcast_finish_to_read_file;
    broadcast_finish_to_read_file->
      main!organize_stop;
    {incoming_input,Source_Node,Source_Pid,Input,Depth,Fathers}->
      manage_requests!{new_request,Source_Node,Source_Pid,Input,Depth,Fathers};
    {answer_for_request,Source_Node,Source_Pid,{Res,Root}}->
      {Source_Node,Source_Node}!{mission_accomplished,Source_Pid,{Res,Root}};
    {mission_accomplished,Source_Pid,{Res,Root}}->
      Source_Pid!{final_result_for_request,{Res,Root}};
    {local_request_with_input,worker1,Source_Pid,Input,Depth,Fathers}->
      {Worker1,Worker1}!{incoming_input,node(),Source_Pid,Input,Depth,Fathers};
    {local_request_with_input,worker2,Source_Pid,Input,Depth,Fathers}->
      {Worker2,Worker2}!{incoming_input,node(),Source_Pid,Input,Depth,Fathers};
    {local_request_with_input,worker3,Source_Pid,Input,Depth,Fathers}->
      {Worker3,Worker3}!{incoming_input,node(),Source_Pid,Input,Depth,Fathers};
    {local_request_with_input,worker4,Source_Pid,Input,Depth,Fathers}->
      {Worker4,Worker4}!{incoming_input,node(),Source_Pid,Input,Depth,Fathers}

  end,
  server(Worker1,Worker2,Worker3,Worker4,Master).


construction_from_master()->
  Res = receive
         X->X
         end,
  %[1,[listOfallComputers],address_of_master].
  Res.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This section will read the proper file and divide the data between all proper processes:
%range1 : a - f
%range2 : g - l
%range3 : m - s
%range4 : t - z

read_file_and_send_the_data(MY_ID)->
  io:format("Start reading ~n"),
  File =  csv_reader:main(["file" ++ [MY_ID + 48] ++ ".csv"]),  %Open the right file
  [work_on_line(X) || X <- File],
  %send to all stop
  Server = node(),
  Server!local_finish_to_read_file,
  ok.

work_on_line(Input)->
  Line = string:split(element(2,Input),"|",all),
  [send_update_to_the_fit_worker(X,Line -- [X]) || X <- Line,X =/= []]. % all_permutations

send_update_to_the_fit_worker(Element,Rest_Of_Line)->
  Server = node(),
  First_Letter = first_letter(Element),
  Server!{localUpdate,for_which_worker(Element),Element,Rest_Of_Line},
  ok.


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
%This section will get the data from the former section and organized it in data structure;
get_data_and_organized_it(Number_Of_Worker)->
  Structure = maps:new(),
  get_data_and_organized_it(Structure,Number_Of_Worker,Number_Of_Worker).

get_data_and_organized_it(Structure,I,Number_Of_Worker)->
    receive
      {organize,Element,Partners} ->
        Old_Val = maps:get(Element,Structure,notfound),
        New_Structure = if
                          Old_Val =:= notfound -> maps:put(Element, Partners, Structure);
                          true -> maps:put(Element, Old_Val ++ Partners, Structure)
                        end,
        get_data_and_organized_it(New_Structure,I,Number_Of_Worker);
      organize_stop->
        if
          I =:= Number_Of_Worker -> Structure;
          true -> get_data_and_organized_it(Structure,I + 1,Number_Of_Worker)
        end;
      _->error
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This section will manage request for searching in the structure
manage_requests_fun(Structure,List_Of_Processes)->
  receive
    {new_request,Source_Node,Source_Pid,Input,Depth,Fathers}->
      Pid = spawn(fun() -> searcher(Structure,Source_Node,Source_Pid,Input,Depth,Fathers) end),
      manage_requests_fun(Structure,List_Of_Processes ++ [Pid]);
    kill -> stopped

  end.


searcher(Structure,Source_Node,Source_Pid,Input,Depth,Fathers)->%maybe not found
  Server = node(),
  Partners = maps:get(Input,Structure,notfound),
  if
    Partners =:= notfound ->
      io:format("not found in node = ~p , and input = ~p !n",[node(),Input]),
      Server!{answer_for_request,Source_Node,Source_Pid,{notfound,Input}};
    Depth =:= 3 ->
      Res = make_tree(Input,Partners),
      Server!{answer_for_request,Source_Node,Source_Pid,{Res,Input}};

    true ->
      Number_Of_Partners = length(Partners),
      List_Of_Relevant_Partners = [Server!{local_request_with_input,for_which_worker(Person),self(),Person,Depth + 1,Fathers ++ [Person]} || Person <- Partners,not(lists:member(Person,Fathers))],
      List_Of_Sub_Trees = receiving_sub_trees(length(List_Of_Relevant_Partners),[]), %list of [{Res,Root}] of all sub trees
      Res = merge_trees(Input,List_Of_Sub_Trees),
      Server!{answer_for_request,Source_Node,Source_Pid,{Res,Input}}
  end,
  finito.


receiving_sub_trees(0,List_Of_Sub_Trees)->List_Of_Sub_Trees;
receiving_sub_trees(I,List_Of_Sub_Trees)->
  receive
    {final_result_for_request,{Res,Root}}->
      receiving_sub_trees(I - 1,List_Of_Sub_Trees ++ [{Res,Root}])
  end.

make_tree(Input,Partners)->
  %G = digraph:new(),
  %[digraph:add_vertex(G, V) || V <- ([Input] ++ Partners)],
  %[digraph:add_edge(G, Input, V) || V <- Partners],
  %G.

  [Input] ++ Partners.

merge_trees(Input,List_Of_Sub_Trees)->
  [Input] ++ List_Of_Sub_Trees.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%General functions:

index_of(Item, List) -> index_of(Item, List, 1).  %%Function that find the index of element in list
index_of(_, [], _)  -> not_found;
index_of(Item, [Item|_], Index) -> Index;
index_of(Item, [_|Tl], Index) -> index_of(Item, Tl, Index+1).





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%tests:


f(A,B)->
  merge_trees(c,[A,B]).

g(1)->
  make_tree(1,[2,3,4]);
g(2)->
  make_tree(11,[12,13,14]).



