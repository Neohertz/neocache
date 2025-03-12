# Neocache
A versatile and preformant cache module for instances and beyond.

## Example Usage
```lua
local audioCache = neocache.new(function()
	local sfx = Instance.new("Sound")
	sfx.Parent = SoundService
	return sfx
end, 100, 10)

function playSoundEffect()
	local sound = audioCache:next()
	sound.SoundID = "rbxassetid//9114092958"
	sound:Play()
end
```

##  Behavior
Neocache acts like a ring buffer. Whenever `:next()` or `lockNext()` is invoked, it will increment the pointer to find the next availible instance. If it doesn't exist, it will just create it.

Neocache also has support for locking, allowing you to "check out" a result from the cache, modifiy it, then return it once done. While an entry is locked, it will be skipped in all future `next() / lockNext()` calls.

# Creating a Cache
`neocache.new(factory: () -> T, size: number, buffer: number?)`
- Factory
	- Invoked whenever the cache needs to create a new instance. Returns a value.
- Size
	- How big the cache should be.
- Buffer
	- Prewarm the cache by populating the first X entries.
```lua
local audioCache = neocache.new(function()
	local sfx = Instance.new("Sound")
	sfx.Parent = SoundService
	return sfx
end, 100, 10)
```

# API
## 