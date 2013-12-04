function love.load()
	atl = require 'src'
	
	function loadmap(filename)
		-- Test loading and saving
		map = assert( atl.Loader.load(filename) )
		assert(atl.Loader.save(map, 'test/map.tmx'))
		
		-- Test properties
		assert(map.properties.map == 1)
		
		local ts = map.tilesets.tileset
		assert(ts.properties.tileset == 1)
		assert(ts.tiles[0].properties.tile1 == 1)
		
		assert(map.layers['Tile Layer 1'].properties.layer == 1)
		
		-- Test object properties
		-- **Staggered does not support objects in 0.9**
		if not map.orientation == 'staggered' then
			assert(map.layers['Object Layer 1'].objects[1].properties.name == 'obj1')
		end
	end	
	
	-- Cycle through these maps
	list = {
		'map.tmx',
		'stagmap.tmx',
		'isomap.tmx',
	}
	list_i      = 1 
	
	loadmap( list[list_i] )
	
	-- Affects map presentation
	x,y         = 0,0
	scale       = 1
	defaultspeed= 350
	speed       = defaultspeed
	
	-- affects draw range
	draw_all    = true
	padding     = -70
	wx,wy,ww,wh = 0,0,800,600
end

function love.keypressed(k)
	if k == ' ' then
		list_i = list_i + 1
		list_i = list_i > #list and 1 or list_i
		
		loadmap( list[list_i] )
		
		assert(atl.Loader.save(map, 'test/map.tmx'))
		
		x,y  = 0,0
		scale= 1
		speed= defaultspeed
	end
	if k == 'tab' and map.setDrawRange then
		draw_all = not draw_all
		if draw_all then
			map:setDrawRange()
		end
	end
	if k == 'x' then
		map.layerOrder[1]:flipTile(0,0, true)
	end
	if k == 'y' then
		map.layerOrder[1]:flipTile(0,0, false,true)
	end
	if k == 'r' then
		map.layerOrder[1]:rotateTile(0,0)
	end
end

function love.mousepressed(x,y,b)
	if b == 'wu' then
		scale = scale * 1.2
		speed = speed / 1.2
	end
	if b == 'wd' then
		scale = scale / 1.2
		speed = speed * 1.2
	end
end

function love.update(dt)
	if love.keyboard.isDown 'left' then
		x = x + dt * -speed
	end
	if love.keyboard.isDown 'right' then
		x = x + dt * speed
	end
	if love.keyboard.isDown 'up' then
		y = y + dt * -speed
	end
	if love.keyboard.isDown 'down' then
		y = y + dt * speed
	end
	
	if not draw_all and map.autoDrawRange then
		map:autoDrawRange(x,y, scale, padding)
	end
	
	local layer = map.layerOrder[1]
	if layer then 
		layer.parallaxX = .7
		layer.parallaxY = .7
		map.ox = x
		map.oy = y
	end
end

function love.draw()
	love.graphics.push()
	love.graphics.translate(400,300) -- center
	love.graphics.scale(scale)
	if map.setDrawRange then
		love.graphics.translate(-x,-y)
	end
	
	map:draw(-x,-y)
	
	love.graphics.pop()
	if not draw_all then
		love.graphics.rectangle('line',wx-padding,wy-padding,ww+padding*2,wh+padding*2)
	end
	
	fps = love.timer.getFPS()
	
	local msg = {
		'fps: '..fps,
		'map name: '..list[list_i],
		'scale: '..scale,
		'Draw limit: '..tostring(not draw_all),
		'Press tab to toggle draw control',
		'Press space to switch map',
		'Arrow keys to move, mouse wheel to zoom',
		'Press x/y/r to flipx/flipy/rotate',
	}
	local complete_msg = table.concat(msg,'\n')
	
	love.graphics.print( complete_msg ,0,0)
end