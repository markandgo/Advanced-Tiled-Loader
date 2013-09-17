--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2011-2012 Casey Baxter
Copyright (c) 2013 Minh Ngo
]]

TILED_LOADER_PATH= TILED_LOADER_PATH or (...):match('^.+[%.\\/]') or ''
local Tile       = require(TILED_LOADER_PATH..'Tile')
local TileSet    = require(TILED_LOADER_PATH..'TileSet')
local TileLayer  = require(TILED_LOADER_PATH..'TileLayer')
local ObjectLayer= require(TILED_LOADER_PATH..'ObjectLayer')

local Map   = {class= "Map"}
Map.__index = Map
Map.__call  = function(self, layername) return self.layers[layername] end
---------------------------------------------------------------------------------------------------
function Map:new(args)
	local a = args
	return setmetatable({
	
		width      = a.width,
		height     = a.height,
		tilewidth  = a.tilewidth,
		tileheight = a.tileheight,
		
		orientation= a.orientation or 'orthogonal',
		layers     = a.layers or {}, -- indexed by name
		tilesets   = a.tilesets or {}, -- indexed by name
		layerOrder = a.layerOrder or {}, -- indexed by draw order
		tiles      = a.tiles or {}, -- indexed by gid
		
		properties = a.properties or {},
		
	},Map)
end
---------------------------------------------------------------------------------------------------
function Map:newTileSet(args)
	local tileset= TileSet:new(args)
	local name   = tileset.name
	if self.tilesets[name] then 
	  error(  string.format("Map:newTileSet - A tile set named \"%s\" already exists.", name) )
	end
	self.tilesets[name] = tileset
	for _,tile in ipairs(tileset.tiles) do
		self.tiles[tile.gid] = tile
	end
	return tileset
end
---------------------------------------------------------------------------------------------------
function Map:newTileLayer(args,position)
	position   = position or #self.layerOrder+1
	local layer= TileLayer:new(args)
	layer.map  = self
	local name = layer.name
   if self.layers[name] then 
      error( string.format("Map:newTileLayer - A layer named \"%s\" already exists.", name) )
   end
   self.layers[name] = layer
   table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   return layer
end
---------------------------------------------------------------------------------------------------
function Map:newObjectLayer(args, position)
	position   = position or #self.layerOrder+1
	local layer= ObjectLayer:new(args)
	layer.map  = self
	local name = layer.name
   if self.layers[name] then 
      error( string.format("Map:newObjectLayer - A layer named \"%s\" already exists.", name) )
   end
   self.layers[name] = layer
   table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   return layer
end
---------------------------------------------------------------------------------------------------
function Map:newCustomLayer(args, position)
	local layer = {class = 'CustomLayer', map = self}
	for i,v in pairs(args) do
		layer[i] = v
	end
	
	if self.layers[layer.name] then 
      error( string.format("Map:newCustomLayer - A layer named \"%s\" already exists.", name) )
   end
	self.layers[layer.name]= layer
   table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   return layer
end
---------------------------------------------------------------------------------------------------
-- The unit length of a tile on both axes is 1. 
-- Point (0,0) is the apex of tile (0,0).
function Map:fromIso(ix,iy)
	local hw,hh = self.tilewidth/2,self.tileheight/2
	return hw*(ix - iy),hh*(ix + iy)
end
---------------------------------------------------------------------------------------------------
-- Point (0,0) is always at the apex of tile (0,0) pre-parallax.
function Map:toIso(x,y)
	local hw,hh   = self.tilewidth/2,self.tileheight/2
	-- matrix inverse
	local a,b,c,d = hw,-hw,hh,hh
	local det     = 1/(a*d-b*c)
	
	return det * (d * x - b * y), det * (-c * x + a * y)
end
---------------------------------------------------------------------------------------------------
function Map:callback(cb_name, ...)
	local order = self.layerOrder
	for i=1,#order do
		local layer = order[i]
      if layer[cb_name] then layer[cb_name](layer, ...) end
	end
end
---------------------------------------------------------------------------------------------------
function Map:draw(x,y)
	self:callback('draw', x,y)
end
---------------------------------------------------------------------------------------------------
return Map