require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASS || 'postgres',
  database: process.env.DB_NAME || 'vroomsquad',
});

async function main() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const insertUser = `
      INSERT INTO users (name, email, password_hash, role, is_verified)
      VALUES ('Super Admin', 'admin@vroomsquad.com', '$2a$12$8.h2lncM/0iieCtFFAFmseQxMDlMqmM4mmCLyHgaWL3OdRJJim/OW', 'admin', TRUE)
      ON CONFLICT (email) DO NOTHING
      RETURNING id
    `;
    const userRes = await client.query(insertUser);
    const userId = userRes.rows[0]?.id;
    if (!userId) {
      const existing = await client.query(`SELECT id FROM users WHERE email = 'admin@vroomsquad.com'`);
      if (!existing.rows.length) {
        console.log('No user found and no insert happened. Rollback.');
        await client.query('ROLLBACK');
        return;
      }
      console.log('Admin user already exists. Using existing user.');
    } else {
      console.log('Admin user created:', userId);
    }

    await client.query(`
      INSERT INTO wallets (user_id, currency)
      VALUES ((SELECT id FROM users WHERE email = 'admin@vroomsquad.com'), 'NPR')
      ON CONFLICT (user_id) DO NOTHING
    `);
    console.log('Wallet ensured for admin.');

    await client.query('COMMIT');
    console.log('Done.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

main();
