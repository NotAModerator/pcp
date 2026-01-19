--pcp v0.1.2
local api, funcTbl, queue = {}, {}, {}

function toChunks(tbl)
	local str, _tbl = string.char(table.unpack(tbl)), {}
	for i = 1, #str, 255 do table.insert(_tbl, str:sub(i, i + 254)) end
	return _tbl
end

function getFuncId(id)
	for i = 1, #funcTbl do
		if funcTbl[i].id == id then return i end
	end
	return 0
end

function getMaxIdx(tbl)
	local max = 0
	for k, _ in ipairs(tbl) do
		if max < k then max = k end
	end
	return max
end

function tableSum(tbl)
	local sum = 0
	for i = 1, #tbl do sum = sum + tbl[i] end
	return sum
end

function packetBuilder(tbl)
	local buf = data:createBuffer()
	buf:write(#tbl)
	for i = 1, #tbl do
		buf:write(#tbl[i].dat)
		buf:writeByteArray(tbl[i].dat)
		buf:write(tbl[i].func)
		buf:write(tbl[i].channel)
		buf:write(tbl[i].idx)
		buf:writeLong(tbl[i].sum)
	end
	buf:setPosition(0)
	local raw = buf:readByteArray()
	buf:close()
	return raw
end

function pings.transfer(packet)
	local buf = data:createBuffer()
	buf:writeByteArray(packet)
	buf:setPosition(0)
	for i = 1, buf:read() do
		local raw, f = buf:readByteArray(buf:read()), buf:read()
		local channel, idx = buf:read(), buf:read()
		if funcTbl[f] then
			if funcTbl[f].recv then
				funcTbl[f].recv[channel] = funcTbl[f].recv[channel] or {}
				funcTbl[f].recv[channel][idx] = raw
				local sum = buf:readLong()
				local _raw = {string.byte(table.concat(funcTbl[f].recv[channel]), 1, -1)}
				if tableSum(_raw) == sum then
					funcTbl[f].callback(_raw)
					funcTbl[f].recv[channel] = nil
				end
			else
				funcTbl[f].callback({string.byte(raw, 1, -1)})
			end
		end
	end
	buf:close()
end

function api.register(id, func, sticky)
	table.insert(funcTbl, {
		id = id,
		callback = func,
		recv = sticky and {} or nil
	})
end

function api.transfer(id, byteArray, timeout, interval)
	local _id = getFuncId(id)
	if _id > 0 then
		local channel = 0
		if funcTbl[_id].recv then
			channel = getMaxIdx(funcTbl[_id].recv) + 1
			funcTbl[_id].recv[channel] = {}
		end
		table.insert(queue, {
			func = _id,
			channel = funcTbl[_id].recv and channel or 0,
			idx = 1,
			chunks = toChunks(byteArray),
			timeout = timeout or 1,
			interval = interval or 1
		})
	end
end

function events.tick()
	if host:isHost() then
		local tbl, length = {}, 0
		for i, v in pairs(queue) do
			if world:getTime() % v.interval == 0 then
				if length + #v.chunks[v.idx] < 997 then
					local sum = 0
					for i = 1, #v.chunks do
						sum = sum + tableSum({string.byte(v.chunks[i], 1, -1)}) 
					end
					table.insert(tbl, {
						sum = sum,
						func = v.func,
						channel = v.channel,
						idx = v.idx,
						dat = v.chunks[v.idx]
					})
					v.idx, length = v.idx + 1, length + #v.chunks[v.idx]
				end
				if v.idx > #v.chunks then
					v.idx, v.timeout = 1, v.timeout - 1
					if v.timeout < 1 then queue[i] = nil end
				end
			end
		end
		local packet = packetBuilder(tbl)
		if #packet > 4 then pings.transfer(packet) end
	end
end

return api