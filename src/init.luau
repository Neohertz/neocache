--!strict
--!optimize 2

--[=[
	A fast, factory based cache system for roblox.

	By default, neocache acts like a ring buffer. This behavior is useful for lightning-fast one-off sound effects or particles.
	
	Neocache also has support for "using", similar to PartCache. 

	Written by Neohertz.
]=]

local neocache = {}
neocache.__index = neocache

--[=[
	Constants
]=]
local ERROR = {
	NO_SELF = "[Cache] Self was not provided. Did you mean to call this method with ':'?",
}

local emptyFunction = function() end

--[=[
	Types
]=]

type NeoCacheInternal<T> = {
	__internal: {
		__bin: { [number]: T },
		__size: number,
		__buffer: number,
		__lockedIndices: { [number]: true | nil },
		__pointer: number,
		__factory: () -> T,
		__cleanup: (obj: T) -> (),
	},
}

export type NeoCache<T> = typeof(setmetatable({} :: NeoCacheInternal<T>, neocache))

--[=[
	Fetch or create the instance at the current pointer location.
]=]
function __getOrCreate<T>(self: NeoCache<T>): T
	local bin = self.__internal.__bin :: any
	local factory = self.__internal.__factory
	local pointer = self.__internal.__pointer + 1

	if bin[pointer] == nil then
		bin[pointer] = factory()
	end

	return bin[pointer]
end

function __deleteIndex(self: NeoCache<any>, idx: number): ()
	local ref = self.__internal.__bin[idx]

	if ref == nil then
		return
	end

	self.__internal.__cleanup(ref)
	self.__internal.__bin[idx] = nil
end

--[=[
	Default cleanup method for use by cache instances.
]=]
function __defaultCleanup(ref: unknown)
	if typeof(ref) == "Instance" then
		ref:Destroy()
	end
end

--[=[
	Create a new instance of the cache system.

	@param size The max number of items the cache will hold.
	@param buffer Number of items to be populated at creation.
]=]
function neocache.new<T>(factory: () -> T, size: number, buffer: number?): NeoCache<T>
	buffer = buffer ~= nil and buffer or 0
	assert(size >= buffer, `[Cache] Buffer ({buffer}) cannot exceed the size ({size}).`)

	local self = {} :: NeoCache<T>
	self.__internal = {
		__cleanup = __defaultCleanup,
		__lockedIndices = {},
		__buffer = buffer,
		__bin = table.create(size),
		__size = size,
		__pointer = 0,
		__factory = factory,
	}

	local meta = setmetatable(self, neocache) :: any

	-- Populate the buffer with default values, then return pointer to zero.
	for i = 1, buffer do
		neocache.next(meta)
	end
	meta.__internal.__pointer = 0

	return meta
end

--[=[
	Pass a custom cleanup method. This method is invoked whenever the cache is cleared or resized.
	
	Useful when caching non-instance objects.
]=]
function neocache.useCleanupMethod<T>(self: NeoCache<T>, fn: (obj: T) -> ()): NeoCache<T>
	self.__internal.__cleanup = fn
	return self
end

--[=[
	Retrieve or create the next **availible** object in the cache. Will not return entries that are currently in use.

	Will return nil if no objects are found.
]=]
function neocache.next<T>(self: NeoCache<T>): T?
	assert(getmetatable(self), ERROR.NO_SELF)

	local result: T
	local internal = self.__internal

	-- Find the next unlocked index.
	for i = 1, self.__internal.__size do
		local idx = (internal.__pointer % internal.__size)
		local lock = internal.__lockedIndices[idx]

		if lock == nil then
			result = __getOrCreate(self)
		end

		internal.__pointer = (internal.__pointer + 1) % internal.__size

		if result then
			break
		end
	end

	return result
end

--[=[
	Returns the first instance that isn't already in use (locked). This will prevent this instance from showing up in `next()` calls until it's released.
]=]
function neocache.lockNext<T>(self: NeoCache<T>): (T?, () -> ())
	assert(getmetatable(self), ERROR.NO_SELF)

	local next = neocache.next(self)
	if next == nil then
		return nil, emptyFunction
	end
	-- we know that this must be the next idx at all times.
	local nextIDX = (self.__internal.__pointer - 1) % self.__internal.__size
	self.__internal.__lockedIndices[nextIDX] = true

	return next, function()
		self.__internal.__lockedIndices[nextIDX] = nil
	end
end

--[=[
	Get a unique, non cached instance from the cache's factory. 
]=]
function neocache.unique<T>(self: NeoCache<T>): T
	assert(getmetatable(self), ERROR.NO_SELF)

	return self.__internal.__factory()
end

--[=[
	Look at the current index in the cache.

	Optional `at` paramter for peeking at a specific index.

	@returns object, isLocked
]=]
function neocache.peek<T>(self: NeoCache<T>, at: number?): (T, boolean)
	assert(getmetatable(self), ERROR.NO_SELF)
	at = at ~= nil and at or self.__internal.__pointer + 1
	return self.__internal.__bin[at], self.__internal.__lockedIndices[self.__internal.__pointer] == true
end

--[=[
	Clear the cache and cleanup any created instances, reguardless if they are locked or not.
]=]
function neocache.clear(self: NeoCache<any>): ()
	assert(getmetatable(self), ERROR.NO_SELF)

	for i, inst in self.__internal.__bin do
		__deleteIndex(self, i)
	end

	self.__internal.__lockedIndices = {}
	self.__internal.__bin = {}
end

--[=[
	Resize the cache. This operation is destructive on shrink.

	Size will always be greater than zero reguardless of passed value.

	Automatically repopulates the cache with the existing or provided buffer.
]=]
function neocache.resize(self: NeoCache<any>, newSize: number, buffer: number?): ()
	assert(getmetatable(self), ERROR.NO_SELF)
	newSize = math.max(1, newSize)

	-- Assign buffer if nessesary.
	if buffer ~= nil then
		assert(newSize >= buffer, `[Cache] (Resize) Buffer ({buffer}) cannot exceed the size ({newSize}).`)
		self.__internal.__buffer = buffer
	end

	-- Ensure that size is not the same.
	if newSize == self.__internal.__size then
		return
	end

	local bin = self.__internal.__bin

	self.__internal.__size = newSize

	if #bin > newSize then
		-- shrink the bin
		for i = #bin, newSize + 1, -1 do
			self.__internal.__lockedIndices[i - 1] = nil
			__deleteIndex(self, i)
		end
	else
		for i = #bin + 1, newSize do
			if i <= self.__internal.__buffer then
				self.__internal.__pointer = i - 1 -- pointer is 0-index
				__getOrCreate(self)
			else
				break -- nothing left to do
			end
		end
	end

	-- Align pointer
	if self.__internal.__pointer > newSize - 1 then
		self.__internal.__pointer = math.max(newSize - 1, 0)
	end
end

--[=[
	Release all in-use (locked) objects.
]=]
function neocache.releaseAll(self: NeoCache<any>): ()
	assert(getmetatable(self), ERROR.NO_SELF)
	self.__internal.__lockedIndices = {}
end

--[=[
	Destroy the cache and all associated objects. Any subsequent calls to this cache object will error.
]=]
function neocache.destroy(self: NeoCache<any>): ()
	assert(getmetatable(self), ERROR.NO_SELF)

	neocache.clear(self)
	self.__internal = nil :: any
	setmetatable(self, nil)
end

return neocache
