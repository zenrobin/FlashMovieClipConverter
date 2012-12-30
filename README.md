FlashMovieClipConverter
=======================

The github home for ShaneSmit's public movieclip converter for Starling.

Version 1.4 has been downloaded from the Starling Forum and posted here for the community to continue improvements.

Forum:
http://forum.starling-framework.org/topic/flash-movieclip-converter-preserves-display-list-hierarchy

Orig code: (posted here)
http://digitalloom.org/CodeWeaver/FlashMovieClipConverter-1.4.zip

Shane's origional Post (October, 2012):


I started looking at Starling 2 days ago, and quickly realized a great truth that I'm sure you are all very familiar with: Starling MovieClip != Flash MovieClip.

Obviously, we still want to be able to create content and animations with Flash, so the typical solution is to walk through each frame of a Flash MovieClip and create a texture from it. With large and/or long animations this is a terrible waste of GPU memory. And you've lost all the display list hierarchy (if that was important to you).

So I wrote some code that attempts to really convert a Flash MovieClip to a Starling IAnimatable Sprite. It's many AS files worth of code, so I won't paste it here... but here's the basic psuedocode:

Walk through the Flash MovieClip display list:
    For each child
        If it's a container
            Create a Starling Sprite (IAnimatable if more than 1 frame)
            Start over, using the new Sprite (recursive)
        Else
            Create a Starling Texture from it. (uses CRCs to avoid dups)
The code can be found here: http://DigitalLoom.org/CodeWeaver/FlashMovieClipConverter-1.4.zip
Version 1.4 - Added command-line AIR app to pre-convert the Flash MovieClip.
version 1.3 - Performance enhancements, and added clone() function.
version 1.2 - Added typical MovieClip controls (gotoAndStop, etc.)
version 1.1 - Added Texture Atlasing

Usage - Run-time conversion:

var animSprite:ConvertedMovieClip = FlashMovieClipConverter.convert( flashMC );
Starling.juggler.add( animSprite );
Usage - Pre-conversion via command-line AIR app

> StarlingConverter [-noSortBitmaps] MyMovieClip.swf
var clipData:XML = // Load MyMovieClip-clipData.xml
var atlasBitmaps:Vector.<BitmapData> = // Load MyMovieClip-atlas1.png (and atlas2, atlas3, etc.)
var animSprite:ConvertedMovieClip = FlashMovieClipImporter.importFromXML( clipData, atlasBitmaps );
Starling.juggler.add( animSprite );
The code is quite limited... it only handles animation of position, rotation, scale, and alpha. But that's 90% of what I usually animate anyway. It was intended to convert Flash MovieClips loaded from SWF files without any AS linkage (as required by iOS), so I can't guarantee it'll work in other situations. Furthermore, I can't spend time supporting it... so if you improve it, just post it back to this thread.

Forgive me if someone else has already created something like this. The only thing I was able to find was emibap's Dynamic Texture Atlas Generator, which didn't appear to do what I wanted.
