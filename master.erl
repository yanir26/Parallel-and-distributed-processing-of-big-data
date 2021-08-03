%%%-------------------------------------------------------------------
%%% @author elioz
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. Aug 2021 3:35 PM
%%%-------------------------------------------------------------------
-module(master).
-author("elioz").

-behaviour(gen_server).

%% API
-export([start/0]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, node()).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================
%%%===================================================================
%Our Code:

start()->
  Number_Of_Workers = 4,
  register(main,self()),
  gen_server:start_link({local, node()}, ?MODULE, [Number_Of_Workers], []),

  wait_until_workers_finish(Number_Of_Workers),

  get_input_from_customer().
  %need to close all servers of nodes


wait_until_workers_finish(0)->ok_continue_with_work;
wait_until_workers_finish(I)->
  receive
    broadcast_finish_to_read_file->
      wait_until_workers_finish(I - 1)
  end.


get_input_from_customer()->
  Input = "Helmer Strik", %change
  Worker = for_which_worker(Input),
  gen_server:cast({?SERVER,?SERVER},{local_request_with_input,Worker,self(),Input,1,[Input]}),

  Res = receive
          {final_result_for_request,{Answer,_Root}}->Answer
        end,
  graphviz:graph("G"),
  [ graphviz:add_edge(replace(V1," ","_"), replace(V2," ","_")) || {V1,V2} <- Res],
  graphviz:to_file("result.png", "png"),
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

replace(String,Symbol,New_Symbol)-> replace(string:replace(String,Symbol,New_Symbol,all),[]).
replace([],List)->List -- "." -- "," -- "(" -- ")" --":" -- ";";
replace([H|T],List)-> replace(T,List ++ H).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%End our code:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
init([Number_Of_Workers]) ->
  {ok, [Number_Of_Workers,Number_Of_Workers,[]]}.

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

handle_call({broadcast_node,Node}, _From, [Number_Of_Workers,0,List_Of_Nodes]) ->
  Result = List_Of_Nodes,
  New_Status = List_Of_Nodes ++ [Node] ++ [node(),Number_Of_Workers],
  {reply, Result, New_Status};
handle_call({broadcast_node,Node}, _From, [Number_Of_Workers,I,List_Of_Nodes]) ->
  {noreply,[Number_Of_Workers,I - 1,List_Of_Nodes ++ [Node]]}.


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

handle_cast({broadcast_node,Node}, [Number_Of_Workers,1,List_Of_Nodes])->
  New_List_Of_Nodes = List_Of_Nodes ++ [Node],
  [gen_server:cast({lists:nth(X,New_List_Of_Nodes),lists:nth(X,New_List_Of_Nodes)},{construction_from_master,[X,New_List_Of_Nodes,node()]}) || X <- lists:seq(1,Number_Of_Workers)],
  io:format("State = ~p ~n ",[New_List_Of_Nodes]),
  {noreply, New_List_Of_Nodes};
handle_cast({broadcast_node,Node}, [Number_Of_Workers,I,List_Of_Nodes])->
  {noreply, [Number_Of_Workers,I - 1,List_Of_Nodes ++ [Node]]};
handle_cast(broadcast_finish_to_read_file,State)->
  main!broadcast_finish_to_read_file,
  {noreply, State};
handle_cast({local_request_with_input,worker1,Source_Pid,Input,Depth,Fathers},[Worker1,Worker2,Worker3,Worker4])->
  gen_server:cast({Worker1,Worker1},{incoming_input,node(),Source_Pid,Input,Depth,Fathers}),
  {noreply, [Worker1,Worker2,Worker3,Worker4]};
handle_cast({local_request_with_input,worker2,Source_Pid,Input,Depth,Fathers},[Worker1,Worker2,Worker3,Worker4])->
  gen_server:cast({Worker2,Worker2},{incoming_input,node(),Source_Pid,Input,Depth,Fathers}),
  {noreply, [Worker1,Worker2,Worker3,Worker4]};
handle_cast({local_request_with_input,worker3,Source_Pid,Input,Depth,Fathers},[Worker1,Worker2,Worker3,Worker4])->
  gen_server:cast({Worker3,Worker3},{incoming_input,node(),Source_Pid,Input,Depth,Fathers}),
  {noreply, [Worker1,Worker2,Worker3,Worker4]};
handle_cast({local_request_with_input,worker4,Source_Pid,Input,Depth,Fathers},[Worker1,Worker2,Worker3,Worker4])->
  gen_server:cast({Worker4,Worker4},{incoming_input,node(),Source_Pid,Input,Depth,Fathers}),
  {noreply, [Worker1,Worker2,Worker3,Worker4]};
handle_cast({mission_accomplished,Source_Pid,{Res,Root}},State)->
  Source_Pid!{final_result_for_request,{Res,Root}},
  {noreply, State}.



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
terminate(_Reason, _State) ->
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
