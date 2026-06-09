const pool = require('../../config/database');

const toAmount = (value) => {
  const amount = Number(value);
  return Number.isFinite(amount) && amount > 0 ? Number(amount.toFixed(2)) : null;
};

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

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const wallet = await getOrCreateWallet(userId, client);
    const locked = await client.query('SELECT * FROM wallets WHERE id = $1 FOR UPDATE', [wallet.id]);
    if (Number(locked.rows[0].balance) < amount) {
      throw { status: 400, message: 'Insufficient wallet balance' };
    }
    const { rows } = await client.query(
      `UPDATE wallets SET balance = balance - $1, updated_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [amount, wallet.id],
    );
    await client.query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description)
       VALUES ($1, 'withdrawal_request', $2, $3)`,
      [wallet.id, amount, 'Driver withdrawal request'],
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
  const { qrPaymentId, qrPaymentLabel, qrPaymentImageUrl } = input;
  const { rows } = await pool.query(
    `UPDATE users
     SET qr_payment_id = COALESCE($1, qr_payment_id),
         qr_payment_label = COALESCE($2, qr_payment_label),
         qr_payment_image_url = COALESCE($3, qr_payment_image_url),
         updated_at = NOW()
     WHERE id = $4
     RETURNING qr_payment_id, qr_payment_label, qr_payment_image_url`,
    [qrPaymentId, qrPaymentLabel, qrPaymentImageUrl, userId],
  );
  return {
    qrPaymentId: rows[0].qr_payment_id,
    qrPaymentLabel: rows[0].qr_payment_label,
    qrPaymentImageUrl: rows[0].qr_payment_image_url,
  };
};

const listWithdrawalRequests = async () => {
  const { rows } = await pool.query(
    `SELECT wt.*, u.name, u.email
     FROM wallet_transactions wt
     JOIN wallets w ON w.id = wt.wallet_id
     JOIN users u ON u.id = w.user_id
     WHERE wt.type = 'withdrawal_request'
     ORDER BY wt.created_at DESC
     LIMIT 100`,
  );
  return rows.map((row) => ({
    ...rowToTransaction(row),
    userName: row.name,
    userEmail: row.email,
  }));
};

module.exports = {
  getWallet,
  getTransactions,
  topUpWallet,
  requestWithdrawal,
  adminCreditWallet,
  updateDriverQr,
  listWithdrawalRequests,
  getOrCreateWallet,
};
