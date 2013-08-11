TILED_LOADER_PATH= TILED_LOADER_PATH or (...):match('^.+[%.\\/]') or ''
local Tile       = require(TILED_LOADER_PATH..'Tile')
local TileSet    = require(TILED_LOADER_PATH..'TileSet')
local TileLayer  = require(TILED_LOADER_PATH..'TileLayer')
local ObjectLayer= require(TILED_LOADER_PATH..'ObjectLayer')

local floor = math.floor

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
		
		x          = a.x or 0, -- draw location
		y          = a.y or 0,
		ox         = a.ox or 0, -- origin offset, affects parallax
		oy         = a.oy or 0,
		
		properties = a.properties or {},
		__drawrange= nil, -- {x,y,x2,y2} no drawrange means draw everything
		
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
	args.map   = self
	local layer= TileLayer:new(args)
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
	args.map   = self
	local layer= ObjectLayer:new(args)
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
function Map:draw()
	self:callback('draw')
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
-- dx,dy is the map translation from its origin (in local coordinates)
-- scale: scale of map
local getWindow = love.graphics.getMode or love.window.getMode
function Map:autoDrawRange(dx,dy, scale, padding)
	local w,h    = getWindow()
	dx,dy        = -(dx or 0),-(dy or 0)
	scale,padding= scale or 1, padding or 30
	-- bigger scale --> make things smaller
	scale        = 1/scale
	padding      = padding * scale
	
	self:setDrawRange(
		dx - padding,
		dy - padding,
		dx + w * scale + padding,
		dy + h * scale + padding)
end
---------------------------------------------------------------------------------------------------
return Map