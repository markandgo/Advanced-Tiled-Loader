ATL_PATH         = ATL_PATH or (...):match('^.+[%.\\/]') or ''
local Tile       = require(ATL_PATH..'Tile')
local TileSet    = require(ATL_PATH..'TileSet')
local TileLayer  = require(ATL_PATH..'TileLayer')
-- local Object     = require(ATL_PATH..'Object')
-- local ObjectLayer= require(ATL_PATH..'ObjectLayer')

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
-- function Map:newObjectLayer(position, args)
	-- local layer= ObjectLayer:new(self, args)
	-- local name = layer.name
   -- if self.layers[name] then 
      -- error( string.format("Map:newTileLayer - A layer named \"%s\" already exists.", name) )
   -- end
   -- self.layers[name] = layer
   -- table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   -- return layer
-- end
---------------------------------------------------------------------------------------------------
-- function Map:newCustomLayer(name, position, layer)
	-- if self.layers[name] then 
      -- error( string.format("Map:newTileLayer - A layer named \"%s\" already exists.", name) )
   -- end
	-- layer            = layer or {name= name}
	-- layer.class      = 'CustomLayer'
	-- self.layers[name]= layer
   -- table.insert(self.layerOrder, position or #self.layerOrder + 1, layer) 
	
   -- return layer
-- end
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