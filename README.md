Tidal
========

Tidal loads and renders [Tiled](http://www.mapeditor.org/) maps. 
Requires [LÖVE](http://love2d.org)

Currently compatible with Tiled **0.10.0**

This was a fork of Kadoba's [Advanced Tiled Loader](https://github.com/Kadoba/Advanced-Tiled-Loader). 
The majority of the code has been rewritten from the ground up. 
Latest update is found on the master branch.

Supports every known feature except for the following:
* Specifying draw order

Stable release:
[v0.10.2](https://github.com/markandgo/Tidal/releases/tag/v0.10.2)

Please check out the [wiki](https://github.com/markandgo/Tidal/wiki) 
for help.

Example: 

````lua
tidal          = require 'src'
map            = tidal.load('map.tmx')
map.batch_draw = true -- Enable spritebatches (default)

layer = map.layerOrder[1]  -- Get lowest layer
layer.opacity      = 0.5   -- Set layer transparency
layer.ox, layer.oy = 5,5   -- Offset layer by these many pixels
layer.visible      = true  -- Set layer visibility
tile = layer:get(tx,ty)    -- Return tile at tx,ty

gid  = 1
tile = map.tiles[gid]             -- Get tile
print(tile.properties.myproperty) -- Get set property in Tiled

function love.update(dt)
	map:update(dt) -- For animating tiles
end

function love.draw()
	map:draw(x,y)
end
````
