/**
 * @author Shane Smit <Shane@DigitalLoom.org>
 * 
 * @version 1.4
 */
package ssmit
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.FrameLabel;
	import flash.display.MovieClip;
	import flash.display.Scene;
	import flash.display.Shape;
	import flash.geom.Rectangle;

	public final class FlashMovieClipExporter
	{
		private static const VERSION		: String	= "1.4";
		
		private static var _textureList		: TextureList;
		private static var _objectsXML		: XML;
		
		// Extracts the frameInformation and big Bitmaps from a Flash MovieClip. 
		public static function export( flashMC:flash.display.MovieClip, outAtlases:Vector.<BitmapData>, sortBitmaps:Boolean=true ) : XML
		{
			_textureList = new TextureList();
			_objectsXML = <objects />;
			
			exportRecursive( flashMC, true );
			
			var clipData:XML = <clipData />;
			clipData.@version = VERSION;
			clipData.@frameRate = flashMC.loaderInfo.frameRate;
			clipData.appendChild( _objectsXML );
			
			var regionInfo:XML = <atlases />;
			var outBitmaps:Vector.<BitmapData> = _textureList.exportTextureAtlases( regionInfo, sortBitmaps );
			clipData.appendChild( regionInfo );
			
			for( var i:int=0; i<outBitmaps.length; ++i )
				outAtlases.push( outBitmaps[ i ] );
			
			_textureList.dispose();
			_textureList = null;
			_objectsXML = null;
			
			return clipData;
		}
		
		
		// Walks though a Flash DisplayObject and extracts it's frame information (and it's children) to XML.
		private static function exportRecursive( displayObject:DisplayObject, ignoreTotalFrames:Boolean=false ) : XML
		{
//			var objectXML:XML = <object id={ "o" + _objectsXML.object.length() }/>;
			var objectXML:XML = <object />;
			_objectsXML.appendChild( objectXML );
			
			// Assign common properties.
			objectXML.@name = displayObject.name;
			if( displayObject.alpha != 1 )
				objectXML.appendChild( <alpha>{ displayObject.alpha }</alpha> );
			if( displayObject.transform.matrix.a != 1
			 || displayObject.transform.matrix.b != 0
			 || displayObject.transform.matrix.c != 0
			 || displayObject.transform.matrix.d != 1 )
			{
				var transformXML:XML = <transform />;
				transformXML.@a = displayObject.transform.matrix.a;
				transformXML.@b = displayObject.transform.matrix.b;
				transformXML.@c = displayObject.transform.matrix.c;
				transformXML.@d = displayObject.transform.matrix.d;
				transformXML.@tx = displayObject.transform.matrix.tx;
				transformXML.@ty = displayObject.transform.matrix.ty;
				objectXML.appendChild( transformXML );
			}
			else if( displayObject.x != 0 || displayObject.y != 0 )
			{
				var positionXML:XML = <position />;
				positionXML.@x = displayObject.x;
				positionXML.@y = displayObject.y;
				objectXML.appendChild( positionXML );
			}
			
			if( displayObject is flash.display.DisplayObjectContainer )
			{
				var container:flash.display.DisplayObjectContainer = displayObject as flash.display.DisplayObjectContainer;
				
				if( container is flash.display.MovieClip && ( ignoreTotalFrames || (container as flash.display.MovieClip).totalFrames > 1 ) )
				{
					objectXML.@type = "movie clip";
					
					var movieClip:MovieClip = container as flash.display.MovieClip;
					var frameData:FrameData = FrameData.importFromFlashMovieClip( movieClip, exportFrameObject );
					
					objectXML.appendChild( frameData.exportToXML() );
					objectXML.appendChild( exportSceneData( movieClip ) );
				}
				else
				{
					objectXML.@type = "sprite";
					
					var childrenXML:XML = <children />;
					
					// Add the children to the new Starling Sprite.
					for( var i:int=0; i<container.numChildren; ++i ) 
					{
						var child:DisplayObject = container.getChildAt( i );
						var childXML:XML = exportRecursive( child );
//						childrenXML.appendChild( <child idref={ childXML.@id } /> );
						childrenXML.appendChild( <child object={ childXML.childIndex() } /> );
					}
					
					objectXML.appendChild( childrenXML );
				}
			}
			else
			{
				if( displayObject is Shape || displayObject is Bitmap )
				{
					objectXML.@type = "image";
					
					var bitmapInfo:BitmapInfo = _textureList.getBitmapInfoFromDisplayObject( displayObject ); 
					
					var objectRect:Rectangle = displayObject.getRect( displayObject );
					var imagePosX:Number = displayObject.x + objectRect.left;
					var imagePosY:Number = displayObject.y + objectRect.top;
					
					if( imagePosX != 0 || imagePosY != 0 )
					{
						if( positionXML == null )
						{
							positionXML = <position />;
							objectXML.appendChild( positionXML );
						}
						positionXML.@x = imagePosX; 
						positionXML.@y = imagePosY;
					}
					
					if( bitmapInfo._xmlList == null )
						bitmapInfo._xmlList = new <XML>[];
					bitmapInfo._xmlList.push( objectXML );
				}
				else
					throw new Error( "Unhandled child object " + displayObject.toString() );
			}
			
			return objectXML;
		}
		
		
		private static function exportFrameObject( flashObject:flash.display.DisplayObject ) : XML
		{
			return exportRecursive( flashObject );
		}
		
		
		// Extracts the scene and label information from a Flash MovieClip to XML
		private static function exportSceneData( movieClip:MovieClip ) : XML
		{
			var scenesXML:XML = <scenes />;
			var sceneCount:int = movieClip.scenes.length;
			for( var sceneIndex:int=0; sceneIndex<sceneCount; ++sceneIndex )
			{
				var scene:Scene = movieClip.scenes[ sceneIndex ];
				var sceneXML:XML = <scene />;
				
				sceneXML.@name = scene.name;
				sceneXML.@numFrames = scene.numFrames;
				
				for each( var label:FrameLabel in scene.labels )
				{
					var labelXML:XML = <label />;
					labelXML.@name = label.name;
					labelXML.@frame = label.frame;
					sceneXML.appendChild( labelXML );
				}
				
				scenesXML.appendChild( sceneXML );
			}
			
			return scenesXML;
		}
	}
}