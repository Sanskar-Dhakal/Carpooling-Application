const jwt = require('jsonwebtoken');
const pool = require('../config/database');

const authenticate = async (req, res, next) => {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'No token provided' });
    }
    const token = header.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const { rows } = await pool.query(
      'SELECT id,name,email,phone,role,is_verified,rating FROM users WHERE id=$1',
      [decoded.id]
    );
    if (!rows.length) return res.status(401).json({ message: 'User not found' });

    req.user = rows[0];
    next();
  } catch (err) {
    const msg = err.name === 'TokenExpiredError' ? 'Token expired' : 'Invalid token';
    return res.status(401).json({ message: msg });
  }
};

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

module.exports = { authenticate, requireAdmin, requireDriver };
