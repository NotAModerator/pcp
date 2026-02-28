# Ping Control Protocol (PCP) v0.1.4
Implements features to allow for more performance in Figura's pings API.

# Installation
- 1: Download `pcp.lua` and move it to your avatars' folder.
- 2: Go to `script.lua` or any script you may have set to run automatically and insert the following snippet. (Recommended to include at the beginning of your script.)
```lua
local animatedText = require("pcp")
 ```

# Documentation

## register(id, func, sticky)
Creates a function to callback to when a transfer pointing to it is finished.
  - `id`: Name or identifier of the callback. Converted to numerical index; max 255 entries
  - `func`: Function that gets called once the transfer finishes. Accepts a table byteArray as an argument.
  - `sticky`: Boolean to set whether to save incoming chunks of data to a table or use the regular ping behaviour.
> [!NOTE]
> This function should be ran **before** starting a transfer, and should be ran **globally**, meaning that it should be in a function or event that every client will trigger on runtime.

## transfer(id, byteArray, timeout, interval)
Initiates the transfer of data. Will callback to `func` when finished.
  - `id`: Identifier for a callback created in register().
  - `byteArray`: Table byteArray of the data you wish to send.
  - `timeout`: Amount of times to retry sending all data before terminating the transfer.
  - `interval`: Time in ticks between packets. Values above 12 or proportional to the data size perform best.

 # Example

```lua
local pcp = require("pcp")
local promise = require("Promise") --make networking easier, optional to be alongside pcp

--register function(s) to be called once transfer finishes
--a max of 255 transfers can be executed at once and run in parallel due to packet structure, so this should be fairly spam-proof
pcp.register("tex", function(byteArray)
	log("Total bytes sent: ", #byteArray)
end, true)

--trigger transfer for "tex"; retries twice at an interval of 8 ticks before terminating.
local request = net.http:request("https://static.planetminecraft.com/files/resource_media/screenshot/1411/2014-03-15_042718.jpg"):method("GET")
keybinds:newKeybind("myBind", "key.keyboard.enter"):onPress(function()
	promise.await(request:send(), 5000):then_(function(stream)
		local buf = data:createBuffer(stream:available())
		buf:readFromStream(stream)
		buf:setPosition(0)
		local raw = buf:readByteArray()
		pcp.transfer("tex", {string.byte(raw, 1, -1)}, 2, 8) --convert our data to a table byteArray for use.
		buf:close()
	end)
end)
```
