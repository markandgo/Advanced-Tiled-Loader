--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2011-2012 Casey Baxter
Copyright (c) 2013 Minh Ngo
]]

---------------------------------------------------------------------------------------------------
-- -= Loader =-
---------------------------------------------------------------------------------------------------

-- Define path so lua knows where to look for files.
TILED_LOADER_PATH= TILED_LOADER_PATH or (...):match('^.+[%.\\/]') or ''
local base64     = require(TILED_LOADER_PATH .. 'Base64')
local xmlparser  = require(TILED_LOADER_PATH .. 'external.xml')
local deflate    = require(TILED_LOADER_PATH ..'external.deflate')
local Map        = require(TILED_LOADER_PATH .. "Map")
local TileSet    = require(TILED_LOADER_PATH .. "TileSet")
local TileLayer  = require(TILED_LOADER_PATH .. "TileLayer")
local ObjectLayer= require(TILED_LOADER_PATH .. "ObjectLayer")
local imageCache = setmetatable({},{__mode= 'v'})
local elementkey = '__element' -- key for element name

local allowed_property = {
	string = true,
	number = true,
	boolean= true,
}

local Loader = {
	filterMin = 'nearest', 
	filterMag = 'nearest',
}

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
	local element = {[elementkey] = name}
	if attr then
		for k,v in pairs(attr) do
			element[k] = tonumber(v) or v
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
-- should return map else error as second message

function Loader.load(filename)
	local ok,tmxmap = pcall(function()
		return Loader._expandMap( Loader.parseXML(filename) )
	end)
	if not ok then return nil,tmxmap end
	return tmxmap
end
---------------------------------------------------------------------------------------------------
-- should return true if successful else error as second message

function Loader.save(map,filename)
	return pcall(function()
		local tmxmap = Loader._compactMap(map)
		Loader._saveAsXML(tmxmap,filename)
	end)
end
---------------------------------------------------------------------------------------------------
function Loader.parseXML(filename)
	local h        = newHandler()
	local tmxparser= xmlparser(h)
	local str,err  = love.filesystem.read(filename)
	assert(str,err)
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
		local etype = element[elementkey]
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
		local str,err  = love.filesystem.read(path)
		assert(str,err)
		tsxparser:parse(str)
		local tsxtable = h.root[1]
		
		for i,v in pairs(tsxtable) do
			tmxtileset[i] = v
		end
	end
	
	local a = tmxtileset
	local tileset = TileSet:new{
		firstgid   = a.firstgid,
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
		local etype = element[elementkey]
		if etype == 'tileoffset' then
			tileset.offsetX = element.x
			tileset.offsetY = element.y
		elseif etype == 'image' then
			-- The image stored in the TSX file is relative to its location
			-- The source is changed to be relative to the location of the TMX file
			if tmxtileset.source then
				local dir_of_tsx = getPathComponents( tmxtileset.source )
				element.source   = string.format( '/%s/%s',
					dir_of_tsx, 
					element.source )
			end
			Loader._expandImage(element,tmxmap)
			tileset.image      = element.image
			tileset.imagesource= element.source
			tileset.trans      = element.trans
			tileset.tiles      = tileset:makeTiles()
		elseif etype == 'tile' then
			for i,v in ipairs(element) do
				if v[elementkey] == 'properties' then
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
---------------------------------------------------------------------------------------------------
function Loader._streamLayerData(tmxlayer,tmxmap)
	local data
	for i = 1,#tmxlayer do
		if tmxlayer[i][elementkey] == 'data' then data = tmxlayer[i]; break end
	end
	local str   = data.encoding == 'base64' and base64.dec('string',data[1]) or data[1]
	
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
		local etype = element[elementkey]
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
		local etype = element[elementkey]
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
				local etype = sub[elementkey]
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
				if etype == 'ellipse' then
					object.ellipse = true
				end
			end
			
		elseif etype == 'properties' then
			layer.properties = Loader._expandProperties(element)
		end
	end
	
	return layer
end
---------------------------------------------------------------------------------------------------
function Loader._compactMap(map)
	local tmxmap = {
		[elementkey]= 'map',
		attr = {
			version     = '1.0',
			orientation = map.orientation,
			width       = map.width,
			height      = map.height,
			tilewidth   = map.tilewidth,
			tileheight  = map.tileheight,
		},
	}
	
	-- do tilesets
	local tilesets = {}
	for name,tileset in pairs(map.tilesets) do
		table.insert( tilesets, Loader._compactTileSet(tileset) )
	end
	table.sort(tilesets,function(a,b)
		return a.attr.firstgid < b.attr.firstgid
	end)
	for _,tmxtileset in ipairs(tilesets) do
		table.insert( tmxmap, tmxtileset )
	end
	
	-- do layers
	for i,layer in ipairs(map.layerOrder) do
		if layer.class == 'TileLayer' then
			table.insert( tmxmap, Loader._compactTileLayer(layer) )
		end
		if layer.class == 'ObjectLayer' then
			table.insert( tmxmap, Loader._compactObjectGroup(layer) )
		end
	end
	
	-- do properties
	Loader._insertProperties( tmxmap, map.properties )
	
	return tmxmap
end
---------------------------------------------------------------------------------------------------
function Loader._insertProperties(parent,properties)
	if not (properties and next(properties)) then return end

	local tmxproperties = {
		[elementkey] = 'properties',
	}
	for name,value in pairs(properties) do
		if allowed_property[ type(name) ] and allowed_property[ type(value) ] then
			table.insert(tmxproperties, {
				[elementkey]= 'property',
				attr        = {
					name = tostring(name),
					value= tostring(value),
				},
			})
		end
	end
	
	table.insert(parent,tmxproperties)
end
---------------------------------------------------------------------------------------------------
function Loader._compactTileSet(tileset)
	local t = tileset
	local tmxtileset = {
		[elementkey]= 'tileset',
		attr = {
			firstgid    = t.firstgid,
			name        = t.name,
			tilewidth   = t.tilewidth,
			tileheight  = t.tileheight,
			spacing     = t.spacing,
			margin      = t.margin,
		},
		------------------------
		{
			[elementkey]= 'tileoffset',
			attr = {
				x           = t.offsetX,
				y           = t.offsetY,
			},
		},
		{
			[elementkey]= 'image',
			attr = {
				source      = t.imagesource,
				trans       = t.trans,
				width       = t.image:getWidth(),
				height      = t.image:getHeight(),
			},
		},
	}
	
	for id = 0,#t.tiles do
		local tile = t.tiles[id]
		if next(tile.properties) then
			local tmxtile = {
				[elementkey]= 'tile',
				attr        = {
					id = id,
				},
			}
			Loader._insertProperties(tmxtile,tile.properties)
			table.insert(tmxtileset,tmxtile)
		end
	end
	
	Loader._insertProperties( tmxtileset, t.properties )
	
	return tmxtileset
end
---------------------------------------------------------------------------------------------------
function Loader._compactTileLayer(tilelayer)
	local t = tilelayer
	local tmxtilelayer = {
		[elementkey]= 'layer',
		attr = {
			name        = t.name,
			opacity     = t.opacity,
			visible     = t.visible and 1 or 0,
			width       = tilelayer.map.width,
			height      = tilelayer.map.height,
		},
		---------------------
		Loader._compactLayerData(tilelayer),
	}
	Loader._insertProperties( tmxtilelayer, t.properties )
	
	return tmxtilelayer
end
---------------------------------------------------------------------------------------------------
local bitoffset = 2^29

function Loader._compactLayerData(tilelayer)
	local w,h = tilelayer.map.width,tilelayer.map.height
	local rows= {}
	
	for ty = 0,h-1 do
		local row = {}
		for tx = 0,w-1 do
			local tile        = tilelayer(tx,ty)
			local gid,flipbits= 0,0
			if tile then
				gid      = tile.gid or gid 
				flipbits = tilelayer._gridflip:get(tx,ty) or flipbits
			end
			table.insert(row, flipbits * bitoffset + gid)
		end
		table.insert(rows, table.concat(row,','))
	end
	
	return {
		[elementkey]= 'data',
		attr        = { encoding = 'csv'},
		-----------------
		table.concat(rows, ',\n')
	}
end
---------------------------------------------------------------------------------------------------
function Loader._compactObjectGroup(objectlayer)
	local o = objectlayer
	
	local color = '#'
	for i = 1,3 do
		local channel= string.format('%.2x',o.color[i])
		color        = color .. channel
	end
	
	local tmxobjectlayer = {
		[elementkey]= 'objectgroup',
		attr = {
			name        = o.name,
			color       = color,
			opacity     = o.opacity,
			visible     = o.visible and 1 or 0,
			width       = o.map.width,
			height      = o.map.height,
		},
	}
	Loader._insertProperties(tmxobjectlayer,o.properties)
	
	for i,object in ipairs(o.objects) do
		local o = object
		local tmxobject = {
			[elementkey]= 'object',
			attr = {
				name        = o.name,
				type        = o.type,
				x           = o.x,
				y           = o.y,
				width       = o.width,
				height      = o.height,
				gid         = o.gid,
				visible     = o.visible and 1 or 0,
			},
		}
		Loader._insertProperties(tmxobject,o.properties)
		
		local subtype = o.ellipse and 'ellipse' or 
			o.polygon and 'polygon' or 
			o.polyline and 'polyline'
		
		if subtype then
			local tmxtype = {
					[elementkey]= subtype,
					attr        = {},
				}
			if subtype ~= 'ellipse' then
				local points = {}
				for i = 1,#o[subtype],2 do
					table.insert(points,o[subtype][i]..','..o[subtype][i+1])
				end
				tmxtype.attr.points = table.concat(points,' ')
			end
			table.insert(tmxobject,tmxtype)
		end
		
		table.insert(tmxobjectlayer, tmxobject)
	end
	
	return tmxobjectlayer
end
---------------------------------------------------------------------------------------------------
-- attributes have non numeric keys
-- subelements have numeric keys

function Loader._saveAsXML(tmxmap,filename)
	local dir   = getPathComponents(filename)
	local dir_ok= love.filesystem.mkdir( dir )
	
	if not dir_ok then error('Unable to make directory: '..dir) end
	if love.filesystem.isDirectory(filename) then
		error( string.format('Unable to save, \"%s\" is a directory',filename) )
	end
	
	
	local file = love.filesystem.newFile(filename)
	
	file:open 'w'
	file:write '<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n'
	
	local recursive
	recursive = function(t,level)
		local element = t[elementkey]
		local tabs    = string.rep('\t',level)
		
		file:write (tabs..'<'..element)
		-- attributes
		if t.attr then
			for i,v in pairs(t.attr) do
				local itype = type(i)
				local vtype = type(v)
				
				if v ~= '' and allowed_property[ vtype ] and allowed_property[itype] then
					file:write( string.format( ' %s=%q ',tostring(i),tostring(v) ) )
				end
			end
		end
		-- write subelements else terminate tag
		if t[1] then 
			file:write ('>\n')
			-- subelements/text
			for i,v in ipairs(t) do
				local vtype = type(v)
				
				if vtype == 'table' then
					recursive(v,level+1)
				else
					file:write(tostring(v)..'\n')
				end
			end
			file:write (tabs..'</'..element..'>\n')
		else
			file:write ('/>\n')
		end
	end
	recursive(tmxmap,0)
	file:close()
end
---------------------------------------------------------------------------------------------------
return Loader
