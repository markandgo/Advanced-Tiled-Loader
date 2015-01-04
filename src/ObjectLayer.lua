--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2015 Minh Ngo
]]


-- -= ObjectLayer =-

-- Setup
local MODULE_PATH  = (...):match('^.+[%.\\/]')
local Class        = require(MODULE_PATH .. 'Class')
local Object       = require( MODULE_PATH .. "Object")

local grey         = {128,128,128,255}

local ObjectLayer  = Class "ObjectLayer" {}

-- Creates and returns a new ObjectLayer
function ObjectLayer:init(map,args)
	local a = args or {}
	
	self.map        = map or error 'Must specify a map as an argument'
	
	-- OPTIONAL:
	self.name       = a.name or 'Unnamed ObjectLayer'
	self.color      = a.color or grey
	self.opacity    = a.opacity or 1
	self.properties = a.properties or {}
	self.visible    = (a.visible== nil and true) or a.visible
	self.linewidth  = a.linewidth or 2
	self.ox,self.oy = a.ox or 0, a.oy or 0
	
	-- INIT:
	self.objects    = {}
	self._drawlist  = {}
	self._redraw    = true
end

function ObjectLayer:addObject(object,position)
	if object.layer then
		object.layer:removeObject(object)
	end

	table.insert(self.objects, position or #self.objects+1, object) 
   self._redraw = true
   object.layer = self
end

function ObjectLayer:removeObject(object)
	for k,an_object in pairs(self.objects) do
		if an_object == object then
			table.remove(self.objects,k)
			object.layer = nil
			self._redraw = true
			return object
		end
	end
end

function ObjectLayer:newObject(x,y,gid,args,position)
	local object = Object(self,x,y,gid,args)
	self:addObject(object,position)
	return object
end

local function sort_cb(obj1,obj2)
	return obj1._bbox[4] < obj2._bbox[4]
end

function ObjectLayer:depthSort()
	table.sort(self._drawlist,sort_cb)
end

-- Draws the object layer. The way the objects are drawn depends on the map orientation and
-- if the object has an associated tile. It tries to draw the objects as closely to the way
-- Tiled does it as possible.
function ObjectLayer:draw(x,y)
	if not self.visible then return end
		
	x,y = x or 0,y or 0
	local map= self.map
	local ox = self.ox
	local oy = self.oy
	
	if self._redraw then
		self._redraw = false
		
		local add_all = not map._drawrange
		local vx,vy,vx2,vy2
		if map._drawrange then
			vx,vy,vx2,vy2 = unpack(map._drawrange)
			vx,vy  = vx - ox, vy - oy
			vx2,vy2= vx2 - ox, vy2 - oy
		end	
		
		local new_drawlist = {}
		for i,object in ipairs(self.objects) do
			local x,y,x2,y2 = unpack(object._bbox)
			
			if add_all or (vx < x2 and vx2 > x and vy < y2 and vy2 > y) then
				table.insert(new_drawlist,object)
			end
		end
		self._drawlist = new_drawlist
		self:depthSort()
	end
	
	love.graphics.push()
	love.graphics.translate(x+ox,y+oy)
	local old_width = love.graphics.getLineWidth()
	
	love.graphics.setLineWidth(self.linewidth)
	
	local r,g,b,a = love.graphics.getColor()
	local color   = self.color
	local new_a   = self.opacity*a
	love.graphics.setColor(color[1],color[2],color[3],new_a)
	
	for _,object in ipairs(self._drawlist) do
		if object.gid then
			love.graphics.setColor(r,g,b,new_a)
			object:draw()
			love.graphics.setColor(color[1],color[2],color[3],new_a)
		else
			object:draw()
		end
	end
	
	love.graphics.setLineWidth(old_width)
	love.graphics.setColor(r,g,b,a)
	love.graphics.pop()
end

-- Return the ObjectLayer class
return ObjectLayer