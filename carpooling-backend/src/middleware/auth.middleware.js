const jwt  = require('jsonwebtoken');
const pool = require('../config/database');
const { getJson, setJson, del, getPp, setPp, delPp } = require('../config/redis');

// Cache TTL for user rows: 5 minutes.
// This is safe because:
//   • Tokens already expire (default 15 m).
//   • We always check is_blocked/is_verified from the cache.
//   • Admin block/unblock calls invalidateUserCache() to clear immediately.
const USER_CACHE_TTL = 300; // seconds

const userCacheKey = (id) => `user:${id}`;

/**
 * Fetch the user row from Redis if present, otherwise hit PostgreSQL
 * and populate the cache for subsequent requests.
 */
const getUser = async (id) => {
  const cached = await getJson(userCacheKey(id));
  if (cached) return cached;

  const { rows } = await pool.query(
    'SELECT id,name,email,phone,role,is_verified,verification_status,is_blocked,rating,profile_photo_url FROM users WHERE id=$1',
    [id],
  );
  if (!rows.length) return null;

  await setJson(userCacheKey(id), rows[0], USER_CACHE_TTL);
  await setPp(id, rows[0]);
  return rows[0];
};

/**
 * Call this whenever a user's block/verify status changes so the next
 * request re-reads from PostgreSQL instead of a stale cache entry.
 */
const invalidateUserCache = (id) => {
  del(userCacheKey(id));
  delPp(id);
};

const authenticateWithOptions = ({ requireVerified = true, allowDocumentReupload = false } = {}) =>
  async (req, res, next) => {
    try {
      const header = req.headers.authorization;
      if (!header?.startsWith('Bearer ')) {
        return res.status(401).json({ message: 'No token provided' });
      }
      const token   = header.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const isDocumentReuploadToken = decoded.purpose === 'document_reupload';

      if (isDocumentReuploadToken && !allowDocumentReupload) {
        return res.status(403).json({ message: 'This session can only reupload verification documents.' });
      }

      // ── Redis-first user lookup (avoids a DB query on every request) ──────
      const user = await getUser(decoded.id);

      if (!user) return res.status(401).json({ message: 'User not found' });

      if (user.is_blocked) {
        return res.status(403).json({ message: 'Your account has been blocked. Please contact admin.' });
      }
      if (isDocumentReuploadToken && !['rejected', 'retake'].includes(user.verification_status)) {
        return res.status(403).json({ message: 'Document reupload is not available for this account.' });
      }
      if (requireVerified && user.role !== 'admin' && user.is_verified !== true) {
        return res.status(403).json({ message: 'Your account is pending admin verification.' });
      }

      req.user = user;
      next();
    } catch (err) {
      const msg = err.name === 'TokenExpiredError' ? 'Token expired' : 'Invalid token';
      return res.status(401).json({ message: msg });
    }
  };

const authenticate = authenticateWithOptions();
const authenticateDocumentReupload = authenticateWithOptions({
  requireVerified: false,
  allowDocumentReupload: true,
});

const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Admin access required' });
  }
  next();
};

const requireDriver = (req, res, next) => {
  if (!['driver', 'both'].includes(req.user.role)) {
    return res.status(403).json({ message: 'Driver access required' });
  }
  next();
};

module.exports = {
  authenticate,
  authenticateDocumentReupload,
  requireAdmin,
  requireDriver,
  invalidateUserCache,
};