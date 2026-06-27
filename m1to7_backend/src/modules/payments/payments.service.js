const pool = require('../../config/database');
const { ensureWalletTransactionsSchema } = require('../../services/schema.service');

const PLATFORM_FEE_RATE = 0.15;

const toAmount = (value) => {
  const amount = Number(value);
  return Number.isFinite(amount) && amount > 0 ? Number(amount.toFixed(2)) : null;
};

const roundMoney = (value) => Number(Number(value).toFixed(2));

// M2: qr_payment_image_url is now a permanent column in init.sql.
// No more ensurePaymentsSchema() ALTER TABLE calls needed.

const walletSelect = `
  w.id,
  w.user_id,
  w.balance,
  w.reserved,
  w.currency,
  w.updated_at
`;

const rowToWallet = (row) => ({
  id: row.id,
  userId: row.user_id,
  balance: Number(row.balance),
  reserved: Number(row.reserved),
  currency: row.currency,
  updatedAt: row.updated_at,
});

const rowToTransaction = (row) => ({
  id: row.id,
  walletId: row.wallet_id,
  type: row.type,
  amount: Number(row.amount),
  description: row.description,
  rideId: row.ride_id,
  createdAt: row.created_at,
});

const getOrCreateWallet = async (userId, client = pool) => {
  const { rows } = await client.query(`SELECT ${walletSelect} FROM wallets w WHERE w.user_id = $1`, [userId]);
  if (rows.length) return rows[0];
  const created = await client.query('INSERT INTO wallets (user_id) VALUES ($1) RETURNING *', [userId]);
  return created.rows[0];
};

const getAdminWallet = async (client = pool) => {
  const adminRes = await client.query(
    `SELECT id FROM users WHERE role = 'admin' ORDER BY created_at ASC LIMIT 1`,
  );
  if (!adminRes.rows.length) throw { status: 500, message: 'Admin wallet account not found' };
  return getOrCreateWallet(adminRes.rows[0].id, client);
};

const creditPlatformFee = async (client, amount, description, rideId = null) => {
  const fee = roundMoney(Number(amount) * PLATFORM_FEE_RATE);
  if (fee <= 0) return 0;
  const adminWallet = await getAdminWallet(client);
  await client.query(
    `UPDATE wallets SET balance = balance + $1, updated_at = NOW()
     WHERE id = $2`,
    [fee, adminWallet.id],
  );
  await client.query(
    `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
     VALUES ($1, 'credit', $2, $3, $4)`,
    [adminWallet.id, fee, description, rideId],
  );
  return fee;
};

const getWallet = async (userId) => {
  const wallet = await getOrCreateWallet(userId);
  return rowToWallet(wallet);
};

const getTransactions = async (userId) => {
  const wallet = await getOrCreateWallet(userId);
  const { rows } = await pool.query(
    `SELECT * FROM wallet_transactions
     WHERE wallet_id = $1
     ORDER BY created_at DESC
     LIMIT 100`,
    [wallet.id],
  );
  return rows.map(rowToTransaction);
};

const topUpWallet = async (userId, amountInput) => {
  const amount = toAmount(amountInput);
  if (!amount) throw { status: 400, message: 'A positive amount is required' };

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const userRes = await client.query(
      'SELECT is_verified FROM users WHERE id = $1',
      [userId],
    );
    if (!userRes.rows.length) throw { status: 404, message: 'User not found' };
    if (userRes.rows[0].is_verified !== true) {
      throw { status: 403, message: 'Please verify your account before topping up your wallet' };
    }

    const wallet = await getOrCreateWallet(userId, client);
    const { rows } = await client.query(
      `UPDATE wallets SET balance = balance + $1, updated_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [amount, wallet.id],
    );
    await client.query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description)
       VALUES ($1, 'credit', $2, $3)`,
      [wallet.id, amount, 'Passenger wallet top-up'],
    );
    await client.query('COMMIT');
    return rowToWallet(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const requestWithdrawal = async (userId, amountInput) => {
  const amount = toAmount(amountInput);
  if (!amount) throw { status: 400, message: 'A positive amount is required' };
  await ensureWalletTransactionsSchema();

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const wallet = await getOrCreateWallet(userId, client);
    const locked = await client.query('SELECT * FROM wallets WHERE id = $1 FOR UPDATE', [wallet.id]);
    if (Number(locked.rows[0].balance) < amount) {
      throw { status: 400, message: 'Insufficient wallet balance' };
    }
    const payout = roundMoney(amount);
    const { rows } = await client.query(
      `UPDATE wallets SET balance = balance - $1, reserved = reserved + $1, updated_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [payout, wallet.id],
    );
    await client.query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description, status)
       VALUES ($1, 'withdrawal_request', $2, $3, 'pending')`,
      [wallet.id, payout, `Withdrawal request by ${userId}`],
    );
    await client.query('COMMIT');
    return rowToWallet(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const adminCreditWallet = async ({ email, userId, amount: amountInput, description }) => {
  const amount = toAmount(amountInput);
  if (!amount || (!email && !userId)) {
    throw { status: 400, message: 'User email/id and a positive amount are required' };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const userRes = await client.query(
      `SELECT id FROM users WHERE ${userId ? 'id = $1' : 'LOWER(email) = LOWER($1)'}`,
      [userId || email],
    );
    if (!userRes.rows.length) throw { status: 404, message: 'User not found' };
    const wallet = await getOrCreateWallet(userRes.rows[0].id, client);
    const { rows } = await client.query(
      `UPDATE wallets SET balance = balance + $1, updated_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [amount, wallet.id],
    );
    await client.query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description)
       VALUES ($1, 'credit', $2, $3)`,
      [wallet.id, amount, description || 'Admin wallet credit'],
    );
    await client.query('COMMIT');
    return rowToWallet(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const updateDriverQr = async (userId, input) => {
  const { qrPaymentId, qrPaymentLabel, qrPaymentImageUrl, qrPaymentImages } = input;
  const { rows } = await pool.query(
    `UPDATE users
     SET qr_payment_id = COALESCE($1, qr_payment_id),
         qr_payment_label = COALESCE($2, qr_payment_label),
         qr_payment_image_url = COALESCE($3, qr_payment_image_url),
         qr_payment_images = COALESCE($4::jsonb, qr_payment_images),
         updated_at = NOW()
     WHERE id = $5
     RETURNING qr_payment_id, qr_payment_label, qr_payment_image_url, qr_payment_images`,
    [qrPaymentId, qrPaymentLabel, qrPaymentImageUrl, qrPaymentImages ? JSON.stringify(qrPaymentImages) : null, userId],
  );
  return {
    qrPaymentId: rows[0].qr_payment_id,
    qrPaymentLabel: rows[0].qr_payment_label,
    qrPaymentImageUrl: rows[0].qr_payment_image_url,
    qrPaymentImages: rows[0].qr_payment_images && typeof rows[0].qr_payment_images === 'object' ? rows[0].qr_payment_images : {},
  };
};

const listWithdrawalRequests = async () => {
  await ensureWalletTransactionsSchema();
  const { rows } = await pool.query(
    `SELECT wt.*, u.id AS user_id, u.name, u.email
     FROM wallet_transactions wt
     JOIN wallets w ON w.id = wt.wallet_id
     JOIN users u ON u.id = w.user_id
     WHERE wt.type = 'withdrawal_request'
     ORDER BY (wt.status = 'pending') DESC, wt.created_at DESC
     LIMIT 100`,
  );
  return rows.map((row) => ({
    ...rowToTransaction(row),
    status: row.status,
    userId: row.user_id,
    userName: row.name,
    userEmail: row.email,
  }));
};

// Admin marks a pending withdrawal request as paid out (e.g. after sending the
// money via bank transfer / eSewa / Khalti outside the app). Clears the
// reserved hold and records a matching `withdrawal_paid` transaction.
const completeWithdrawalRequest = async (transactionId) => {
  await ensureWalletTransactionsSchema();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT wt.*, w.id AS wallet_id
       FROM wallet_transactions wt
       JOIN wallets w ON w.id = wt.wallet_id
       WHERE wt.id = $1 AND wt.type = 'withdrawal_request'
       FOR UPDATE OF wt`,
      [transactionId],
    );
    if (!rows.length) throw { status: 404, message: 'Withdrawal request not found' };
    const request = rows[0];
    if (request.status !== 'pending') {
      throw { status: 400, message: `This request was already ${request.status}` };
    }

    await client.query(
      `UPDATE wallets SET reserved = reserved - $1, updated_at = NOW() WHERE id = $2`,
      [request.amount, request.wallet_id],
    );
    await client.query(
      `UPDATE wallet_transactions SET status = 'completed' WHERE id = $1`,
      [transactionId],
    );
    await client.query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description, status)
       VALUES ($1, 'withdrawal_paid', $2, $3, 'completed')`,
      [request.wallet_id, request.amount, 'Withdrawal request fulfilled by admin'],
    );

    await client.query('COMMIT');
    return { id: transactionId, status: 'completed' };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

// Admin rejects a pending withdrawal request — the reserved amount is
// released back into the user's spendable balance.
const rejectWithdrawalRequest = async (transactionId, reason) => {
  await ensureWalletTransactionsSchema();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT wt.*, w.id AS wallet_id
       FROM wallet_transactions wt
       JOIN wallets w ON w.id = wt.wallet_id
       WHERE wt.id = $1 AND wt.type = 'withdrawal_request'
       FOR UPDATE OF wt`,
      [transactionId],
    );
    if (!rows.length) throw { status: 404, message: 'Withdrawal request not found' };
    const request = rows[0];
    if (request.status !== 'pending') {
      throw { status: 400, message: `This request was already ${request.status}` };
    }

    await client.query(
      `UPDATE wallets SET balance = balance + $1, reserved = reserved - $1, updated_at = NOW() WHERE id = $2`,
      [request.amount, request.wallet_id],
    );
    await client.query(
      `UPDATE wallet_transactions SET status = 'rejected' WHERE id = $1`,
      [transactionId],
    );
    await client.query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description, status)
       VALUES ($1, 'release', $2, $3, 'completed')`,
      [request.wallet_id, request.amount, reason ? `Withdrawal rejected: ${reason}` : 'Withdrawal request rejected'],
    );

    await client.query('COMMIT');
    return { id: transactionId, status: 'rejected' };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

module.exports = {
  getWallet,
  getTransactions,
  topUpWallet,
  requestWithdrawal,
  adminCreditWallet,
  updateDriverQr,
  listWithdrawalRequests,
  completeWithdrawalRequest,
  rejectWithdrawalRequest,
  getOrCreateWallet,
  creditPlatformFee,
  PLATFORM_FEE_RATE,
};
