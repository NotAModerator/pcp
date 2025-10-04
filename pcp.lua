--[[
	Ping (NOT Port!) Control Protocol (PCP)
	Manages pings like TCP and acts as its own Promise API, making pings more reliable.
	
	docs:
	- api.onTransfer(id, func): table
		- id: Name or identifier for this connection.
		- func: Function that api.transfer will callback to once the transfer completes.
		NOTE: this function MUST be called globally for PCP to have a valid destination.
	- api.transfer(conn, bytes, size, freq): nil
		- conn: Table returned from api.open(). Not to be confused with id.
		- bytes: String/table bytearray that will be transferred.
		- size: Size in bytes of each packet minus some packet headers.
		- delay: Delay measured in ticks between packets sent. Recommended to be above 20 ticks or be proportional to size for optimal performance.
	- api.toByteArray(str): table
		- str: string byteArray to convert to a table.concat
	- api.toStringByteArray(table): string
		- table: table of bytes to convert to string byteArray.
]]

local api, connections = {}, {}

function api.toStringByteArray(tbl)
	local str = ""
	for _, b in pairs(tbl) do
		str = str .. string.char(b)
	end
	return str
end

function api.toByteArray(b)
	if type(b) == "table" then return b end
	return {string.byte(b, 1, #b)}
end

local function intLength(int)
	local buf = data:createBuffer()
	buf:writeInt(int)
	buf:setPosition(0)
	local length = buf:getLength()
	buf:close()
	return length
end

function pings.transfer(id, b, i)
	local conn = connections[id]
	if not b then
		local byteArray = {}
		for _, packet in pairs(conn.recv) do
			for i = 1, #packet do
				table.insert(byteArray, packet[i])
			end
		end
		conn.func(byteArray)
		conn.packets, conn.recv = {{}}, {}
	else
		conn.recv[i] = api.toByteArray(b)
	end
end

function api.onTransfer(id, func)
	connections[id] = {id = id, packets = {{}}, recv = {}, func = func}
	return connections[id]
end

function api.transfer(conn, b, size, delay)
	local uuid, byteArray = client:intUUIDToString(client:generateUUID()), api.toByteArray(b)
	for i, b in ipairs(byteArray) do
		if i % (math.clamp(size, 1, 1000) - intLength(#conn.packets + 1) + #api.toByteArray(conn.id) + 3) == 0 then 
			table.insert(conn.packets, {})
		end
		table.insert(conn.packets[#conn.packets], b)
	end
	conn.sent = 1
	events.tick:register(function()
		if world:getTime() % delay == 0 then
			if #conn.packets > 1 then
				if conn.sent < #conn.packets then
					if conn.recv[conn.sent] then conn.sent = conn.sent + 1 end
					pings.transfer(conn.id, api.toStringByteArray(conn.packets[conn.sent]), conn.sent)
				else
					pings.transfer(conn.id)
					events.tick:remove(uuid)
				end
			else
				if conn.recv[conn.sent] then 
					pings.transfer(conn.id)
					events.tick:remove(uuid)
				else
					pings.transfer(conn.id, api.toStringByteArray(conn.packets[conn.sent]), conn.sent)
				end
			end
		end
	end, uuid)
end

return api