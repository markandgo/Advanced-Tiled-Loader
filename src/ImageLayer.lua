--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2011-2012 Casey Baxter
Copyright (c) 2013-2014 Minh Ngo
]]

local MODULE_PATH= (...):match('^.+[%.\\/]')
local Class      = require(MODULE_PATH .. 'Class')
local ImageLayer = Class "ImageLayer" {}
---------------------------------------------------------------------------------------------------
function ImageLayer:init(map,image,args)
	local a = args or {}
	
	self.map        = map or error 'Must specify a map as an argument'
	self.image      = image or error 'Must specify an image as an argument'
	-- OPTIONAL:
	self.name       = a.name or 'Unnamed Layer'
	self.opacity    = a.opacity or 1 
	self.visible    = (a.visible== nil and true) or a.visible
	self.properties = a.properties or {}
	self.imagesource= a.imagesource
	self.parallaxX  = a.parallaxX or 1 -- 1 is normal speed
	self.parallaxY  = a.parallaxY or 1 -- 1 is normal speed
	self.offsetX    = a.offsetX or 0   -- x offset added to map position
	self.offsetY    = a.offsetY or 0   -- y offset added to map position
end
---------------------------------------------------------------------------------------------------
function ImageLayer:draw(x,y)
	if not self.visible then return end
	
	local map = self.map
	
	-- origin offset
	local ox = (map.ox * self.parallaxX) - map.ox - self.offsetX
	local oy = (map.oy * self.parallaxY) - map.oy - self.offsetY
	
	local r,g,b,a = love.graphics.getColor()
	love.graphics.setColor(r,g,b,self.opacity*a)	
	love.graphics.draw(self.image, x,y, nil,nil,nil, ox, oy)
	love.graphics.setColor(r,g,b,a)
end
---------------------------------------------------------------------------------------------------
return ImageLayer