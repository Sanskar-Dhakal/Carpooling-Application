const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host:     process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT) || 5432,
  user:     process.env.DB_USER     || 'vroomuser',
  password: process.env.DB_PASS     || 'vroompass',
  database: process.env.DB_NAME     || 'vroomsquad',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 3000,
});

pool.on('connect', () => console.log('✅ PostgreSQL connected'));
pool.on('error',  (err) => console.error('❌ PostgreSQL error:', err.message));

module.exports = pool;
