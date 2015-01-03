function love.load()
	tidal = require 'src'
	
	function loadmap(filename,chunksize)
		if chunksize then
			loading = true
			
			-- proxy methods return self
			proxy = tidal.load(filename,chunksize)
				:onLoad(function(newmap)
					map = newmap
					loading = false
					-- Reset scale/position/speed
					x,y  = 0,0
					scale= 1
					speed= defaultspeed
				end)
				:onError(function(err)
					error(err)
				end)
		else
			proxy  = nil
			loading= false
			map    = assert(tidal.load(filename))
			-- Reset scale/position/speed
			x,y  = 0,0
			scale= 1
			speed= defaultspeed
		end
	end	
	
	-- Cycle through these maps
	list = {
		'assets/desert.tmx',
		'assets/stagmap.tmx',
		'assets/isomap.tmx',
	}
	list_i    = 1 
	show_help = true
	loading   = false
	
	-- Affects map presentation
	x,y         = 0,0
	scale       = 1
	defaultspeed= 350
	speed       = defaultspeed
	
	-- affects draw range
	draw_all    = true
	padding     = -70
	wx,wy,ww,wh = 0,0,800,600
	
	loadmap( list[list_i] )
end

function love.keypressed(k)
	if k == ' ' or k == 'f2' then
		list_i = list_i + 1
		list_i = list_i > #list and 1 or list_i
	end
	if k == ' ' then
		loadmap( list[list_i], 10 )
	end
	if k == 'f2' then
		loadmap( list[list_i])
	end
	if k == 'tab' then
		draw_all = not draw_all
		if draw_all then
			map:setDrawRange()
		end
	end
	if k == 'f1' then
		show_help = not show_help
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
	
	if proxy then proxy:update() end
	
	if map then
		if not draw_all then
			map:autoDrawRange(x,y, scale, padding)
		end
		
		map:update(dt)
	end
end

function love.draw()
	love.graphics.push()
		love.graphics.translate(400,300) -- center the map
		love.graphics.scale(scale)
		
		if map then
			map:draw(-x,-y)
		end
	love.graphics.pop()
	
	if not draw_all then
		love.graphics.rectangle('line',wx-padding,wy-padding,ww+padding*2,wh+padding*2)
	end
	
	fps = love.timer.getFPS()
	
	if show_help then
		local msg = {
			'fps: '..fps,
			'map name: '..list[list_i],
			'scale: '..scale,
			'Draw limit: '..tostring(not draw_all),
			'Press f1 to toggle help view',
			'Press tab to toggle draw control',
			'Press space to load map asynchronously',
			'Press f2 to load map synchronously',
			'Arrow keys to move, mouse wheel to zoom',
			'Loading: '..tostring(loading),
		}
		local complete_msg = table.concat(msg,'\n')
		
		love.graphics.print( complete_msg ,0,0)
	end
end