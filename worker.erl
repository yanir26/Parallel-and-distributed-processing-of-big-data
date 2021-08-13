%%%-------------------------------------------------------------------
%%% @author elioz
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. Aug 2021 12:30 PM
%%%-------------------------------------------------------------------
-module(worker).
-author("elioz").

-behaviour(gen_server).

%% API
-export([start/1]).
-include_lib("wx/include/wx.hrl").


%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, node()).
-define(NUMBER_OF_FILES,4).
-define(DEPTH,3).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================
%%%===================================================================
%Our Code:
start(Node_Of_Master)->
  register(main,self()),
  start(Node_Of_Master,0).
start(Node_Of_Master,I)->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [Node_Of_Master], []),	%Start a gen server
  gen_server:start_link({local, keep_alive_server}, ?MODULE, [keep_alive_server], []), %Start keep alive server
  List_Of_Command_From_Master = gen_server:call(?SERVER,construction_from_master,infinity),% This line are get commands from the master, List_Of_Command_From_Master = [Responsibilities,List_Of_Workers,Master node]
  Responsibilities = lists:nth(1,List_Of_Command_From_Master),	%Take responsibilities
  List_Of_Workers = lists:nth(2,List_Of_Command_From_Master),	%Take List_Of_Workers
  Number_Of_Worker = length(List_Of_Workers),
  io:format("List_Of_Workers = ~p ~n Number_Of_Worker = ~p ~n",[List_Of_Workers,Number_Of_Worker]),

  [ spawn(fun() -> read_file_and_send_the_data(Id,List_Of_Workers,Node_Of_Master) end) || Id <- Responsibilities],%Open process that read file for every Responsibility
  {What,Structure} = get_data_and_organized_it(?NUMBER_OF_FILES),	%Here we call the function from section that orgenized the data
  case What of
    restart->		%what if we get restart, it's mean that one of the computers was down 
      timer:sleep(1000),
      start(Node_Of_Master,I + 1);
    _->
      %will wait to input to search
      Manage_Of_Requests_Pid = spawn(fun() -> manage_requests_fun(Structure,List_Of_Workers,[],maps:new(),Responsibilities) end),
      register(manage_requests,Manage_Of_Requests_Pid),
      receive
        kill -> Structure;
        restart->
          timer:sleep(1000),
          start(Node_Of_Master,I + 1)
      end
  end.





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%Every computer will be resnposible on range of letters in english.
%%Every partition to ranges will determined by bucketing permotation that known by all workers and the master as well. 

%%This section will read the proper file and divide the data between all proper node that rensposible on the proper range.
%%In other words, every line the process update about the partnership all computers that need to know about it

read_file_and_send_the_data(MY_ID,List_Of_Workers,Node_Of_Master)->
  T1 = erlang:timestamp(),
  io:format("Start reading ~n"),
  File =  csv_reader:main(["Part" ++ [MY_ID + 48] ++ ".csv"]),  %Open the right file
  [work_on_line(X,List_Of_Workers) || X <- File],
  [ gen_server:cast({Worker,Worker},broadcast_finish_to_read_file)|| Worker <- List_Of_Workers],
  gen_server:cast({Node_Of_Master,Node_Of_Master},broadcast_finish_to_read_file),
  io:format("Runtime for reading the data  = ~p microseconds ~n",[timer:now_diff(erlang:timestamp(),T1)]),
  ok.

work_on_line(Input,List_Of_Workers)->
   Line = string:split(lists:nth(2,string:split(element(1,Input),";",all)),"|",all),
  [gen_server:cast({for_which_worker(X,List_Of_Workers),for_which_worker(X,List_Of_Workers)},{remoteUpdate,X,Line -- [X]})|| X <- Line,X =/= []]. % all_permutations



first_letter(Element)->hd(string:lowercase(Element)). %Give the first letter in word, but only lowercase

for_which_worker(Element,List_Of_Workers)->
  First_Letter = first_letter(Element),
  Number_Of_Workers = length(List_Of_Workers),
  Index = if
            ((First_Letter >= 97) and (First_Letter =< 122)) -> round(math:ceil(((First_Letter - 97 + 0.0001 ) * Number_Of_Workers) / 26));
            true -> 1
          end,
  lists:nth(Index,List_Of_Workers).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This section will get the data from the former section and organized it in data structure;
get_data_and_organized_it(Number_Of_Worker)->
  Structure = maps:new(),
  get_data_and_organized_it(Structure,Number_Of_Worker,Number_Of_Worker).

get_data_and_organized_it(Structure,0,_Number_Of_Worker)->{ok,Structure};
get_data_and_organized_it(Structure,I,Number_Of_Worker)->
  receive
    {organize,Element,Partners} ->
      Old_Val = maps:get(Element,Structure,notfound),
      New_Structure = if
                        Old_Val =:= notfound -> maps:put(Element, Partners, Structure);
                        true -> maps:put(Element,remove_duplicate(Old_Val ++ Partners), Structure) %remove_duplicate(
                      end,
      get_data_and_organized_it(New_Structure,I,Number_Of_Worker);
    organize_stop->
    	get_data_and_organized_it(Structure,I - 1,Number_Of_Worker);
    restart->{restart,restart};
    _->error
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This section will manage request for searching in the structure
manage_requests_fun(Structure,List_Of_Workers,List_Of_Processes,History,Responsibilities)->
  receive
    new_mission->
        [ Pid!kill || Pid <- List_Of_Processes],
	if 
	  List_Of_Processes =/= [] -> io:format("Number of processes = ~p ~n",[length(List_Of_Processes) +  length(Responsibilities) + 2]);
	  true -> ok
	end,
	manage_requests_fun(Structure,List_Of_Workers,[],maps:new(),Responsibilities);
    {new_request,Source_Node,Source_Pid,Input,Depth,Fathers}->
      case maps:get(Input,History,notfound) of 
        notfound ->
          Pid = spawn(fun() -> searcher(Structure,List_Of_Workers,Source_Node,Source_Pid,Input,Depth,Fathers) end),
          manage_requests_fun(Structure,List_Of_Workers,List_Of_Processes ++ [Pid],maps:put(Input, true, History),Responsibilities);
        _->
          gen_server:cast({Source_Node,Source_Node},{mission_accomplished,Source_Pid,{ask_already,Input}}),
          manage_requests_fun(Structure,List_Of_Workers,List_Of_Processes,History,Responsibilities)

      end;
    kill ->
      io:format("Number of processes = ~p ~n",[length(List_Of_Processes) +  length(Responsibilities) + 2]),
      [ Pid!kill || Pid <- List_Of_Processes]
  end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%This process get a request for creating and returning sub tree that rooted with input that the process get as argument.
%%The process get more data like List_Of_Workers that contain the nodes of all workers
%%and the source node ets as well.
%%The process first check if the input is restore in the data strucrure. After that 
%%the process check the depth, if it's the last one it return an empty sub tree with the root (itself), otherwise it 
%%generate a new request for sub tree that rooted with every partner of the input that not apear already in the tree and send the request to the proper worker.
%%After all sub trees arrived, it merge them to on tree and return the answer to the Source_Node.
%%And so on it continue and work recursivly

searcher(Structure,List_Of_Workers,Source_Node,Source_Pid,Input,Depth,Fathers)->
  Partners = maps:get(Input,Structure,notfound),
  if
    ((Partners =:= notfound) or (Partners =:= [])) ->
      io:format("The author ~p is not found ~n",[Input]),
      gen_server:cast({Source_Node,Source_Node},{mission_accomplished,Source_Pid,{notfound,Input}});
    Depth =:= ?DEPTH + 1 ->
      gen_server:cast({Source_Node,Source_Node},{mission_accomplished,Source_Pid,{[],Input}});

    true ->
      List_Of_Relevant_Partners = [gen_server:cast({for_which_worker(Person,List_Of_Workers),for_which_worker(Person,List_Of_Workers)},{incoming_input,node(),self(),Person,Depth + 1,Fathers ++ [Person]  ++ Partners}) || Person <- Partners,not(lists:member(Person,Fathers))],
      List_Of_Sub_Trees = receiving_sub_trees(length(List_Of_Relevant_Partners),[]), %list of [{Res,Root}] of all sub trees
      if
        List_Of_Sub_Trees =:= stopped -> stopped;
        true ->
          Res = merge_trees(Input,List_Of_Sub_Trees),
          gen_server:cast({Source_Node,Source_Node},{mission_accomplished,Source_Pid,{Res,Input}})
      end
  end,
  finito.


receiving_sub_trees(0,List_Of_Sub_Trees)->List_Of_Sub_Trees; % That function wait until all answers of subtrees was arrived
receiving_sub_trees(I,List_Of_Sub_Trees)->
  receive
    {final_result_for_request,{ask_already,_}}->
      receiving_sub_trees(I - 1,List_Of_Sub_Trees);
    {final_result_for_request,{Res,Root}}->
      receiving_sub_trees(I - 1,List_Of_Sub_Trees ++ [{Res,Root}]);
    kill -> stopped
  end.





merge_trees(Input,List_Of_Sub_Trees)->	%That function merge all sub trees
  Roots = [element(2,X) || X <- List_Of_Sub_Trees],
  Result_Till_Now = [element(1,Y) || Y <- List_Of_Sub_Trees,((element(1,Y) =/= notfound) and (element(1,Y) =/= ask_already))],
  [{Input,Rooti} || Rooti <- Roots] ++ lists:merge(Result_Till_Now).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%General functions:

 remove_duplicate(List) -> % This function removed all duplicates elements from the list
    Set = sets:from_list(List),
    sets:to_list(Set).
    
    
send_message_to_proc_without_fail(Name,Message)->	%The function is send message to process and cath any 
  case whereis(Name) of
    undefined ->
      ok;
    _->
      try Name!Message of
        _->ok
      catch
        error:_Error	-> ok;
        exit:_Exit	->   ok;
        throw:_Throw->  ok
      end
  end.
  
 

%%End my code
%%%===================================================================
%%The server will almost only pass messages to the node's processes. It happend in order to avoid the battleneck that can happen. In other words the server doesn't do a difficult missions.
%%--------------------------------------------------------------------
%%--------------------------------------------------------------------
%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([keep_alive_server]) ->
  {ok,keep_alive_server};
init([Node_Of_Master]) ->
  {ok, [Node_Of_Master]}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
  {reply, Reply :: term(), NewState :: #state{}} |
  {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
  {stop, Reason :: term(), NewState :: #state{}}).
%handle_call(_Request, _From, State) ->
 % {reply, ok, State}.

handle_call(ping, _From, State) ->
  {reply, pong, State};
handle_call(construction_from_master, _From, [Node_Of_Master]) ->
  Result = gen_server:call({Node_Of_Master,Node_Of_Master},{ask_to_construction_from_master,node()},infinity),
  State = lists:nth(2,Result) ++ [Node_Of_Master],
  {reply, Result, State}.
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
%handle_cast(_Request, State) ->
 % {noreply, State}.




handle_cast(broadcast_finish_to_read_file,State)->
  main!organize_stop,
  {noreply, State};
handle_cast({remoteUpdate,Element,Rest_Of_Line},State)->
  main!{organize,Element,Rest_Of_Line},
  {noreply, State};
handle_cast({incoming_input,Source_Node,Source_Pid,Input,Depth,Fathers},State)->
  manage_requests!{new_request,Source_Node,Source_Pid,Input,Depth,Fathers},
  {noreply, State};
handle_cast( {mission_accomplished,Source_Pid,{Res,Root}},State)->
  Source_Pid!{final_result_for_request,{Res,Root}},
  {noreply, State};
handle_cast(new_mission,State)->
	manage_requests!new_mission,
	{noreply, State};
handle_cast(restart,_)->
  {noreply, restart}.





%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_info(_Info, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).
%terminate(_Reason, _State) ->
 % ok.
terminate(_Reason, keep_alive_server) ->
  io:format("Keep_alive_server stopped ~n"),
  ok;
terminate(_Reason, restart) ->
  io:format("Restart server ~n"),
  send_message_to_proc_without_fail(manage_requests,kill),
  send_message_to_proc_without_fail(main,restart),
  gen_server:stop(keep_alive_server), %keep alive
  ok;
terminate(_Reason, _State) ->
  io:format("Terminate server ~n"),
  send_message_to_proc_without_fail(manage_requests,kill),
  send_message_to_proc_without_fail(main,kill),
  gen_server:stop(keep_alive_server), %keep alive
  io:format("Server stopped ~n"),
  ok.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
  {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
