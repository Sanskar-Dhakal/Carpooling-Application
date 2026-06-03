const bcrypt = require('bcryptjs');
const jwt    = require('jsonwebtoken');
const pool   = require('../../config/database');

const makeTokens = (user) => ({
  token: jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '15m' }
  ),
  refreshToken: jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' }
  ),
});

const fmt = (u) => ({
  id: u.id, name: u.name, email: u.email,
  phone: u.phone, role: u.role,
  is_verified: u.is_verified,
  rating: parseFloat(u.rating) || 0,
  profile_photo_url: u.profile_photo_url || null,
  qr_payment_id:    u.qr_payment_id    || null,
  qr_payment_label: u.qr_payment_label || null,
  qr_payment_image_url: u.qr_payment_image_url || null,
});

// ── Register ──────────────────────────────────────────────
const register = async ({ name, email, phone, password, role }) => {
  const exists = await pool.query('SELECT id FROM users WHERE email=$1', [email]);
  if (exists.rows.length) throw { status: 409, message: 'Email already registered' };

  const hash = await bcrypt.hash(password, 12);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `INSERT INTO users (name,email,phone,password_hash,role)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [name, email, phone, hash, role]
    );
    await client.query('INSERT INTO wallets (user_id) VALUES ($1)', [rows[0].id]);
    await client.query('COMMIT');
    return { user: fmt(rows[0]), ...makeTokens(rows[0]) };
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

// ── Login ─────────────────────────────────────────────────
const login = async ({ email, password }) => {
  const { rows } = await pool.query('SELECT * FROM users WHERE email=$1', [email]);
  if (!rows.length) throw { status: 401, message: 'Invalid email or password' };

  const valid = await bcrypt.compare(password, rows[0].password_hash);
  if (!valid)   throw { status: 401, message: 'Invalid email or password' };

  return { user: fmt(rows[0]), ...makeTokens(rows[0]) };
};

// ── Refresh ───────────────────────────────────────────────
const refresh = async (token) => {
  try {
    const decoded = jwt.verify(token, process.env.JWT_REFRESH_SECRET);
    const { rows } = await pool.query('SELECT * FROM users WHERE id=$1', [decoded.id]);
    if (!rows.length) throw { status: 401, message: 'User not found' };
    return { user: fmt(rows[0]), ...makeTokens(rows[0]) };
  } catch {
    throw { status: 401, message: 'Invalid refresh token' };
  }
};

// ── Get Me ────────────────────────────────────────────────
const getMe = async (id) => {
  const { rows } = await pool.query('SELECT * FROM users WHERE id=$1', [id]);
  if (!rows.length) throw { status: 404, message: 'User not found' };
  return fmt(rows[0]);
};

module.exports = { register, login, refresh, getMe };
