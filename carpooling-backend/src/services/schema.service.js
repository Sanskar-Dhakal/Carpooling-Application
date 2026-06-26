const pool = require('../config/database');

let usersProfileSchemaReady;
let walletTransactionsSchemaReady;

const ensureUsersProfileSchema = async () => {
  if (!usersProfileSchemaReady) {
    usersProfileSchemaReady = (async () => {
      await pool.query(`
        ALTER TABLE users
          ADD COLUMN IF NOT EXISTS id_document_url TEXT,
          ADD COLUMN IF NOT EXISTS license_document_url TEXT,
          ADD COLUMN IF NOT EXISTS verification_status VARCHAR(20) DEFAULT 'none'
      `);
      await pool.query(`
        ALTER TABLE users
          DROP CONSTRAINT IF EXISTS users_verification_status_check;
        ALTER TABLE users
          ADD CONSTRAINT users_verification_status_check
          CHECK (verification_status IN ('none','pending','verified','retake','rejected'));
       `);
       await pool.query(`
         ALTER TABLE users
           ADD COLUMN IF NOT EXISTS qr_payment_images JSONB NOT NULL DEFAULT '{}'::jsonb,
           ADD COLUMN IF NOT EXISTS qr_payment_image_url TEXT
       `);
     })();
   }
   return usersProfileSchemaReady;
 };

// Adds a `status` lifecycle column to wallet_transactions so withdrawal
// requests can be tracked as pending -> completed / rejected by the admin.
// Existing rows are safely backfilled exactly once (status starts NULL,
// is filled in, then locked to NOT NULL) so re-running this on every server
// boot never resets a withdrawal that was already processed.
const ensureWalletTransactionsSchema = async () => {
  if (!walletTransactionsSchemaReady) {
    walletTransactionsSchemaReady = (async () => {
      await pool.query(`
        ALTER TABLE wallet_transactions
          ADD COLUMN IF NOT EXISTS status VARCHAR(20)
      `);
      await pool.query(`
        UPDATE wallet_transactions
        SET status = CASE WHEN type = 'withdrawal_request' THEN 'pending' ELSE 'completed' END
        WHERE status IS NULL
      `);
      await pool.query(`
        ALTER TABLE wallet_transactions
          ALTER COLUMN status SET DEFAULT 'completed',
          ALTER COLUMN status SET NOT NULL
      `);
      await pool.query(`
        ALTER TABLE wallet_transactions
          DROP CONSTRAINT IF EXISTS wallet_transactions_status_check
      `);
      await pool.query(`
        ALTER TABLE wallet_transactions
          ADD CONSTRAINT wallet_transactions_status_check
          CHECK (status IN ('pending','completed','rejected'))
      `);
    })();
  }
  return walletTransactionsSchemaReady;
};

module.exports = { ensureUsersProfileSchema, ensureWalletTransactionsSchema };
