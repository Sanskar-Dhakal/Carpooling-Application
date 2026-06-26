const router = require('express').Router();
const pool = require('../../config/database');
const { authenticate, invalidateUserCache } = require('../../middleware/auth.middleware');
const { sendPush } = require('../notifications/notification.service');
const { ensureUsersProfileSchema } = require('../../services/schema.service');

// Middleware — admin only
const requireAdmin = (req, res, next) => {
  if (req.user?.role !== 'admin') return res.status(403).json({ message: 'Admin only' });
  next();
};

// GET /api/v1/admin/contact — public admin contact for wallet assistance
router.get('/contact', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT name, email, phone FROM users WHERE role='admin' ORDER BY created_at ASC LIMIT 1`
    );
    if (!rows.length) return res.status(404).json({ message: 'No admin found' });
    res.json({ admin: { name: rows[0].name, email: rows[0].email, phone: rows[0].phone } });
  } catch (e) { next(e); }
});

// GET /api/v1/admin/users
router.get('/users', authenticate, requireAdmin, async (req, res, next) => {
  try {
    await ensureUsersProfileSchema();
    const { role, verified } = req.query;
    let query = `SELECT id,name,email,phone,role,is_verified,verification_status,id_document_url,license_document_url,rating,profile_photo_url,is_blocked,is_red_listed,created_at FROM users`;
    const params = [];
    const conditions = [];
    if (role) { conditions.push(`role = $${params.length + 1}`); params.push(role); }
    if (verified !== undefined) { conditions.push(`is_verified = $${params.length + 1}`); params.push(verified === 'true'); }
    if (conditions.length) query += ' WHERE ' + conditions.join(' AND ');
    query += ' ORDER BY created_at DESC LIMIT 100';
    const { rows } = await pool.query(query, params);
    res.json({ users: rows });
  } catch (e) { next(e); }
});

// PUT /api/v1/admin/users/:id/verify
router.put('/users/:id/verify', authenticate, requireAdmin, async (req, res, next) => {
  try {
    await ensureUsersProfileSchema();
    const { rows } = await pool.query(
      `UPDATE users
       SET is_verified = true, verification_status = 'verified', updated_at = NOW()
       WHERE id = $1
       RETURNING id, name, fcm_token`,
      [req.params.id],
    );
    if (!rows.length) return res.status(404).json({ message: 'User not found' });
    await sendPush({
      token: rows[0].fcm_token,
      title: 'Account Verified!',
      body: 'Your Vroom Squad account has been verified.',
      data: { type: 'account_verified' },
    });
    await invalidateUserCache(req.params.id);
    res.json({ message: 'User verified', user: rows[0] });
  } catch (e) { next(e); }
});

// PUT /api/v1/admin/users/:id/status
router.put('/users/:id/status', authenticate, requireAdmin, async (req, res, next) => {
  try {
    const { is_blocked, is_red_listed } = req.body;
    let setClause = [];
    let params = [];
    if (is_blocked !== undefined) { params.push(is_blocked); setClause.push(`is_blocked = $${params.length}`); }
    if (is_red_listed !== undefined) { params.push(is_red_listed); setClause.push(`is_red_listed = $${params.length}`); }
    if (!setClause.length) return res.status(400).json({ message: 'Nothing to update' });
    params.push(req.params.id);
    
    const { rows } = await pool.query(
      `UPDATE users SET ${setClause.join(', ')} WHERE id = $${params.length} RETURNING *`,
      params
    );
    if (!rows.length) return res.status(404).json({ message: 'User not found' });
    await invalidateUserCache(req.params.id);
    res.json({ message: 'Status updated', user: rows[0] });
  } catch (e) { next(e); }
});

// GET /api/v1/admin/users/:id/history
router.get('/users/:id/history', authenticate, requireAdmin, async (req, res, next) => {
  try {
    const { rows: user } = await pool.query(`SELECT role FROM users WHERE id = $1`, [req.params.id]);
    if (!user.length) return res.status(404).json({ message: 'User not found' });
    
    if (user[0].role === 'driver') {
      const { rows } = await pool.query(
        `SELECT id, origin_address, destination_address, departure_time, status, seats_total, price_per_seat 
         FROM rides WHERE driver_id = $1 ORDER BY created_at DESC LIMIT 50`,
        [req.params.id]
      );
      res.json({ history: rows, type: 'rides' });
    } else {
      const { rows } = await pool.query(
        `SELECT b.id, b.status, b.created_at, b.total_amount, r.origin_address, r.destination_address, r.departure_time
         FROM bookings b JOIN rides r ON r.id = b.ride_id
         WHERE b.passenger_id = $1 ORDER BY b.created_at DESC LIMIT 50`,
        [req.params.id]
      );
      res.json({ history: rows, type: 'bookings' });
    }
  } catch (e) { next(e); }
});

// GET /api/v1/admin/rides
router.get('/rides', authenticate, requireAdmin, async (req, res, next) => {
  try {
    const { status } = req.query;
    const params = [];
    let query = `SELECT r.*, u.name AS driver_name FROM rides r JOIN users u ON u.id = r.driver_id`;
    if (status) { query += ` WHERE r.status = $1`; params.push(status); }
    query += ' ORDER BY r.created_at DESC LIMIT 100';
    const { rows } = await pool.query(query, params);
    res.json({ rides: rows });
  } catch (e) { next(e); }
});

// GET /api/v1/admin/wallet — admin wallet overview with commission earnings + transactions
router.get('/wallet', authenticate, requireAdmin, async (req, res, next) => {
  try {
    const adminRes = await pool.query(
      `SELECT u.id AS admin_id FROM users u WHERE u.role = 'admin' ORDER BY u.created_at ASC LIMIT 1`
    );
    if (!adminRes.rows.length) return res.status(404).json({ message: 'No admin found' });
    const adminId = adminRes.rows[0].admin_id;

    const walletRes = await pool.query(
      `SELECT id, balance, reserved, currency FROM wallets WHERE user_id = $1 LIMIT 1`,
      [adminId]
    );
    if (!walletRes.rows.length) {
      return res.json({ wallet: { balance: 0, currency: 'NPR', reserved: 0 }, totalEarnings: 0, transactions: [] });
    }
    const wallet = walletRes.rows[0];

    const earningsRes = await pool.query(
      `SELECT COALESCE(SUM(amount), 0) AS total_earnings
       FROM wallet_transactions
       WHERE wallet_id = $1 AND type = 'credit'
         AND description ILIKE 'Platform commission%'`,
      [wallet.id]
    );

    const txRes = await pool.query(
      `SELECT wt.id, wt.type, wt.amount, wt.description, wt.created_at, r.origin_address, r.destination_address
       FROM wallet_transactions wt
       LEFT JOIN rides r ON r.id = wt.ride_id
       WHERE wt.wallet_id = $1
       ORDER BY wt.created_at DESC
       LIMIT 100`,
      [wallet.id]
    );

    res.json({
      wallet: {
        id: wallet.id,
        balance: Number(wallet.balance),
        currency: wallet.currency,
        reserved: Number(wallet.reserved),
      },
      totalEarnings: Number(earningsRes.rows[0].total_earnings),
      transactions: txRes.rows,
    });
  } catch (e) { next(e); }
});

// POST /api/v1/admin/wallet/withdraw — admin withdraws accumulated commission balance
router.post('/wallet/withdraw', authenticate, requireAdmin, async (req, res, next) => {
  try {
    const { amount } = req.body;
    const withdrawAmount = Number(amount);
    if (!withdrawAmount || withdrawAmount <= 0) {
      return res.status(400).json({ message: 'A positive withdrawal amount is required' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const adminRes = await client.query(
        `SELECT u.id AS admin_id FROM users u WHERE u.role = 'admin' ORDER BY u.created_at ASC LIMIT 1`
      );
      if (!adminRes.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'No admin found' });
      }
      const adminId = adminRes.rows[0].admin_id;

      const walletRes = await client.query(
        `SELECT id, balance FROM wallets WHERE user_id = $1 FOR UPDATE LIMIT 1`,
        [adminId]
      );
      if (!walletRes.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'Admin wallet not found' });
      }
      const wallet = walletRes.rows[0];
      if (Number(wallet.balance) < withdrawAmount) {
        await client.query('ROLLBACK');
        return res.status(400).json({ message: 'Insufficient balance' });
      }

      await client.query(
        `UPDATE wallets SET balance = balance - $1, updated_at = NOW() WHERE id = $2`,
        [withdrawAmount, wallet.id]
      );

      await client.query(
        `INSERT INTO wallet_transactions (wallet_id, type, amount, description)
         VALUES ($1, 'withdrawal_paid', $2, $3)`,
        [wallet.id, withdrawAmount, 'Admin commission withdrawal']
      );

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    res.json({ message: 'Withdrawal successful' });
  } catch (e) { next(e); }
});

// GET /api/v1/admin/wallet/withdrawals
router.get('/wallet/withdrawals', authenticate, requireAdmin, async (req, res, next) => {
  try {
    const adminRes = await pool.query(
      `SELECT u.id AS admin_id FROM users u WHERE u.role = 'admin' ORDER BY u.created_at ASC LIMIT 1`
    );
    if (!adminRes.rows.length) return res.status(404).json({ message: 'No admin found' });
    const adminId = adminRes.rows[0].admin_id;

    const walletRes = await pool.query(
      `SELECT id FROM wallets WHERE user_id = $1 LIMIT 1`,
      [adminId]
    );
    if (!walletRes.rows.length) {
      return res.json({ withdrawals: [] });
    }
    const walletId = walletRes.rows[0].id;

    const { rows } = await pool.query(
      `SELECT wt.id, wt.type, wt.amount, wt.description, wt.created_at, r.origin_address, r.destination_address
       FROM wallet_transactions wt
       LEFT JOIN rides r ON r.id = wt.ride_id
       WHERE wt.wallet_id = $1 AND wt.type = 'withdrawal_paid'
       ORDER BY wt.created_at DESC
       LIMIT 100`,
      [walletId]
    );

    res.json({ withdrawals: rows });
  } catch (e) { next(e); }
});

// PUT /api/v1/admin/users/:id/doc-review
router.put('/users/:id/doc-review', authenticate, requireAdmin, async (req, res, next) => {
  try {
    await ensureUsersProfileSchema();
    const { action } = req.body; // 'accept' | 'retake' | 'reject'
    let updateFields = '';
    if (action === 'accept') {
      updateFields = `is_verified = true, verification_status = 'verified'`;
    } else if (action === 'retake') {
      updateFields = `verification_status = 'retake', id_document_url = NULL`;
    } else if (action === 'reject') {
      updateFields = `is_verified = false, is_blocked = false, verification_status = 'rejected'`;
    } else {
      return res.status(400).json({ message: 'Invalid action' });
    }
    const { rows } = await pool.query(
      `UPDATE users SET ${updateFields}, updated_at = NOW() WHERE id = $1 RETURNING *`,
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ message: 'User not found' });
    await invalidateUserCache(req.params.id);
    res.json({ message: 'Document reviewed', user: rows[0] });
  } catch (e) { next(e); }
});

module.exports = router;