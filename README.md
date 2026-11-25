# ping++ v1.0
Implements features to allow for more performance in Figura's pings API.

# Installation
- 1: Download `pingpp.lua` and move it to your avatars' folder.
- 2: Go to `script.lua` or any script you may have set to run automatically and insert the following snippet. (Recommended to include at the beginning of your script.)
```lua
local pingpp = require("pingpp")
 ```

# Documentation

## register(id, func, chunked, sticky)
Creates a function to callback to when a transfer pointing to it is finished.
  - `id`: Name or identifier of the callback.
  - `func`: Function that gets called once the transfer finishes. Accepts a few arguments:
	- `byteArray`: Table byteArray of the data provided from `transfer`. Is `nil` until it has finished.
  - `chunked`: Boolean to set whether to save incoming chunks of data to a table or use the regular ping behaviour.
  - `sticky`: Boolean to toggle whether the final result should be cached for later use.
> [!NOTE]
> - This function should be ran **before** starting a transfer, and should be ran **globally**, meaning that it should be in a function or event that every client will trigger on runtime.
> -  `sticky` is only applicable if the data sent by a transfer has already been stored on others clients; will only take effect once the bytearray of choice has already been uploaded. This does not persist across reloads/relogs.

## send(id, byteArray, timeout, interval)
Initiates the transfer of data. Will callback to `func` when finished.
  - `id`: Identifier for a callback created in register().
  - `byteArray`: Table byteArray of the data you wish to send.
  - `timeout`: Amount of times to retry sending all data before terminating the transfer.
  - `interval`: Time in ticks between packets. Values above 12 or proportional to the data size perform best.

## setSizeLimit(x)
Sets the maximum limit in bytes a ping/packet can be before holding data in the queue.
  - `x`: Number of bytes each ping can be. Default is 1024.
> [!WARNING]
> This is only applicable if you have raised upload/ping limits on your avatar, and should NOT be used otherwise.

 # Example

```lua
local pingpp = require("pingpp") --require ping++

pingpp.register("myCallback", function(byteArray)
	log("Total bytes sent:", #byteArray) 
end, true) --register a new function under the ID "myCallback", with the chunked flag enabled

keybinds:newKeybind("send", "key.keyboard.enter"):onPress(function()
	local buf, stream = data:createBuffer(), resources:get("resources/avatar.png")
	buf:readFromStream(stream)
	buf:setPosition(0)
	local raw = {string.byte(buf:readByteArray(), 1, -1)} --turn string bytearray into table
	pingpp.send("myCallback", raw, 2, 7) --send bytearray at a rate of 1 ping/7gt, and retrying twice
	buf:close()
end)
```
