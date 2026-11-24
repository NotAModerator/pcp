local api, registeredCallbacks, queue, sizeLimit = {}, {}, {}, 1024

local function fnv(byteArray)
	local buf, hash = data:createBuffer(), 0x811c9c5
	for i = 1, #byteArray do
		hash = bit32.bxor(hash, byteArray[i])
		hash = hash * 0x01000193
	end
	hash = bit32.bxor(bit32.rshift(hash, 4), bit32.band(hash, 0xFFFFFFFF))
	buf:writeInt(hash)
	buf:setPosition(0)
	hash = buf:readByteArray()
	buf:close()
	return hash
end

local function toChunks(byteArray)
	local tbl = {}
	for i = 1, #byteArray, 255 do table.insert(tbl, {table.unpack(byteArray, i, i + 254)}) end
	return tbl
end

local function arraySum(byteArray)
	local sum = 0
	for _, v in ipairs(byteArray) do sum = sum + v end
	return sum
end

local function getVacant(tbl)
	for i, channel in pairs(tbl.channels) do
		if #channel.chunks == 0 then return i end
	end
	return 1
end

local function matchPlayers(a, b)
	for k, _ in pairs(a) do if not b[k] then return end end
	for k, _ in pairs(b) do if not a[k] then return end end
	return true
end

function pings.send(byteArray)
	local buf = data:createBuffer()
	buf:writeByteArray(byteArray)
	buf:setPosition(0)
	for i = 1, buf:read() do
		local reg = registeredCallbacks[buf:readByteArray(4)]
		local hash = buf:readByteArray(4)
		local sum = buf:readLong()
		local channel = buf:read()
		local idx = buf:readUShort()
		local chunk = buf:readByteArray(buf:read())
		if reg.channels then
			local _sum, _byteArray = 0, ""
			if not reg.channels[channel] then reg.channels[channel] = {chunks = {}} end
			reg.channels[channel].chunks[idx] = chunk
			for _, v in pairs(reg.channels[channel].chunks) do
				_byteArray = _byteArray .. v
				_sum = _sum + arraySum({string.byte(v, 1, -1)})
			end
			if _sum == sum and not reg.channels[channel].closed then
				reg.callback({string.byte(_byteArray, 1, -1)})
				reg.channels[channel].closed = true
				if reg.cache then
					if not reg.cache[hash] then reg.cache[hash] = {} end
					reg.cache[hash][tostring(sum)] = {
						byteArray = _byteArray,
						plr = world.getPlayers()
					}
				end
			end
			reg.channels[channel].decay = 0
		else
			reg.callback({string.byte(chunk, 1, -1)})
		end
	end
	buf:close()
end

function pings.sync(byteArray)
	local buf = data:createBuffer()
	buf:writeByteArray(byteArray)
	buf:setPosition(0)
	local id = buf:readByteArray(4)
	local reg = registeredCallbacks[id]
	local cachedHash, sum = reg.cache[buf:readByteArray(4)], buf:readLong()
	if cachedHash then
		local _byteArray = cachedHash[tostring(sum)].byteArray
		if cachedHash[tostring(sum)] then reg.callback({string.byte(_byteArray, 1, -1)}) end
	end
end

function api.register(id, callback, chunked, sticky)
	registeredCallbacks[fnv({string.byte(id, 1, -1)})] = {
		callback = callback,
		channels = chunked and {},
		cache = sticky and {}
	}
end

function api.send(id, byteArray, retries, interval)
	local _id = fnv({string.byte(id, 1, -1)})
	local reg = registeredCallbacks[_id]
	local hash, sum = fnv(byteArray), arraySum(byteArray)
	if reg.cache then
		local buf = data:createBuffer()
		buf:writeByteArray(_id)
		buf:writeByteArray(hash)
		buf:writeLong(sum)
		buf:setPosition(0)
		local _byteArray = buf:readByteArray()
		buf:close()
		if reg.cache[hash] then
			if matchPlayers(world.getPlayers(), reg.cache[hash][tostring(sum)].plr) then
				pings.sync(_byteArray)
				return
			end
		end
	end
	table.insert(queue, {
		id = _id,
		hash = hash,
		sum = sum,
		chunks = toChunks(byteArray),
		channel = reg.channels and getVacant(reg) or 0,
		idx = 1,
		retries = retries or 1,
		interval = interval and math.clamp(interval, 1, 20) or 1
	})
end

function api.setSizeLimit(x) sizeLimit = x end

function events.tick()
	if host:isHost() then
		local payload, len = {}, 0
		for i, task in pairs(queue) do
			if world:getTime() % task.interval == 0 then
				local buf = data:createBuffer()
				buf:writeByteArray(task.id)
				buf:writeByteArray(task.hash)
				buf:writeLong(task.sum)
				buf:write(task.channel)
				buf:writeUShort(task.idx)
				buf:write(#task.chunks[task.idx])
				buf:setPosition(0)
				local headerLength = buf:getLength()
				buf:setPosition(0)
				if headerLength + #task.chunks[task.idx] <= sizeLimit - 3 then
					table.insert(payload, {
						headers = buf:readByteArray(),
						chunk = string.char(table.unpack(task.chunks[task.idx]))
					})
					task.idx = task.idx + 1
					if task.idx > #task.chunks then
						task.retries, task.idx = task.retries - 1, 1
						if task.retries <= 0 then queue[i] = nil end
					end
				end
				buf:close()
			end
		end
		if #payload > 0 then
			local buf = data:createBuffer()
			buf:write(#payload)
			for i, packet in ipairs(payload) do
				buf:writeByteArray(packet.headers)
				buf:writeByteArray(packet.chunk)
			end
			buf:setPosition(0)
			pings.send(buf:readByteArray())
			buf:close()
		end
	end
	for _, reg in pairs(registeredCallbacks) do
		if reg.channels then
			for i, channel in pairs(reg.channels) do
				channel.decay = channel.decay + 1
				if channel.decay > 20 then reg.channels[i] = nil end
			end
		end
	end
end

return api