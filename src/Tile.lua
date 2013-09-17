--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2011-2012 Casey Baxter
Copyright (c) 2013 Minh Ngo
]]

---------------------------------------------------------------------------------------------------
-- -= Tile =-
---------------------------------------------------------------------------------------------------

local draw = love.graphics.newGeometry and love.graphics.draw or love.graphics.drawq

-- Setup
local Tile = {class = "Tile"}
Tile.__index = Tile

-- Creates a new tile and returns it.
function Tile:new(args)
	local a = args
	local tile = {
		gid       = a.gid,
		image     = a.image,
		quad      = a.quad,
		tileset   = a.tileset,
		
		-- optional
		properties= a.properties or {},
	}
	return setmetatable(tile,Tile)
end

-- Draws the tile at the given location 
function Tile:draw(...)
	draw(self.image,self.quad,...)
end

-- Return the Tile class
return Tile