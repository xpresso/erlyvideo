%%%---------------------------------------------------------------------------------------
%%% @author     Max Lapshin <max@maxidoors.ru> [http://erlyvideo.org]
%%% @copyright  2010 Max Lapshin
%%% @doc        timeshift
%%% @reference  See <a href="http://erlyvideo.org" target="_top">http://erlyvideo.org</a> for more information
%%% @end
%%%
%%% This file is part of erlyvideo.
%%% 
%%% erlyvideo is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU General Public License as published by
%%% the Free Software Foundation, either version 3 of the License, or
%%% (at your option) any later version.
%%%
%%% erlyvideo is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with erlyvideo.  If not, see <http://www.gnu.org/licenses/>.
%%%
%%%---------------------------------------------------------------------------------------

-module(array_timeshift).
-author('Max Lapshin <max@maxidoors.ru>').
-include_lib("erlmedia/include/video_frame.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("../log.hrl").

-behaviour(gen_format).

-export([init/2, read_frame/2, properties/1, seek/3, can_open_file/1, write_frame/2]).

-record(shift, {
  first = 0,
  last = 0,
  frames,
  size
}).

%%%%%%%%%%%%%%%           Timeshift features         %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
init(Options, _MoreOptions) ->
  Shift = proplists:get_value(timeshift, Options),
  Size = Shift*80 div 1000, % About 80 fps for video and audio
  {ok, #shift{frames = array:new(Size), size = Size}}.


can_open_file(_) ->
  false.

properties(#shift{first = First, last = Last, frames = Frames}) when First =/= Last ->
  #video_frame{dts = FirstDTS} = array:get(First, Frames),
  #video_frame{dts = LastDTS} = array:get((Last-1+array:size(Frames)) rem array:size(Frames), Frames),
  [{duration,(LastDTS - FirstDTS)},{start,FirstDTS}];
  
properties(#shift{size = Size}) ->
  [{duration,0},{timeshift_size,Size},{type,stream}];
  
properties(_) ->
  [].


seek(#shift{first = First, frames = Frames}, _BeforeAfter, Timestamp) when Timestamp =< 0 ->
  % ?D({"going to seek", Timestamp}),
  case array:get(First, Frames) of
    undefined -> undefined;
    #video_frame{dts = DTS} -> {(First + 1) rem array:size(Frames), DTS}
  end;

seek(#shift{first = First, last = Last, frames = Frames}, BeforeAfter, Timestamp) ->
  % ?D({"going to seek", Timestamp}),
  S = seek_in_timeshift(First, Last, Frames, BeforeAfter, Timestamp, undefined),
  % ?D({"Seek in array", First, Last, Timestamp, S}),
  S.
  
seek_in_timeshift(First, First, _Frames, _BeforeAfter, _Timestamp, Key) ->
  Key;

seek_in_timeshift(First, Last, Frames, BeforeAfter, Timestamp, Key) ->
  case array:get(First, Frames) of
    #video_frame{dts = DTS} when BeforeAfter == before andalso DTS > Timestamp ->
      Key;
    #video_frame{content = video, flavor = keyframe, dts = DTS} when BeforeAfter == 'after' andalso DTS > Timestamp ->
      {First, DTS};
    #video_frame{content = video, flavor = keyframe, dts = DTS} ->
      seek_in_timeshift((First+1) rem array:size(Frames), Last, Frames, BeforeAfter, Timestamp, {First, DTS});
    #video_frame{} ->
      seek_in_timeshift((First+1) rem array:size(Frames), Last, Frames, BeforeAfter, Timestamp, Key)
  end.

read_frame(#shift{first = First} = Shift, undefined) ->
  read_frame(Shift, First);

read_frame(#shift{frames = Frames}, Key) ->
  % ?D({"Read", Key}),
  case array:get(Key, Frames) of
    undefined -> eof;
    Frame -> Frame#video_frame{next_id = (Key + 1) rem array:size(Frames)}
  end.


write_frame(#video_frame{flavor = config}, MediaInfo) ->
  {ok, MediaInfo};

write_frame(#video_frame{} = Frame, #shift{first = First, last = Last, frames = Frames} = Shift) ->
  Last1 = (Last + 1) rem array:size(Frames),
  First1 = case Last1 of
    First -> (First + 1) rem array:size(Frames);
    _ -> First
  end,
  {ok, Shift#shift{first = First1, last = Last1, frames = array:set(Last, Frame, Frames)}}.


  
