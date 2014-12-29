#Advanced Tiled Loader
========
Advanced Tiled Loader (ATL) loads and renders [Tiled](http://www.mapeditor.org/) maps inside of the [Löve2D](http://love2d.org) game framework.

Currently compatible with Tiled **0.9.0**

Supported features include:
* Multiple Layers
* All object types (regular, polygon, and tile)
* Properties
* Transparent colors
* Margins and spacing
* External tilesets
* zlib/gzip compression
* Isometric maps
* Flipped and rotated tiles

This was a fork of Kadoba's Advanced Tiled Loader. The majority of the code has been rewritten from the ground up.

New features include:
* Chunk loading for cooperative multitasking
* Much faster loading
* Image layer support
* Support for terrain data
* Staggered map
* Extendable class system

Stable release:
[v0.9.2F](https://github.com/markandgo/Advanced-Tiled-Loader/releases/tag/v0.9.2F)