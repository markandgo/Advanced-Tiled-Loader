--[[
This code falls under the terms of the MIT license.
The full license can be found in "license.txt".

Copyright (c) 2011-2012 Casey Baxter
Copyright (c) 2013 Minh Ngo
]]

TILED_LOADER_PATH  = TILED_LOADER_PATH or (...) .. '.'

-- Return the classes in a table
return {
	Map        = require(TILED_LOADER_PATH  .. "Map"),
	TileLayer  = require(TILED_LOADER_PATH  .. "TileLayer"),
	Tile       = require(TILED_LOADER_PATH  .. "Tile"),
	TileSet    = require(TILED_LOADER_PATH  .. "TileSet"),
	Object     = require(TILED_LOADER_PATH  .. "Object"),
	ObjectLayer= require(TILED_LOADER_PATH  .. "ObjectLayer"),
	Loader     = require(TILED_LOADER_PATH  .. "Loader"),
	Grid       = require(TILED_LOADER_PATH .. "Grid"),
	Base64     = require(TILED_LOADER_PATH .. "Base64"),
}