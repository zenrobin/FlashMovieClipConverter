/**
 * @author Shane Smit <Shane@DigitalLoom.org>
 */
package ssmit
{
	import flash.display.BitmapData;
	
	import starling.display.Image;
	
	internal final class BitmapInfo
	{
		internal var _bitmapData	: BitmapData;
		internal var _crc			: uint;
		internal var _name			: String;
		internal var _imageList		: Vector.<Image>;
		internal var _xmlList		: Vector.<XML>;
		
		internal var _atlasX		: int;
		internal var _atlasY		: int;
		internal var _atlasIndex	: int;
		
		internal function dispose() : void
		{
			_bitmapData.dispose();
			_bitmapData = null;
			_name = null;
			_imageList = null;	// WARNING: Do not dispose Images. They are still in use.
			_xmlList = null;
		}
	}
}