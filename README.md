Advanced Tiled Loader
========

Advanced Tiled Loader (ATL) loads and renders [Tiled](http://www.mapeditor.org/) maps inside of the [Löve2D](http://love2d.org) game framework.

Currently compatible with Tiled **0.10.0**

This was a fork of Kadoba's Advanced Tiled Loader. 
The majority of the code has been rewritten from the ground up. 
Latest update is found on the master branch.

Supports every known feature except for the following:
* Object rotation
* Specifying draw order
* Tile animation

Stable release:
[v0.9.2F](https://github.com/markandgo/Advanced-Tiled-Loader/releases/tag/v0.9.2F)

Example: 

````lua
atl = require 'src'
map = atl.load('map.tmx')

function love.draw()
	map:draw(x,y)
end
````