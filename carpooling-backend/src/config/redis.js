const Redis = require('ioredis');
require('dotenv').config();

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT) || 6379,
  retryStrategy: (times) => Math.min(times * 50, 2000),
  lazyConnect: true,
});

redis.on('connect', () => console.log('✅ Redis connected'));
redis.on('error',   (err) => console.error('❌ Redis error:', err.message));

// ── Helpers ────────────────────────────────────────────────────────────────────

/**
 * Get a JSON value from Redis. Returns null on miss or error.
 */
const getJson = async (key) => {
  try {
    const raw = await redis.get(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
};

/**
 * Store a JSON value in Redis with a TTL (seconds).
 * Silently swallows errors so a Redis outage never breaks the app.
 */
const setJson = async (key, value, ttlSeconds) => {
  try {
    await redis.set(key, JSON.stringify(value), 'EX', ttlSeconds);
  } catch {
    // Redis down — no-op, fall through to DB
  }
};

/**
 * Delete one or more keys (accepts a single key or an array).
 * Silently swallows errors.
 */
const del = async (keys) => {
  try {
    const arr = Array.isArray(keys) ? keys : [keys];
    if (arr.length) await redis.del(...arr);
  } catch {
    // no-op
  }
};

/**
 * Delete all keys matching a glob pattern.
 * Uses SCAN so it is safe on large keyspaces.
 */
const delPattern = async (pattern) => {
  try {
    let cursor = '0';
    do {
      const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
      cursor = nextCursor;
      if (keys.length) await redis.del(...keys);
    } while (cursor !== '0');
  } catch {
    // no-op
  }
};

const PP_TTL = 300; // seconds - same as user cache

const ppKey = (id) => `pp:${id}`;

const getPp = async (id) => {
  try {
    const raw = await redis.get(ppKey(id));
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
};

const setPp = async (id, value) => {
  try {
    await redis.set(ppKey(id), JSON.stringify(value), 'EX', PP_TTL);
  } catch {
    // no-op
  }
};

const delPp = async (id) => {
  try {
    await redis.del(ppKey(id));
  } catch {
    // no-op
  }
};

module.exports = { redis, getJson, setJson, del, delPattern, getPp, setPp, delPp };