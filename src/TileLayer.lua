--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2015 Minh Ngo
]]

local MODULE_PATH= (...):match('^.+[%.\\/]')
local Class      = require(MODULE_PATH .. 'Class')
local Grid       = require(MODULE_PATH..'Grid')

-- 0.8 compatibility
local addQuad = 'add'
if love.graphics.drawq then
	addQuad = 'addq'
end

local floor    = math.floor
local min,max  = math.min,math.max

local TileLayer = Grid:extend "TileLayer" {}

function TileLayer:init(map,args)
	local a = args or {}
	
	Grid.init(self)
	
	self.map       = map or error 'Must specify a map as an argument'
	-- OPTIONAL:
	self.name      = a.name or 'Unnamed Layer'
	self.opacity   = a.opacity or 1 
	self.visible   = (a.visible == nil and true) or a.visible
	self.properties= a.properties or {}
	self.ox,self.oy= a.ox or 0, a.oy or 0
	
	-- INIT:
	self._gridflip = Grid:new()
	self._batches  = {}   -- indexed by tileset
	self._redraw   = true -- redraw batches
end

function TileLayer:clear()
	self.cells    = {}
	self._gridflip= {}
	self._batches = {}
end

-- passing nil clears a tile
function TileLayer:setTile(tx,ty,tile,flipbits)
	self:set(tx,ty,tile)
	if tile and flipbits then 
		self._gridflip:set(tx,ty,flipbits)
	else 
		self._gridflip:set(tx,ty,0)
	end
	self._redraw = true
end

-- nil for unchange, true to flip
function TileLayer:flipTile(tx,ty, flipX,flipY)
	local flip = self._gridflip:get(tx,ty) or 0
	
	if flipX then 
		local xbit= floor(flip / 4) % 2
		flip      = flip + (xbit== 1 and -4 or 4)
	end
	if flipY then 
		local ybit= floor(flip / 2) % 2
		flip      = flip + (ybit== 1 and -2 or 2)
	end
	
	self._gridflip:set(tx,ty, flip)
	self._redraw = true
	return flip
end

-- rotate 90 degrees
-- Can specify amount of rotation (1x,2x,3x,...)
function TileLayer:rotateTile(tx,ty,amount)
	local flip = self._gridflip:get(tx,ty) or 0
	
	for i = 1,amount or 1 do
		-- Amazing hack
		if flip == 0 then flip = 5
		elseif flip == 1 then flip = 4 
		elseif flip == 2 then flip = 1
		elseif flip == 3 then flip = 0 
		elseif flip == 4 then flip = 7
		elseif flip == 5 then flip = 6
		elseif flip == 6 then flip = 3
		elseif flip == 7 then flip = 2 
		end
	end
	
	self._gridflip:set(tx,ty, flip)
	self._redraw = true
	return flip
end

-- Reset tile orientation
function TileLayer:resetTileOrientation(tx,ty)
	self._gridflip:set(tx,ty,0)
	self._redraw = true
end

function TileLayer:_getTileIterator()
	local tw,th = self.map.tilewidth, self.map.tileheight
	local tile_iterator
	
	if self.map._drawrange then
		local vx,vy,vx2,vy2 = unpack(self.map._drawrange)
		-- apply drawing offsets
		vx,vy  = vx - self.ox, vy - self.oy
		vx2,vy2= vx2 - self.ox, vy2 - self.oy
		
		if self.map.orientation == 'orthogonal' then
			local gx,gy,gx2,gy2 = floor( vx / tw ), floor( vy / th ),
				floor( vx2 / tw ), floor( vy2 / th )
			
			gx,gy,gx2,gy2 = 
				max(0,gx),
				max(0,gy),
				min(gx2, self.map.width),
				min(gy2, self.map.height)
			
			tile_iterator = self:rectangle(gx,gy,gx2,gy2, true)
		
		elseif self.map.orientation == 'isometric' then
			
			tile_iterator = self:isoRectangle(vx,vy, vx2,vy2)
			
		elseif self.map.orientation == 'staggered' then
			local gx,gy,gx2,gy2 = floor( vx / tw ), floor( vy / th ) * 2,
				floor( vx2 / tw ), floor( vy2 / th ) * 2
			
			gx,gy,gx2,gy2 = 
				max(0,gx),
				max(0,gy),
				min(gx2, self.map.width),
				min(gy2, self.map.height)
			
			tile_iterator = self:rectangle(gx,gy, gx2,gy2, true)
		end
	else
		tile_iterator = self:rectangle(0,0, self.map.width-1, self.map.height-1, true)
	end
	
	return tile_iterator
end

function TileLayer:_getDrawParameters(tx,ty,tile)
	local qw,qh
	if tile.image then
		qw,qh  = tile.image:getWidth(),tile.image:getHeight()
	else
		qw,qh  = tile.tileset.tilewidth, tile.tileset.tileheight
	end
		
	local flipbits= self._gridflip:get(tx,ty) or 0
	local flipX   = floor(flipbits / 4) == 1       
	local flipY   = floor( (flipbits % 4) / 2) == 1
	local flipDiag= flipbits % 2 == 1
	
	local x,y
	
	-- offsets to rotate about center
	local ox,oy = qw/2,qh/2
	
	-- offsets to align to top left again
	local dx,dy = ox,oy
	
	local sx,sy = flipX and -1 or 1, flipY and -1 or 1
	local angle = 0
	if flipDiag then
		angle = math.pi/2
		sx,sy = sy, sx*-1
		
		-- rotated tile has switched dimensions
		dx,dy = dy,dx
		
		-- extra offset to align to bottom like Tiled
		dy    = dy - (qw - self.map.tileheight)
	else
		dy    = dy - (qh - self.map.tileheight)
	end
	
	if self.map.orientation == 'orthogonal' then

		x,y   = tx * self.map.tilewidth,
				  ty * self.map.tileheight
		
	elseif self.map.orientation == 'isometric' then
		x,y = self.map:fromIso(tx,ty)
		
		-- apex of tile (0,0) is point (0,0)
		x   = x - (self.map.tilewidth/2)
	elseif self.map.orientation == 'staggered' then
		local offset  = ty % 2
		local xoffset = (offset*0.5*self.map.tilewidth)
		x             = tx * self.map.tilewidth + xoffset
		y             = ty * self.map.tileheight*0.5
	end
	
	return x,y, dx,dy, angle, sx,sy, ox,oy
end

function TileLayer:draw(x,y)
	if not self.visible then return end
	
	x,y = x or 0,y or 0
	local map = self.map
	local unbind
	
	local r,g,b,a = love.graphics.getColor()
	love.graphics.setColor(r,g,b,self.opacity*a)
	
	if map.batch_draw then
		if self._redraw then
		
			self._redraw= false
			unbind      = true
			
			local tile_iterator = self:_getTileIterator()
					
			for _,batch in pairs(self._batches) do
				batch:bind()
				batch:clear()
			end
			
			for tx,ty,tile in tile_iterator do
			
				local batch  = self._batches[tile.tileset]
				local tileset= tile.tileset
				
				-- make batch if it doesn't exist
				if not self._batches[tileset] then
					assert(tileset.image, 'Unable to batch draw. One or more tileset contains an image collection.')
					local size   = map.width * map.height
					batch        = love.graphics.newSpriteBatch(tile.tileset.image,size)
					
					self._batches[tileset] = batch
					batch:bind()
				end
				
				local x2,y2,dx,dy,angle,sx,sy,ox2,oy2 = self:_getDrawParameters(tx,ty,tile)
				
				batch[addQuad](batch, tile.quad, x2+dx,y2+dy, angle, sx,sy, ox2,oy2)
					
			end		
	
		end
		
		for tileset,batch in pairs(self._batches) do
			if unbind then batch:unbind() end
		
			love.graphics.draw(batch, x,y, nil,nil,nil, 
				-self.ox-tileset.offsetX, -self.oy-tileset.offsetY)
		end
	else
		if next(self._batches) then
			self._batches = {}
		end
	
		love.graphics.push()
		love.graphics.translate(x+self.ox,y+self.oy)
		
		local tile_iterator = self:_getTileIterator()
		for tx,ty,tile in tile_iterator do
			local x2,y2,dx,dy,angle,sx,sy,ox2,oy2 = self:_getDrawParameters(tx,ty,tile)			
			tile:draw(x2+dx+tile.tileset.offsetY,y2+dy+tile.tileset.offsetY, 
				angle, sx,sy, ox2,oy2)
		end
		
		love.graphics.pop()
	end
	love.graphics.setColor(r,g,b,a)
end

function TileLayer:isoRectangle(vx,vy,vx2,vy2)
	-- http://gamedev.stackexchange.com/questions/25896/how-do-i-find-which-isometric-tiles-are-inside-the-cameras-current-view

	local map    = self.map
	local mw,mh  = map.width,map.height
	
	local ix,iy  = map:toIso(vx,vy)
	local ix2,iy2= map:toIso(vx2,vy2)
	
	ix,iy,ix2,iy2= floor(ix),floor(iy),floor(ix2),floor(iy2)	
	
	-- all tiles on the same row have equal sums (x+y)
	-- all tiles on the same column have equal diff (x-y)
	local x1 = 0-(mh-1)
	local y1 = 0
	local x2 = mw-1
	local y2 = (mw+mh)-2
	
	x1,y1,x2,y2 =
		max(x1,ix-iy),
		max(y1,ix+iy),
		min(x2,ix2-iy2),
		min(y2,ix2+iy2)

	local xi,yi = x1-1,y1
		
	return function()
		while true do
			xi = xi+1
			if yi > y2 then return end
			if xi > x2 then 
				yi = yi + 1; xi = x1-1
			else

				-- equation obtained from solving
				-- y = tx + ty
				-- x = tx - ty
				local tx,ty = (yi  + xi)*0.5,
					(yi  - xi)*0.5
				
				local tile = Grid.get(self,tx,ty)
				if tile then
					return tx,ty,tile
				end
				
			end
		end
	end
end

return TileLayer