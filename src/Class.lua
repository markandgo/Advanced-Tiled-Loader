--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2015 Minh Ngo
]]

-- Simple class with inspiration from other class modules
-------------------------------------------------
local Class,base

-- Syntax: Class "name" {...}
Class = function(name)
	return function(prototype)
		local Class  = prototype or {}
		Class.__type = name
		Class.__index= Class
		return setmetatable(Class,base)
	end
end

--[[
	Class methods:
		:new
		:type
		:typeOf
		:extend
		:mixin
		:clone
]]

base = {__type = 'Object'}
base.__index  = base

-- create class instance 
-- and initiate if necessary
function base.__call(Class,...)
	local obj = setmetatable({},Class.__proxy_meta or Class)
	if obj.init then obj:init(...) end
	return obj
end

function base.new(Class,...)
	return base.__call(Class,...)
end

function base.type(obj)
	return obj.__type
end

function base.typeOf(obj,name)
	while obj do
		if obj.__type == name then return true end
		local meta = getmetatable(obj)
		obj = meta and meta.__index
	end
	return false
end

local metamethods = {
	'add',
	'sub',
	'mul',
	'div',
	'mod',
	'pow',
	'unm',
	'concat',
	'len',
	'eq',
	'lt',
	'le',
	'call',
	'tostring',
} 

-- create subclass
function base:extend(name)
	return function(prototype)
		local super   = self
		local Class   = Class(name) (prototype)
		Class.__proxy_meta = {__index = Class}
		
		local pmeta = Class.__proxy_meta
		
		-- Invoking a missing class metamethod will invoke the metamethod 
		-- of the super class.
		for _,metamethod in ipairs(metamethods) do
			metamethod        = '__'..metamethod
			pmeta[metamethod] = function(...)
				return Class[metamethod](...)
			end
		end
		
		return setmetatable(Class,{__index = super, __call = base.__call})
	end
end

local reserved = {
	__index= true,
	__type = true,
}

function base:mixin(source)
	for i,v in pairs(source) do
		if not reserved[i] then self[i] = v end
	end
	return self
end

-- http://lua-users.org/wiki/CopyTable
local function deep_copy(t,done)
	if done[t] then return done[t]
	elseif type(t) ~= 'table' then return t end
	
	local newt = setmetatable( {}, getmetatable(t) )
	done[t]    = newt
	for i,v in pairs(t) do
		i      = deep_copy(i,done)
		v      = deep_copy(v,done)
		newt[i]= v
	end
	return newt
end

function base:clone()
	return deep_copy(self,{})
end

return Class