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
TILED_LOADER_PATH= TILED_LOADER_PATH or (...):match('^.+[%.\\/]')
local Class      = require(TILED_LOADER_PATH..'Class')
local Tile       = require(TILED_LOADER_PATH..'Tile')

local TileSet    = Class "TileSet" {}
TileSet.__call   = function(self,id)
	return self.tiles[id]
end
----------------------------------------------------------------------------------------------------
-- Creates a new tileset.
function TileSet:init(args)
	local a = args
	
	self.firstgid   = a.firstgid
	self.tilewidth  = a.tilewidth
	self.tileheight = a.tileheight
	self.image      = a.image
	self.imagesource= a.imagesource
	self.trans      = a.trans -- hexadecimal string "aabbcc"
	-- OPTIONAL:
	self.name       = a.name or 'Unnamed TileSet'
	self.spacing    = a.spacing or 0
	self.margin     = a.margin or 0
	self.offsetX    = a.offsetX or 0
	self.offsetY    = a.offsetY or 0
	self.tiles      = a.tiles -- indexed by local id
	self.properties = a.properties or {}
	
	if not self.tiles and self.image then self.tiles = TileSet.makeTiles(self) end
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
