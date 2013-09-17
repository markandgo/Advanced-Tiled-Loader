--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2011-2012 Casey Baxter
Copyright (c) 2013 Minh Ngo
]]

---------------------------------------------------------------------------------------------------
-- -= TileSet =-
---------------------------------------------------------------------------------------------------
-- Setup
TILED_LOADER_PATH= TILED_LOADER_PATH or (...):match('^.+[%.\\/]') or ''
local Tile       = require(TILED_LOADER_PATH..'Tile')
local TileSet    = {class= "TileSet"}
TileSet.__index  = TileSet
TileSet.__call   = function(self,id)
	return self.tiles[id]
end

----------------------------------------------------------------------------------------------------
-- Creates a new tileset.
function TileSet:new(args)
	local a = args
	local tileset = setmetatable({
		firstgid   = a.firstgid,
		tilewidth  = a.tilewidth,
		tileheight = a.tileheight,
		
		image      = a.image,
		imagesource= a.imagesource,
		trans      = a.trans, -- hexadecimal string
		
		tiles      = a.tiles, -- indexed by local id
		
		-- optional
		name       = a.name or 'Unnamed TileSet',
		spacing    = a.spacing or 0,
		margin     = a.margin or 0,
		properties = a.properties or {},
		
		offsetX    = a.offsetX or 0,
		offsetY    = a.offsetY or 0,
		
	},TileSet)
	
	if not tileset.tiles and tileset.image then tileset.tiles = TileSet.makeTiles(tileset) end
	
	return tileset
end
----------------------------------------------------------------------------------------------------
function TileSet:columns()
	return math.floor( (self.image:getWidth() - self.margin*2 + self.spacing) /
					(self.tilewidth + self.spacing) )
end
---------------------------------------------------------------------------------------------------
function TileSet:rows()
	return math.floor( (self.image:getHeight() - self.margin*2 + self.spacing) /
					(self.tileheight + self.spacing) )	
end
---------------------------------------------------------------------------------------------------
-- Produces tiles from the settings and returns them in a table indexed by their id.
-- These are cut out left-to-right, top-to-bottom.
function TileSet:makeTiles()
	local x,y   = self.margin, self.margin
	local tiles = {}
	assert(self.image,'Cannot make tiles without an Image!')
   local iw,ih = self.image:getWidth(), self.image:getHeight()
	local tw,th = self.tilewidth,self.tileheight
	local gid   = self.firstgid
	local id    = 0

	for j = 1, self:rows() do
		for i = 1, self:columns() do
			local quad = love.graphics.newQuad(x,y,tw,th,iw,ih)
			local tile = Tile:new{
				gid    = gid,
				tileset= self,
				image  = self.image,
				quad   = quad,
			}
			tiles[id] = tile
			x  = x + tw + self.spacing
			id = id + 1
			gid= gid + 1
		end
		x = self.margin
		y = y + th + self.spacing
	end

	return tiles
end

----------------------------------------------------------------------------------------------------
-- Return the TileSet class
return TileSet
