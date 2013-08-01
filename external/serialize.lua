--[[
**Modified for LOVE**

	Save Table to File
	Load Table from File
	v 1.0
	
	Lua 5.2 compatible
	
	Only Saves Tables, Numbers, Strings, and Booleans
	Insides Table References are saved
	Does not save Userdata, Metatables, Functions and indices of these
	----------------------------------------------------
	successful,errmsg = save( table,filename )
	
	----------------------------------------------------
	table = load( filename )
	
	----------------------------------------------------
	
	Licensed under the same terms as Lua itself.
]]--
-- declare local variables
--// exportstring( string )
--// returns a "Lua" portable version of the string
local function exportstring( s )
	return string.format("%q", s)
end

local function createSubDir(path)
	local dir,name,ext = path:match('^(.-)([^\\/]-)%.?([^\\/%.]*)$')
	if #name == 0 then name = ext; ext = '' end
	local dirpath = ''
	for subfolder in dir:gmatch('([^\\/]-[\\/])') do
		dirpath = dirpath..subfolder
		if love.filesystem.isFile(dirpath) then
			return 'Cannot save table, '..dirpath..' is a file'
		end
		if not love.filesystem.exists(dirpath) then
			love.filesystem.mkdir(dirpath)
		end
	end
end

local insert = function(t,v)
	if t.len then
		t.len = t.len+1
		t[t.len] = v
		return
	end
	table.insert(t,v)
end

local s = {}

--// The Save Function
function s.save( tbl,filename )
	local charS,charE = "\t","\n"
	
	local err = createSubDir(filename)
	if err then return nil,err end
	
	local file = love.filesystem.newFile(filename)
	file:open('w')

	-- initiate variables for save procedure
	local tables,lookup = { tbl; len = 1 },{ [tbl] = 1 }
	file:write( "return {"..charE )

	for idx,t in ipairs( tables ) do
		file:write( "-- Table: {"..idx.."}"..charE )
		file:write( "{"..charE )
		local thandled = {}

		for i,v in ipairs( t ) do
			thandled[i] = true
			local stype = type( v )
			-- only handle value
			if stype == "table" then
				if not lookup[v] then
					insert( tables, v )
					lookup[v] = #tables
				end
				file:write( charS.."{"..lookup[v].."},"..charE )
			elseif stype == "string" then
				file:write(  charS..exportstring( v )..","..charE )
			elseif stype == "number" or stype == 'boolean' then
				file:write(  charS..tostring( v )..","..charE )
			end
		end

		for i,v in pairs( t ) do
			-- escape handled values
			if (not thandled[i]) then
			
				local str = ""
				local stype = type( i )
				-- handle index
				-- if stype == "table" then
					-- if not lookup[i] then
						-- insert( tables,i )
						-- lookup[i] = #tables
					-- end
					-- str = charS.."[{"..lookup[i].."}]="
				if stype == "string" then
				-- elseif stype == "string" then
					str = charS.."["..exportstring( i ).."]="
				elseif stype == "number" or stype == 'boolean' then
					str = charS.."["..tostring( i ).."]="
				end
			
				if str ~= "" then
					stype = type( v )
					-- handle value
					if stype == "table" then
						if not lookup[v] then
							insert( tables,v )
							lookup[v] = #tables
						end
						file:write( str.."{"..lookup[v].."},"..charE )
					elseif stype == "string" then
						file:write( str..exportstring( v )..","..charE )
					elseif stype == "number" or stype == 'boolean' then
						file:write( str..tostring( v )..","..charE )
					end
				end
			end
		end
		file:write( "},"..charE )
	end
	file:write( "}" )
	file:close()
	
	return true
end

--// The Load Function
function s.load( filename )
	if not love.filesystem.exists(filename) then return end
	local tables = love.filesystem.load(filename)()
	for idx = 1,#tables do
		local tolinki = {}
		for i,v in pairs( tables[idx] ) do
			if type( v ) == "table" then
				tables[idx][i] = tables[v[1]]
			end
			if type( i ) == "table" and tables[i[1]] then
				insert( tolinki,{ i,tables[i[1]] } )
			end
		end
		-- link indices
		for _,v in ipairs( tolinki ) do
			tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
		end
	end
	return tables[1]
end

return s

-- ChillCode