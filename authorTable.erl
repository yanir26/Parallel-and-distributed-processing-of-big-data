
-module(authorTable).

%% API
-export([makeTable/2]).
-include_lib("wx/include/wx.hrl").
-define(DEPTH,4).

makeTable(Input,Edges)->
  G = digraph:new(),
  buildTree(Edges,G),
  Ets = ets:new(tab,[set]),
  buildEts(Ets,1),
  updateEts(G,1,[Input],Input,Ets),
  Parent = wx:new(),
  Frame = wxFrame:new(Parent,1,"Table",[{pos,{500,500}},{size,{400,720}}]),
  Grid = wxGrid:new(Frame,2,[]),
  wxGrid:createGrid(Grid,26,4),
  setCol(Grid,0),
  setRow(Grid,0,["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]),
  setCell(Ets,Grid,0,1),

  wxFrame:show(Frame).

setCell(_,_,_,?DEPTH+1)->ok;
setCell(Ets,Grid,26,Col)->setCell(Ets,Grid,0,Col+1);
setCell(Ets,Grid,Row,Col)->
  Letter = {"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"},
  wxGrid:setCellValue(Grid,Row,Col-1,integer_to_list(element(2,hd(ets:lookup(Ets,{element(Row+1,Letter),Col}))))),
  setCell(Ets,Grid,Row+1,Col).

setCol(_,?DEPTH)->ok;
setCol(Grid,Dep)->
  wxGrid:setColLabelValue(Grid,Dep,"Depth " ++ integer_to_list(Dep+1)),
  setCol(Grid,Dep+1).


setRow(_,_,[])->ok;
setRow(Grid,Row,List)->
  wxGrid:setRowLabelValue(Grid,Row,hd(List)),
  setRow(Grid,Row+1,tl(List)).


updateEts(_,5,_,_,Ets)->Ets;
updateEts(G,Level,List,Root,Ets)->
  Neighbors = digraph:out_neighbours(G,Root)++digraph:in_neighbours(G,Root)--List,
  [ets:update_counter(Ets,{string:lowercase(string:slice(A,0,1)),Level},{2,1})||A<-Neighbors],
  [updateEts(G,Level+1,List++Neighbors,B,Ets)||B<-(Neighbors--List)].


buildEts(_,5)->ok;
buildEts(Ets,Level)->
  [ets:insert(Ets,{{A,Level},0})||A<-["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]],
  buildEts(Ets,Level+1).

%%The func get a list of edge and build digraph:
buildTree(Edg,build)->
  G = digraph:new(),
  buildTree(Edg,G);

buildTree([],G)->G;

buildTree(Edg,G)->
  digraph:add_vertex(G,element(1,hd(Edg))),
  digraph:add_vertex(G,element(2,hd(Edg))),
  digraph:add_edge(G,element(1,hd(Edg)),element(2,hd(Edg))),
  buildTree(tl(Edg),G).
