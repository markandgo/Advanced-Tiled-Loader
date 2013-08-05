TILED_LOADER_PATH= TILED_LOADER_PATH or (...):match('^.+[%.\\/]') or ''
local Grid       = require(TILED_LOADER_PATH..'Grid')
local TileLayer  = setmetatable( {class= "TileLayer"}, {__index = Grid})
TileLayer.__index= TileLayer
TileLayer.__call = function(self,x,y) return Grid.get(self,x,y) end

local addQuad = 'addq'
local setQuad = 'setq'
if love.graphics.newGeometry then
	addQuad = 'add'
	setQuad = 'set'
end

local bitoffset = 2^16

---------------------------------------------------------------------------------------------------
function TileLayer:new(args)
	local a = args
	local tilelayer = {
		map       = a.map or error 'Must specify a map as an argument',
		
		name      = a.name or 'Unnamed Layer',
		opacity   = a.opacity or 1, 
		visible   = (a.visible == nil and true) or a.visible,
		properties= a.properties or {},
		
		parallaxX = a.parallaxX or 1,
		parallaxY = a.parallaxY or 1,
		offsetX   = a.offsetX or 0,
		offsetY   = a.offsetY or 0,
		
		cells     = {},
		_gridflip = Grid:new(),
		
		_batches  = {}, -- indexed by tileset
		_batchid  = {}, -- indexed by batch then coordinates (ty has 16 bits)
		_redraw   = {}, -- coords of tiles to be redrawn (ty has 16 bits)
	}
	return setmetatable(tilelayer,TileLayer)
end
---------------------------------------------------------------------------------------------------
-- store y coordinate as 16 bits for redraw
function TileLayer:setTile(tx,ty,tile,flipbits)
	self:set(tx,ty,tile)
	if flipbits then self._gridflip:set(tx,ty,flipbits) end
	self._redraw[tx*bitoffset + ty] = true
end
---------------------------------------------------------------------------------------------------
-- nil for unchange, true to flip
function TileLayer:flipTile(tx,ty, flipX,flipY)
	local flip = self._gridflip:get(tx,ty) or 0
	
	if flipX then 
		local xbit= math.floor(flip / 4) % 2
		flip      = flip + (xbit== 1 and -4 or 4)
	end
	if flipY then 
		local ybit= math.floor(flip / 2) % 2
		flip      = flip + (ybit== 1 and -2 or 2)
	end
	
	self._gridflip:set(tx,ty, flip)
	self._redraw[tx*bitoffset + ty] = true
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
	self._redraw[tx*bitoffset + ty] = true
end
---------------------------------------------------------------------------------------------------
function TileLayer:draw(x,y)
	if not self.visible then return end
	
	local unbind
	
	if next(self._redraw) then
		unbind    = true
		local map = self.map
		
		for _,batch in pairs(self._batches) do
			batch:bind()
		end
		
		for coord in pairs(self._redraw) do
		
			local ty = coord % bitoffset
			local tx = (coord - ty) / bitoffset
			
			local tile   = self(tx,ty)
			local batch  = self._batches[tile.tileset]
			local tileset= tile.tileset
			
			-- make batch if it doesn't exist
			if not self._batches[tileset] then
				local size   = map.width * map.height
				batch        = love.graphics.newSpriteBatch(tile.image,size)
				local batchid= {}
				
				self._batches[tileset] = batch
				self._batchid[batch]   = batchid
				
				batch:bind()
				for ty = 0,map.height-1 do
					for tx = 0,map.width-1 do
						batchid[ tx*bitoffset + ty ] = 
							batch[addQuad](batch,tile.quad,0,0,0,0)
					end
				end
			end
			
			local qw,qh  = tileset.tilewidth , tileset.tileheight
			local id     = self._batchid[batch][coord]
				
			local flipbits= self._gridflip:get(tx,ty) or 0
			local flipX   = math.floor(flipbits / 4) == 1       
			local flipY   = math.floor( (flipbits % 4) / 2) == 1
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
			
			batch[setQuad](batch, id, tile.quad, x+dx,y+dy, angle, sx,sy, ox,oy)
			self._redraw[coord] = nil
			
		end
		
	end

	x = (x or 0) * self.parallaxX + self.offsetX
	y = (y or 0) * self.parallaxY + self.offsetY
	local r,g,b,a = love.graphics.getColor()
	love.graphics.setColor(r,g,b,self.opacity*255)
	for tileset,batch in pairs(self._batches) do
		if unbind then batch:unbind() end
	
		love.graphics.draw(batch, x + tileset.offsetX, y + tileset.offsetY)
	end
	love.graphics.setColor(r,g,b,a)
end
---------------------------------------------------------------------------------------------------
return TileLayer