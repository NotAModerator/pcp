--pcp v0.1.5
local api, funcTbl, queue = {}, {}, {}

local function toChunks(tbl)
	local str, _tbl = string.char(table.unpack(tbl)), {}
	for i = 1, #str, 255 do table.insert(_tbl, str:sub(i, i + 254)) end
	return _tbl
end

local function getFuncId(id)
	for i = 1, #funcTbl do
		if funcTbl[i].id == id then return i end
	end
	return 0
end

local function getVacant(tbl)
	for k, v in pairs(tbl) do
		if not v.c then return k end
	end
	return 1
end

local function tableSum(tbl)
	local sum = 0
	for i = 1, #tbl do sum = sum + tbl[i] end
	return sum
end

local function equalTables(a, b)
	if #a ~= #b then return false end
	for k, v in pairs(a) do
		if v ~= b[k] then return end
	end
	return true
end

function table.iconcat(tbl)
	local str = ""
	for _, v in pairs(tbl) do str = str .. v end
	return str
end

local function packetBuilder(tbl)
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
				if not funcTbl[f].recv[channel] then 
					funcTbl[f].recv[channel] = {t = false, c = {}, decay = 0}
				end
				funcTbl[f].recv[channel].c[idx] = raw
				local sum = buf:readLong()
				local _raw = funcTbl[f].cache[tostring(sum)] or {
					raw = {string.byte(table.iconcat(funcTbl[f].recv[channel].c), 1, -1)}
				}
				_raw.plr = world.getPlayers()
				if not funcTbl[f].recv[channel].t then
					local _sum = tableSum(_raw.raw)
					if _sum == sum then
						funcTbl[f].callback(_raw.raw)
						funcTbl[f].cache[tostring(sum)] = _raw
						funcTbl[f].recv[channel].t = true
					else
						funcTbl[f].callback(nil, _sum / sum * 100)
					end
				end
				funcTbl[f].recv[channel].decay = 0
			else
				funcTbl[f].callback({string.byte(raw, 1, -1)})
			end
		end
	end
	buf:close()
end

function pings.sync(f, key) 
	funcTbl[f].callback(funcTbl[f].cache[key].raw)
end

function api.register(id, func, sticky)
	table.insert(funcTbl, {
		id = id,
		callback = func,
		recv = sticky and {} or nil,
		cache = {}
	})
end

function api.transfer(id, byteArray, timeout, interval)
	local _id, sum = getFuncId(id), tableSum(byteArray, 1, -1)
	if _id > 0 then
		local channel = 0
		if funcTbl[_id].recv then
			local cacheIdx = funcTbl[_id].cache[tostring(sum)]
			if cacheIdx and equalTables(cacheIdx.plr, world.getPlayers()) then
				pings.sync(_id, tostring(sum))
				return
			end
			channel = getVacant(funcTbl[_id].recv) + 1
		end
		table.insert(queue, {
			func = _id,
			channel = funcTbl[_id].recv and channel or 0,
			idx = 1,
			chunks = toChunks(byteArray),
			timeout = math.clamp(timeout, 1, 20) or 1,
			interval = interval or 1,
			sum = sum
		})
	end
end

function events.tick()
	if host:isHost() then
		local tbl, length = {}, 0
		for i, v in pairs(queue) do
			if world:getTime() % v.interval == 0 then
				if length + #v.chunks[v.idx] < 997 then
					table.insert(tbl, {
						sum = v.sum,
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
	for _, v in pairs(funcTbl) do
		if not v.recv then return end
		for i, channel in pairs(v.recv) do
			if channel.decay then
				channel.decay = channel.decay + 1
				if channel.decay > 20 then v.recv[i] = nil end
			end
		end
	end
end

return api