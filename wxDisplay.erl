-module(wxDisplay).
-include_lib("wx/include/wx.hrl").
-export([wxDisplay/0]).




wxDisplay()->
  Parent = wx:new(),
  Frame = wxFrame:new(Parent,1,"Parallel and distributed processing of big data",[{pos,{500,500}},{size,{503,332}}]),
  Background = wxImage:new("background.jpg",[]),
  Bitmap = wxBitmap:new(wxImage:scale(Background, round(wxImage:getWidth(Background)), round(wxImage:getHeight(Background)), [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  wxStaticBitmap:new(Frame, ?wxID_ANY, Bitmap),
  Button = wxButton:new(Frame,3,[{label,"Search"},{size,{50,50}},{pos,{230,50}}]),
  wxTextCtrl:new(Frame,60,[{pos,{160,120}},{size,{200,30}}]),
  wxButton:connect(Button,command_button_clicked),
  wxFrame:show(Frame).
