# Neocache

A blazingly fast caching module for instances and beyond.

> [!WARNING]
> Neocache is pre v1.0 software. You may encounter bugs.

## Example Usage

```lua
local audioCache = neocache.new(function()
	local sfx = Instance.new("Sound")
	sfx.Parent = SoundService
	return sfx
end, 100, 10)

function playSoundEffect(id: string)
	local sound = audioCache:next()
	sound.SoundID = id
	sound:Play()
end
```

## Behavior

Neocache acts like a ring buffer. Whenever `:next()` or `lockNext()` is invoked, it will increment the pointer to find the next available instance. If it doesn't exist, it will just create it.

Neocache also has support for locking, allowing you to "check out" a result from the cache, modify it, then return it once done. While an entry is locked, it will be skipped in all future `next() / lockNext()` calls.

## Install

### Wally

Get the latest version from [Wally](https://wally.run/package/neohertz/neocache).

```toml
# wally.toml
neocache = "neohertz/neocache@x.x.x"
```

### Typescript (Roblox-TS)

Install neocache via npm. (coming soon)

```sh
npm i @rbxts/neocache
```

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

### `cache:next(fast: boolean?)`

Get a reference to the next **available** item in the cache and increment the internal pointer.

If `fast` is true, the cache will grab the next item in the queue. If this item is locked, `:next(true)` will return nil.

```lua
local sound = audioCache:next()

if sound then
	sound:Play()
end
```

### `cache:lockNext()`

Same thing as `cache:next()`, but this instance is locked until the returned unlock method is invoked.

While this item is locked or _"checked out"_, it will be skipped in any future `next()` or `lockNext()` calls.

If `optimize` is true, released keys will be cached internally to make iteration quicker. This can provide faster queries within large caches.

> This is useful if you want to prevent overlapping operations on a specific item in the cache.

```lua
local sound, release = audioCache:lockNext()

if sound then
	sound:Play()
	sound.Ended:Once(function()
		release()
	end)
end
```

### `cache:unique()`

Grab a unique, non cached instance from the factory.

```lua
local uniqueSoundEffect = audioCache:unique()
```

### `cache:peek()`

View the next item in the cache.

```lua
local ref = audioCache:peek()
```

### `cache:resize(newSize: number, newBuffer: number?)`

Resize the cache. This operation is destructive on shrinking.

If the cache grows to a size below the buffer, those items will be immediately generated.

```lua
-- Current Size: 100 | Current Buffer: 10
-- 5 deletions guaranteed, 90 possible.
cache:resize(5)

-- Current Size: 5 | Current Buffer: 10
-- 5 factory invocations guaranteed.
cache:resize(10)
```

### `cache:clear()`

Entirely wipe the cache. Invokes the cleanup method. Neocache will automatically regenerate the objects upon subsequent `next()` or `lockNext()` calls.

```lua
audioCache:clear()
audioCache:next() -- invokes factory.
```

### `cache:useCleanupMethod<T>(fn: (obj: T) -> ())`

Override the default cleanup method with a custom one. This method will be invoked by both `cache:clear()` and `cache:destroy()`.

Useful when using non-instance items within the cache.

```lua
cache:useCleanupMethod(function(table: MyTable)
	table:Cleanup()
end)
```

### `cache:destroy()`

Destroy the cache and any instances within entirely.
Subsequent calls to this cache will error.

```lua
cahce:destroy()
cache:next() -- ❌ error!
```
