--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2011-2012 Casey Baxter
Copyright (c) 2013 Minh Ngo
]]

TILED_LOADER_PATH  = TILED_LOADER_PATH or (...):match('^.+[%.\\/]')
local Class        = require(TILED_LOADER_PATH .. 'Class')

local draw = love.graphics.newGeometry and love.graphics.draw or love.graphics.drawq
---------------------------------------------------------------------------------------------------
-- -= Tile =-
---------------------------------------------------------------------------------------------------
-- Setup
local Tile = Class 'Tile' {}

-- Creates a new tile and returns it.
function Tile:init(args)
	local a = args
	
	self.gid     = a.gid
	self.quad    = a.quad
	self.tileset = a.tileset
	
	-- optional
	self.properties = a.properties or {}
end

-- Draws the tile at the given location 
function Tile:draw(...)
	draw(self.tileset.image,self.quad,...)
end

-- Return the Tile class
return Tile