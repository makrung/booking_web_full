const admin = require('../../config/firebase');

// Simple in-memory cache with TTL
const _cache = new Map();
const DEFAULT_TTL_MS = 60 * 1000; // 1 minute

/**
 * Get a setting value from Firestore collection `settings` (doc id = key).
 * The document shape is expected: { value: any }
 * Will return defaultValue if not found.
 * Cached for a short TTL to reduce reads.
 */
async function getSettingValue(key, defaultValue = null, { ttlMs = DEFAULT_TTL_MS } = {}) {
  const now = Date.now();
  const cached = _cache.get(key);
  if (cached && (now - cached.ts) < (cached.ttlMs ?? ttlMs)) {
    return cached.value;
  }
  try {
    const db = admin.firestore();
    const doc = await db.collection('settings').doc(key).get();
    if (doc.exists) {
      const data = doc.data() || {};
      const val = (typeof data.value === 'undefined') ? defaultValue : data.value;
      _cache.set(key, { value: val, ts: now, ttlMs });
      return val;
    }
  } catch (e) {
    // swallow and fallback
  }
  _cache.set(key, { value: defaultValue, ts: now, ttlMs });
  return defaultValue;
}

/**
 * Convenience numeric getter with parsing and default fallback
 */
async function getNumericSetting(key, defaultNumber, opts) {
  const v = await getSettingValue(key, defaultNumber, opts);
  if (typeof v === 'number') return v;
  if (typeof v === 'string') {
    const n = Number(v.trim());
    return Number.isFinite(n) ? n : defaultNumber;
  }
  return defaultNumber;
}

/**
 * Convenience boolean getter with parsing and default fallback
 */
async function getBooleanSetting(key, defaultBool, opts) {
  const v = await getSettingValue(key, defaultBool, opts);
  if (typeof v === 'boolean') return v;
  if (typeof v === 'string') {
    const s = v.trim().toLowerCase();
    if (s === 'true' || s === '1' || s === 'yes' || s === 'on') return true;
    if (s === 'false' || s === '0' || s === 'no' || s === 'off') return false;
  }
  if (typeof v === 'number') return v !== 0;
  return !!defaultBool;
}

/**
 * Clear cache for a specific key or all keys
 */
function clearCache(key = null) {
  if (key) {
    _cache.delete(key);
    return { cleared: key };
  }
  const size = _cache.size;
  _cache.clear();
  return { cleared: 'all', count: size };
}

module.exports = {
  getSettingValue,
  getNumericSetting,
  getBooleanSetting,
  clearCache,
};
