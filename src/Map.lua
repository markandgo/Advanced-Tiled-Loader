--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2015 Minh Ngo
]]

local MODULE_PATH= (...):match('^.+[%.\\/]')
local Class      = require(MODULE_PATH .. 'Class')
local Tile       = require(MODULE_PATH..'Tile')
local TileSet    = require(MODULE_PATH..'TileSet')
local TileLayer  = require(MODULE_PATH..'TileLayer')
local ObjectLayer= require(MODULE_PATH..'ObjectLayer')
local ImageLayer = require(MODULE_PATH..'ImageLayer')

local floor = math.floor
local ERROR_LAYER_NAME = "A layer named \"%s\" already exists."

-- 0.8/0.9+ compatibility
local getWindow = love.graphics.getMode or love.window.getMode

local Map   = Class "Map" {}
Map.__call  = function(self, layername) return self.layers[layername] end

function Map:init(width,height,tilewidth,tileheight,args)
	local a = args or {}
	
	self.width      = width
	self.height     = height
	self.tilewidth  = tilewidth
	self.tileheight = tileheight
	
	-- OPTIONAL:
	self.orientation= a.orientation or 'orthogonal'
	self.layers     = a.layers or {} -- indexed by name
	self.tilesets   = a.tilesets or {} -- indexed by name
	self.layerOrder = a.layerOrder or {} -- indexed by draw order
	self.tiles      = a.tiles or {} -- indexed by gid
	self.properties = a.properties or {}
	self._drawrange = nil -- {x,y,x2,y2} no drawrange means draw everything
	self.batch_draw = a.batch_draw == nil and true or a.batch_draw -- Disable for image collection / tile animation
end

function Map:newTileSet(tilewidth,tileheight,imageOrTable,firstgid,args)
	local tileset= TileSet:new(tilewidth,tileheight,imageOrTable,firstgid,args)
	local name   = tileset.name
	if self.tilesets[name] then 
	  error(  string.format("A tileset named \"%s\" already exists.",name) )
	end
	self.tilesets[name] = tileset
	for _,tile in ipairs(tileset.tiles) do
		self.tiles[tile.gid] = tile
	end
	return tileset
end

function Map:newTileLayer(args,position)
	position   = position or #self.layerOrder+1
	local layer= TileLayer:new(self,args)
	local name = layer.name
   if self.layers[name] then 
      error( string.format(ERROR_LAYER_NAME,name) )
   end
   self.layers[name] = layer
   table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   return layer
end

function Map:newObjectLayer(args, position)
	position   = position or #self.layerOrder+1
	local layer= ObjectLayer:new(self,args)
	local name = layer.name
   if self.layers[name] then 
      error( string.format(ERROR_LAYER_NAME,name) )
   end
   self.layers[name] = layer
   table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   return layer
end

function Map:newImageLayer(image, args, position)
	position   = position or #self.layerOrder+1
	local layer= ImageLayer:new(self,image,args)
	local name = layer.name
   if self.layers[name] then 
      error( string.format(ERROR_LAYER_NAME,name) )
   end
   self.layers[name] = layer
   table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   return layer
end

function Map:newCustomLayer(name, position, layer)
	layer      = layer or {}
	layer.name = name or 'Unnamed Layer'
	layer.map  = self
	layer.class= 'CustomLayer'
	if self.layers[name] then 
      error( string.format(ERROR_LAYER_NAME,name) )
   end
	self.layers[name]= layer
   table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   return layer
end

function Map:removeLayer(nameOrIndex)
	local layer
	if type(nameOrIndex) == 'string' then
		layer = self.layers[nameOrIndex]
		self.layers[nameOrIndex] = nil
		
		for i,a_layer in ipairs(self.layerOrder) do
			if a_layer == layer then
				table.remove(self.layerOrder,i)
				break
			end
		end
	elseif type(nameOrIndex) == 'number' then
		layer = table.remove(self.layerOrder,nameOrIndex)
		self.layers[layer.name] = nil
	else
		error 'Invalid argument. Must be a number or string'
	end
	return layer
end

-- The unit length of a tile on both axes is 1. 
-- Point (0,0) is the apex of tile (0,0).
function Map:fromIso(ix,iy)
	local hw,hh = self.tilewidth/2,self.tileheight/2
	-- tiles on the same row have the same sum
	-- tiles on the same column have the same difference
	return hw*(ix - iy),hh*(ix + iy)
end

-- Point (0,0) is always at the apex of tile (0,0) pre-parallax.
function Map:toIso(x,y)
	local hw,hh   = self.tilewidth/2,self.tileheight/2
	-- matrix inverse
	local a,b,c,d = hw,-hw,hh,hh
	local det     = 1/(a*d-b*c)
	
	return det * (d * x - b * y), det * (-c * x + a * y)
end

function Map:callback(cb_name, ...)
	local order = self.layerOrder
	for i=1,#order do
		local layer = order[i]
      if layer[cb_name] then layer[cb_name](layer, ...) end
	end
end

function Map:update(dt)
	for k,tile in pairs(self.tiles) do
		tile:update(dt)
	end
end

function Map:draw(x,y)
	self:callback('draw',x,y)
end

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
	end
	for i,layer in ipairs(self.layerOrder) do
		layer._redraw = true
	end
end

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

return Map