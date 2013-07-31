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
		
		directory  = a.directory, -- file path to map
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
	local layer = {class = 'CustomLayer'}
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
function Map:fromIso(ix,iy)
	local tw,th= self.tilewidth,self.tileheight
	local x    = ix*tw/2 - iy*tw/2
	local y    = ix*th/2 + iy*th/2
	return x,y
end
---------------------------------------------------------------------------------------------------
function Map:toIso(x,y)
	local tw,th= self.tilewidth,self.tileheight
	-- matrix inverse
	local a,b,c,d = tw/2,tw/2,th/2,th/2
	local det     = 1/(a*d-b*c)
	local ix,iy   = det * (d * x - b * y), det * (-c * x + a * y)
	return ix,iy
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
	local order = self.layerOrder
	for i = 1,#order do
		order[i]:draw(x,y)
	end
end
---------------------------------------------------------------------------------------------------
return Map