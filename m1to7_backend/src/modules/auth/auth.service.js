const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const pool = require('../../config/database');
const storageService = require('../../services/storage.service');
const { ensureUsersProfileSchema } = require('../../services/schema.service');

// ── JWT helpers ───────────────────────────────────────────────────────────────
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

const makeReuploadToken = (user) => jwt.sign(
  { id: user.id, email: user.email, role: user.role, purpose: 'document_reupload' },
  process.env.JWT_SECRET,
  { expiresIn: '30m' }
);

const fmt = (u) => ({
  id: u.id,
  name: u.name,
  email: u.email,
  phone: u.phone,
  role: u.role,
  is_verified: u.is_verified,
  verification_status: u.verification_status || 'none',
  rating: parseFloat(u.rating) || 0,
  profile_photo_url: u.profile_photo_url || null,
  id_document_url: u.id_document_url || null,
  license_document_url: u.license_document_url || null,
  qr_payment_id: u.qr_payment_id || null,
  qr_payment_label: u.qr_payment_label || null,
  qr_payment_image_url: u.qr_payment_image_url || null,
  qr_payment_images: (u.qr_payment_images && typeof u.qr_payment_images === 'object') ? u.qr_payment_images : {},
});

// ── Email transporter (Nodemailer) ────────────────────────────────────────────
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: Number(process.env.SMTP_PORT) || 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

// ── Register ──────────────────────────────────────────────────────────────────
const register = async ({ name, email, phone, password, role, document }) => {
  await ensureUsersProfileSchema();
  const exists = await pool.query('SELECT id FROM users WHERE email=$1', [email]);
  if (exists.rows.length) throw { status: 409, message: 'Email already registered' };

  const hash = await bcrypt.hash(password, 12);
  const documentKey = await storageService.uploadFile(
    'id-documents',
    document.buffer,
    document.originalname,
    document.mimetype,
  );
  const documentUrl = await storageService.getPresignedUrl('id-documents', documentKey);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `INSERT INTO users (
         name,email,phone,password_hash,role,is_verified,verification_status,id_document_url
       )
       VALUES ($1,$2,$3,$4,$5,false,'pending',$6) RETURNING *`,
      [name, email, phone, hash, role, documentUrl]
    );
    await client.query('INSERT INTO wallets (user_id) VALUES ($1)', [rows[0].id]);
    await client.query('COMMIT');
    return {
      message: 'Registration submitted. You can log in after an admin verifies your document.',
      user: fmt(rows[0]),
    };
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

// ── Login ─────────────────────────────────────────────────────────────────────
const login = async ({ email, password }) => {
  const { rows } = await pool.query('SELECT * FROM users WHERE email=$1', [email]);
  if (!rows.length) throw { status: 401, message: 'Invalid email or password' };

  const valid = await bcrypt.compare(password, rows[0].password_hash);
  if (!valid) throw { status: 401, message: 'Invalid email or password' };

  if (rows[0].is_blocked) {
    throw { status: 403, message: 'Your account has been blocked. Please contact admin.' };
  }

  const verificationStatus = rows[0].verification_status || 'pending';
  if (rows[0].role !== 'admin' && rows[0].is_verified !== true) {
    const status = verificationStatus;
    const message = status === 'rejected'
      ? 'Your document has been rejected. Would you like to reupload?'
      : status === 'retake'
        ? 'Admin requested a new document. Would you like to reupload?'
        : 'Your account is pending admin verification.';
    const error = { status: 403, message, verification_status: status };
    if (status === 'rejected' || status === 'retake') {
      error.token = makeReuploadToken(rows[0]);
    }
    throw error;
  }

  return { user: fmt(rows[0]), ...makeTokens(rows[0]) };
};

// ── Refresh ───────────────────────────────────────────────────────────────────
const refresh = async (token) => {
  try {
    const decoded = jwt.verify(token, process.env.JWT_REFRESH_SECRET);
    const { rows } = await pool.query('SELECT * FROM users WHERE id=$1', [decoded.id]);
    if (!rows.length) throw { status: 401, message: 'User not found' };
    if (rows[0].is_blocked || (rows[0].role !== 'admin' && rows[0].is_verified !== true)) {
      throw { status: 403, message: 'Account is not verified' };
    }
    return { user: fmt(rows[0]), ...makeTokens(rows[0]) };
  } catch (e) {
    if (e?.status) throw e;
    throw { status: 401, message: 'Invalid refresh token' };
  }
};

// ── Get me ────────────────────────────────────────────────────────────────────
const getMe = async (id) => {
  const { rows } = await pool.query('SELECT * FROM users WHERE id=$1', [id]);
  if (!rows.length) throw { status: 404, message: 'User not found' };
  return fmt(rows[0]);
};

// ── Send email verification link ──────────────────────────────────────────────
// email_token and email_token_exp columns now live permanently in init.sql (M2).
// No more runtime ALTER TABLE calls here.
const sendVerificationEmail = async (userId, email) => {
  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours

  await pool.query(
    'UPDATE users SET email_token=$1, email_token_exp=$2 WHERE id=$3',
    [token, expiresAt, userId]
  );

  const appUrl = process.env.APP_URL || 'http://localhost:3000';
  const link = `${appUrl}/api/v1/auth/verify-email?token=${token}`;

  await transporter.sendMail({
    from: `"Vroom Squad" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'Verify your Vroom Squad email',
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px">
        <h2 style="color:#1A3C5E">Verify your email</h2>
        <p>Thanks for joining Vroom Squad! Click the button below to verify your email address.</p>
        <a href="${link}"
           style="display:inline-block;background:#1A3C5E;color:#fff;padding:14px 28px;
                  border-radius:8px;text-decoration:none;font-weight:600;margin:16px 0">
          Verify Email
        </a>
        <p style="color:#666;font-size:13px">This link expires in 24 hours.<br>
           If you didn't create an account, you can safely ignore this email.</p>
      </div>
    `,
  });

  return token;
};

// ── Verify email token ────────────────────────────────────────────────────────
const verifyEmailToken = async (token) => {
  const { rows } = await pool.query(
    `SELECT id, email_token_exp
     FROM users
     WHERE email_token = $1 AND is_verified = false`,
    [token]
  );

  if (!rows.length) {
    throw { status: 400, message: 'Invalid or already used verification link.' };
  }
  if (new Date(rows[0].email_token_exp) < new Date()) {
    throw { status: 400, message: 'Verification link has expired. Please register again.' };
  }

  await pool.query(
    `UPDATE users
     SET is_verified = true, email_token = NULL, email_token_exp = NULL
     WHERE id = $1`,
    [rows[0].id]
  );

  return { message: 'Email verified successfully.' };
};

// ── Check if user is verified ─────────────────────────────────────────────────
const checkVerified = async (userId) => {
  const { rows } = await pool.query(
    'SELECT is_verified FROM users WHERE id=$1',
    [userId]
  );
  if (!rows.length) throw { status: 404, message: 'User not found' };
  return rows[0].is_verified === true;
};

module.exports = {
  register,
  login,
  refresh,
  getMe,
  sendVerificationEmail,
  verifyEmailToken,
  checkVerified,
};
