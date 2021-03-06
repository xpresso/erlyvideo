package
{
	import VideoSource;
	import VideoSourceEvent;
	import flash.events.NetStatusEvent;
	import flash.events.AsyncErrorEvent;
	import flash.events.EventDispatcher;
	import flash.net.NetStream;
	import flash.media.Video;
	
	import mx.controls.Alert;
	public class VideoStream extends EventDispatcher
	{
		private var _source:VideoSource;
		public var _stream : NetStream;
		public var width : int = 320;
		public var height : int = 240;
		public var totalTime : int;
		
		public var paused : Boolean = false;
		
		private static var number : int = 0;
		public var id : int;

		private var _url:String;
		private var _video:Video;
		
		public function VideoStream(s:VideoSource = null):void
		{
			_source = s || VideoSource.source;
			_source.addEventListener(VideoSourceEvent.CONNECTED, onConnect);
			_source.addEventListener(VideoSourceEvent.DISCONNECT, onDisconnect);
			id = ++number;
			if (_source.connected) {
				onConnect(null);
			}
		}
		
		public function onConnect(event : VideoSourceEvent) : void
		{
	  	var listener : Object = new Object();
	  	_stream = new NetStream(_source.connection);
	  	_stream.addEventListener(NetStatusEvent.NET_STATUS, onStreamStatus);
	  	_stream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onDisconnect);
	    _stream.bufferTime = 1;
	  	listener.onMetaData = onMetaData;
	  	_stream.client = listener;

			dispatchEvent(new VideoSourceEvent(VideoSourceEvent.STREAM_READY));
			
			if (_url && _video) {
				_video.attachNetStream(_stream);
				_stream.play(_url);
			}
		}
		
		public function play(url : String, video : Video) : Boolean {
			_url = url;
			_video = video;
			if (!_stream) {
				return true;
			}
			video.attachNetStream(_stream);
			_stream.play(url);
			return true
		}
		
		
		public function onDisconnect(event : Object) : void
		{
			stop();
			close();
			_stream = null;
			dispatchEvent(new VideoSourceEvent(VideoSourceEvent.STREAM_FAILED));
		}
		
		public function close() : void
		{
		  if (_stream) {
		    _stream.close();
		  }
		}
		
		public function get time():int
		{
			if (_stream) return _stream.time;
			else return -1;
		}
		
		public function stop() : void
		{
		  if (_stream) {
		    _stream.play(null);
		  }
		}
				
		protected function onStreamStatus( event : NetStatusEvent ) : void
		{
			switch(event.info.code){
		  	case "NetStream.Play.StreamNotFound":
					dispatchEvent(new VideoSourceEvent(VideoSourceEvent.FILE_NOT_FOUND));
		  		break;

		  	case "NetStream.Seek.Notify":
					//statusTimer.start();
		      break;

		  	case "NetStream.Play.Complete":
				  dispatchEvent(new VideoSourceEvent(VideoSourceEvent.FINISHED));
		  	  break;

        case "NetStream.Play.Start":
          dispatchEvent(new VideoSourceEvent(VideoSourceEvent.PLAY_START));
          break;
          
			default:
			    
		  }

		}
		
		
		private function onMetaData(metadata : Object) : void
		{
		  width = metadata.width;
		  height = metadata.height;
		  totalTime = metadata.duration;
			dispatchEvent(new VideoSourceEvent(VideoSourceEvent.METADATA, metadata));
		}

		
	}
}