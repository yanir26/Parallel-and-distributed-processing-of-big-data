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
-export([start/0,f/0]).

start()->
  Node_Of_Master = bla, %%%%change
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

  ok.

manage_of_subworkers(Structure)->
  receive
    {incomingInput,Source,Input,Depth}->
      Partners = maps:get(Input,Structure,notfound),
      if
        Depth >= 3-> 1;%Need to return sub tree that the root is Input and all Partners are the suns
        true -> %Depth < 3
          %[raise process for every partner || Element <- Partners]
      1
      end
  end,
  manage_of_subworkers(Structure).
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
      {Worker4,Worker4}!broadcast_finish_to_read_file;
    broadcast_finish_to_read_file->
      main!organize_stop;
    {request_input,Source,Input,Depth}->  %We will need to return sub tree which the Input will be the root to the Source
      %What to do
      main!{incomingInput,Source,Input,Depth}


  end,
  server(Worker1,Worker2,Worker3,Worker4,Master).


construction_from_master()->
  %Res = receive
  %       X->X
  %       end,
  [1,[listOfallComputers],address_of_master].



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This section will read the proper file and divide the data between all proper processes:
%range1 : a - f
%range2 : g - l
%range3 : m - s
%range4 : t - z

read_file_and_send_the_data(MY_ID)->
  File =  csv_reader:main(["file" ++ [MY_ID + 48] ++ ".csv"]),  %Open the right file
  [work_on_line(X) || X <- File],
  %send to all stop
  Server = node(),
  Server!local_finish_to_read_file,
  ok.

work_on_line(Input)->
  Line = string:split(element(2,Input),"|",all),
  [send_update_to_the_fit_worker(X,Line -- [X]) || X <- Line]. % all_permutations

send_update_to_the_fit_worker(Element,Rest_Of_Line)->
  Server = node(),
  First_Letter = first_letter(Element),
  Message = {update,Element,Rest_Of_Line},
  if
    ((First_Letter >= 97) and (First_Letter =< 102))  -> %send to computer that responsible on letters a - f
      Server!{localUpdate,worker1,Element,Rest_Of_Line},
      1;
    ((First_Letter >= 103) and (First_Letter =< 108))  ->%send to computer that responsible on letters g - l
      Server!{localUpdate,worker2,Element,Rest_Of_Line},
      1;
    ((First_Letter >= 109) and (First_Letter =< 115))  -> %send to computer that responsible on letters m - s
      Server!{localUpdate,worker3,Element,Rest_Of_Line},
      1;
    ((First_Letter >= 116) and (First_Letter =< 122))  ->%send to computer that responsible on letters t - z
      Server!{localUpdate,worker4,Element,Rest_Of_Line},
      1;
    true -> error
  end.

first_letter(Element)->hd(string:lowercase(Element)). %Give the first letter in word, but only lowercase
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


