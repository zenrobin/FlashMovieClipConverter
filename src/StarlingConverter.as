/**
 * @author Shane Smit <Shane@DigitalLoom.org>
 */
package
{
	import flash.desktop.NativeApplication;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.InvokeEvent;
	import flash.filesystem.File;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	
	// Main class for the "StarlingConverter" command-line AIR application.
	public class StarlingConverter extends Sprite
	{
		private var _loaders		: Vector.<Loader>;
		private var _errorCode		: int;
		private var _outputPath		: File;
		private var _sortBitmaps	: Boolean;
		
		private var _encoder		: flash.display.PNGEncoderOptions;
		
		
		public function StarlingConverter()
		{
			NativeApplication.nativeApplication.addEventListener( InvokeEvent.INVOKE, onInvoke );
		}
		
		
		// Reads the command-line options, and starts the processing.
		// Sadly, AIR doesn't provide an easy way to output to stdout, so the trace statements will not be seen when invoked via the command line. :(
		public function onInvoke( event:InvokeEvent ) : void
		{
			if( event.arguments.length == 0 )
			{
				trace( "Usage: StarlingConverter <swfFile>" );
				exit( 1 );
				return;
			}
			
			_errorCode = 0;
			if( Capabilities.isDebugger )
				_outputPath = File.desktopDirectory;
			else
				_outputPath = event.currentDirectory;
			
			_sortBitmaps = true;
			
			_loaders = new <Loader>[];
			for each( var arg:String in event.arguments )
			{
				if( arg.charAt(0) == "-" )
				{
					var option:String = arg.slice( 1 );	// Strip off the leading '-'
					if( option.toLowerCase() == "nosortbitmaps" )
					{
						trace( "Option: Disabling bitmap sorting during texture packing." );
						_sortBitmaps = false;
					}
					else
						trace( "Unknown option: " + option );
					continue;
				}
				
				try {
					var file:File = event.currentDirectory.resolvePath( arg );
				} catch( error:Error ) {
					trace( "Invalid Argument: " + arg );
					exit( 1 );
					return;
				}
				
				var loader:Loader = new Loader();
				_loaders.push( loader );
				
				loader.contentLoaderInfo.addEventListener( Event.COMPLETE, onLoaderComplete )
				loader.contentLoaderInfo.addEventListener( IOErrorEvent.IO_ERROR, onLoaderError );
				loader.load( new URLRequest( file.url ) );
			}
		}
		
		
		private function onLoaderError( event:IOErrorEvent ) : void
		{
			var loaderInfo:LoaderInfo = LoaderInfo(event.target);
			var url:String = event.text.substr( event.text.indexOf( "URL: " ) + 5 );
			var file:File = new File();
			file.url = url;
			trace( "Could not load: " + file.nativePath );
			_errorCode = 1;
			
			_loaders.splice( _loaders.indexOf( loaderInfo.loader ), 1 );
			if( _loaders.length == 0 )
				exit( _errorCode );
		}
		
		
		private function onLoaderComplete( event:Event ) : void
		{
			var loaderInfo:LoaderInfo = LoaderInfo(event.target);
			var file:File = new File();
			file.url = loaderInfo.url;
			trace( "Loaded: " + file.nativePath );
			if( loaderInfo.contentType != "application/x-shockwave-flash" )
			{
				trace( "Invalid content type: " + loaderInfo.contentType );
				_loaders.splice( _loaders.indexOf( loaderInfo.loader ), 1 );
				if( _loaders.length == 0 )
					exit( _errorCode );
				return;
			}
			
			var exporter:Exporter = new Exporter( MovieClip(loaderInfo.content), file.name );
			exporter.export( _outputPath, _sortBitmaps );
			
			_loaders.splice( _loaders.indexOf( loaderInfo.loader ), 1 );
			if( _loaders.length == 0 )
				exit( _errorCode );
		}
		
		
		private static function exit( errorCode:int=0 ) : void
		{
			NativeApplication.nativeApplication.exit( errorCode );
		}
	}
}