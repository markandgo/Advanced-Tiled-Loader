--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2015 Minh Ngo
]]


-- -= Loader =-

-- 0.8 compatibility
local createDirectory = love.filesystem.mkdir or love.filesystem.createDirectory

-- Define path so lua knows where to look for files.
local MODULE_PATH= (...):match('^.+[%.\\/]') or ''
local base64     = require(MODULE_PATH .. 'Base64')
local xmlparser  = require(MODULE_PATH .. 'external.xml')
local deflate    = require(MODULE_PATH ..'external.deflate')
local Map        = require(MODULE_PATH .. "Map")
local Tile       = require(MODULE_PATH .. "Tile")
local TileSet    = require(MODULE_PATH .. "TileSet")
local TileLayer  = require(MODULE_PATH .. "TileLayer")
local Object     = require(MODULE_PATH .. "Object")
local ObjectLayer= require(MODULE_PATH .. "ObjectLayer")
local ImageLayer = require(MODULE_PATH .. "ImageLayer")
local imageCache = setmetatable({},{__mode= 'v'})
local elementkey = '__element' -- key for element name

local allowed_property = {
	string = true,
	number = true,
	boolean= true,
}

local Loader = {
	filterMin = 'linear', 
	filterMag = 'nearest',
}


-- UTILITY

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

-- Convert string bytes to numbers
local function byteToNumber(str)
	local num = 0
	local len = #str
	for i = 1,len do
		num = num + string.byte(str,i) * 256^(i-1)
	end
	return num
end


-- XML HANDLER

local handler   = {}
handler.__index = handler

handler.new = function()
	local h    = {root = {},stack = {len = 1}}
	h.stack[1] = h.root
	
	return setmetatable(h,handler)
end

handler.starttag = function(self,name,attr)
	local stack   = self.stack
	local element = {[elementkey] = name}
	if attr then
		for k,v in pairs(attr) do
			element[k] = tonumber(v) or v
		end
	end
	stack.len = stack.len + 1
	table.insert(self.stack,element)
	Loader._chunkCheck(self)
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

-- should return map else false and error string
function Loader._load(filename,chunk_size)
	local status,map = xpcall(function()
		local tmxmap = Loader._parseTMX(filename,chunk_size)
		-- Store the chunk stuff for streaming in the parsed table!
		tmxmap.chunk_size   = chunk_size
		tmxmap.chunk_counter= 0
		return Loader._expandMap( tmxmap )
	end,debug.traceback)
	if not status then local error = map; return nil,error end
	return map
end

function Loader.load(filename,chunk_size)
	if chunk_size then
		assert(chunk_size > 0, 'Chunk size must be greater than 0!')
		
		local proxy = {
			resolved = false,
			run = coroutine.wrap(function()
				local map,err = Loader._load(filename,chunk_size)
				coroutine.yield(map,err)
			end),
			update = function(self)
				if self.resolved then return end
				local map,err = self.run()
				if map or err then self.resolved = true end
				if map and self._onLoad then self._onLoad(map) end
				if err and self._onError then self._onError(err) end
			end,
			onLoad = function(self,callback)
				self._onLoad = callback
				return self
			end,
			onError = function(self,callback)
				self._onError = callback
				return self
			end,
		}
		return proxy
	end
	return Loader._load(filename)
end

function Loader._chunkCheck(object)
	if coroutine.running() then
		object.chunk_counter = object.chunk_counter + 1
		if object.chunk_counter % object.chunk_size == 0 then
			coroutine.yield()
		end
	end
end

function Loader._parseTMX(filename,chunk_size)
	local h        = handler.new()
	h.chunk_size   = chunk_size
	h.chunk_counter= 0
	local tmxparser= xmlparser(h)
	local str,err  = love.filesystem.read(filename)
	assert(str,err)
	tmxparser:parse(str)
	local tmxmap   = h.root[1]
	
	local dir       = getPathComponents(filename)
	tmxmap.directory= dir 
	
	return tmxmap
end

function Loader._expandMap(tmxmap)
	local a = tmxmap
	local map = Map:new(
		a.width,a.height,a.tilewidth,a.tileheight,
	{
		orientation= a.orientation or 'orthogonal',
		layers     = nil, -- indexed by name
		tilesets   = nil, -- indexed by name
		layerOrder = nil, -- indexed by draw order
		tiles      = nil, -- indexed by gid
		properties = nil,
		
		directory  = tmxmap.directory,
	})
	
	for i,element in ipairs(tmxmap) do
		local etype = element[elementkey]
		if etype == 'tileset' then
			local tileset = Loader._expandTileSet(element,tmxmap)
			
			if map.tilesets[tileset.name] then 
				error( string.format( 'A tileset named \"%s\" already exists', tileset.name ) )
			end
			
			map.tilesets[tileset.name] = tileset
			for i = 0,#tileset.tiles do
				local tile = tileset.tiles[i]
				map.tiles[tileset.firstgid+tile.id] = tile
			end
			
		elseif etype == 'layer' or etype == 'objectgroup' or etype == 'imagelayer' then
			local layer = etype == 'layer' and Loader._expandTileLayer(element,tmxmap,map)
			or etype == 'objectgroup' and Loader._expandObjectGroup(element,tmxmap,map)
			or Loader._expandImageLayer(element,tmxmap,map)
			
			if map.layers[layer.name] then 
				error( string.format( 'A layer named \"%s\" already exists', layer.name ) )
			end
			
			map.layers[layer.name] = layer
			table.insert(map.layerOrder,layer)
		
		elseif etype == 'properties' then
			map.properties = Loader._expandProperties(element)
		end
	end
	
	-- Can't use batch draw with an image collection (Tiled 0.10.0)
	for _,tileset in pairs(map.tilesets) do
		if not tileset.image then
			map.batch_draw = false
		end
	end
	
	-- Disable batch drawing when tiles are animated
	for _,tile in pairs(map.tiles) do
		if tile.animated then
			map.batch_draw = false
			break
		end
	end
	
	return map
end

function Loader._expandProperties(tmxproperties)
	local properties = {}
	for i,property in ipairs(tmxproperties) do
		properties[property.name] = property.value		
	end
	return properties
end

function Loader._expandTileSet(tmxtileset,tmxmap)
	if tmxtileset.source then
		local path         = stripExcessSlash( stripUpDirectory(tmxmap.directory..tmxtileset.source) )
		local tsxtable,err = Loader._parseTMX(path,tmxmap.chunk_size)
		assert(tsxtable,err)
		for i,v in pairs(tsxtable) do
			tmxtileset[i] = v
		end
	end
	
	local t                 = tmxtileset
	local args              = {name= t.name,spacing= t.spacing,margin= t.margin}
	local tmx_tiles         = {}
	local tmx_tileproperties= {}
	local tileimages        = {}
	local tmx_tileterrains  = {}
	local tmx_terraintypes  = {}
	local tmx_animations    = {}
	local tmx_objectgroups  = {}
	
	for i,element in ipairs(tmxtileset) do
		local etype = element[elementkey]
		if etype == 'tileoffset' then
			args.offsetX = element.x
			args.offsetY = element.y
		elseif etype == 'image' then
			-- The image source is relative to the location of the TSX file
			-- The source is changed to be relative to the location of the TMX file
			if tmxtileset.source then
				local dir_of_tsx = getPathComponents( tmxtileset.source )
				element.source   = string.format( '/%s/%s',
					dir_of_tsx, 
					element.source )
			end
			Loader._expandImage(element,tmxmap)
			args.image      = element.image
			args.imagesource= element.source
			args.trans      = element.trans
		elseif etype == 'terraintypes' then
			tmx_terraintypes = element
		elseif etype == 'tile' then
			tmx_tiles[element.id] = element
			
			for i,v in ipairs(element) do
				if v[elementkey] == 'properties' then
					tmx_tileproperties[element.id] = Loader._expandProperties(v)
				elseif v[elementkey] == 'image' then
					Loader._expandImage(v,tmxmap)
					tileimages[element.id] = v.image
				elseif v[elementkey] == 'animation' then
					tmx_animations[element.id] = v
				elseif v[elementkey] == 'objectgroup' then
					tmx_objectgroups[element.id] = v
				end
			end
			if element.terrain then
				local a,b,c,d = element.terrain:match '(.*),(.*),(.*),(.*)'
				a,b,c,d       = a and tonumber(a),b and tonumber(b),c and tonumber(c),d and tonumber(d)
				tmx_tileterrains[element.id] = {a,b,c,d}
			end
		elseif etype == 'properties' then
			args.properties = Loader._expandProperties(element)
		end
	end
	
	local tileset = TileSet:new(
		t.tilewidth,
		t.tileheight,
		args.image or tileimages,
		t.firstgid,
		args)
	
	-- Import terrain types
	for i,tmx_terrain in ipairs(tmx_terraintypes) do
		local properties
		for i,v in ipairs(tmx_terrain) do
			if v[elementkey] == 'properties' then
				properties = Loader._expandProperties(v)
			end
		end
		tileset:newTerrain(tmx_terrain.name,tmx_terrain.tile,properties)
	end
		
	local tiles = tileset.tiles
	for id,tmxtile in pairs(tmx_tiles) do
		tiles[id].properties= tmx_tileproperties[id]
		tiles[id].terrain   = tmx_tileterrains[id]
		
		local tmxanimation = tmx_animations[id]
		if tmxanimation then
			tiles[id].animated = true
			tiles[id].current_frame = 1
			tiles[id].current_frame_id = tmxanimation[1].tileid
			tiles[id].frame_durations = {}
			tiles[id].frame_ids = {}
						
			-- Duration is in milliseconds			
			for i,tmxframe in ipairs(tmxanimation) do
				tiles[id].frame_ids[i] = tmxframe.tileid
				tiles[id].frame_durations[i] = tmxframe.duration/1000
			end
		end
		
		-- Replace terrain numbers in tables with direct reference
		local terrain = tiles[id].terrain
		if terrain then
			for i = 1,4 do
				terrain[i] = tileset.terraintypes[terrain[i]]
			end
		end
		
		for id,tmx_objectgroup in pairs(tmx_objectgroups) do
			tiles[id].objects = {}
			for _,tmxobject in ipairs(tmx_objectgroup) do
				table.insert(tiles[id].objects,Loader._expandObject(tmxobject))
			end
		end
	end
		
	return tileset
end

function Loader._expandImage(tmximage,tmxmap)
	local source      = stripExcessSlash(  stripUpDirectory(tmxmap.directory..tmximage.source)  )
	local trans       = tmximage.trans
	local image       = imageCache[source..(trans or '')]
	if not image then
		if trans then	
			local color = {}
			
			-- hack to undo string to number conversion
			if type(trans) == 'number' then
				trans = string.format( '%.6d', trans )
			end
			
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
		image:setFilter(Loader.filterMin,Loader.filterMag)
		imageCache[source..(trans or '')] = image
	end
	tmximage.image = image
end

local divbits = 2^29
function Loader._separateGidAndFlipBits(num)
	local gid   = num % divbits
	local flips = math.floor(num / 2^29)
	return gid,flips
end

function Loader._streamLayerData(tmxlayer,tmxmap)
	local data
	for i = 1,#tmxlayer do
		if tmxlayer[i][elementkey] == 'data' then data = tmxlayer[i]; break end
	end
	local str   = data.encoding == 'base64' and base64.decode('string',data[1]) or data[1]
	
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
			
			local gid,flips = Loader._separateGidAndFlipBits(num)
			
			local y = math.ceil(count/w) - 1
			local x = count - (y)*w -1
			
			coroutine.yield(gid,x,y,flips)
		end
	end)
end

function Loader._expandTileLayer(tmxlayer,tmxmap,map)
	local layer = TileLayer:new(map,{
		name      = tmxlayer.name or ('Layer '..#map.layerOrder+1),
		opacity   = tmxlayer.opacity,
		visible   = (tmxlayer.visible or 1) == 1,
		properties= nil,
	})
	
	for i,element in ipairs(tmxlayer) do
		local etype = element[elementkey]
		if etype == 'data' then
			for gid,x,y,flipbits in Loader._streamLayerData(tmxlayer,tmxmap) do
				Loader._chunkCheck(tmxmap)
			
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

function Loader._expandObjectGroup(tmxlayer,tmxmap,map)
	local layer = ObjectLayer:new(map,{
		name       = tmxlayer.name or ('Layer '..#map.layerOrder+1),
		opacity    = tmxlayer.opacity,
		visible    = (tmxlayer.visible or 1)== 1,
		
		color      = nil,
		properties = nil,
		objects    = nil,
	})
	
	if tmxlayer.color then
		local color = {}
		for i = 2,#tmxlayer.color,2 do
			table.insert(color, tonumber( tmxlayer.color:sub(i,i+1), 16 ) )
		end
		layer.color = color
	end
	
	for i,element in ipairs(tmxlayer) do
		local etype = element[elementkey]
		if etype == 'object' then
			Loader._chunkCheck(tmxmap)
			
			layer:addObject(Loader._expandObject(element,layer))
			
		elseif etype == 'properties' then
			layer.properties = Loader._expandProperties(element)
		end
	end
	
	return layer
end

function Loader._expandObject(tmxobject, layer)
	local gid,flipbits
	local e = tmxobject
	
	if e.gid then
		gid,flipbits = Loader._separateGidAndFlipBits(e.gid)
	end
	
	local args = {
		name      = e.name,
		type      = e.type,
		width     = e.width,
		height    = e.height,
		visible   = (e.visible == nil and true) or e.visible,
		rotation  = e.rotation,
		flipbits  = flipbits,
		
		polygon   = nil,
		polyline  = nil,
		properties= nil,
	}
	
	for i,sub in ipairs(e) do
		local etype = sub[elementkey]
		if etype == 'properties' then
			args.properties = Loader._expandProperties(sub)
		end
		if etype == 'polygon' or etype == 'polyline' then
			local points = sub.points
			local t      = {}
			for num in points:gmatch '-?%d+' do
				table.insert(t,tonumber(num))
			end
			args[etype] = t
		end
		if etype == 'ellipse' then
			args.ellipse = true
		end
	end
	
	return Object(layer, e.x,e.y, gid, args)
end

function Loader._expandImageLayer(tmxlayer,tmxmap,map)
	local properties,imagelayer,image_element

	for i,element in ipairs(tmxlayer) do
		local etype = element[elementkey]
		if etype == 'image' then
			image_element = element
			Loader._expandImage(element,tmxmap)
		elseif etype == 'properties' then
			properties = Loader._expandProperties(element)
		end
	end
	
	imagelayer = ImageLayer:new(map,image_element.image,{
		name       = tmxlayer.name or ('Layer '..#map.layerOrder+1),
		opacity    = tmxlayer.opacity,
		visible    = (tmxlayer.visible or 1)== 1,
		properties = properties,
		imagesource= image_element.source,
	})
	imagelayer.ox, imagelayer.oy = tmxlayer.x, tmxlayer.y
	
	return imagelayer
end

return Loader