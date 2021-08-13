%%%-------------------------------------------------------------------
%%% @author Elioz & Yanir
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 12. Aug 2021 1:41 AM
%%%-------------------------------------------------------------------
-module(master_statem).
-author("Elioz & Yanir").

-behaviour(gen_statem).

%% API
-export([wait_until_workers_finish/3,workers_finish/3]).

%% gen_statem callbacks
-export([
  init/1,
  format_status/2,
  state_name/3,
  handle_event/4,
  terminate/3,
  code_change/4,
  callback_mode/0
]).

-define(NUMBER_OF_FILES,4).


%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_statem process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------

%%%===================================================================
%%% gen_statem callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_statem is started using gen_statem:start/[3,4] or
%% gen_statem:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @spec init(Args) -> {CallbackMode, StateName, State} |
%%                     {CallbackMode, StateName, State, Actions} |
%%                     ignore |
%%                     {stop, StopReason}
%% @end
%%--------------------------------------------------------------------
init([Number_Of_Workers]) ->
  state_start(Number_Of_Workers),
  State = wait_until_workers_finish,
  Data = {Number_Of_Workers,0,?NUMBER_OF_FILES,{bla,bla}}, %{Number_Of_Workers,Count_Start,Count_Broadcast},
  {ok, State, Data}.
  

state_start(Number_Of_Workers)->
  gen_server:start_link({local, node()}, master, [Number_Of_Workers], []),	%open gen_server
  spawn(fun() ->  master:keep_alive_fun() end), %open the process that check the keepalive
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_statem when it needs to find out 
%% the callback mode of the callback module.
%%
%% @spec callback_mode() -> atom().
%% @end
%%--------------------------------------------------------------------
callback_mode() ->
  state_functions.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Called (1) whenever sys:get_status/1,2 is called by gen_statem or
%% (2) when gen_statem terminates abnormally.
%% This callback is optional.
%%
%% @spec format_status(Opt, [PDict, StateName, State]) -> term()
%% @end
%%--------------------------------------------------------------------
format_status(_Opt, [_PDict, _StateName, _State]) ->
  Status = some_term,
  Status.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name.  If callback_mode is statefunctions, one of these
%% functions is called when gen_statem receives and event from
%% call/2, cast/2, or as a normal process message.
%%
%% @spec state_name(Event, From, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Actions} |
%%                   {stop, Reason, NewState} |
%%    				 stop |
%%                   {stop, Reason :: term()} |
%%                   {stop, Reason :: term(), NewData :: data()} |
%%                   {stop_and_reply, Reason, Replies} |
%%                   {stop_and_reply, Reason, Replies, NewState} |
%%                   {keep_state, NewData :: data()} |
%%                   {keep_state, NewState, Actions} |
%%                   keep_state_and_data |
%%                   {keep_state_and_data, Actions}
%% @end
%%--------------------------------------------------------------------
state_name(_EventType, _EventContent, State) ->
  NextStateName = next_state,
  {next_state, NextStateName, State}.

wait_until_workers_finish(cast,broadcast_finish_to_read_file,{Number_Of_Workers,Count_Start,1,{Frame,Text}})->
{New_Frame,New_Text} =        if
		   Count_Start =:= 0 -> master:wxDisplay(Number_Of_Workers);
		   true -> 
			  wxStaticText:destroy(Text),
		  	  {Frame,wxStaticText:new(Frame,2,"Write the author full name",[{pos,{170,100}}])}
		  end,
  {next_state, workers_finish, {Number_Of_Workers,Count_Start,0,{New_Frame,New_Text}}};

%The situation where the master waits for the workers to finish processing
wait_until_workers_finish(cast,broadcast_finish_to_read_file,{Number_Of_Workers,Count_Start,Count_Broadcast,Text})->
  {next_state, wait_until_workers_finish, {Number_Of_Workers,Count_Start,Count_Broadcast - 1,Text}};
wait_until_workers_finish(cast,{restart,New_Number_Of_Workers},{Number_Of_Workers,Count_Start,_Count_Broadcast,{Frame,Text}})->
  wxStaticText:destroy(Text),
  New_Text = wxStaticText:new(Frame,2,"Computer down - wait a minute",[{pos,{150,100}}]),
  state_start(New_Number_Of_Workers),
  State = wait_until_workers_finish,
  Data = {Number_Of_Workers,Count_Start + 1,?NUMBER_OF_FILES,{Frame,New_Text}},
  {next_state, State, Data}.

workers_finish(cast,kill,_Data)->
  stop;


%The situation in which the workers finished working. Here the master's situation machine is waiting for events of killing or falling a computer
workers_finish(cast,{restart,New_Number_Of_Workers},{Number_Of_Workers,Count_Start,_Count_Broadcast,{Frame,Text}})->
  wxStaticText:destroy(Text),
  New_Text = wxStaticText:new(Frame,2,"Computer down - wait a minute",[{pos,{150,100}}]),
  state_start(New_Number_Of_Workers),
  State = wait_until_workers_finish,
  Data = {Number_Of_Workers,Count_Start + 1,?NUMBER_OF_FILES,{Frame,New_Text}},
  {next_state, State, Data}.



%%--------------------------------------------------------------------
%% @private
%% @doc
%%
%% If callback_mode is handle_event_function, then whenever a
%% gen_statem receives an event from call/2, cast/2, or as a normal
%% process message, this function is called.
%%
%% @spec handle_event(Event, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Actions} |
%%                   {stop, Reason, NewState} |
%%    				 stop |
%%                   {stop, Reason :: term()} |
%%                   {stop, Reason :: term(), NewData :: data()} |
%%                   {stop_and_reply, Reason, Replies} |
%%                   {stop_and_reply, Reason, Replies, NewState} |
%%                   {keep_state, NewData :: data()} |
%%                   {keep_state, NewState, Actions} |
%%                   keep_state_and_data |
%%                   {keep_state_and_data, Actions}
%% @end
%%--------------------------------------------------------------------
handle_event(_EventType, _EventContent, _StateName, State) ->
  NextStateName = the_next_state_name,
  {next_state, NextStateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_statem when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_statem terminates with
%% Reason. The return value is ignored.
%%
%% @spec terminate(Reason, StateName, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, StateName, State, Extra) ->
%%                   {ok, StateName, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
  {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
