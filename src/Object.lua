--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2015 Minh Ngo
]]

local MODULE_PATH= (...):match('^.+[%.\\/]')
local Class      = require(MODULE_PATH .. 'Class')

local rotate = function(x,y, angle)
	local xnew = x*math.cos(angle) - y*math.sin(angle)
	local ynew = x*math.sin(angle) + y*math.cos(angle)
	return xnew,ynew
end

-- -= Object =-

-- Setup
local Object = Class "Object" {}


-- Returns a new Object
function Object:init(layer,x,y,gid,args)
	local a = args or {}
	
	self.x         = x
	self.y         = y
	self.layer     = layer
	self.gid       = gid
	
	
	-- OPTIONAL:
	self.polygon   = a.polygon
	self.polyline  = a.polyline
	self.ellipse   = a.ellipse -- boolean
	
	self.name      = a.name or ''
	self.type      = a.type or ''
	
	self.drawmode  = a.drawmode or 'line'
	self.width     = a.width
	self.height    = a.height
	self.visible   = (a.visible == nil and true) or a.visible
	self.rotation  = a.rotation or 0 -- in degrees
	self.properties= a.properties or {}
	self.flipbits  = a.flipbits or 0
	self.draw_bbox = a.draw_bbox or false
	
	-- INIT:
	
	self._bbox     = {0,0,0,0}
	
	if self.layer then Object.updateAABB(self) end
end


function Object:updateAABB()
	local map   = self.layer.map
	local th    = map.tileheight
	
	local x,y      = self.x,self.y
	local isIso    = map.orientation == 'isometric'
	local points   = self.polyline or self.polygon
	local top,left,right,bot

	if isIso then
		x,y = x/th,y/th
		x,y = map:fromIso(x,y)
	end
	
	if points then
		for i = 1,#points,2 do
			local px,py = points[i] , points[i+1]
			if isIso then px,py = map:fromIso( px / th, py / th ) end
			
			if self.rotation then
				px,py = rotate(px,py,math.rad(self.rotation))
			end
			
			px,py       = px + x, py + y
			left,right  = math.min(left or px,px), math.max(right or px,px)
			top,bot     = math.min(top or py,py),  math.max(bot or py,py)
		end
	else 
		local x0,y0,x1,y1,x2,y2,x3,y3 = 0,0
		local w,h = self.width or 0, self.height or 0
		
		if self.gid then
			local tile = self.layer.map.tiles[self.gid]
			w,h = tile:getWidth(), tile:getHeight()
		
			-- Note that the bottom center is the origin for iso images
			if isIso then
				x0,y0 = -w/2,0
				x1,y1 = w/2,0
				x2,y2 = w/2,-h
				x3,y3 = -w/2,-h
			else
				x1,y1 = w,0
				x2,y2 = w,-h
				x3,y3 = 0,-h
			end
			
		elseif isIso then 
--[[
      0,0
       /\
      /  \
x3,y3/    \x1,y1
     \    /
      \  /
       \/x2,y2
]]
		
			w,h  = w/th, h/th
			x1,y1 = map:fromIso(w,0)
			x2,y2 = map:fromIso(w,h)
			x3,y3 = map:fromIso(0,h)
			
		else
			x1,y1 = w,0
			x2,y2 = w,h
			x3,y3 = 0,h
		end
		
		if self.rotation ~= 0 then
			local angle_rad = math.rad(self.rotation)
			
			x0,y0 = rotate(x0,y0, angle_rad)
			x1,y1 = rotate(x1,y1, angle_rad)
			x2,y2 = rotate(x2,y2, angle_rad)
			x3,y3 = rotate(x3,y3, angle_rad)
		end
		
		left,right = math.min(x0+x, x1+x, x2+x, x3+x), math.max(x0+x, x1+x, x2+x, x3+x)
		top,bot    = math.min(y0+y, y1+y, y2+y, y3+y), math.max(y0+y, y1+y, y2+y, y3+y)
	end
	
	local bb = self._bbox
	bb[1],bb[2],bb[3],bb[4] = left,top,right,bot
end

-- Draw the object.
local h_to_diag = 1 / 2^.5
local octant    = math.pi / 4
function Object:draw()

   if not self.visible then return end
	
	local map   = self.layer.map
	local tw,th = map.tilewidth, map.tileheight
	
	local x,y   = self.x,self.y
	local isIso = map.orientation == 'isometric'
	local points= self.polyline or self.polygon
	
	love.graphics.push()
	
	if isIso then
		x,y = map:fromIso(x/th,y/th)
	end
	
	love.graphics.translate(x,y)
	love.graphics.rotate(math.rad(self.rotation))
	
	
	if isIso and not self.gid then
--[[
	length of tile diagonal in isometric coordinates: 
		sqrt(th*th + th*th) = sqrt(2) * th = a
	x is the scale factor for diagonal to equal tileheight:
		a * x = th
		x     = sqrt(2) / 2
	y is the scale factor for the diagonal to equal tilewidth:
		a * y = tw
		y     = tw/a = tw/(th *sqrt(2)) = tw/th * x
	
		  th
		-------
		|*    |
		|  *  | th
		|    *|
		-------
]]
		
		local w_ratio   = tw/th

		love.graphics.scale(h_to_diag*w_ratio,h_to_diag)
		love.graphics.rotate(octant)
	end
	
	-- The object is a polyline.
	if self.polyline then
		
		love.graphics.line( points )
	  
	-- The object is a polygon.
	elseif self.polygon then
		
		love.graphics.polygon( self.drawmode, points ) 
	  
	-- The object is a tile object. Draw the tile.
	elseif self.gid then
		local tile   = map.tiles[self.gid]
		local tileset= tile.tileset
		
		local flipX = math.floor(self.flipbits / 4) == 1       
		local flipY = math.floor( (self.flipbits % 4) / 2) == 1
		local ox,oy = 0,0
		local dx,dy = 0,0
		local sx,sy = 1,1
		
		if (flipX or flipY) then
			ox,oy = tile:getWidth()/2,tile:getHeight()/2
			sx,sy = flipX and -1 or 1, flipY and -1 or 1
			dx,dy = ox,oy
		end
		
		-- align bottom center (iso) / left (ortho)
		tile:draw((isIso and 0.5 or 0) * -tile:getWidth() + dx,-tile:getHeight() + dy, nil, sx,sy, ox,oy)
	elseif self.ellipse then
		local w,h= self.width,self.height
		local r  = w/2
		-- stretch circle vertically
		love.graphics.scale(1,h/w)
		love.graphics.circle(self.drawmode, r,r, r)
	else
		local w,h= self.width,self.height
		love.graphics.rectangle(self.drawmode, 0,0, w or 0,h or 0)
	end
	
	love.graphics.pop()
	
	if self.draw_bbox then
		local bx,by,bx2,by2 = unpack(self._bbox)
		love.graphics.rectangle('line',bx,by,bx2-bx,by2-by)
	end
end


-- Returns the Object class
return Object