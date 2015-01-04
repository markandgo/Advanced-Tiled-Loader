--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2015 Minh Ngo
]]


-- -= TileSet =-

-- Setup
local MODULE_PATH= (...):match('^.+[%.\\/]')
local Class      = require(MODULE_PATH..'Class')
local Tile       = require(MODULE_PATH..'Tile')

local TileSet    = Class "TileSet" {}
TileSet.__call   = function(self,id)
	return self.tiles[id]
end

-- Creates a new tileset.
function TileSet:init(tilewidth,tileheight,imageOrTable,firstgid,args)
	local a = args or {}
	
	self.tilewidth  = tilewidth
	self.tileheight = tileheight
	self.image      = type(imageOrTable) ~= 'table' and imageOrTable or nil
	self.firstgid   = firstgid
	-- OPTIONAL:
	self.name       = a.name or 'Unnamed TileSet'
	self.imagesource= a.imagesource
	self.trans      = a.trans -- hexadecimal string "aabbcc"
	self.spacing    = a.spacing or 0
	self.margin     = a.margin or 0
	self.offsetX    = a.offsetX or 0
	self.offsetY    = a.offsetY or 0
	self.properties = a.properties or {}
	
	self.tiles       = {} -- indexed by local id
	self.terraintypes= {} -- index starts at 0
	
	-- INIT:
	if self.image then
		local tiles = self.tiles
		local x,y   = self.margin, self.margin
	   local iw,ih = self.image:getWidth(), self.image:getHeight()
		local tw,th = self.tilewidth,self.tileheight
		local id    = 0
	
		for j = 1, self:rows() do
			for i = 1, self:columns() do
				local quad = love.graphics.newQuad(x,y,tw,th,iw,ih)
				local tile = Tile:new(self,id,quad)
				tiles[id]  = tile
				x  = x + tw + self.spacing
				id = id + 1
			end
			x = self.margin
			y = y + th + self.spacing
		end
	else
		for id,image in pairs(imageOrTable) do
			self.tiles[id] = Tile(self,id,image)
		end
	end
end

function TileSet:columns()
	return math.floor( (self.image:getWidth() - self.margin*2 + self.spacing) /
					(self.tilewidth + self.spacing) )
end

function TileSet:rows()
	return math.floor( (self.image:getHeight() - self.margin*2 + self.spacing) /
					(self.tileheight + self.spacing) )	
end

function TileSet:newTerrain(name,tile_id,properties)
	local terrain_id = #self.terraintypes + (self.terraintypes[0] and 1 or 0)

	table.insert(self.terraintypes,terrain_id,{ name = name, tile = tile_id, properties = properties })
end

-- Return the TileSet class
return TileSet
