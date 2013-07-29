ATL_PATH         = ATL_PATH or (...):match('^.+[%.\\/]') or ''
local Grid       = require(ATL_PATH..'Grid')
local TileLayer  = {class= "TileLayer"}
TileLayer.__index= TileLayer
TileLayer.__call = function(self,x,y) return self._grid:get(x,y) end
local dummyquad  = love.graphics.newQuad(0,0,0,0, 0,0)

local addQuad = 'addq'
local setQuad = 'setq'
if love.graphics.newGeometry then
	addQuad = 'add'
	setQuad = 'set'
end
---------------------------------------------------------------------------------------------------
function TileLayer:new(args)
	local a = args
	local tilelayer = {
		map       = a.map,
		
		name      = a.name or 'Unamed Layer',
		opacity   = a.opacity or 1, 
		visible   = a.visible or 1,			
		parallaxX = a.parallaxX or 1,
		parallaxY = a.parallaxY or 1,
		offsetX   = a.offsetX or 0,
		offsetY   = a.offsetY or 0,
		properties= a.properties or {},
		
		_grid     = Grid:new(),
		_gridflip = Grid:new(),
		-- _tilerange= {0,0,a.map.width-1,a.map.height-1},		
		_batches  = {},
		-- _redraw   = true,
	}
	return setmetatable(tilelayer,TileLayer)
end
---------------------------------------------------------------------------------------------------
function TileLayer:setTile(tx,ty,tile)
	self._grid:set(tx,ty,tile)
	-- self._redraw = true
	self:redrawTile(tx,ty)
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
	
	-- self._redraw = true
	self:redrawTile(tx,ty)
end
---------------------------------------------------------------------------------------------------
-- rotate 90 degrees
function TileLayer:rotateTile(tx,ty)
	local flip = self._gridflip:get(tx,ty) or 0
	
	-- From Tiled source: tilelayer.cpp
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
	-- self._redraw = true
	self:redrawTile(tx,ty)
end
---------------------------------------------------------------------------------------------------
function TileLayer:importData(data)
	-- TODO
end
---------------------------------------------------------------------------------------------------
function TileLayer:draw(x,y)
	if not self.visible then return end
	if self._redraw then self:redrawTile() end

	x = (x or 0) + self.offsetX * self.parallaxX
	y = (y or 0) + self.offsetY * self.parallaxY
	local r,g,b,a = love.graphics.getColor()
	love.graphics.setColor(r,g,b,self.opacity*255)
	for tileset,batch in pairs(self._batches) do
		love.graphics.draw(batch, x + tileset.offsetX, y + tileset.offsetY)
	end
	love.graphics.setColor(r,g,b,a)
end
---------------------------------------------------------------------------------------------------
function TileLayer:redrawTile(tx,ty)
	local map = self.map
	local tile= self(tx,ty)
	
	-- for _,batch in pairs(self._batches) do
		-- batch:clear()
		-- batch:bind()
	-- end
	
	-- local x,y,x2,y2 = unpack(self._tilerange)
	
	-- for tx,ty,tile in self._grid:rectangle(x,y,x2,y2, true) do
		local batch   = self._batches[tile.tileset]
		local tileset = tile.tileset
		local tw,th   = tileset.tilewidth , tileset.tileheight
		local id      = (ty * map.width) + 1 + tx
		
		
		local flipbits= self._gridflip:get(tx,ty) or 0
		local flipX   = math.floor(flipbits / 4) == 1       
		local flipY   = math.floor( (flipbits % 4) / 2) == 1
		local flipDiag= flipbits % 2 == 1
		
		if not batch then
			local size= map.width * map.height
			batch     = love.graphics.newSpriteBatch(tile.image,size)
			self._batches[tile.tileset] = batch
			
			for i = 1,size do
				batch[addQuad](batch,tile.quad,0,0,0,0)
			end
		end
		
		if map.orientation == 'orthogonal' then
			local x,y   = tx * tw + (tw - map.tilewidth),
							  ty * th + (th - map.tileheight)
			local hw,hh = tw/2,th/2
			local sx,sy = flipX and -1 or 1, flipY and -1 or 1
			local angle = 0
			if flipDiag then
				angle = math.pi/2
				sx,sy = sy, sx*-1
			end
			
			-- batch[addQuad](batch, tile.quad, x+hw,y+hh, angle, sx,sy, hw,hh)
			batch[setQuad](batch, id, tile.quad, x+hw,y+hh, angle, sx,sy, hw,hh)
		elseif map.orientation == 'isometric' then
		
		elseif map.orientation == 'staggered' then
		
		end
	-- end
	
	-- for _,batch in pairs(self._batches) do
		-- batch:unbind()
	-- end
	
	-- self._redraw = false
end
---------------------------------------------------------------------------------------------------
return TileLayer