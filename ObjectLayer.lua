---------------------------------------------------------------------------------------------------
-- -= ObjectLayer =-
---------------------------------------------------------------------------------------------------
-- Setup
TILED_LOADER_PATH = TILED_LOADER_PATH or ({...})[1]:gsub("[%.\\/][Oo]bject[Ll]ayer$", "") .. '.'
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
		
		parallaxX  = a.parallaxX or 1,
		parallaxY  = a.parallaxY or 1,
		offsetX    = a.offsetX or 0,
		offsetY    = a.offsetY or 0,
		
		objects    = {},
		objectOrder= {},
      
   }, ObjectLayer)
    
   return layer
end

---------------------------------------------------------------------------------------------------
-- Creates a new object, automatically inserts it into the layer, and then returns it
function ObjectLayer:newObject(args, position)
	args.name   = args.name or 'Object '..(#self.objectOrder + 1)
	local object= Object:new(args)
	object.layer= self
   if self.objects[object.name] then 
      error(  string.format("An object named \"%s\" already exists.", object.name) )   
   end
   self.objects[object.name] = object
   table.insert(self.objectOrder, position or #self.objectOrder+1, object) 
   return object
end

---------------------------------------------------------------------------------------------------
-- Draws the object layer. The way the objects are drawn depends on the map orientation and
-- if the object has an associated tile. It tries to draw the objects as closely to the way
-- Tiled does it as possible.
function ObjectLayer:draw(x,y)
	if not self.visible then return end

	x = (x or 0) * self.parallaxX + self.offsetX
	y = (y or 0) * self.parallaxY + self.offsetY
	
	love.graphics.push()
	love.graphics.translate(x,y)
	local old_width = love.graphics.getLineWidth()
	
	love.graphics.setLineWidth(2)
	
	local r,g,b,a = love.graphics.getColor()
	local color   = self.color
	love.graphics.setColor(color[1],color[2],color[3],self.opacity*255)
	
	for _,object in ipairs(self.objectOrder) do
		if object.gid then
			love.graphics.setColor(255,255,255,a)
			object:draw()
			love.graphics.setColor(color[1],color[2],color[3],self.opacity*255)
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