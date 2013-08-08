TILED_LOADER_PATH= TILED_LOADER_PATH or (...):match('^.+[%.\\/]') or ''
local Grid       = require(TILED_LOADER_PATH..'Grid')
local TileLayer  = setmetatable( {class= "TileLayer"}, {__index = Grid})
TileLayer.__index= TileLayer
TileLayer.__call = function(self,x,y) return Grid.get(self,x,y) end

local addQuad = 'addq'
if love.graphics.newGeometry then
	addQuad = 'add'
end

local bitoffset = 2^16
local floor = math.floor

---------------------------------------------------------------------------------------------------
function TileLayer:new(args)
	local a = args
	local tilelayer = {
		map       = a.map or error 'Must specify a map as an argument',
		
		name      = a.name or 'Unnamed Layer',
		opacity   = a.opacity or 1, 
		visible   = (a.visible == nil and true) or a.visible,
		properties= a.properties or {},
		
		parallaxX = a.parallaxX or 1, -- scale x argument for layer:draw(x,y)
		parallaxY = a.parallaxY or 1, -- scale y argument for layer:draw(x,y)
		offsetX   = a.offsetX or 0,   -- x offset is added to x position
		offsetY   = a.offsetY or 0,   -- y offset is added to y position
		
		cells     = {},
		_gridflip = Grid:new(),
		
		_batches  = {}, -- indexed by tileset
		_redraw   = true,
	}
	return setmetatable(tilelayer,TileLayer)
end
---------------------------------------------------------------------------------------------------
function TileLayer:clear()
	self.cells    = {}
	self._gridflip= {}
	self._batches = {}
	self._batchid = {}
end
---------------------------------------------------------------------------------------------------
-- store y coordinate as 16 bits for redraw
-- passing nil clears a tile
function TileLayer:setTile(tx,ty,tile,flipbits)
	self:set(tx,ty,tile)
	if flipbits then self._gridflip:set(tx,ty,flipbits) end
	self._redraw = true
end
---------------------------------------------------------------------------------------------------
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
end
---------------------------------------------------------------------------------------------------
-- rotate 90 degrees
function TileLayer:rotateTile(tx,ty)
	local flip = self._gridflip:get(tx,ty) or 0
	
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
	
	self._gridflip:set(tx,ty, flip)
	self._redraw = true
end
---------------------------------------------------------------------------------------------------
function TileLayer:draw(x,y)
	if not self.visible then return end
	
	local map = self.map
	local unbind
	
	x = (x or 0) * self.parallaxX + self.offsetX
	y = (y or 0) * self.parallaxY + self.offsetY
	local r,g,b,a = love.graphics.getColor()
	love.graphics.setColor(r,g,b,self.opacity*255)
	
	if self._redraw then
	
		local tw,th = map.tilewidth,map.tileheight
		self._redraw= false
		unbind      = true
		
		local tile_iterator
		
		if map.drawrange then
			local vx,vy,vx2,vy2 = unpack(map.drawrange)
			-- apply drawing offsets
			vx,vy  = vx - x, vy - y
			vx2,vy2= vx2 - x, vy2 -y
			
			if map.orientation == 'orthogonal' then
				local gx,gy,gx2,gy2 = floor( vx / tw ), floor( vy / th ),
					floor( vx2 / tw ), floor( vy2 / th )
				
				tile_iterator = self:rectangle(gx,gy,gx2,gy2, true)
			
			elseif map.orientation == 'isometric' then
				
				tile_iterator = self:isoRectangle(vx,vy, vx2,vy2)
				
			elseif map.orientation == 'staggered' then
				local gx,gy,gx2,gy2 = floor( vx / tw ), floor( vy / th ) * 2,
					floor( vx2 / tw ), floor( vy2 / th ) * 2
				
				tile_iterator = self:rectangle(gx,gy, gx2,gy2, true)
			end
		else
			tile_iterator = self:rectangle(0,0,map.width-1,map.height-1,true)
		end
		
		for _,batch in pairs(self._batches) do
			batch:bind()
			batch:clear()
		end
		
		
		for tx,ty,tile in tile_iterator do
		
			local batch  = self._batches[tile.tileset]
			local tileset= tile.tileset
			
			-- make batch if it doesn't exist
			if not self._batches[tileset] then
				local size   = map.width * map.height
				batch        = love.graphics.newSpriteBatch(tile.image,size)
				
				self._batches[tileset] = batch
				batch:bind()
			end
			
			local qw,qh  = tileset.tilewidth , tileset.tileheight
				
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
				dy    = dy - (qw - map.tileheight)
			else
				dy    = dy - (qh - map.tileheight)
			end
			
			if map.orientation == 'orthogonal' then
		
				x,y   = tx * map.tilewidth,
						  ty * map.tileheight
				
			elseif map.orientation == 'isometric' then
				x,y = map:fromIso(tx,ty)
				
				-- apex of tile (0,0) is point (0,0)
				x   = x - (map.tilewidth/2)
			elseif map.orientation == 'staggered' then
				local y_is_odd= ty % 2 ~= 0
				local xoffset = (y_is_odd and map.tilewidth*0.5 or 0)
				x             = tx * map.tilewidth + xoffset
				y             = ty * map.tileheight*0.5
			end
			
			batch[addQuad](batch, tile.quad, x+dx,y+dy, angle, sx,sy, ox,oy)
				
		end		

	end
			
		
	for tileset,batch in pairs(self._batches) do
		if unbind then batch:unbind() end
	
		love.graphics.draw(batch, x+tileset.offsetX, y+tileset.offsetY)
	end
	love.graphics.setColor(r,g,b,a)
end
---------------------------------------------------------------------------------------------------
function TileLayer:isoRectangle(vx,vy,vx2,vy2)
	local map    = self.map
	local ix,iy  = map:toIso(vx,vy)
	local ix2,iy2= map:toIso(vx2,vy2)
	ix,iy,ix2,iy2= floor(ix),floor(iy),floor(ix2),floor(iy2)	
		
	-- convert to staggered
	local x,y  = map:isoToStag(ix,iy)
	local x2,y2= map:isoToStag(ix2,iy2)

	local xi,yi = x-1,y
	return function()
		while true do
			xi = xi+1
			if xi > x2 then yi = yi + 1; xi = x end
			if yi > y2 then return end
			local ix,iy = map:stagToIso(xi,yi)
			local tile = Grid.get(self,ix,iy)
			if tile then
				return ix,iy,tile
			end
		end
	end
end
---------------------------------------------------------------------------------------------------
return TileLayer