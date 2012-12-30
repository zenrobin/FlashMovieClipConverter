/**
 * @author Shane Smit <Shane@DigitalLoom.org>
 * 
 * @version 1.4
 */
package ssmit
{
	import flash.display.BitmapData;
	import flash.display.FrameLabel;
	import flash.display.Scene;
	import flash.geom.Point;
	
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.display.Sprite;
	import starling.textures.Texture;
	import starling.textures.TextureAtlas;

	public final class FlashMovieClipImporter
	{
		public static function importFromXML( clipDataXML:XML, atlasBitmaps:Vector.<BitmapData>, generateMipMaps:Boolean=true ) : ConvertedMovieClip
		{
			// Create the texture atlases.
			var atlases:Vector.<TextureAtlas> = new Vector.<TextureAtlas>( clipDataXML.atlases[0].TextureAtlas.length(), true );
			for( var i:int=0; i<atlases.length; ++i )
			{
				var texture:Texture = Texture.fromBitmapData( atlasBitmaps[ i ], generateMipMaps );
				atlases[ i ] = new TextureAtlas( texture, clipDataXML.atlases[0].TextureAtlas[i] );
			}
			
			var version:String = clipDataXML.@version;	// TODO: Check version
			var frameRate:Number = clipDataXML.@frameRate;
			
			// Create the objects.
			var objects:Vector.<DisplayObject> = new Vector.<DisplayObject>( clipDataXML.objects[0].object.length(), true );
			for( i=0; i<objects.length; ++i )
			{
				var objectXML:XML = clipDataXML.objects[0].object[i];
				var objectType:String = objectXML.@type;
				var object:DisplayObject;
				switch( objectType )
				{
					case "movie clip":
						object = new ConvertedMovieClip();
						break;
					case "sprite":
						object = new Sprite();
						break;
					case "image":
						object = createImage( objectXML, atlases );
						break;
					default:
						throw new Error( "Unhandled object type: " + objectType );
				}
				
				object.name = objectXML.@name;
				if( objectXML.transform.length() > 0 )
				{
					var matrixXML:XML = objectXML.transform[0];
					object.transformationMatrix.setTo( matrixXML.@a, matrixXML.@b, matrixXML.@c, matrixXML.@d, matrixXML.@tx, matrixXML.@ty );
					object.x = matrixXML.@tx;
					object.y = matrixXML.@ty;
				}
				else if( objectXML.position.length() > 0 )
				{
					var positionXML:XML = objectXML.position[0];
					object.x = positionXML.@x;
					object.y = positionXML.@y;
				}
				if( objectXML.alpha.length() > 0 )
					object.alpha = objectXML.alpha[0];
				
				objects[ i ] = object;
			}
			
			// Now that all the objects exist... finalize the movie clips and sprites.
			for( i=0; i<objects.length; ++i )
			{
				objectXML = clipDataXML.objects[0].object[i];
				objectType = objectXML.@type;
				if( objectType == "movie clip" )
				{
					// Fill in the frame data and scene data.
					var movieClip:ConvertedMovieClip = ConvertedMovieClip(objects[i]);
					movieClip.frameRate = frameRate;
					movieClip.frameData = FrameData.importFromXML( objectXML.frames[ 0 ], objects );
					movieClip.sceneData = importSceneData( objectXML.scenes[ 0 ] ); 
					movieClip.initFrame();
				}
				else if( objectType == "sprite" )
				{
					// Add all the children.
					var sprite:Sprite = Sprite(objects[i]);
					for each( var childXML:XML in objectXML.children[0].child )
					{
						var objectIndex:int = childXML.@object;
						sprite.addChild( objects[ objectIndex ] );
					}
				}
			}
			
			// Return the first object, which is the root movie clip.
			movieClip = ConvertedMovieClip(objects[ 0 ]);
			movieClip.textureAtlases = atlases;
			
			return movieClip;
		}
		
		
		private static function createImage( imageXML:XML, atlases:Vector.<TextureAtlas> ) : Image
		{
			var textureXML:XML = imageXML.texture[0];
			var atlasIndex:int = textureXML.@atlas;
			var regionName:String = textureXML.@region;
			var texture:Texture = atlases[ atlasIndex ].getTexture( regionName );
			
			// Annoyingly, I can't seem to find a way to create the image at the smaller size without a dummy texture.
			var dummyTexture:Texture = Texture.empty( texture.width - (TextureList.PADDING*2), texture.height - (TextureList.PADDING*2) );
			var image:Image = new Image( dummyTexture );
			dummyTexture.dispose();
			image.texture = texture;
			
			// Adjust texture coordinates to account for padding.
			var leftTC:Number = TextureList.PADDING / texture.width;
			var topTC:Number = TextureList.PADDING / texture.height;
			var rightTC:Number = ( texture.width - TextureList.PADDING ) / texture.width;
			var bottomTC:Number = ( texture.height - TextureList.PADDING ) / texture.height;
			image.setTexCoords( 0, new Point(  leftTC,    topTC ) );
			image.setTexCoords( 1, new Point( rightTC,    topTC ) );
			image.setTexCoords( 2, new Point(  leftTC, bottomTC ) );
			image.setTexCoords( 3, new Point( rightTC, bottomTC ) );
			
			return image;
		}
		
		
		private static function importSceneData( scenesXML:XML ) : Vector.<Scene>
		{
			var scenes:Vector.<Scene> = new Vector.<Scene>( scenesXML.scene.length(), true );
			
			for( var i:int=0; i<scenes.length; ++i )
			{
				var sceneXML:XML = scenesXML.scene[ i ];
				var labels:Array = [];
				for( var j:int=0; j<sceneXML.label.length(); ++j )
				{
					var labelXML:XML = sceneXML.label[ j ];
					labels.push( new FrameLabel( labelXML.@name, labelXML.@frame ) );
				}
				
				scenes[ i ] = new Scene( sceneXML.@name, labels, sceneXML.@numFrames );
			}
			
			return scenes;
		}
	}
}