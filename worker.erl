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

-compile(export_all).%delete

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, node()).
-define(NUMBER_OF_FILES,4).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================
s() ->
  [
    try 4/X of
      _->1
    catch
      error:_Error	-> 0;
      exit:_Exit	->   0;
      throw:_Throw->  0
    end
    || X <- [1,2,3,0,4]].
%%%===================================================================
%Our Code:
start(Node_Of_Master)->
  register(main,self()),
  start(Node_Of_Master,0).
start(Node_Of_Master,I)->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [Node_Of_Master], []),
  gen_server:start_link({local, keep_alive_server}, ?MODULE, [keep_alive_server], []), %keep alive
  List_Of_Command_From_Master = gen_server:call(?SERVER,construction_from_master,infinity),
  Responsibilities = lists:nth(1,List_Of_Command_From_Master),
  List_Of_Workers = lists:nth(2,List_Of_Command_From_Master),
  Number_Of_Worker = length(List_Of_Workers),
  io:format("List_Of_Workers = ~p ~n Number_Of_Worker = ~p ~n",[List_Of_Workers,Number_Of_Worker]),

  [ spawn(fun() -> read_file_and_send_the_data(Id,List_Of_Workers,Node_Of_Master) end) || Id <- Responsibilities],
  {What,Structure} = get_data_and_organized_it(?NUMBER_OF_FILES),
  io:format("Structure = ~p ~n",[What]),
  case What of
    restart->
      io:format("get restart 1 ~n"),
      timer:sleep(1000),
      start(Node_Of_Master,I + 1);
    _->
      %will wait to input to search
      Manage_Of_Requests_Pid = spawn(fun() -> manage_requests_fun(Structure,List_Of_Workers,[]) end),
      register(manage_requests,Manage_Of_Requests_Pid),
	io:format("waiting ~n"),
      receive
        kill -> Structure;
        restart->
          io:format("get restart 2 ~n"),
          timer:sleep(1000),
          start(Node_Of_Master,I + 1)
      end
  end.









construction_from_master()->% delete
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

read_file_and_send_the_data(MY_ID,List_Of_Workers,Node_Of_Master)->
  io:format("Start reading ~n"),
  File =  csv_reader:main(["file" ++ [MY_ID + 48] ++ ".csv"]),  %Open the right file
  [work_on_line(X,List_Of_Workers) || X <- File],
  %send to all stop
  %gen_server:cast({?SERVER,?SERVER},local_finish_to_read_file),
  [ gen_server:cast({Worker,Worker},broadcast_finish_to_read_file)|| Worker <- List_Of_Workers],
  gen_server:cast({Node_Of_Master,Node_Of_Master},broadcast_finish_to_read_file),
  ok.

work_on_line(Input,List_Of_Workers)->
  Line = string:split(element(2,Input),"|",all),
  [gen_server:cast({for_which_worker(X,List_Of_Workers),for_which_worker(X,List_Of_Workers)},{remoteUpdate,X,Line -- [X]})|| X <- Line,X =/= []]. % all_permutations
  %[send_to_appropriate_worker(X,Line -- [X],List_Of_Workers)|| X <- Line,X =/= []]. % all_permutations
%gen_server:cast({?SERVER,?SERVER},{localUpdate,for_which_worker(X),X,Line -- [X]})

send_to_appropriate_worker(Element,Rest_Of_Line,List_Of_Workers)->% delete
  Worker = for_which_worker(Element,List_Of_Workers),
  gen_server:cast({Worker,Worker},{remoteUpdate,Element,Rest_Of_Line}).


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
                        true -> maps:put(Element, Old_Val ++ Partners, Structure)
                      end,
      get_data_and_organized_it(New_Structure,I,Number_Of_Worker);
    organize_stop->
    	get_data_and_organized_it(Structure,I - 1,Number_Of_Worker);
      %if
       % I =:= 1 -> Structure;
        %true -> get_data_and_organized_it(Structure,I - 1,Number_Of_Worker)
      %end;
    restart->{restart,restart};
    _->error
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This section will manage request for searching in the structure
manage_requests_fun(Structure,List_Of_Workers,List_Of_Processes)->
  receive
    {new_request,Source_Node,Source_Pid,Input,Depth,Fathers}->
      Pid = spawn(fun() -> searcher(Structure,List_Of_Workers,Source_Node,Source_Pid,Input,Depth,Fathers) end),
      manage_requests_fun(Structure,List_Of_Workers,List_Of_Processes ++ [Pid]);
    kill ->
      [ Pid!kill || Pid <- List_Of_Processes]
  end.


searcher(Structure,List_Of_Workers,Source_Node,Source_Pid,Input,Depth,Fathers)->%maybe not found
  Partners = maps:get(Input,Structure,notfound),
  if
    ((Partners =:= notfound) or (Partners =:= [])) ->
      io:format("not found in node = ~p , and input = ~p !n",[node(),Input]),
      gen_server:cast({Source_Node,Source_Node},{mission_accomplished,Source_Pid,{notfound,Input}});

      %gen_server:cast({?SERVER,?SERVER},{answer_for_request,Source_Node,Source_Pid,{notfound,Input}});
    Depth =:= 3 ->
      List = [X || X <- Partners,not(lists:member(X,Fathers))],
      Res = make_tree(Input,List),
      gen_server:cast({Source_Node,Source_Node},{mission_accomplished,Source_Pid,{Res,Input}});

      %gen_server:cast({?SERVER,?SERVER},{answer_for_request,Source_Node,Source_Pid,{Res,Input}});
    true ->
      List_Of_Relevant_Partners = [gen_server:cast({for_which_worker(Person,List_Of_Workers),for_which_worker(Person,List_Of_Workers)},{incoming_input,node(),self(),Person,Depth + 1,Fathers ++ [Person]  ++ Partners}) || Person <- Partners,not(lists:member(Person,Fathers))],
      %gen_server:cast({?SERVER,?SERVER},{local_request_with_input,for_which_worker(Person),self(),Person,Depth + 1,Fathers ++ [Person]  ++ Partners})
      List_Of_Sub_Trees = receiving_sub_trees(length(List_Of_Relevant_Partners),[]), %list of [{Res,Root}] of all sub trees
      if
        List_Of_Sub_Trees =:= stopped -> stopped;
        true ->
          Res = merge_trees(Input,List_Of_Sub_Trees),
          gen_server:cast({?SERVER,?SERVER},{answer_for_request,Source_Node,Source_Pid,{Res,Input}})
      end
  end,
  finito.


receiving_sub_trees(0,List_Of_Sub_Trees)->List_Of_Sub_Trees;
receiving_sub_trees(I,List_Of_Sub_Trees)->
  receive
    {final_result_for_request,{Res,Root}}->
      receiving_sub_trees(I - 1,List_Of_Sub_Trees ++ [{Res,Root}]);
    kill -> stopped
  end.




make_tree(Input,Partners)-> % make list = G = [V,E] , where V is list of vertexes and E is list of edges {V1,V2}
  [{Input,X} || X <- Partners].



merge_trees(Input,List_Of_Sub_Trees)->
  Roots = [element(2,X) || X <- List_Of_Sub_Trees],
  Result_Till_Now = [element(1,Y) || Y <- List_Of_Sub_Trees,element(1,Y) =/= notfound],
  [{Input,Rooti} || Rooti <- Roots] ++ lists:merge(Result_Till_Now).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%General functions:
send_message_to_proc_without_fail(Name,Message)->
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
  io:format("State = ~p ~n ",[State]),
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



handle_cast(local_finish_to_read_file,State)->%delete
  [Worker1,Worker2,Worker3,Worker4,Master] = State,
  gen_server:cast({Worker1,Worker1},broadcast_finish_to_read_file),
  gen_server:cast({Worker2,Worker2},broadcast_finish_to_read_file),
  gen_server:cast({Worker3,Worker3},broadcast_finish_to_read_file),
  gen_server:cast({Worker4,Worker4},broadcast_finish_to_read_file),
  gen_server:cast({Master,Master},broadcast_finish_to_read_file),
  {noreply, State};
handle_cast(broadcast_finish_to_read_file,State)->
  main!organize_stop,
  {noreply, State};
handle_cast({localUpdate,worker1,Element,Rest_Of_Line},[Worker1,Worker2,Worker3,Worker4,Master])->%delete
  gen_server:cast({Worker1,Worker1},{remoteUpdate,Element,Rest_Of_Line}),
  {noreply, [Worker1,Worker2,Worker3,Worker4,Master]};
handle_cast({localUpdate,worker2,Element,Rest_Of_Line},[Worker1,Worker2,Worker3,Worker4,Master])->%delete
  gen_server:cast({Worker2,Worker2},{remoteUpdate,Element,Rest_Of_Line}),
  {noreply, [Worker1,Worker2,Worker3,Worker4,Master]};
handle_cast({localUpdate,worker3,Element,Rest_Of_Line},[Worker1,Worker2,Worker3,Worker4,Master])->%delete
  gen_server:cast({Worker3,Worker3},{remoteUpdate,Element,Rest_Of_Line}),
  {noreply, [Worker1,Worker2,Worker3,Worker4,Master]};
handle_cast({localUpdate,worker4,Element,Rest_Of_Line},[Worker1,Worker2,Worker3,Worker4,Master])->%delete
  gen_server:cast({Worker4,Worker4},{remoteUpdate,Element,Rest_Of_Line}),
  {noreply, [Worker1,Worker2,Worker3,Worker4,Master]};
handle_cast({remoteUpdate,Element,Rest_Of_Line},State)->
  main!{organize,Element,Rest_Of_Line},
  {noreply, State};
handle_cast({incoming_input,Source_Node,Source_Pid,Input,Depth,Fathers},State)->
  manage_requests!{new_request,Source_Node,Source_Pid,Input,Depth,Fathers},
  {noreply, State};
handle_cast({answer_for_request,Source_Node,Source_Pid,{Res,Root}},State)->%delete
  gen_server:cast({Source_Node,Source_Node},{mission_accomplished,Source_Pid,{Res,Root}}),
  {noreply, State};
handle_cast( {mission_accomplished,Source_Pid,{Res,Root}},State)->
  Source_Pid!{final_result_for_request,{Res,Root}},
  {noreply, State};
handle_cast({local_request_with_input,worker1,Source_Pid,Input,Depth,Fathers},[Worker1,Worker2,Worker3,Worker4,Master])->%delete
  gen_server:cast({Worker1,Worker1},{incoming_input,node(),Source_Pid,Input,Depth,Fathers}),
  {noreply, [Worker1,Worker2,Worker3,Worker4,Master]};
handle_cast({local_request_with_input,worker2,Source_Pid,Input,Depth,Fathers},[Worker1,Worker2,Worker3,Worker4,Master])->%delete
  gen_server:cast({Worker2,Worker2},{incoming_input,node(),Source_Pid,Input,Depth,Fathers}),
  {noreply, [Worker1,Worker2,Worker3,Worker4,Master]};
handle_cast({local_request_with_input,worker3,Source_Pid,Input,Depth,Fathers},[Worker1,Worker2,Worker3,Worker4,Master])->%delete
  gen_server:cast({Worker3,Worker3},{incoming_input,node(),Source_Pid,Input,Depth,Fathers}),
  {noreply, [Worker1,Worker2,Worker3,Worker4,Master]};
handle_cast({local_request_with_input,worker4,Source_Pid,Input,Depth,Fathers},[Worker1,Worker2,Worker3,Worker4,Master])->%delete
  gen_server:cast({Worker4,Worker4},{incoming_input,node(),Source_Pid,Input,Depth,Fathers}),
  {noreply, [Worker1,Worker2,Worker3,Worker4,Master]};
handle_cast(restart,State)->
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
  io:format("keep_alive_server stopped ~n"),
  ok;
terminate(_Reason, restart) ->
  io:format("restart server ~n"),
  send_message_to_proc_without_fail(manage_requests,kill),
  %manage_requests!kill,
  send_message_to_proc_without_fail(main,restart),
  %main!restart,
  gen_server:stop(keep_alive_server), %keep alive
  ok;
terminate(_Reason, _State) ->
  io:format("terminate server ~n"),
  %send_message_to_proc_without_fail(manage_requests,kill),
  manage_requests!kill,
  %send_message_to_proc_without_fail(main,kill),
  main!kill,
  gen_server:stop(keep_alive_server), %keep alive
  io:format("server stopped ~n"),
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
