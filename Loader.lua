---------------------------------------------------------------------------------------------------
-- -= Loader =-
---------------------------------------------------------------------------------------------------

-- Define path so lua knows where to look for files.
TILED_LOADER_PATH= TILED_LOADER_PATH or (...):match('^.+[%.\\/]') or ''
local base64     = require(TILED_LOADER_PATH .. 'external.base64')
local xmlparser  = require(TILED_LOADER_PATH .. 'external.xml')
local deflate    = require(TILED_LOADER_PATH ..'external.deflate')
local Map        = require(TILED_LOADER_PATH .. "Map")
local TileSet    = require(TILED_LOADER_PATH .. "TileSet")
local TileLayer  = require(TILED_LOADER_PATH .. "TileLayer")
local ObjectLayer= require(TILED_LOADER_PATH .. "ObjectLayer")
local imageCache = setmetatable({},{__mode= 'v'})

---------------------------------------------------------------------------------------------------
-- PATH FUNCTIONS

local function getPathComponents(path)
	local dir,name,ext = path:match('^(.-)([^\\/]-)%.?([^\\/%.]*)$')
	if #name == 0 then name = ext; ext = '' end
	return dir,name,ext
end

local function stripUpDirectory(path)
	while path:find('%.%.[\\/]+') do
		path = path:gsub('[^\\/]*[\\/]*%.%.[\\/]+','')
	end
	return path
end

local stripExcessSlash = function(path)
	return path:gsub('[\\/]+','/')
end

---------------------------------------------------------------------------------------------------
-- XML HANDLER

local handler   = {}
handler.__index = handler

handler.starttag = function(self,name,attr)
	local stack   = self.stack
	local element = {element = name}
	if attr then
		for k,v in pairs(attr) do
			v = k ~= 'trans' and tonumber(v) or v
			v = v == 'true' and true or v == 'false' and false or v
			element[k] = v
		end
	end
	stack.len = stack.len + 1
	table.insert(self.stack,element)
end

handler.endtag = function(self,name,attr)
	local stack   = self.stack
	local element = table.remove(stack,stack.len)
	stack.len     = stack.len - 1
	local parent  = stack[stack.len]
	table.insert(parent,element)
end

handler.text = function(self,text)
	table.insert(self.stack[self.stack.len],1,text)
end

local function newHandler()
	local h    = {root = {},stack = {len = 1}}
	h.stack[1] = h.root
	
	return setmetatable(h,handler)
end
---------------------------------------------------------------------------------------------------
-- Convert string bytes to numbers
local function byteToNumber(str)
	local num = 0
	local len = #str
	for i = 1,len do
		num = num + string.byte(str,i) * 256^(i-1)
	end
	return num
end
---------------------------------------------------------------------------------------------------

local Loader = {}
---------------------------------------------------------------------------------------------------
function Loader.load(filename)
	local tmxmap = Loader.parseXML(filename)
	return Loader._expandMap(tmxmap)
end
---------------------------------------------------------------------------------------------------
function Loader.save(filename)

end
---------------------------------------------------------------------------------------------------
function Loader.parseXML(filename)
	local h        = newHandler()
	local tmxparser= xmlparser(h)
	local hasFile  = love.filesystem.isFile(filename)
	if not hasFile then return nil,'File not found: '..filename end
	local str      = love.filesystem.read(filename)
	tmxparser:parse(str)
	local tmxmap   = h.root[1]
	
	local dir       = getPathComponents(filename)
	tmxmap.directory= dir 
	
	return tmxmap
end
---------------------------------------------------------------------------------------------------
function Loader._expandMap(tmxmap)
	local a = tmxmap
	local map = Map:new{
		width      = a.width,
		height     = a.height,
		tilewidth  = a.tilewidth,
		tileheight = a.tileheight,
		
		orientation= a.orientation or 'orthogonal',
		layers     = nil, -- indexed by name
		tilesets   = nil, -- indexed by name
		layerOrder = nil, -- indexed by draw order
		tiles      = nil, -- indexed by gid
		properties = nil,
		
		directory  = tmxmap.directory,
	}
	
	for i,element in ipairs(tmxmap) do
		local etype = element.element
		if etype == 'tileset' then
			local tileset = Loader._expandTileSet(element,tmxmap)
			
			if map.tilesets[tileset.name] then 
				error( string.format( 'A tileset named \"%s\" already exists', tileset.name ) )
			end
			
			map.tilesets[tileset.name] = tileset
			for i = 0,#tileset.tiles do
				local tile = tileset.tiles[i]
				map.tiles[tile.gid] = tile
			end
			
		elseif etype == 'layer' or etype == 'objectgroup' then
			local layer = etype == 'layer' and Loader._expandTileLayer(element,tmxmap,map)
			or Loader._expandObjectGroup(element,tmxmap,map)
			
			if map.layers[layer.name] then 
				error( string.format( 'A layer named \"%s\" already exists', layer.name ) )
			end
			
			map.layers[layer.name] = layer
			table.insert(map.layerOrder,layer)
		
		elseif etype == 'properties' then
			map.properties = Loader._expandProperties(element)
		end
	end
	
	return map
end
---------------------------------------------------------------------------------------------------
function Loader._expandProperties(tmxproperties)
	local properties = {}
	for i,property in ipairs(tmxproperties) do
		properties[property.name] = property.value		
	end
	return properties
end
---------------------------------------------------------------------------------------------------
function Loader._expandTileSet(tmxtileset,tmxmap)
	if tmxtileset.source then
		local h        = newHandler()
		local tsxparser= xmlparser(h)
		local path     = stripExcessSlash( stripUpDirectory(tmxmap.directory..tmxtileset.source) )
		local str      = love.filesystem.read(path)
		tsxparser:parse(str)
		local tsxtable = h.root[1]
		
		for i,v in pairs(tsxtable) do
			tmxtileset[i] = v
		end
	end
	
	local a = tmxtileset
	local tileset = TileSet:new{
		firstgid   = a.firstgid,
		source     = a.source,
		tilewidth  = a.tilewidth,
		tileheight = a.tileheight,
		
		imagesource= nil,
		image      = nil,
		trans      = a.trans,
		-- tiles      = a.tiles, -- indexed by local id
		
		name       = a.name,
		spacing    = a.spacing ,
		margin     = a.margin,
		offsetX    = nil,
		offsetY    = nil,
		properties = nil,
	}
	for i,element in ipairs(tmxtileset) do
		local etype = element.element
		if etype == 'tileoffset' then
			tileset.offsetX = element.x
			tileset.offsetY = element.y
		elseif etype == 'image' then
			Loader._expandImage(element,tmxmap)
			tileset.image      = element.image
			tileset.imagesource= element.source
			tileset.trans      = element.trans
			tileset.tiles      = tileset:makeTiles()
		elseif etype == 'tile' then
			for i,v in ipairs(element) do
				if v.element == 'properties' then
					tileset.tiles[element.id].properties = Loader._expandProperties(v)
				end
			end
		elseif etype == 'properties' then
			tileset.properties = Loader._expandProperties(element)
		end
	end
	return tileset
end
---------------------------------------------------------------------------------------------------
function Loader._expandImage(tmximage,tmxmap)
	local source      = stripExcessSlash(  stripUpDirectory(tmxmap.directory..tmximage.source)  )
	local trans       = tmximage.trans
	local image       = imageCache[source..(trans or '')]
	if not image then
		if trans then	
			local color = {}
			for i = 1,#trans,2 do
				table.insert(color, tonumber( trans:sub(i,i+1), 16 ) )
			end
			local data  = love.image.newImageData(source)
			data:mapPixel(function(x,y,r,g,b,a)
				if r == color[1] and g == color[2] and b == color[3] then
					return 0,0,0,0
				end
				return r,g,b,a
			end)
			image = love.graphics.newImage(data)
		else 
			image = love.graphics.newImage(source)
		end
		imageCache[source..(trans or '')] = image
	end
	tmximage.image = image
end
---------------------------------------------------------------------------------------------------
function Loader._streamLayerData(tmxlayer,tmxmap)
	local data
	for i = 1,#tmxlayer do
		if tmxlayer[i].element == 'data' then data = tmxlayer[i]; break end
	end
	local str   = data.encoding == 'base64' and base64.dec(data[1]) or data[1]
	
	local bytes = {len = 0}
	
	local byteconsume = function(code) 
		bytes.len       = bytes.len+1
		bytes[bytes.len]= string.char(code)
	end
	local handler = { input = str, output = byteconsume, disable_crc = true }
	
	if data.compression == 'gzip' then
		deflate.gunzip( handler )
		str = table.concat(bytes)
	elseif data.compression == 'zlib' then
		deflate.inflate_zlib( handler )
		str = table.concat(bytes)
	end
	
	return coroutine.wrap(function()
		local divbits = 2^29
		local pattern = data.encoding == 'base64' and '(....)' or '(%d+)'
		local count   = 0
		local w,h     = tmxlayer.width or tmxmap.width,tmxlayer.height or tmxmap.height
		
		
		for num in str:gmatch(pattern) do
			count = count + 1
			
			if data.encoding == 'base64' then 
				num = byteToNumber(num)
			else 
				num = tonumber(num) 
			end
			
			-- bit 32: xflip
			-- bit 31: yflip
			-- bit 30: antidiagonal flip
			
			local gid         = num % divbits
			local flips       = math.floor(num / 2^29)
			
			local y = math.ceil(count/w) - 1
			local x = count - (y)*w -1
			
			coroutine.yield(gid,x,y,flips)
		end
	end)
end
---------------------------------------------------------------------------------------------------
function Loader._expandTileLayer(tmxlayer,tmxmap,map)
	local layer = TileLayer:new{
		map       = map,
		name      = tmxlayer.name or ('Layer '..#map.layerOrder+1),
		opacity   = tmxlayer.opacity,
		visible   = (tmxlayer.visible or 1) == 1,
		properties= nil,
	}
	
	for i,element in ipairs(tmxlayer) do
		local etype = element.element
		if etype == 'data' then
			for gid,x,y,flipbits in Loader._streamLayerData(tmxlayer,tmxmap) do
			
				if gid ~= 0 then
					local tile = map.tiles[gid]
					layer:setTile(x,y, tile,flipbits)
				end
			end
		elseif etype == 'properties' then
			layer.properties = Loader._expandProperties(element)
		end
	end
	
	return layer
end
---------------------------------------------------------------------------------------------------
function Loader._expandObjectGroup(tmxlayer,tmxmap,map)
	local layer = ObjectLayer:new{
		map        = map,
		name       = tmxlayer.name or ('Layer '..#map.layerOrder+1),
		opacity    = tmxlayer.opacity,
		visible    = (tmxlayer.visible or 1)== 1,
		
		color      = nil,
		properties = nil,
		objects    = nil,
	}
	
	if tmxlayer.color then
		local color = {}
		for i = 2,#tmxlayer.color,2 do
			table.insert(color, tonumber( tmxlayer.color:sub(i,i+1), 16 ) )
		end
		layer.color = color
	end
	
	for i,element in ipairs(tmxlayer) do
		local etype = element.element
		if etype == 'object' then
			
			local e = element
			
			local object = layer:newObject{
				name      = e.name,
				type      = e.type,
				gid       = e.gid,
				x         = e.x,
				y         = e.y,
				width     = e.width,
				height    = e.height,
				visible   = (e.visible == nil and true) or e.visible,
				
				polygon   = nil,
				polyline  = nil,
				properties= nil,
			}
			
			for i,sub in ipairs(e) do
				local etype = sub.element
				if etype == 'properties' then
					object.properties = Loader._expandProperties(sub)
				end
				if etype == 'polygon' or etype == 'polyline' then
					local points = sub.points
					local t      = {}
					for num in points:gmatch '-?%d+' do
						table.insert(t,tonumber(num))
					end
					object[etype] = t
				end
			end
			
		elseif etype == 'properties' then
			layer.properties = Loader._expandProperties(element)
		end
	end
	
	return layer
end
---------------------------------------------------------------------------------------------------
return Loader
