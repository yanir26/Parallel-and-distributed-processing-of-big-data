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
  %send my address/Pid/node to the master
  List_Of_Command_From_Master = construction_from_master(),
  MY_ID = lists:nth(1,List_Of_Command_From_Master),
  My_Responsibility = lists:nth(MY_ID,lists:nth(3,List_Of_Command_From_Master)),
  Responsibilities = lists:nth(3,List_Of_Command_From_Master),
  List_Of_Addresses = lists:nth(2,List_Of_Command_From_Master),
  %%We will define worker_i as the worker which has the responsibility on range i
  Address_Of_Worker1 =  lists:nth(index_of(1,Responsibilities),List_Of_Addresses),
  register(worker1,Address_Of_Worker1),
  Address_Of_Worker2 =  lists:nth(index_of(2,Responsibilities),List_Of_Addresses),
  register(worker2,Address_Of_Worker2),
  Address_Of_Worker3 =  lists:nth(index_of(3,Responsibilities),List_Of_Addresses),
  register(worker3,Address_Of_Worker3),
  Address_Of_Worker4 =  lists:nth(index_of(4,Responsibilities),List_Of_Addresses),
  register(worker4,Address_Of_Worker4),
  Address_Of_Master = lists:nth(4,List_Of_Command_From_Master),
  register(master,Address_Of_Master),


  Pid_Sending_Process = spawn(fun() -> read_file_and_send_the_data(MY_ID) end),
  Structure = get_data_and_organized_it(),

  %will wait to input to search

  ok.

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
  ok.


construction_from_master()->
  %Res = receive
   %       X->X
    %    end,
  [1,[listOfallComputers],[1,2,3,4],address_of_master].

work_on_line(Input)->
  Line = string:split(element(2,Input),"|",all),
  [send_update_to_the_fit_worker(X,Line -- [X]) || X <- Line]. % all_permutations

send_update_to_the_fit_worker(Element,Rest_Of_Line)->
  First_Letter = first_letter(Element),
  Message = {update,Element,Rest_Of_Line},
  if
    ((First_Letter >= 97) and (First_Letter =< 102))  -> %send to computer that responsible on letters a - f
      %Address_To_Send = lists:nth(index_of(1,Responsibilities),List_Of_Addresses),
      %send Message to Address_To_Send
      worker1!Message,
      1;
    ((First_Letter >= 103) and (First_Letter =< 108))  ->%send to computer that responsible on letters g - l
      %Address_To_Send = lists:nth(index_of(2,Responsibilities),List_Of_Addresses),
      worker2!Message,
      1;
    ((First_Letter >= 109) and (First_Letter =< 115))  -> %send to computer that responsible on letters m - s
      %Address_To_Send = lists:nth(index_of(3,Responsibilities),List_Of_Addresses),
      worker3!Message,
      1;
    ((First_Letter >= 116) and (First_Letter =< 122))  ->%send to computer that responsible on letters t - z
      %Address_To_Send = lists:nth(index_of(4,Responsibilities),List_Of_Addresses),
      worker4!Message,
      1;
    true -> error
  end.

first_letter(Element)->hd(string:lowercase(Element)). %Give the first letter in word, but only lowercase
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This section will get the data from the former section and organized it in data structure;
get_data_and_organized_it()->
  Structure = maps:new(),
  get_data_and_organized_it(Structure).

get_data_and_organized_it(Structure)->
    receive
      {update,Element,Partners} ->
        Old_Val = maps:get(Element,Structure),
        maps:put(Element, Old_Val ++ Partners, Structure),
        get_data_and_organized_it();
      stop->Structure;
      _->error
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%General functions:

index_of(Item, List) -> index_of(Item, List, 1).  %%Function that find the index of element in list
index_of(_, [], _)  -> not_found;
index_of(Item, [Item|_], Index) -> Index;
index_of(Item, [_|Tl], Index) -> index_of(Item, Tl, Index+1).


f()->
  receive
    X->
      io:format("Yesss ~p ~n",[X])
  end.


