/**
 * @author Shane Smit <Shane@DigitalLoom.org>
 */
package ssmit
{
	import flash.display.FrameLabel;
	import flash.display.Scene;
	
	import starling.animation.IAnimatable;
	import starling.animation.Juggler;
	import starling.display.DisplayObject;
	import starling.display.Sprite;
	import starling.textures.TextureAtlas;
	
	
	// A Flash MovieClip that has been converted to a Starling animatable Sprite.
	public class ConvertedMovieClip extends Sprite implements IAnimatable
	{
		private static const ERROR_FRAME_RANGE		: String	= "Frame out of range.";
		
		public var frameRate			: Number;
		public var textureAtlases		: Vector.<TextureAtlas>;
		
		private var _frameData			: FrameData;
		private var _juggler			: Juggler;
		
		private var _frameTime			: Number;
		private var _globalFrame		: int;	// All 'frame' vars are 1 based to emulate the Flash MovieClip timeline.
		private var _isPlaying			: Boolean;
		private var _scenes				: Vector.<Scene>;
		private var _currentScene		: Scene;
		private var _firstSceneFrame	: int;
		private var _lastSceneFrame		: int;
		private var _currentFrame		: int;
		private var _currentFrameLabel	: String;
		private var _currentLabel		: String;
		
		
		// Creates a new ConvertedMovieClip.
		public function ConvertedMovieClip()
		{
			frameRate = 60;
			_frameTime = 0;
			_globalFrame = -1;
			
			_juggler = new Juggler();
			
			_isPlaying = true;
		}
		
		
		// Cleans up everything including the textures.
		public override function dispose() : void
		{
			super.dispose();
			
			if( _juggler != null )
			{
				_juggler.purge();
				_juggler = null;
			}
			
			_frameData.dispose();
			_frameData = null;
			
			// Clear out the texture atlases.
			if( textureAtlases != null )
			{
				for each( var atlas:TextureAtlas in textureAtlases )
					atlas.dispose();
				textureAtlases = null;
			}
			
			_scenes = null;
			_currentScene = null;
			_currentFrameLabel = null;
			_currentLabel = null;
		}
		
		
		// Creates a duplicate of this ConvertedMovieClip... a deep copy.
		public function clone() : ConvertedMovieClip
		{
			var newMovieClip:ConvertedMovieClip = new ConvertedMovieClip();
			
			// Shallow copy this stuff.
			newMovieClip.name = name;
			newMovieClip.transformationMatrix.copyFrom( transformationMatrix );
			newMovieClip.alpha = alpha;
			newMovieClip.blendMode = blendMode;
			newMovieClip.frameRate = frameRate;
			newMovieClip.textureAtlases = textureAtlases;
			newMovieClip._scenes = _scenes;
			
			// Clone the frameData.
			newMovieClip._frameData = _frameData.clone();
			
			newMovieClip.initFrame();
			return newMovieClip;
		}
		
		
		// The parent Juggler calls this.  Advances the frames of this, and all child ConvertedMovieClips.
		public function advanceTime( time:Number ) : void
		{
			if( _isPlaying )
			{
				// Advance the frame based on the frame rate.
				var targetFrame:int = _globalFrame;
				var frameDuration:Number = 1 / frameRate;
				_frameTime += time;
				while( _frameTime >= frameDuration )
				{
					++targetFrame;
					if( targetFrame > _lastSceneFrame )
					{
//						if( loop )
							targetFrame = _firstSceneFrame;
//						else
//							targetFrame = _lastSceneFrame;
					}
					_frameTime -= frameDuration;
				}
				
				// Change the frame, if necessary.
				if( targetFrame != _globalFrame )
					changeFrame( targetFrame );
			}

			// Advance the time of the children, even if this MovieClip is stopped. 
			_juggler.advanceTime( time ); 
		}
		
		
		// Initializes the first frome of the animation.
		internal function initFrame() : void
		{
			_frameData.initFrame( this );
			
			// Bump the frame count. (Why here? Because we are between removing the old and adding the new)
			_globalFrame = 1;
			updateSceneInfo();
		}
		
		
		// Change from the current global frame to another.  Does not have to be sequential. 
		private function changeFrame( targetFrame:int ) : void
		{
			_frameData.changeFrame( this, _globalFrame, targetFrame );
			
			// Bump the frame count.
			_globalFrame = targetFrame;
			updateSceneInfo();
		}
		
		
		// Calls Sprite.flatten() on all children, excluding child ConvertedMovieClips, recursively.
		// Can improve performance.
		public function flattenChildren() : void
		{
			for( var i:int=0; i<numChildren; ++i )
			{
				var child:DisplayObject = getChildAt( i );
				
				if( child is ConvertedMovieClip )
					ConvertedMovieClip(child).flattenChildren();
				else if( child is Sprite )
					Sprite(child).flatten();
			}
		}
		
		
		// Update all the class vars regarding current scene and label, according to the _globalFrame.
		private function updateSceneInfo() : void
		{
			_currentFrameLabel = null;
			_currentLabel = null;

			_lastSceneFrame = 0;
			for each( var scene:Scene in _scenes )
			{
				_firstSceneFrame = _lastSceneFrame + 1;
				_lastSceneFrame += scene.numFrames;
				if( _globalFrame <= _lastSceneFrame )
				{
					_currentScene = scene;
					_currentFrame = ( _globalFrame - _firstSceneFrame ) + 1;
					
					for each( var label:FrameLabel in scene.labels )
					{
						if( _currentFrame < label.frame )
							return;
						
						if( _currentFrame == label.frame )
						{
							_currentFrameLabel = label.name;
							_currentLabel = label.name;
							return;
						}
						
						_currentLabel = label.name;
					}
					
					return;
				}
			}
			
			throw new Error( "This shouldn't happen" );
		}
		
		
		// Converts a scene frame number to a global frame number.
		private function getGlobalFrameFromSceneFrame( sceneName:String, frame:int ) : int
		{
			var firstSceneFrame:int;
			var lastSceneFrame:int = 0;
			for each( var scene:Scene in _scenes )
			{
				firstSceneFrame = lastSceneFrame + 1;
				lastSceneFrame += scene.numFrames;
				if( sceneName == scene.name )
				{
					if( frame > lastSceneFrame )
						throw new Error( ERROR_FRAME_RANGE ); 
					
					return( ( firstSceneFrame - 1 ) + frame );
				}
			}
			
			throw new Error( "Cannot find scene '" + sceneName + "'" ); 
		}
		
		
		// Converts a label in the current scene to a global frame number.
		private function getGlobalFrameFromLabel( labelName:String ) : int
		{
			for each( var label:FrameLabel in _currentScene.labels )
			{
				if( label.name == labelName )
					return( ( _firstSceneFrame - 1 ) + label.frame );
			}
			
			throw new Error( "Cannot find label '" + labelName + "'" );
		}
		
		
		// Converts a scene label to a global frame number.
		private function getGlobalFrameFromSceneLabel( sceneName:String, labelName:String ) : int
		{
			var firstSceneFrame:int;
			var lastSceneFrame:int = 0;
			for each( var scene:Scene in _scenes )
			{
				firstSceneFrame = lastSceneFrame + 1;
				lastSceneFrame += scene.numFrames;
				if( sceneName == scene.name )
				{
					for each( var label:FrameLabel in scene.labels )
					{
						if( label.name == labelName )
							return( ( firstSceneFrame - 1 ) + label.frame );
					}
					
					throw new Error( "Cannot find label '" + labelName + "'" );
				}
			}
			
			throw new Error( "Cannot find scene '" + sceneName + "'" ); 
		}
		
		
		// Given a 'frame' Object, and an optional scene name, returns a global frame number.
		private function getTargetFrame( frame:Object, scene:String ) : int
		{
			var frameInt:int;

			if( !isNaN( Number(frame) ) )	// First check if the frame is, or can be converted to, a number.  (Which is really lame)
			{
				frameInt = int(frame);
				if( frameInt < 1 )
					throw new Error( ERROR_FRAME_RANGE );
				
				if( scene == null )
				{
					frameInt += _firstSceneFrame - 1;
					if( frameInt > _lastSceneFrame )
						throw new Error( ERROR_FRAME_RANGE );
				}
				else
					frameInt = getGlobalFrameFromSceneFrame( scene, frameInt );
			}
			else if( frame is String )	// Otherwise, it's a frame label.
			{
				if( scene == null )
					frameInt = getGlobalFrameFromLabel( String(frame) );
				else
					frameInt = getGlobalFrameFromSceneLabel( scene, String(frame) );
			}
			else
				throw new Error( "Invalid frame object" );
			
			return frameInt;
		}
		
		
		internal function set frameData( value:FrameData ) : void
		{
			_frameData = value;
		}
		
		internal function get frameData() : FrameData
		{
			return _frameData;
		}
		
		
		internal function set sceneData( sceneData:Vector.<Scene> ) : void
		{
			_scenes = sceneData;
		}
		
		
		internal function get juggler() : Juggler
		{
			return _juggler;
		}
		
		
		// Flash MovieClip function implementations
		
		
		/** @copy flash.display.MovieClip#play() */
		public function play() : void
		{
			_isPlaying = true;
		}
		
		
		/** @copy flash.display.MovieClip#stop() */
		public function stop() : void
		{
			_isPlaying = false;
		}
		
		
		/** @copy flash.display.MovieClip#gotoAndPlay() */
		public function gotoAndPlay( frame:Object, scene:String = null ) : void
		{
			var targetFrame:int = getTargetFrame( frame, scene );
			
			_isPlaying = true;
			
			if( targetFrame != _globalFrame )
			{
				_frameTime = 0;
				changeFrame( targetFrame );
			}
		}
		
		
		/** @copy flash.display.MovieClip#gotoAndStop() */
		public function gotoAndStop( frame:Object, scene:String = null ) : void
		{
			var targetFrame:int = getTargetFrame( frame, scene );
			
			_isPlaying = false;
			
			if( targetFrame != _globalFrame )
			{
				_frameTime = 0;
				changeFrame( targetFrame );
			}
		}
		
		
		/** @copy flash.display.MovieClip#nextFrame() */
		public function nextFrame() : void
		{
			var targetFrame:int = _globalFrame + 1;
			if( targetFrame > _lastSceneFrame )
			{
//				if( loop )
					targetFrame = _firstSceneFrame;
//				else
//					targetFrame = _lastSceneFrame;
			}
			
			_isPlaying = false;

			if( targetFrame != _globalFrame )
			{
				_frameTime = 0;
				changeFrame( targetFrame );
			}
		}
		
		
		/** @copy flash.display.MovieClip#prevFrame() */
		public function prevFrame() : void
		{
			var targetFrame:int = _globalFrame - 1;
			if( targetFrame < _firstSceneFrame )
			{
//				if( loop )
					targetFrame = _lastSceneFrame;
//				else
//					targetFrame = _firstSceneFrame;
			}
			
			_isPlaying = false;
			
			if( targetFrame != _globalFrame )
			{
				_frameTime = 0;
				changeFrame( targetFrame );
			}
		}
		
		
		/** @copy flash.display.MovieClip#nextScene() */
		public function nextScene() : void
		{
			var targetFrame:int = _lastSceneFrame + 1;
			if( targetFrame <= _frameData.totalFrames )
			{
				_frameTime = 0;
				changeFrame( targetFrame );
			}
			// else, should we loop to the first scene?
		}
		
		
		/** @copy flash.display.MovieClip#prevScene() */
		public function prevScene() : void
		{
			var targetFrame:int = _firstSceneFrame - 1;
			if( targetFrame >= 1 )
			{
				_frameTime = 0;
				changeFrame( targetFrame );
			}
			// else, should we loop to the last scene?
		}
		
		
		// Flash MovieClip property implementations 
		
		
		/** @copy flash.display.MovieClip#isPlaying */
		public function get isPlaying() : Boolean
		{
			return _isPlaying;
		}
		
		
		/** @copy flash.display.MovieClip#currentFrame */
		public function get currentFrame() : int
		{
			return _currentFrame;
		}
		
		
		/** @copy flash.display.MovieClip#totalFrames */
		public function get totalFrames() : int
		{
			return _frameData.totalFrames;
		}
		
		
		/** @copy flash.display.MovieClip#currentFrameLabel */
		public function get currentFrameLabel() : String
		{
			return _currentFrameLabel;
		}
		
		
		/** @copy flash.display.MovieClip#currentLabel */
		public function get currentLabel() : String
		{
			return _currentLabel;
		}
		
		
		/** @copy flash.display.MovieClip#currentLabels */
		public function get currentLabels() : Vector.<FrameLabel>
		{
			return Vector.<FrameLabel>( _currentScene.labels );
		}
		
		
		/** @copy flash.display.MovieClip#currentScene */
		public function get currentScene() : Scene
		{
			return _currentScene;
		}
		
		
		/** @copy flash.display.MovieClip#scenes */
		public function get scenes() : Vector.<Scene>
		{
			return _scenes;
		}
	}
}


import flash.display.DisplayObject;
import flash.geom.Matrix;

import starling.display.DisplayObject;

// This class stores a single display object's properties, on a single frame.
internal final class ObjectFrameData
{
	public var name					: String;
	public var transformationMatrix	: Matrix;
	public var alpha				: Number;
	
	public var object				: flash.display.DisplayObject;
	public var cloneSource			: starling.display.DisplayObject;
	public var convertedObject		: starling.display.DisplayObject;
	
	public function dispose() : void
	{
		name = null;
		transformationMatrix = null;
		object = null;
		cloneSource = null;
		
		convertedObject.dispose();
		convertedObject = null;
	}
}