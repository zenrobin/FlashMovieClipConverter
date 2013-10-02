/**
 * @author Shane Smit <Shane@DigitalLoom.org>
 * 
 * @version 1.4
 */
package ssmit
{
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.FrameLabel;
	import flash.display.MovieClip;
	import flash.display.Scene;
	import flash.display.Shape;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import starling.display.Image;
	import starling.textures.Texture;
	
	public final class FlashMovieClipConverter
	{
		private static var _textureList		: TextureList;

		
		// Creates a ConvertedMovieClip (a Starling animatable Sprite) from a FLash MovieClip.
		// sortBitmaps: Sorted bitmaps can pack into fewer TextureAtlases, however, the textures may end up being used out of order from the original MovieClip, which would slow thing down.
		public static function convert( flashMC:flash.display.MovieClip, sortBitmaps:Boolean=true, generateMipMaps:Boolean=true ) : ConvertedMovieClip
		{
			_textureList = new TextureList();
			
			var convertedMovieClip:ConvertedMovieClip = convertRecursive( flashMC, true ) as ConvertedMovieClip;
			convertedMovieClip.textureAtlases = _textureList.createTextureAtlases( sortBitmaps, generateMipMaps );
			
			_textureList.dispose();
			_textureList = null;
			
			return convertedMovieClip;
		}
		
		
		// Walks though a Flash DisplayObject and converts it (and it's children) to a Starling DisplayObject.
		private static function convertRecursive( displayObject:flash.display.DisplayObject, ignoreTotalFrames:Boolean=false ) : starling.display.DisplayObject
		{
			var convertedObject:starling.display.DisplayObject;
			
			if( displayObject is flash.display.DisplayObjectContainer )
			{
				var container:flash.display.DisplayObjectContainer = displayObject as flash.display.DisplayObjectContainer;
				
				var convertedContainer:starling.display.DisplayObjectContainer;
				if( container is flash.display.MovieClip && ( ignoreTotalFrames || (container as flash.display.MovieClip).totalFrames > 1 ) )
				{
					var movieClip:MovieClip = container as flash.display.MovieClip;
					var convertedMovieClip:ConvertedMovieClip = new ConvertedMovieClip();
					if( displayObject.loaderInfo != null )
						convertedMovieClip.frameRate = displayObject.loaderInfo.frameRate;
					convertedMovieClip.frameData = FrameData.importFromFlashMovieClip( movieClip, convertFrameObject );
					convertedMovieClip.sceneData = copySceneData( movieClip );
					convertedMovieClip.initFrame();	// Adds the first frame's children to the new ConvertedMovieClip. 
					convertedContainer = convertedMovieClip;
				}
				else //if( container is flash.display.Sprite )
				{
					convertedContainer = new starling.display.Sprite();
					
					// Add the children to the new Starling Sprite.
					for( var i:int=0; i<container.numChildren; ++i ) 
					{
						var child:flash.display.DisplayObject = container.getChildAt( i );
						var convertedChild:starling.display.DisplayObject = convertRecursive( child );
						convertedContainer.addChild( convertedChild );
					}
				}
				convertedObject = convertedContainer;
				convertedObject.transformationMatrix = displayObject.transform.matrix.clone();
				convertedObject.x = displayObject.x;
				convertedObject.y = displayObject.y;
			}
			else
			{
				if( displayObject is Shape || displayObject is Bitmap )
				{
					var bitmapInfo:BitmapInfo = _textureList.getBitmapInfoFromDisplayObject( displayObject );
					
					// Create a dummy texture for now. Will be replaced later after all the bitmaps have been packed.
					var image:Image = new Image( Texture.empty( 
																bitmapInfo._bitmapData.width - (TextureList.PADDING*2), 
																bitmapInfo._bitmapData.height - (TextureList.PADDING*2),
																true,
																false,
																false,
																1.0 ) );
					convertedObject = image;
					
					// Adjust texture coordinates to account for padding.
					var leftTC:Number = TextureList.PADDING / bitmapInfo._bitmapData.width;
					var topTC:Number = TextureList.PADDING / bitmapInfo._bitmapData.height;
					var rightTC:Number = ( TextureList.PADDING + displayObject.width ) / bitmapInfo._bitmapData.width;
					var bottomTC:Number = ( TextureList.PADDING + displayObject.height ) / bitmapInfo._bitmapData.height;
					image.setTexCoords( 0, new Point(  leftTC,    topTC ) );
					image.setTexCoords( 1, new Point( rightTC,    topTC ) );
					image.setTexCoords( 2, new Point(  leftTC, bottomTC ) );
					image.setTexCoords( 3, new Point( rightTC, bottomTC ) );
					
					// Textures don't have offsets, so the image must be translated to compensate.
					var objectRect:Rectangle = displayObject.getRect( displayObject );
					image.x = displayObject.x + objectRect.left;
					image.y = displayObject.y + objectRect.top;
					
					// Add the new image to the list of images that use this bitmap.
					if( bitmapInfo._imageList == null )
						bitmapInfo._imageList = new <Image>[];
					bitmapInfo._imageList.push( image ); 

				}
				else
					throw new Error( "Unhandled child object " + displayObject.toString() );
			}
			
			// Assign common properties.
			convertedObject.name = displayObject.name.slice();
			convertedObject.alpha = displayObject.alpha;
			
			return convertedObject;
		}
		
		
		private static function convertFrameObject( flashObject:flash.display.DisplayObject ) : starling.display.DisplayObject
		{
			return convertRecursive( flashObject );
		}
		
		
		// Copies the scene and label information from a Flash MovieClip.
		private static function copySceneData( movieClip:MovieClip ) : Vector.<Scene>
		{
			// Do a deep copy to prevent any dangling references to the Flash MovieClip.
			var sceneCount:int = movieClip.scenes.length;
			var sceneData:Vector.<Scene> = new Vector.<Scene>( sceneCount, true );
			for( var sceneIndex:int=0; sceneIndex<sceneCount; ++sceneIndex )
			{
				var scene:Scene = movieClip.scenes[ sceneIndex ];
				
				var sceneNameClone:String = scene.name.slice();
				
				var sceneLabelsClone:Array = [];
				for each( var label:FrameLabel in scene.labels )
				{
					var labelNameClone:String = label.name.slice();
					var labelClone:FrameLabel = new FrameLabel( labelNameClone, label.frame );
					sceneLabelsClone.push( labelClone );
				}
				
				var sceneClone:Scene = new Scene( sceneNameClone, sceneLabelsClone, scene.numFrames );
				sceneData[ sceneIndex ] = sceneClone;
			}
			
			return sceneData;
		}
	}
}
