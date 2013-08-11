---------------------------------------------------------------------------------------------------
-- -= Object =-
---------------------------------------------------------------------------------------------------
-- Setup
local Object = {class = "Object"}
Object.__index = Object

---------------------------------------------------------------------------------------------------

-- Returns a new Object
function Object:new(args)
	local a = args
	local object = setmetatable({
		name      = a.name or '',
		type      = a.type or '',
		
		layer     = a.layer,
		polygon   = a.polygon,
		polyline  = a.polyline,
		ellipse   = a.ellipse, -- boolean
		gid       = a.gid,
		
		drawmode  = a.drawmode or 'line',
		x         = a.x or 0,
		y         = a.y or 0,
		width     = a.width or 0,
		height    = a.height or 0,
		visible   = (a.visible == nil and true) or a.visible,
		properties= a.properties or {},
		
		_bbox     = {0,0,0,0},

	},Object)
	
	object:updateAABB()
	
	return object
end

---------------------------------------------------------------------------------------------------
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
			px,py       = px + x, py + y
			left,right  = math.min(left or px,px), math.max(right or px,px)
			top,bot     = math.min(top or py,py),  math.max(bot or py,py)
		end
	else
		if isIso then 
			local w,h  = self.width/th, self.height/th
			local x1,y1= map:fromIso(w,0)
			local x2,y2= map:fromIso(w,h)
			local x3,y3= map:fromIso(0,h)
			
			left,right = math.min(left or 0,x1,x2,x3) + x, math.max(right or 0,x1,x2,x3) + x
			top,bot    = math.min(top or 0,y1,y2,y3) + y, math.max(bot or 0,y1,y2,y3) + y
		else
			left,top,right,bot = x,y,x+self.width,y+self.height
		end
	end
	
	local bb = self._bbox
	bb[1],bb[2],bb[3],bb[4] = left,top,right,bot
end
---------------------------------------------------------------------------------------------------
function Object:drawAABB()
	local x,y,x2,y2 = unpack(self._bbox)
	love.graphics.rectangle('line',x,y,x2-x,y2-y)
end
---------------------------------------------------------------------------------------------------
-- Draw the object.
function Object:draw()

   if not self.visible then return end
	
	local map   = self.layer.map
	local th    = map.tileheight
	
	local x,y      = self.x,self.y
	local isIso    = map.orientation == 'isometric'
	local points   = self.polyline or self.polygon
	local newpoints= points
	
	
	-- isometric tiles have unit length of one tileheight
	-- have to convert every point to "real" coordinates
	if isIso then
		x,y = x/th,y/th
		x,y = map:fromIso(x,y)
		
		if points then
			newpoints = {}
			for i = 1,#points,2 do
				local x,y = points[i] / th ,points[i+1] / th
				newpoints[i],newpoints[i+1] = map:fromIso(x,y)
			end
		end
	end
	
	love.graphics.push()
	love.graphics.translate(x,y)
	
	-- The object is a polyline.
	if self.polyline then
		
		love.graphics.line( newpoints )
	  
	-- The object is a polygon.
	elseif self.polygon then
		
		love.graphics.polygon( self.drawmode, newpoints ) 
	  
	-- The object is a tile object. Draw the tile.
	elseif self.gid then
		local tile   = map.tiles[self.gid]
		local tileset= tile.tileset
		
		-- align bottom center (iso) / left (ortho)
		tile:draw((isIso and 0.5 or 0) * -tileset.tilewidth,-tileset.tileheight)
	else
		if isIso then 
			local w,h  = self.width/th, self.height/th
			local x1,y1= map:fromIso(w,0)
			local x2,y2= map:fromIso(w,h)
			local x3,y3= map:fromIso(0,h)
			
			love.graphics.polygon(self.drawmode, 0,0, x1,y1, x2,y2, x3,y3)
		else
			love.graphics.rectangle(self.drawmode, 0,0, self.width,self.height )
		end
	end
	
	love.graphics.pop()
end

---------------------------------------------------------------------------------------------------
-- Returns the Object class
return Object