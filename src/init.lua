--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2011-2012 Casey Baxter
Copyright (c) 2013-2014 Minh Ngo
]]

local MODULE_PATH  = (...) .. '.'

-- Return the classes in a table
return {
	Map        = require(MODULE_PATH  .. "Map"),
	TileLayer  = require(MODULE_PATH  .. "TileLayer"),
	Tile       = require(MODULE_PATH  .. "Tile"),
	TileSet    = require(MODULE_PATH  .. "TileSet"),
	Object     = require(MODULE_PATH  .. "Object"),
	ObjectLayer= require(MODULE_PATH  .. "ObjectLayer"),
	Loader     = require(MODULE_PATH  .. "Loader"),
	Grid       = require(MODULE_PATH .. "Grid"),
	Base64     = require(MODULE_PATH .. "Base64"),
	Class      = require(MODULE_PATH .. "Class"),
}