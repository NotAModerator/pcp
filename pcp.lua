--pcp v0.1.0
local api, funcTbl, queue, queueIdx = {}, {}, {}, 0

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

function chunkConcat(tbl)
	local str = ""
	for i = 1, #tbl do
		if tbl[i] then str = str .. tbl[i] end
	end
	return str
end

function packetBuilder(tbl)
	local buf = data:createBuffer()
	buf:write(#tbl)
	for i = 1, #tbl do
		buf:writeUShort(tbl[i].sum)
		for _, v in ipairs(tbl[i].headers) do
			buf:write(v)
		end
		buf:writeUShort(#tbl[i].dat)
		buf:writeByteArray(tbl[i].dat)
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
		local tbl = {buf:readUShort()}
		for i = 1, 3 do table.insert(tbl, buf:read()) end
		table.insert(tbl, buf:readUShort())
		if funcTbl[tbl[2]].recv then
			funcTbl[tbl[2]].recv[tbl[3]] = funcTbl[tbl[2]].recv[tbl[3]] or {}
			funcTbl[tbl[2]].recv[tbl[3]][tbl[4]] = buf:readByteArray(tbl[5])
			if #funcTbl[tbl[2]].recv[tbl[3]] >= tbl[1] then
				funcTbl[tbl[2]].callback({
					string.byte(chunkConcat(funcTbl[tbl[2]].recv[tbl[3]]), 1, -1)
				})
				funcTbl[tbl[2]].recv[tbl[3]] = nil
			end
		else
			funcTbl[tbl[2]].callback({
				string.byte(buf:readByteArray(tbl[5]), 1, -1)
			})
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
		table.insert(queue, {
			func = _id,
			channel = funcTbl[_id].recv and #funcTbl[_id].recv + 1 or 0,
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
		for i, v in ipairs(queue) do
			if world.getTime() % v.interval == 0 then
				if length < 1024 then
					table.insert(tbl, {
						sum = #v.chunks,
						headers = {v.func, v.channel, v.idx},
						dat = v.chunks[v.idx]
					})
					v.idx, length = v.idx + 1, length + #v.chunks[v.idx]
					if v.idx > #v.chunks then
						v.idx, v.timeout = 1, v.timeout - 1
						if v.timeout < 1 then queue[i] = nil end
					end
				else
					queueIdx = queueIdx < #queue and i or 1
				end
			end
		end
		local packet = packetBuilder(tbl)
		if #packet > 4 then pings.transfer(packet) end
	end
end

return api