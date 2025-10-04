# Ping Control Protocol (PCP)
Manages Figura pings similar to TCP, making them easier to use for larger sets of data.

# Installation
- 1: Download `pcp.lua` and move it to your avatars' folder.
- 2: Go to `script.lua` or any script you may have set to run automatically and insert the following snippet. (Recommended to include at the beginning of your script.)
```lua
local animatedText = require("pcp")
 ```

# Documentation

## onTransfer(id, func)
Creates a table that will be used to contain outgoing packets from pings. Returns itself when finished.
  - `id`: Name or identifier of the connection.
  - `func`: Function that gets called once the transfer finishes. Accepts a table byteArray as an argument.
> [!NOTE]
> This function should be ran **before** starting a transfer, and should be ran **globally** (Meaning that it should be in a function or event that every client will trigger) or inside of a ping.

## transfer(id, conn, bytes, size, delay)
Initiates the transfer of data. Will callback to `func` when finished.
  - `conn`: Table of the connection made by onTransfer().
  - `bytes`: Table or string byteArray of the data you wish to send.
  - `size`: Size in bytes of each packet minus some extra bytes for headers.
  - `delay`: Time in ticks between packets. Recommended to be above 20 or be proportional to the packet size for best performance.

 # Example

```lua
local pcp = require("pcp")
local promise = require("./scripts/Promise") --make networking easier, optional to be alongside pcp

--create the connection that pings will be sent to
local conn = pcp.onTransfer("myConnection", function (byteArray)
	log("Successfully sent " .. #byteArray .. " bytes.")
end)

--trigger a transfer of texture data
local request = net.http:request("https://static.planetminecraft.com/files/resource_media/screenshot/1411/2014-03-15_042718.jpg"):method("GET")
promise.await(request:send()), 5000):then_(function(stream)
	local buf = data:createBuffer(stream:available())
	buf:readFromStream(stream)
	buf:setPosition(0)
	local raw = buf:readByteArray()
	pcp.transfer(conn, pcp.toByteArray(raw), 800, 21)
	buf:close()
end)
```
