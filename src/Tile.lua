--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2015 Minh Ngo
]]

local MODULE_PATH  = (...):match('^.+[%.\\/]')
local Class        = require(MODULE_PATH .. 'Class')

local draw = love.graphics.drawq or love.graphics.draw

-- -= Tile =-

-- Setup
local Tile = Class 'Tile' {}

-- Creates a new tile and returns it.
function Tile:init(tileset,id,quadOrImage,args)
	args = args or {}

	self.tileset = tileset
	self.id      = id
	self.quad    = quadOrImage:typeOf('Quad') and quadOrImage
	self.image   = quadOrImage:typeOf('Image') and quadOrImage
	
	self.t              = 0
	self.animated       = false
	self.current_frame  = nil
	self.frame_ids      = nil
	self.frame_durations= nil
	
	-- optional
	self.properties = args.properties or {}
	self.terrain    = args.terrain
	self.objects    = args.objects
end

function Tile:getWidth()
	return self.image and self.image:getWidth() or self.tileset.tilewidth
end

function Tile:getHeight()
	return self.image and self.image:getHeight() or self.tileset.tileheight
end

function Tile:update(dt)
	if self.animated then
		self.t = self.t + dt
		if self.t > self.frame_durations[self.current_frame] then 
			self.t = 0
			self.current_frame = self.frame_ids[self.current_frame+1] and
				self.current_frame+1 or 1
		end
	end
end

-- Draws the tile at the given location 
function Tile:draw(...)
	local image,tile = self.image, self
	if self.animated then
		tile = self.tileset.tiles[self.frame_ids[self.current_frame]]
		image= tile.image
	end

	if image then love.graphics.draw(image,...) return end
	draw(tile.tileset.image,tile.quad,...)
end

-- Return the Tile class
return Tile