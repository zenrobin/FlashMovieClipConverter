/**
 * @author Shane Smit <Shane@DigitalLoom.org>
 */
package
{
	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.display.PNGEncoderOptions;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	
	import ssmit.FlashMovieClipExporter;
	
	public final class Exporter
	{
		private var _flashMovieClip		: MovieClip;
		private var _baseName			: String;
		
		
		public function Exporter( flashMovieClip:MovieClip, swfName:String )
		{
			_flashMovieClip = flashMovieClip;
			
			// Get the base filename.
			_baseName = swfName.slice( 0, swfName.toLowerCase().lastIndexOf( ".swf" ) );
		}
		
		internal function export( outputPath:File, sortBitmaps:Boolean=true ) : Boolean
		{
			var bitmaps:Vector.<BitmapData> = new <BitmapData>[];
			var clipData:XML = FlashMovieClipExporter.export( _flashMovieClip, bitmaps, sortBitmaps );
			
			// Write out the texture atlases.
			var encoderOptions:PNGEncoderOptions = new PNGEncoderOptions();
			for( var i:int=0; i<bitmaps.length; ++i )
			{
				var imageBytes:ByteArray = bitmaps[ i ].encode( new Rectangle( 0, 0, bitmaps[ i ].width, bitmaps[ i ].height ), encoderOptions );
				
				var fileName:String = _baseName + "-atlas" + i + ".png";
				var file:File = outputPath.resolvePath( fileName );
				var fileStream:FileStream = new FileStream();
				fileStream.open( file, FileMode.WRITE );
				fileStream.writeBytes( imageBytes );
				fileStream.close();
				trace( "Wrote file: " + file.nativePath );
				
				clipData.atlases[0].TextureAtlas[i].@imagePath = fileName;
			}
			
			// Write the XML file.
			file = outputPath.resolvePath( _baseName + "-clipData.xml" );
			fileStream = new FileStream();
			fileStream.open( file, FileMode.WRITE );
			fileStream.writeUTFBytes( '<?xml version="1.0" encoding="UTF-8" ?>' + File.lineEnding );
			fileStream.writeUTFBytes( clipData.toXMLString() );
			fileStream.close();
			trace( "Wrote file: " + file.nativePath );
			
			return false;
		}
	}
}