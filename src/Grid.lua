--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2015 Minh Ngo
]]

local MODULE_PATH = (...):match('^.+[%.\\/]')
local Class       = require(MODULE_PATH .. 'Class')

local Grid   = Class 'Grid' {}
Grid.__call  = function(...) return Grid.get(...) end

function Grid:init()
	self.cells = {}
end

function Grid:get(x,y)
	return self.cells[x] and self.cells[x][y]
end

function Grid:set(x,y,v)
	self.cells[x]    = self.cells[x] or {}
	self.cells[x][y] = v
end

function Grid:rectangle(x,y,x2,y2,skipNil)
	local xi,yi = x-1,y
	return function()
		while true do
			xi = xi+1
			if yi > y2 then return end
			if xi > x2 then 
				yi = yi + 1; xi = x-1 
			else
				local v = Grid.get(self,xi,yi)
				if v or not skipNil then
					return xi,yi,v
				end
			end
		end
	end
end

function Grid:iterate()
	local cells,x,t,y,v = self.cells
	return function()
		repeat
			if not y then 
				x,t = next(cells,x)
			end
			if not t then return end
			y,v = next(t,y)
		until v
		return x,y,v
	end
end

return Grid