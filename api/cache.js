/**
 * Simple in-memory cache for API responses
 * Reduces calls to external CricAPI to avoid rate limiting
 */

const cache = new Map();

export function getCached(key) {
  const entry = cache.get(key);
  if (!entry) return null;

  const now = Date.now();
  const age = now - entry.timestamp;

  // Return cached data if still fresh (within TTL)
  if (age < entry.ttl) {
    console.log(`[cache] HIT for "${key}" (age: ${Math.round(age / 1000)}s)`);
    return entry.data;
  }

  // Cache is stale, remove it
  cache.delete(key);
  console.log(`[cache] STALE for "${key}" (age: ${Math.round(age / 1000)}s)`);
  return null;
}

export function setCached(key, data, ttlSeconds = 3600) {
  cache.set(key, {
    data,
    timestamp: Date.now(),
    ttl: ttlSeconds * 1000,
  });
  console.log(`[cache] SET "${key}" with TTL ${ttlSeconds}s`);
}
