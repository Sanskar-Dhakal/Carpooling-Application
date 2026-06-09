const router = require('express').Router();
const pool   = require('../../config/database');
const { authenticate } = require('../../middleware/auth.middleware');

router.get('/me', authenticate, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT id,name,email,phone,role,is_verified,rating,profile_photo_url,qr_payment_id,qr_payment_label,qr_payment_image_url FROM users WHERE id=$1',
      [req.user.id]
    );
    res.json({ user: rows[0] });
  } catch (e) { next(e); }
});

router.put('/me', authenticate, async (req, res, next) => {
  try {
    const { name, phone } = req.body;
    const { rows } = await pool.query(
      'UPDATE users SET name=COALESCE($1,name),phone=COALESCE($2,phone),updated_at=NOW() WHERE id=$3 RETURNING id,name,email,phone,role',
      [name, phone, req.user.id]
    );
    res.json({ user: rows[0] });
  } catch (e) { next(e); }
});

router.put('/fcm-token', authenticate, async (req, res, next) => {
  try {
    await pool.query('UPDATE users SET fcm_token=$1 WHERE id=$2', [req.body.token, req.user.id]);
    res.json({ message: 'FCM token updated' });
  } catch (e) { next(e); }
});

router.put('/qr-payment', authenticate, async (req, res, next) => {
  try {
    const { qr_payment_id, qr_payment_label, qr_payment_image_url } = req.body;
    await pool.query(
      'UPDATE users SET qr_payment_id=$1,qr_payment_label=$2,qr_payment_image_url=$3 WHERE id=$4',
      [qr_payment_id, qr_payment_label, qr_payment_image_url, req.user.id]
    );
    res.json({ message: 'QR payment updated' });
  } catch (e) { next(e); }
});

module.exports = router;
