--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2011-2012 Casey Baxter
Copyright (c) 2013-2014 Minh Ngo
]]

local MODULE_PATH= (...):match('^.+[%.\\/]')
local Class      = require(MODULE_PATH .. 'Class')
local Tile       = require(MODULE_PATH..'Tile')
local TileSet    = require(MODULE_PATH..'TileSet')
local TileLayer  = require(MODULE_PATH..'TileLayer')
local ObjectLayer= require(MODULE_PATH..'ObjectLayer')

local floor = math.floor

-- 0.8/0.9+ compatibility
local getWindow = love.graphics.getMode or love.window.getMode

local Map   = Class "Map" {}
Map.__call  = function(self, layername) return self.layers[layername] end
---------------------------------------------------------------------------------------------------
function Map:init(width,height,tilewidth,tileheight,args)
	local a = args or {}
	
	self.width      = width
	self.height     = height
	self.tilewidth  = tilewidth
	self.tileheight = tileheight
	
	-- OPTIONAL:
	self.orientation= a.orientation or 'orthogonal'
	self.ox         = a.ox or 0 -- parallax origin offset
	self.oy         = a.oy or 0
	self.layers     = a.layers or {} -- indexed by name
	self.tilesets   = a.tilesets or {} -- indexed by name
	self.layerOrder = a.layerOrder or {} -- indexed by draw order
	self.tiles      = a.tiles or {} -- indexed by gid
	self.properties = a.properties or {}
	self._drawrange = nil -- {x,y,x2,y2} no drawrange means draw everything
end
---------------------------------------------------------------------------------------------------
function Map:newTileSet(tilewidth,tileheight,image,firstgid,args)
	local tileset= TileSet:new(tilewidth,tileheight,image,firstgid,args)
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
	local layer= TileLayer:new(self,args)
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
	local layer= ObjectLayer:new(self,args)
	local name = layer.name
   if self.layers[name] then 
      error( string.format("Map:newObjectLayer - A layer named \"%s\" already exists.", name) )
   end
   self.layers[name] = layer
   table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   return layer
end
---------------------------------------------------------------------------------------------------
function Map:newCustomLayer(name, position, layer)
	layer = layer or {name = name, class = 'CustomLayer', map = self}
	if self.layers[name] then 
      error( string.format("Map:newCustomLayer - A layer named \"%s\" already exists.", name) )
   end
	self.layers[name]= layer
   table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   return layer
end
---------------------------------------------------------------------------------------------------
-- The unit length of a tile on both axes is 1. 
-- Point (0,0) is the apex of tile (0,0).
function Map:fromIso(ix,iy)
	local hw,hh = self.tilewidth/2,self.tileheight/2
	-- tiles on the same row have the same sum
	-- tiles on the same column have the same difference
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
	self:callback('draw',x,y)
end
---------------------------------------------------------------------------------------------------
function Map:setDrawRange(x,y,x2,y2)
	-- draw everything
	if not (x and y and x2 and y2) then
		if not self._drawrange then return end
		self._drawrange = nil
	else
		local tw,th = self.tilewidth,self.tileheight
	
		local dr       = self._drawrange or {0,0,0,0}
		self._drawrange= dr
		
		local dx,dy,dx2,dy2    = dr[1],dr[2],dr[3],dr[4]
		dr[1],dr[2],dr[3],dr[4]= x,y,x2,y2
		
		-- skip redraw if draw boxes don't share the same cells
		if floor(dx/tw)  == floor(x/tw)  and floor(dy/th)  == floor(y/th) and  
			floor(dx2/tw) == floor(x2/tw) and floor(dy2/th) == floor(y2/th)
			then
			return
		end
		
	end
	for i,layer in ipairs(self.layerOrder) do
		layer._redraw = true
	end
end
---------------------------------------------------------------------------------------------------
-- cx,cy is the center of the untransformed map coordinates
-- scale: scale of map
function Map:autoDrawRange(cx,cy, scale, padding)
	local w,h    = getWindow()
	local hw,hh  = w/2,h/2
	scale,padding= scale or 1, padding or 50
	-- bigger scale --> make view smaller
	local dw,dh  = (hw+padding) / scale, (hh+padding) / scale
	
	self:setDrawRange(
		cx - dw ,
		cy - dh,
		cx + dw ,
		cy + dh)
end
---------------------------------------------------------------------------------------------------
return Map