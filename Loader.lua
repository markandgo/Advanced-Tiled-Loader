---------------------------------------------------------------------------------------------------
-- -= Loader =-
---------------------------------------------------------------------------------------------------

-- Define path so lua knows where to look for files.
ATL_PATH         = ATL_PATH or (...):match('^.+[%.\\/]') or ''
local unb64      = require ('mime').unb64
local xmlparser  = require(ATL_PATH .. 'external.xml')
local deflate    = require(ATL_PATH ..'external.deflate')
local Map        = require(ATL_PATH .. "Map")
local TileSet    = require(ATL_PATH .. "TileSet")
local TileLayer  = require(ATL_PATH .. "TileLayer")
local Tile       = require(ATL_PATH .. "Tile")
-- local Object     = require(ATL_PATH .. "Object")
-- local ObjectLayer= require(ATL_PATH .. "ObjectLayer")

---------------------------------------------------------------------------------------------------
-- PATH FUNCTIONS

local function getPathComponents(path)
	local dir,name,ext = path:match('^(.-)([^\\/]-)%.?([^\\/%.]*)$')
	if #name == 0 then name = ext; ext = '' end
	return dir,name,ext
end
---------------------------------------------------------------------------------------------------
local function removeUpDirectory(path)
	while path:find('%.%.[\\/]+') do
		path = path:gsub('[^\\/]*[\\/]*%.%.[\\/]+','')
	end
	return path
end
---------------------------------------------------------------------------------------------------
local stripExcessSlash = function(path)
	return path:gsub('[\\/]+','/')
end

---------------------------------------------------------------------------------------------------
-- XML HANDLER

local handler   = {}
handler.__index = handler
---------------------------------------------------------------------------------------------------
handler.starttag = function(self,name,attr)
	local stack   = self.stack
	local element = {element = name}
	if attr then
		for k,v in pairs(attr) do
			if not element[k] then
				v = tonumber(v) or v
				v = v == 'true' and true or v == 'false' and false or v
				element[k] = v
			end
		end
	end
	stack.len = stack.len + 1
	table.insert(self.stack,element)
end
---------------------------------------------------------------------------------------------------
handler.endtag = function(self,name,attr)
	local stack   = self.stack
	local element = table.remove(stack,stack.len)
	stack.len     = stack.len - 1
	local parent  = stack[stack.len]
	table.insert(parent,element)
end
---------------------------------------------------------------------------------------------------
handler.text = function(self,text)
	table.insert(self.stack[self.stack.len],1,text)
end
---------------------------------------------------------------------------------------------------
local function newHandler()
	local h    = {root = {},stack = {len = 1}}
	h.stack[1] = h.root
	
	return setmetatable(h,handler)
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
	local tmxmap    = h.root[1]
	
	local dir      = getPathComponents(filename)
	tmxmap.path     = dir
	
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
		layers     = {}, -- indexed by name
		tilesets   = {}, -- indexed by name
		layerOrder = {}, -- indexed by draw order
		tiles      = {}, -- indexed by gid
		properties = nil,
	}
	for i,element in ipairs(tmxmap) do
		local etype = element.element
		if etype == 'tileset' then
			local tileset = Loader._expandTileSet(element)
		elseif etype == 'layer' then
			
		elseif etype == 'properties' then
			map.properties = Loader._expandProperties(element)
		end
	end
end
---------------------------------------------------------------------------------------------------
function Loader._expandProperties(tmxproperties)
	local properties = {}
	for i,property in ipairs(properties) do
		properties[property.name] = property.value		
	end
	return properties
end
---------------------------------------------------------------------------------------------------
function Loader._expandTileSet(tmxtileset)
	local a = tmxtileset
	local tileset = TileSet:new{
		firstgid   = a.firstgid,
		source     = a.source,
		tilewidth  = a.tilewidth,
		tileheight = a.tileheight,
		imagesource= a.imagesource,
		image      = nil,
		-- trans      = a.trans,
		-- tiles      = a.tiles, -- indexed by local id
		
		-- optional
		name       = a.name,
		spacing    = a.spacing ,
		margin     = a.margin,
		offsetX    = nil,
		offsetY    = nil,
		properties = nil,
	}
	for i,element in ipairs(tmxtileset) do
		local etype = element
		if etype == 'tileoffset' then
			tileset.offsetX = element.x
			tileset.offsetY = element.y
		elseif etype == 'image' then
			
		elseif etype == 'tile' then
		
		elseif etype == 'properties' then
		
		end
	end
end
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
return Loader