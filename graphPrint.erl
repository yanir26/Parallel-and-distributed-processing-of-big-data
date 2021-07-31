
-module(graphPrint).

%% API
-export([graphicGraph/2,buildTree/2,mergeTree/3, digraph/1, graph/1, delete/0, add_node/1, add_edge/2, graph_server/1, to_dot/1, to_file/2]).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%Partners  == [[[[V1,V2],[V1,V6]],root1],[[[[V3,V4]],root1]]]
%%In a lower stage we send Partners  ==[[[],root1],[[],root2]] because we do not want the child of this stage.
%%Edg == [] (when we call to the func).
%%The output is list of edge:   [[a,b],[a,c]]
mergeTree(_,[],Edg)-> Edg;

mergeTree(Input,Partners,Edg)-> mergeTree(Input,tl(Partners),Edg++hd(hd(Partners))++[[Input,hd(tl(hd(Partners)))]]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%Only in master (The func get a list of edge and build tree):
buildTree(Edg,build)->
    G = digraph:new(),
    buildTree(Edg,G);

buildTree([],G)->G;

buildTree(Edg,G)->
    digraph:add_vertex(G,hd(hd(Edg))),
    digraph:add_vertex(G,hd(tl(hd(Edg)))),
    digraph:add_edge(G,hd(hd(Edg)),hd(tl(hd(Edg)))),
    buildTree(tl(Edg),G).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%Graphviz - credit to Glejeune.
graphicGraph([])->
    to_file("pic.png","png"),
    delete(),
    ok;
graphicGraph(Edg)->
    add_edge(hd(hd(Edg)),hd(tl(hd(Edg)))),
    graphicGraph(tl(Edg)).

graphicGraph(Edg,build)->
    graph("G"),
    graphicGraph(Edg).


% -- Constructor
digraph(Id) ->
   register(graph_server, spawn(?MODULE, graph_server, [{Id, {digraph, "->"}, [] ,[], []}])).

graph(Id) ->
   register(graph_server, spawn(?MODULE, graph_server, [{Id, {graph, "--"}, [] ,[], []}])).

% -- Destructor
delete() ->
   graph_server ! stop.

% -- Server/Dispatcher
graph_server(Graph) ->
   receive
      {add_node, Id} ->
         graph_server(add_node(Graph, Id));

      {add_edge, NodeOne, NodeTwo} ->
         graph_server(add_edge(Graph, NodeOne, NodeTwo));

      {to_dot, File} ->
         to_dot(Graph, File),
         graph_server(Graph);

      {to_file, File, Format} ->
         to_file(Graph, File, Format),
         graph_server(Graph);

      {value, Pid} ->
         Pid ! {value, Graph},
         graph_server(Graph);

      stop -> true
   end.

% -- Methods

add_node(Id) -> graph_server ! {add_node, Id}.
add_edge(NodeOne, NodeTwo) -> graph_server ! {add_edge, NodeOne, NodeTwo}.
to_dot(File) -> graph_server ! {to_dot, File}.
to_file(File, Format) -> graph_server ! {to_file, File, Format}.

% -- Implementation

add_node(Graph, Id) ->
   {GraphId, Type, GraphOptions, Nodes, Edges} = Graph,
   {GraphId, Type, GraphOptions, Nodes ++ [Id], Edges}.

add_edge(Graph, NodeOne, NodeTwo) ->
   {GraphId, Type, GraphOptions, Nodes, Edges} = Graph,
   {GraphId, Type, GraphOptions, Nodes, Edges ++ [{NodeOne, NodeTwo}]}.

to_dot(Graph, File) ->
   {GraphId, Type, _, Nodes, Edges} = Graph,
   {GraphType, EdgeType} = Type,

   % open file
   {ok, IODevice} = file:open(File, [write]),

   % print graph
   io:format(IODevice, "~s ~s {~n", [GraphType, GraphId]),

   % print nodes
   lists:foreach(
      fun(Node) ->
            io:format(IODevice, "  ~s;~n",[Node])
      end,
      Nodes
   ),

   % print edges
   lists:foreach(
      fun(Edge) ->
            {NodeOne, NodeTwo} = Edge,
            io:format(IODevice, "  ~s ~s ~s;~n",[NodeOne, EdgeType, NodeTwo])
      end,
      Edges
   ),

   % close file
   io:format(IODevice, "}~n", []),
   file:close(IODevice).

to_file(Graph, File, Format) ->
   {A1,A2,A3} = erlang:timestamp(),
   DotFile = lists:concat([File, ".dot-", A1, "-", A2, "-", A3]),
   to_dot(Graph, DotFile),
   DotCommant = lists:concat(["dot -T", Format, " -o", File, " ", DotFile]),
   os:cmd(DotCommant),
   file:delete(DotFile).

