%%%-------------------------------------------------------------------
%%% @author Elioz & Yanir
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. Aug 2021 3:35 PM
%%%-------------------------------------------------------------------
-module(master).
-author("Elioz & Yanir").

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
-define(TIMER,500).



-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================
%%%===================================================================
%Our Code:

% instruction = [Id,List_Of_Nodes,master_node]
start(Number_Of_Workers)->
  register(main,self()),
  new_start(0,Number_Of_Workers).

new_start(I,Number_Of_Workers)->
  gen_server:start_link({local, node()}, ?MODULE, [Number_Of_Workers], []),
  spawn(fun() ->  keep_alive_fun() end), %keep alive

  case wait_until_workers_finish(?NUMBER_OF_FILES) of
    ok_continue_with_work ->
      wxDisplay(Number_Of_Workers),
      io:format("waiting ~n"),
      receive
        kill -> ok;
        {restart,New_Number_Of_Workers}->new_start(I + 1,New_Number_Of_Workers)
      end;
    New_Number_Of_Workers->
      new_start(I + 1,New_Number_Of_Workers)
  end.



  %need to close all servers of nodes


wait_until_workers_finish(0)->ok_continue_with_work;
wait_until_workers_finish(I)->
  receive
    broadcast_finish_to_read_file->
      wait_until_workers_finish(I - 1);
    {restart,New_Number_Of_Workers}->
      New_Number_Of_Workers
  end.


get_input_from_customer(Input,Number_Of_Workers)->
  Worker = for_which_worker(Input,Number_Of_Workers),
  gen_server:cast({?SERVER,?SERVER},{local_request_with_input,Worker,self(),Input,1,[Input]}),

  Res = receive
          {final_result_for_request,{Answer,_Root}}->Answer
        end,
  if
    Res =:= notfound ->
      wxDisplay(Number_Of_Workers);
    true->
    	io:format("finitoo ~n Res = ~p ~n",[Res]),
      graphviz:graph("G"),
      [ graphviz:add_edge(replace(V1," ","_"), replace(V2," ","_")) || {V1,V2} <- Res],
      graphviz:to_file("result.png", "png"),
      os:cmd("xdg-open result.png"),
      gen_server:stop(?SERVER),
      main!kill,
      Res
  end.


wxDisplay(Number_Of_Workers)->
  Parent = wx:new(),
  Frame = wxFrame:new(Parent,1,"Parallel and distributed processing of big data",[{pos,{500,500}},{size,{503,332}}]),
  Background = wxImage:new("background.jpg",[]),
  Bitmap = wxBitmap:new(wxImage:scale(Background, round(wxImage:getWidth(Background)), round(wxImage:getHeight(Background)), [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  wxStaticBitmap:new(Frame, ?wxID_ANY, Bitmap),
  Button = wxButton:new(Frame,3,[{label,"Search"},{size,{50,50}},{pos,{230,50}}]),
  Text = wxTextCtrl:new(Frame,60,[{pos,{160,120}},{size,{200,30}}]),
  wxButton:connect(Button,command_button_clicked,[{callback,fun(_,_)->get_input_from_customer(wxTextCtrl:getLineText(Text,0),Number_Of_Workers)end}]),
  wxFrame:show(Frame).



first_letter(Element)->hd(string:lowercase(Element)). %Give the first letter in word, but only lowercase

for_which_worker(Element,Number_Of_Workers)->
  First_Letter = first_letter(Element),
  Index = if
            ((First_Letter >= 97) and (First_Letter =< 122)) -> round(math:ceil(((First_Letter - 97 + 0.0001 ) * Number_Of_Workers) / 26));
            true -> 1
          end,
  Index.


replace(String,Symbol,New_Symbol)-> replace(string:replace(String,Symbol,New_Symbol,all),[]).
replace([],List)->[Letter || Letter <- List, ((hd(string:lowercase([Letter])) >= 97) and (hd(string:lowercase([Letter])) =< 122)) or (Letter =:= hd("_"))];
replace([H|T],List)-> replace(T,List ++ H).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

keep_alive_fun()->
  List_Of_Workers = gen_server:call(?SERVER,who_is_workers,infinity),
  Number_Of_Workers = length(List_Of_Workers),
  keep_alive_fun(Number_Of_Workers,List_Of_Workers).


keep_alive_fun(Number_Of_Workers,List_Of_Workers)->
  timer:sleep(round(?TIMER )),
  io:format("List_Of_Workers = ~p , Number_Of_Workers ~p ~n ",[List_Of_Workers,Number_Of_Workers]),
  List = [ is_worker_alive(Worker) || Worker <- List_Of_Workers],
  New_Number_Of_Workers = lists:sum(List),
  if
    Number_Of_Workers =:= New_Number_Of_Workers -> keep_alive_fun(Number_Of_Workers,List_Of_Workers);
    true ->
    	%%%%
      timer:sleep(round(?TIMER )),
    	List1 = [ is_worker_alive(Worker) || Worker <- List_Of_Workers],
  	  New_Number_Of_Workers1 = lists:sum(List1),
      if
        Number_Of_Workers =:= New_Number_Of_Workers1 -> keep_alive_fun(Number_Of_Workers,List_Of_Workers);
        true->
          io:format("fail in keep alive , Number_Of_Workers = ~p , List = ~p ~n",[New_Number_Of_Workers,List]),
          gen_server:cast(?SERVER,restart),
          gen_server:stop(?SERVER),
          main!{restart,New_Number_Of_Workers}
      end
    	%%%%
      %io:format("fail in keep alive , Number_Of_Workers = ~p , List = ~p ~n",[New_Number_Of_Workers,List]),
      %gen_server:cast(?SERVER,restart),
      %gen_server:stop(?SERVER),
      %main!{restart,New_Number_Of_Workers}
  end.



is_worker_alive(Worker)->
  try gen_server:call({keep_alive_server,Worker},ping,?TIMER) of
    _->1
  catch
    error:_Error	-> 0;
    exit:_Exit	->   0;
    throw:_Throw->  0
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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
  {ok, [Number_Of_Workers,Number_Of_Workers,[],[],[]]}.

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

handle_call(who_is_workers, From, [Number_Of_Workers,I,List_Of_Nodes,Clients,[]]) ->
  {noreply, [Number_Of_Workers,I,List_Of_Nodes,Clients,From]};
handle_call({ask_to_construction_from_master,Node}, _From,[Number_Of_Workers,1,List_Of_Nodes,Clients,Keep_alive_Proc])-> % need to change if there is number of files =/= 4
  New_List_Of_Nodes = List_Of_Nodes ++ [Node],
  Responsibility =   case Number_Of_Workers of
                       1->
                         [1,2,3,4];
                       2->
                         gen_server:reply(lists:nth(1,Clients),[[1,2],New_List_Of_Nodes,node()]),
                         [3,4];
                       3->
                         gen_server:reply(lists:nth(1,Clients),[[1,2],New_List_Of_Nodes,node()]),
                         gen_server:reply(lists:nth(2,Clients),[[3],New_List_Of_Nodes,node()]),
                         [4];
                       4->
                         [ gen_server:reply(lists:nth(X,Clients),[[X],New_List_Of_Nodes,node()]) || X <- lists:seq(1,Number_Of_Workers - 1)],
                         [Number_Of_Workers];
                       _->
                         [ gen_server:reply(lists:nth(X,Clients),[[X],New_List_Of_Nodes,node()]) || X <- lists:seq(1,4 )],
                         []
                     end,
  Result = [Responsibility,New_List_Of_Nodes,node()],
  gen_server:reply(Keep_alive_Proc,New_List_Of_Nodes), %keep alive
  io:format("State = ~p ~n ",[New_List_Of_Nodes]),
  {reply, Result, New_List_Of_Nodes};
handle_call({ask_to_construction_from_master,Node}, From,[Number_Of_Workers,I,List_Of_Nodes,Clients,Keep_alive_Proc])->
  {noreply, [Number_Of_Workers,I - 1,List_Of_Nodes ++ [Node],Clients ++ [From],Keep_alive_Proc]}.


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
handle_cast({local_request_with_input,Index,Source_Pid,Input,Depth,Fathers},State)->
  Worker = lists:nth(Index,State),
  gen_server:cast({Worker,Worker},{incoming_input,node(),Source_Pid,Input,Depth,Fathers}),
  {noreply, State};
handle_cast({mission_accomplished,Source_Pid,{Res,Root}},State)->
  Source_Pid!{final_result_for_request,{Res,Root}},
  {noreply, State};
handle_cast(restart,State)->
  [
    try gen_server:cast({Worker,Worker},restart) of
      _->ok
    catch
      error:_Error	-> ok;
      exit:_Exit	->   ok;
      throw:_Throw->  ok
    end
    || Worker <- State],
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
%terminate(_Reason, _State) ->
 % ok.

terminate(_, State) ->
  io:format("terminate master ,State = ~p ~n",[State]),
   [
    try gen_server:stop({Worker,Worker}) of
     _->ok
    catch
      error:_Error	-> ok;
      exit:_Exit	->   ok;
      throw:_Throw->  ok
    end
   || Worker <- State],
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
