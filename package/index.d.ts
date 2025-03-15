interface Neocache<T> {
	/**
	 * Pass a custom cleanup method. This method is invoked whenever the cache is cleared or resized.
	 *
	 * Useful when caching non-instance objects.
	 *
	 * @param fn `() -> T`
	 */
	useCleanupMethod(fn: Consumer<T>): Neocache<T>;

	/**
	 * Retrieve or create the next **availible** object in the cache. Will not return entries that are currently in use.
	 *
	 * Will return nil if no objects are found.
	 * By default, `next()` can potentially iterate over the entire cache if all objects are locked.
	 *
	 * @param fast Instead of incrementing the pointer until a `released` object is found, the cache will simply return the next object.
	 * @returns T?
	 */
	next(fast?: boolean): T | undefined;

	/**
	 *	Returns the first instance that isn't already in use (reserved). This will prevent this instance from showing up in `next()` calls until it's released.
	 *
	 * @param optimize Optimize for more random workloads by caching released indices.
	 * @param fast Instead of incrementing the pointer until a `released` object is found, the cache will simply return the next object.
	 */
	reserveNext(optimize?: boolean, fast?: boolean): LuaTuple<[T | undefined, Callback]>;

	/**
	 * Get a unique, non cached instance from the cache's factory.
	 * @returns T
	 */
	unique(): T;

	/**
	 * Clear the cache and cleanup any created instances, regardless if they are locked or not.
	 */
	clear(): void;

	/**
	 * Resize the cache. This operation is destructive on shrink.
	 * Size will always be greater than zero regardless of passed value.
	 *
	 * Automatically repopulates the cache (if necessary) with the existing or provided buffer.
	 * @param newSize
	 * @param newBuffer
	 */
	resize(newSize: number, newBuffer?: number): void;

	/**
	 * Increment/decrement the internal cache pointer by (x).
	 *
	 * The pointer's value will be assigned based on the following formula: `(pointer + distance) % size`
	 *
	 * @param distance: `(number)` amount to increment / decrement pointer by.
	 * @returns pointer
	 */
	jumpPointer(distance: number): number;

	/**
	 * Get the current size of the cache.
	 *
	 * @returns size
	 */
	size(): number;

	/**
	 * Move the internal pointer to a specific index.
	 * he pointer's value will be assigned based on the following formula: `location % size`
	 *
	 * @param location
	 * @returns pointer
	 */
	setPointer(location: number): number;

	/**
	 * Release all in-use (reserved) objects.
	 */
	releaseAll(): void;

	/**
	 * Destroy the cache and all associated objects. Any subsequent calls to this cache object will error.
	 */
	destroy(): void;
}

type Factory<T> = () => T;
type Consumer<T> = (obj: T) => void;

interface NeocacheConstructor {
	/**
	 * Create a new instance of the cache system.
	 *
	 * @param factory: Callback that is invoked to create an item within the cache.
	 * @param size: The max number of items the cache will hold.
	 * @param buffer: how many items to cache immediately.
	 */
	new <T>(factory: Factory<T>, size: number, buffer?: number): Neocache<T>;
}

declare const Neocache: NeocacheConstructor;
export default Neocache;
export { Neocache, Factory, Consumer };
