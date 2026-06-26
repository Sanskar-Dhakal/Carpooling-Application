const router = require('express').Router();
const pool   = require('../../config/database');
const { authenticate, authenticateDocumentReupload, invalidateUserCache } = require('../../middleware/auth.middleware');
const upload = require('../../middleware/upload.middleware');
const storageService = require('../../services/storage.service');
const { ensureUsersProfileSchema } = require('../../services/schema.service');

const isValidNepalMobile = (phone) => /^(97|98)\d{8}$/.test(String(phone || ''));

// GET /api/v1/users/me
router.get('/me', authenticate, async (req, res, next) => {
  try {
    await ensureUsersProfileSchema();
    const { rows } = await pool.query(
       `SELECT id,name,email,phone,role,is_verified,verification_status,rating,is_blocked,is_red_listed,
               profile_photo_url,id_document_url,qr_payment_id,qr_payment_label,qr_payment_image_url,qr_payment_images,
              (SELECT COUNT(*) FROM rides WHERE driver_id = users.id AND status='completed') AS total_rides_driver,
              (SELECT COUNT(*) FROM bookings WHERE passenger_id = users.id AND status='completed') AS total_rides_passenger
       FROM users WHERE id=$1`,
      [req.user.id],
    );
    res.json({ user: rows[0] });
  } catch (e) { next(e); }
});

// PUT /api/v1/users/me — update name and phone
router.put('/me', authenticate, async (req, res, next) => {
  try {
    const { name, phone } = req.body;
    if (phone !== undefined && phone !== null && phone !== '' && !isValidNepalMobile(phone)) {
      return res.status(400).json({ message: 'Enter a valid Nepal mobile number' });
    }
    const { rows } = await pool.query(
      `UPDATE users SET name=COALESCE($1,name),phone=COALESCE($2,phone),updated_at=NOW()
       WHERE id=$3 RETURNING id,name,email,phone,role,is_verified,rating,profile_photo_url`,
      [name, phone, req.user.id],
    );
    res.json({ user: rows[0] });
  } catch (e) { next(e); }
});

// PUT /api/v1/users/fcm-token
router.put('/fcm-token', authenticate, async (req, res, next) => {
  try {
    await pool.query('UPDATE users SET fcm_token=$1 WHERE id=$2', [req.body.token, req.user.id]);
    res.json({ message: 'FCM token updated' });
  } catch (e) { next(e); }
});

// PUT /api/v1/users/qr-payment
router.put('/qr-payment', authenticate, async (req, res, next) => {
  try {
    const { qr_payment_id, qr_payment_label, qr_payment_image_url, qr_payment_images } = req.body;
    const setFields = [];
    const params = [];
    if (qr_payment_id !== undefined) { params.push(qr_payment_id); setFields.push(`qr_payment_id=$${params.length}`); }
    if (qr_payment_label !== undefined) { params.push(qr_payment_label); setFields.push(`qr_payment_label=$${params.length}`); }
    if (qr_payment_image_url !== undefined) { params.push(qr_payment_image_url); setFields.push(`qr_payment_image_url=$${params.length}`); }
    if (qr_payment_images !== undefined) { params.push(JSON.stringify(qr_payment_images)); setFields.push(`qr_payment_images=$${params.length}`); }
    params.push(req.user.id);
    await pool.query(`UPDATE users SET ${setFields.join(',')} WHERE id=$${params.length}`, params);
    res.json({ message: 'QR payment updated' });
  } catch (e) { next(e); }
});

// POST /api/v1/users/photo — upload profile photo to MinIO
router.post('/photo', authenticate, upload.single('photo'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No file uploaded' });
    const key = await storageService.uploadFile(
      'profile-photos',
      req.file.buffer,
      req.file.originalname,
      req.file.mimetype,
    );
    const url = await storageService.getPresignedUrl('profile-photos', key);
    await pool.query('UPDATE users SET profile_photo_url=$1 WHERE id=$2', [url, req.user.id]);
    await invalidateUserCache(req.user.id);
    res.json({ url });
  } catch (e) { next(e); }
});

// POST /api/v1/users/verify-doc — upload ID documents to MinIO, notify admin
router.post('/verify-doc', authenticateDocumentReupload, upload.fields([{ name: 'document', maxCount: 1 }, { name: 'license', maxCount: 1 }]), async (req, res, next) => {
  try {
    await ensureUsersProfileSchema();
    if (!req.files || (!req.files.document && !req.files.license)) {
      return res.status(400).json({ message: 'No file uploaded' });
    }
    
    let docUrl = null;
    let licenseUrl = null;

    if (req.files.document && req.files.document.length > 0) {
      const docFile = req.files.document[0];
      const key = await storageService.uploadFile('id-documents', docFile.buffer, docFile.originalname, docFile.mimetype);
      docUrl = await storageService.getPresignedUrl('id-documents', key);
    }
    
    if (req.files.license && req.files.license.length > 0) {
      const licFile = req.files.license[0];
      const key = await storageService.uploadFile('id-documents', licFile.buffer, licFile.originalname, licFile.mimetype);
      licenseUrl = await storageService.getPresignedUrl('id-documents', key);
    }

    // Store doc URL and mark verification pending
    const setFields = [];
    const params = [];
    if (docUrl) {
      params.push(docUrl);
      setFields.push(`id_document_url=$${params.length}`);
    }
    if (licenseUrl) {
      params.push(licenseUrl);
      setFields.push(`license_document_url=$${params.length}`);
    }
    params.push(req.user.id);
    
    await pool.query(
      `UPDATE users SET ${setFields.join(', ')}, verification_status='pending' WHERE id=$${params.length}`,
      params,
    );

    // Notify all admins
    const { rows: admins } = await pool.query(
      `SELECT fcm_token FROM users WHERE role='admin' AND fcm_token IS NOT NULL`,
    );
    const { sendPush } = require('../notifications/notification.service');
    const { rows: user } = await pool.query('SELECT name FROM users WHERE id=$1', [req.user.id]);
    for (const admin of admins) {
      await sendPush({
        token: admin.fcm_token,
        title: 'Verification Request',
        body: `${user[0]?.name || 'A user'} submitted ID documents for verification.`,
        data: { type: 'verification_request', userId: req.user.id },
      });
    }
    res.json({ message: 'Documents uploaded. Pending admin verification.', docUrl, licenseUrl });
  } catch (e) { next(e); }
});

// GET /api/v1/users/:id/profile — public profile
router.get('/:id/profile', authenticate, async (req, res, next) => {
  try {
    await ensureUsersProfileSchema();
    const { rows } = await pool.query(
      `SELECT id, name, email, phone, role, is_verified, rating, profile_photo_url, is_blocked, is_red_listed,
              (SELECT COUNT(*) FROM rides WHERE driver_id = users.id AND status='completed') AS total_rides_driver,
              (SELECT COUNT(*) FROM bookings WHERE passenger_id = users.id AND status='completed') AS total_rides_passenger
       FROM users WHERE id=$1`,
      [req.params.id],
    );
    if (!rows.length) return res.status(404).json({ message: 'User not found' });
    res.json({ user: rows[0] });
  } catch (e) { next(e); }
});

module.exports = router;
