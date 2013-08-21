---------------------------------------------------------------------------------------------------
-- -= ObjectLayer =-
---------------------------------------------------------------------------------------------------
-- Setup
TILED_LOADER_PATH  = TILED_LOADER_PATH or (...):match('^.+[%.\\/]') or ''
local Object       = require( TILED_LOADER_PATH .. "Object")
local ObjectLayer  = {class= "ObjectLayer"}
local grey         = {128,128,128,255}
ObjectLayer.__index= ObjectLayer

---------------------------------------------------------------------------------------------------
-- Creates and returns a new ObjectLayer
function ObjectLayer:new(args)
	local a     = args
   local layer = setmetatable({
		map        = a.map or error 'Must specify a map as an argument',
		
		name       = a.name or 'Unnamed ObjectLayer',
		color      = a.color or grey,
		opacity    = a.opacity or 1,
		properties = a.properties or {},
		visible    = (a.visible== nil and true) or a.visible,
		
		parallaxX  = a.parallaxX or 1, -- 1 is normal speed
		parallaxY  = a.parallaxY or 1, -- 1 is normal speed
		offsetX    = a.offsetX or 0,   -- offset added to map position
		offsetY    = a.offsetY or 0,   -- offset added to map position
		linewidth  = a.linewidth or 2,
		
		objects    = {},
		_drawlist  = {},
		_redraw    = true,
      
   }, ObjectLayer)
    
   return layer
end

---------------------------------------------------------------------------------------------------
-- Creates a new object, automatically inserts it into the layer, and then returns it
function ObjectLayer:newObject(args, position)
	args.layer   = self
	local object = Object:new(args)
   table.insert(self.objects, position or #self.objects+1, object) 
   self._redraw = true
   return object
end

---------------------------------------------------------------------------------------------------
-- Draws the object layer. The way the objects are drawn depends on the map orientation and
-- if the object has an associated tile. It tries to draw the objects as closely to the way
-- Tiled does it as possible.
function ObjectLayer:draw()
	if not self.visible then return end
		
	local map= self.map
	
	-- origin offset
	local ox = (map.ox * self.parallaxX) - map.ox - self.offsetX
	local oy = (map.oy * self.parallaxY) - map.oy - self.offsetY
	
	if self._redraw then
		self._redraw = false
		
		local add_all = not map._drawrange
		local vx,vy,vx2,vy2
		if map._drawrange then
			vx,vy,vx2,vy2 = unpack(map._drawrange)
			vx,vy  = vx + ox, vy + oy
			vx2,vy2= vx2 + ox, vy2 + oy
		end	
		
		local new_drawlist = {}
		for i,object in ipairs(self.objects) do
			local x,y,x2,y2 = unpack(object._bbox)
			
			if add_all or (vx < x2 and vx2 > x and vy < y2 and vy2 > y) then
				table.insert(new_drawlist,object)
			end
		end
		self._drawlist = new_drawlist
	end
	
	love.graphics.push()
	love.graphics.translate(-ox,-oy)
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
---------------------------------------------------------------------------------------------------
-- Return the ObjectLayer class
return ObjectLayer