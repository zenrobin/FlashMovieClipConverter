/**
 * @author Shane Smit <Shane@DigitalLoom.org>
 */
package ssmit
{
	import flash.display.BitmapData;
	import flash.geom.Matrix;
	
	internal final class TexturePacker
	{
		private static const MAX_TEXELS			: int	= 2048 * 2048;
		
		
		// Packs bitmaps into a series of texture atlases.  
		internal static function pack( bitmapInfoList:Vector.<BitmapInfo>, sortBitmaps:Boolean=true ) : Vector.<BitmapData>
		{
			// Sort the bitmaps from largest to smallest, so they pack tighter.
			// Sorting can actually slow thing down, since the textures may be used out of order from how they were referenced in the original MovieClip.
			if( sortBitmaps )
			{
				bitmapInfoList.sort(
					function( info1:BitmapInfo, info2:BitmapInfo ) : Number
					{
						var xTexels:int = info1._bitmapData.width * info1._bitmapData.height;
						var yTexels:int = info2._bitmapData.width * info2._bitmapData.height;
						return( yTexels - xTexels );
					}
				);
			}
			
			// Create one texture packer tree, with minimal size... and work up from there.
			var trees:Vector.<Node> = new <Node>[ new Node ];
			trees[ 0 ]._x = 0;
			trees[ 0 ]._y = 0;
			
			var treeSize:int = calcTreeSize( bitmapInfoList, 0 );
			trees[ 0 ]._width = treeSize;
			trees[ 0 ]._height = treeSize;
			
			// Place the bitmaps into the texture packer trees.
			var startInfoIndex:int = 0;
			for( var infoIndex:int=0; infoIndex<bitmapInfoList.length; ++infoIndex )
			{
				var info:BitmapInfo = bitmapInfoList[ infoIndex ];
				if( info._bitmapData.width > 2048 || info._bitmapData.height > 2048 )
					throw new Error( "Bitmap is too large" ); 
				
				for( var treeIndex:int=0; treeIndex<trees.length; ++treeIndex )
				{
					var tree:Node = trees[ treeIndex ];
					
					// Place the bitmap in the tree.
					var node:Node = tree.insert( info._bitmapData );
					if( node != null )
					{
						info._atlasX = node._x;
						info._atlasY = node._y;
						info._atlasIndex = treeIndex;
						break;
					}
					else if( treeIndex == trees.length - 1 )	// Last tree.
					{
						if( tree._width < 2048 && tree._height < 2048 )
						{
							// Replace this tree with one twice as big.
							var newTree:Node = new Node();
							newTree._x = 0;
							newTree._y = 0;
							newTree._width = tree._width * 2;
							newTree._height = tree._height * 2;
							trees[ treeIndex ] = newTree;
							
							// Repack this tree, because the new size will change the layout.
							infoIndex = startInfoIndex - 1;
						}
						else
						{
							// Create a new tree.
							newTree = new Node();
							newTree._x = 0;
							newTree._y = 0;
							treeSize = calcTreeSize( bitmapInfoList, infoIndex );
							newTree._width = treeSize;
							newTree._height = treeSize;
							trees.push( newTree );
							
							// If this new tree gets resized, start over at this bitmap.
							startInfoIndex = infoIndex;
						}
					}
				}
			}			

			// Create the packed bitmaps.
			var packedBitmaps:Vector.<BitmapData> = new Vector.<BitmapData>( trees.length, true );
			for( var i:int=0; i<trees.length; ++i )
			{
				packedBitmaps[ i ] = new BitmapData( trees[ i ]._width, trees[ i ]._height, true, 0x00000000 );
				packedBitmaps[ i ].lock();	// Lock to prepare for drawing.
			}

			// Write the individual bitmaps to the packed bitmaps.
			var matrix:Matrix = new Matrix();
			for each( info in bitmapInfoList )
			{
				matrix.tx = info._atlasX;
				matrix.ty = info._atlasY;
				packedBitmaps[ info._atlasIndex ].draw( info._bitmapData, matrix );
			}
			
			for( i=0; i<packedBitmaps.length; ++i )
				packedBitmaps[ i ].unlock();	// Drawing finished.
			
			return packedBitmaps;
		}
		
		
		// Guess how big to make a new texture packer tree.
		private static function calcTreeSize( bitmapInfoList:Vector.<BitmapInfo>, startIndex:int ) : int
		{
			var maxWidth:int = 0;
			var maxHeight:int = 0;
			var totalTexels:int = 0;
			
			// This is *very* conservative (dumb) guess.  It's basically just big enough to fit the largest bitmap in the list.
			for( var i:int=startIndex; i<bitmapInfoList.length; ++i )
			{
				var bitmapData:BitmapData = bitmapInfoList[ i ]._bitmapData;
				if( maxWidth < bitmapData.width )
					maxWidth = nextPow2( bitmapData.width );
				if( maxHeight < bitmapData.height )
					maxHeight = nextPow2( bitmapData.height );
				
				// If the total texels has reached 2048x2048, then it's safe to say that should be the tree size.
				totalTexels += bitmapData.width * bitmapData.height;
				if( totalTexels >= MAX_TEXELS )
					return 2048;
			}
			
			return Math.max( maxWidth, maxHeight );
		}
		
		
		// Returns the next power of two of a value.
		private static function nextPow2( value:int ) : int
		{
			value--;
			value = (value >> 1) | value;
			value = (value >> 2) | value;
			value = (value >> 4) | value;
			value = (value >> 8) | value;
			value = (value >> 16) | value;
			value++;
			return value;
		}
	}
}


import flash.display.BitmapData;


// Texture packer tree node.
internal final class Node
{
	public var _children	: Vector.<Node>;
	public var _x			: int;
	public var _y			: int;
	public var _width		: int;
	public var _height		: int;
	public var _occupied	: Boolean;
	
	// Used lightmap packing algorithm presented at http://www.blackpawn.com/texts/lightmaps/
	public function insert( bitmapData:BitmapData ) : Node
	{
		if( _children != null )	// If we're not a leaf
		{
			// Try inserting into first child.
			var newNode:Node = _children[ 0 ].insert( bitmapData );
			if( newNode != null )
				return newNode;
			
			// No room, insert into second.
			return _children[ 1 ].insert( bitmapData );
		}
		else
		{
			if( _occupied )
				return null;	// Already a texture here.
			
			if( _width < bitmapData.width || _height < bitmapData.height )
				return null;	// Too small.
			
			if( _width == bitmapData.width && _height == bitmapData.height )
			{
				// Just right. Mark as occupied.
				_occupied = true;
				return this;
			}
			
			// Otherwise, gotta split this node and create some children.
			_children = new <Node>[ new Node(), new Node() ];
			_children.fixed = true;
			
			// decide which way to split.
			var dw:int = _width - bitmapData.width;
			var dh:int = _height - bitmapData.height;
			if( dw > dh )
			{
				_children[ 0 ]._x = _x;
				_children[ 0 ]._y = _y;
				_children[ 0 ]._width  = bitmapData.width;
				_children[ 0 ]._height = _height;

				_children[ 1 ]._x = _x + bitmapData.width;
				_children[ 1 ]._y = _y;
				_children[ 1 ]._width  = _width - bitmapData.width;
				_children[ 1 ]._height = _height;
			}
			else
			{
				_children[ 0 ]._x = _x;
				_children[ 0 ]._y = _y;
				_children[ 0 ]._width  = _width;
				_children[ 0 ]._height = bitmapData.height;
				
				_children[ 1 ]._x = _x;
				_children[ 1 ]._y = _y + bitmapData.height;
				_children[ 1 ]._width  = _width;
				_children[ 1 ]._height = _height - bitmapData.height;
			}
			
			// insert into first child we created.
			return _children[ 0 ].insert( bitmapData );
		}
		
		return null;
	}
}