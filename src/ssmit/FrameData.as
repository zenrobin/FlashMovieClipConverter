/**
 * @author Shane Smit <Shane@DigitalLoom.org>
 */
package ssmit
{
	import flash.display.Bitmap;
	import flash.display.MovieClip;
	import flash.display.Shape;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	
	import starling.animation.IAnimatable;
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.display.Sprite;

	internal final class FrameData
	{
		private var _frameList		: Vector.<Vector.<ObjectFrameData>>;
		
		public function FrameData( frameCount:int )
		{
			_frameList = new Vector.<Vector.<ObjectFrameData>>( frameCount, true );
		}
		
		
		internal function dispose() : void
		{
			// Clean out the frame data.
			for each( var objectList:Vector.<ObjectFrameData> in _frameList )
			{
				for each( var objectFrameData:ObjectFrameData in objectList )
					objectFrameData.dispose();
			}
			_frameList = null;
		}
		
		
		// Imports frame data from a Flash MovieClip
		internal static function importFromFlashMovieClip( movieClip:MovieClip, objectCallback:Function ) : FrameData
		{
			var frameData:FrameData = new FrameData( movieClip.totalFrames );
			
			for( var frame:int=1; frame<=movieClip.totalFrames; ++frame )
			{
				movieClip.gotoAndStop( frame );
				
				frameData._frameList[ frame-1 ] = new Vector.<ObjectFrameData>( movieClip.numChildren, true );
				
				// Fetch the frame-by-frame information for each child in the movie clip.
				for( var i:int=0; i<movieClip.numChildren; ++i )
				{
					// Find or create a converted version of each child object.
					var child:flash.display.DisplayObject = movieClip.getChildAt( i );
					
					var objectFrameData:ObjectFrameData = new ObjectFrameData();
					var oldFrameData:ObjectFrameData = frameData.findObjectFrameData( child );
					
					if( oldFrameData != null )
					{
						if( oldFrameData.name != child.name )
							throw new Error( "This can actually happen." );
						
						objectFrameData.name = oldFrameData.name;
						objectFrameData.starlingObject = oldFrameData.starlingObject;
						objectFrameData.xmlObject = oldFrameData.xmlObject;
					}
					else
					{
						objectFrameData.name = child.name.slice();
						
						// I'm not too happy about how this ended up.
						var object:Object = objectCallback( child );
						if( object is starling.display.DisplayObject )
							objectFrameData.starlingObject = starling.display.DisplayObject(object);
						else if( object is XML )
							objectFrameData.xmlObject = XML(object);
					}
					
					objectFrameData.flashObject = child;
					objectFrameData.transformationMatrix = new Matrix();
					objectFrameData.transformationMatrix.copyFrom( child.transform.matrix );
					if( child is Shape || child is Bitmap )
					{
						// Child will be converted to a texture, compensate with offset.
						var childRect:Rectangle = child.getBounds( child );
						objectFrameData.transformationMatrix.tx += childRect.left;
						objectFrameData.transformationMatrix.ty += childRect.top;
					}
					objectFrameData.alpha = child.alpha;
					
					frameData._frameList[ frame-1 ][ i ] = objectFrameData;
				}
			}
			
			// Clean out all the Flash object references.
			for( frame=frameData._frameList.length-1; frame>=0; --frame )
			{
				for each( objectFrameData in frameData._frameList[ frame ] )
					objectFrameData.flashObject = null;
			}
			
			// Reset the original movie clip, just in case.
			movieClip.gotoAndStop( 1 );
			
			return frameData;
		}
		
		
		// finds an existing ObjectFrameData in prior frames, given a Flash DisplayObject.
		private function findObjectFrameData( object:flash.display.DisplayObject ) : ObjectFrameData
		{
			for( var frame:int=_frameList.length-1; frame>=0; --frame )
			{
				for each( var frameData:ObjectFrameData in _frameList[ frame ] )
				{
					if( frameData != null && frameData.flashObject === object )
						return frameData;
				}
			}
			
			return null;
		}
		
		
		// Imports frame data from xml.
		internal static function importFromXML( xml:XML, objects:Vector.<DisplayObject> ) : FrameData
		{
			var frameData:FrameData = new FrameData( xml.frame.length() );
			
			for( var i:int=0; i<frameData._frameList.length; ++i  )
			{
				var frameXML:XML = xml.frame[ i ];
				var objectList:Vector.<ObjectFrameData> = new Vector.<ObjectFrameData>( frameXML.child.length(), true );
				for( var j:int=0; j<objectList.length; ++j )
				{
					var childXML:XML = frameXML.child[ j ];
					var objectFrameData:ObjectFrameData = new ObjectFrameData();
					objectFrameData.name = childXML.@name;
					
					if( childXML.transform.length() > 0 )
					{
						var matrixXML:XML = childXML.transform[ 0 ];
						objectFrameData.transformationMatrix = new Matrix( matrixXML.@a, matrixXML.@b, matrixXML.@c, matrixXML.@d, matrixXML.@tx, matrixXML.@ty );
					}
					else if( childXML.position.length() > 0 )
					{
						var positionXML:XML = childXML.position[ 0 ];
						objectFrameData.transformationMatrix = new Matrix( 1, 0, 0, 1, positionXML.@x, positionXML.@y );
					}
					else
						objectFrameData.transformationMatrix = new Matrix();
					
					if( childXML.alpha.length() > 0 )
						objectFrameData.alpha = childXML.alpha[0];
					else
						objectFrameData.alpha = 1;
					
					var objectIndex:int = childXML.@object;
					objectFrameData.starlingObject = objects[ objectIndex ];
					objectList[ j ] = objectFrameData;
				}
				
				frameData._frameList[ i ] = objectList;
			}
			
			return frameData;
		}
			
			
		// Exports the frame data to xml.
		internal function exportToXML() : XML
		{
			var xml:XML = <frames />;
			
			for( var frame:int=0; frame<_frameList.length; ++frame )
			{
				var frameXML:XML = <frame />;
				
				var objectList:Vector.<ObjectFrameData> = _frameList[ frame ];
				for( var object:int=0; object<objectList.length; ++object )
				{
					var objectFrameData:ObjectFrameData = objectList[ object ];
					
//					var childXML:XML = <child idref={ objectFrameData.xmlObject.@id }/>;
					var childXML:XML = <child object={ objectFrameData.xmlObject.childIndex() }/>;
					childXML.@name = objectFrameData.name;
					if( objectFrameData.alpha != 1 )
						childXML.appendChild( <alpha>{ objectFrameData.alpha }</alpha> );
					if( objectFrameData.transformationMatrix.a != 1
					 || objectFrameData.transformationMatrix.b != 0
					 || objectFrameData.transformationMatrix.c != 0
					 || objectFrameData.transformationMatrix.d != 1
					 || objectFrameData.transformationMatrix.tx != 0
					 || objectFrameData.transformationMatrix.ty != 0 )
					{
						var transformXML:XML = <transform />;
						transformXML.@a = objectFrameData.transformationMatrix.a;
						transformXML.@b = objectFrameData.transformationMatrix.b;
						transformXML.@c = objectFrameData.transformationMatrix.c;
						transformXML.@d = objectFrameData.transformationMatrix.d;
						transformXML.@tx = objectFrameData.transformationMatrix.tx;
						transformXML.@ty = objectFrameData.transformationMatrix.ty;
						childXML.appendChild( transformXML );
					}
					
					frameXML.appendChild( childXML );
				}
				
				xml.appendChild( frameXML );
			}
			
			return xml;
		}
		
		
		internal function clone() : FrameData
		{
			var newFrameData:FrameData = new FrameData( _frameList.length );
			
			for( var f:int=0; f<_frameList.length; ++f )
			{
				var objectList:Vector.<ObjectFrameData> = _frameList[ f ];
				var newObjectList:Vector.<ObjectFrameData> = new Vector.<ObjectFrameData>( objectList.length, true ); 
				for( var o:int=0; o<objectList.length; ++o )
				{
					var objectFrameData:ObjectFrameData = objectList[ o ];
					var newObjectFrameData:ObjectFrameData = new ObjectFrameData();
					
					// Shallow copy.
					newObjectFrameData.name = objectFrameData.name;
					newObjectFrameData.transformationMatrix = objectFrameData.transformationMatrix;
					newObjectFrameData.alpha = objectFrameData.alpha;
					newObjectFrameData.cloneSource = objectFrameData.starlingObject;
					
					// Deep copy the starling object.
					var oldObjectFrameData:ObjectFrameData = newFrameData.findObjectFrameDataByCloneSource( objectFrameData.starlingObject );
					var newStarlingObject:starling.display.DisplayObject;
					
					if( oldObjectFrameData != null )
					{
						newStarlingObject = oldObjectFrameData.starlingObject;
					}
					else
					{
						if( objectFrameData.starlingObject is ConvertedMovieClip )
							newStarlingObject = ConvertedMovieClip(objectFrameData.starlingObject).clone();
						else if( objectFrameData.starlingObject is Sprite )
							newStarlingObject = cloneSprite( Sprite(objectFrameData.starlingObject) );
						else if( objectFrameData.starlingObject is Image )
							newStarlingObject = cloneImage( Image(objectFrameData.starlingObject) );
					}
					
					newObjectFrameData.starlingObject = newStarlingObject;
					
					newObjectList[ o ] = newObjectFrameData;
				}
				newFrameData._frameList[ f ] = newObjectList;
			}
			
			// Clean out the cloneSource object references
			for( f=0; f<_frameList.length; ++f )
			{
				objectList = _frameList[ f ];
				for( o=0; o<objectList.length; ++o )
					objectList[ o ].cloneSource = null;
			}
			
			return newFrameData;
		}
		
		
		// finds an existing ObjectFrameData in prior frames, given a clone source object.
		private function findObjectFrameDataByCloneSource( cloneSource:starling.display.DisplayObject ) : ObjectFrameData
		{
			for( var frame:int=_frameList.length-1; frame>=0; --frame )
			{
				for each( var frameData:ObjectFrameData in _frameList[ frame ] )
				{
					if( frameData != null && frameData.cloneSource === cloneSource )
						return frameData;
				}
			}
			
			return null;
		}
		
		
		// Creates a deep copy of a child Sprite.
		private static function cloneSprite( sprite:Sprite ) : Sprite
		{
			var newSprite:Sprite = new Sprite();
			
			newSprite.name = sprite.name;
			newSprite.transformationMatrix.copyFrom( sprite.transformationMatrix );
			newSprite.alpha = sprite.alpha;
			newSprite.blendMode = sprite.blendMode;
			
			// Add the children to the new Sprite.
			for( var i:int=0; i<sprite.numChildren; ++i ) 
			{
				var child:starling.display.DisplayObject = sprite.getChildAt( i );
				var newChild:starling.display.DisplayObject;
				
				if( child is ConvertedMovieClip )
					newChild = ConvertedMovieClip(child).clone();
				else if( child is Sprite )
					newChild = cloneSprite( Sprite(child) );
				else if( child is Image )
					newChild = cloneImage( Image(child) );
				
				newSprite.addChild( newChild );
			}
			
			return newSprite;
		}
		
		
		// Creates a copy of a child image.  The texture is not duplicated.
		private static function cloneImage( image:Image ) : Image
		{
			var newImage:Image = new Image( image.texture );
			newImage.setTexCoords( 0, image.getTexCoords( 0 ) );
			newImage.setTexCoords( 1, image.getTexCoords( 1 ) );
			newImage.setTexCoords( 2, image.getTexCoords( 2 ) );
			newImage.setTexCoords( 3, image.getTexCoords( 3 ) );
			
			newImage.name = image.name;
			newImage.transformationMatrix.copyFrom( image.transformationMatrix );
			newImage.alpha = image.alpha;
			newImage.blendMode = image.blendMode;
			newImage.smoothing = image.smoothing;
			
			return newImage;
		}
		
		
		// Initializes the first frome of the animation.
		internal function initFrame( parent:ConvertedMovieClip ) : void
		{
			// Add the new children. And update their frame properties.
			var frameObjectList:Vector.<ObjectFrameData> = _frameList[ 0 ];
			for( var i:int=0; i<frameObjectList.length; ++i )
			{
				var objectFrameData:ObjectFrameData = frameObjectList[ i ];
				var object:starling.display.DisplayObject = objectFrameData.starlingObject;
				
				object.transformationMatrix.copyFrom( objectFrameData.transformationMatrix );
				object.alpha = objectFrameData.alpha;
				
				if( object is IAnimatable )
					parent.juggler.add( IAnimatable(object) );
				parent.addChildAt( object, i );
			}
		}
		
		
		// Change from the current global frame to another.  Does not have to be sequential. 
		internal function changeFrame( parent:ConvertedMovieClip, currentFrame:int, targetFrame:int ) : void
		{
			var object:starling.display.DisplayObject;
			
			// Avoid excessive child removal and addition.
			var curObjects:Dictionary = new Dictionary();	// Object indices from the current frame
			var newObjects:Dictionary = new Dictionary();	// Object indices in the new frame
			var allObjects:Dictionary = new Dictionary();	// Object indices in the new frame, and -1s for objects in the old frame.
			
			var curFrameObjectList:Vector.<ObjectFrameData> = _frameList[ currentFrame - 1 ];
			var newFrameObjectList:Vector.<ObjectFrameData> = _frameList[ targetFrame - 1 ];
			
			// Build a dictionary of every child in the current frame.
			for( var i:int=0; i<curFrameObjectList.length; ++i )
			{
				object = curFrameObjectList[ i ].starlingObject;
				curObjects[ object ] = i;
				allObjects[ object ] = -1;	// Mark this object to be removed.
			}
			
			// Determine which children should stick around, be added, or be removed.
			for( i=0; i<newFrameObjectList.length; ++i )
			{
				object = newFrameObjectList[ i ].starlingObject;
				newObjects[ object ] = i;	// This will also be the child index.
				allObjects[ object ] = i;	// Unmark the object to be removed if it existed in the current frame.
			}
			
			// Remove all the children still marked with a -1.
			for( var key:Object in allObjects )
			{
				var childIndex:int = allObjects[ key ];
				if( childIndex == -1 )
				{
					parent.removeChild( starling.display.DisplayObject(key) );
					if( key is IAnimatable )
						parent.juggler.remove( IAnimatable(key) );
				}
			}
			
			// Finally, add the new children or reorder the existing children. And update their frame properties.
			for( i=0; i<newFrameObjectList.length; ++i )
			{
				var frameData:ObjectFrameData = newFrameObjectList[ i ];
				object = frameData.starlingObject;
				
				object.transformationMatrix.copyFrom( frameData.transformationMatrix );
				object.alpha = frameData.alpha;
				
				// Determine if the object was already a child.
				if( curObjects[ object ] != undefined )
				{
					if( curObjects[ object ] != i )
						parent.setChildIndex( object, i );
				}
				else
				{
					if( object is IAnimatable )
						parent.juggler.add( IAnimatable(object) );
					parent.addChildAt( object, i );
				}
			}
		}
		
		
		internal function get totalFrames() : uint
		{
			return _frameList.length;
		}
	}
}


import flash.display.DisplayObject;
import flash.geom.Matrix;

import starling.display.DisplayObject;

internal final class ObjectFrameData
{
	public var name					: String;
	public var transformationMatrix	: Matrix;
	public var alpha				: Number;
	
	public var flashObject			: flash.display.DisplayObject;
	public var starlingObject		: starling.display.DisplayObject;
	public var xmlObject			: XML;
	public var cloneSource			: starling.display.DisplayObject;
	
	public function dispose() : void
	{
		name = null;
		transformationMatrix = null;
		flashObject = null;
		cloneSource = null;
		
		if( starlingObject != null )
		{
			starlingObject.dispose();
			starlingObject = null;
		}
		xmlObject = null;
	}
}