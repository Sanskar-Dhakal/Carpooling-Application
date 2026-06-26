require('dotenv').config();
const { Pool } = require('pg');
const redis = require('redis');
const admin = require('firebase-admin');

async function clearData() {
  console.log('Clearing Postgres Database...');
  const pool = new Pool({
    user: process.env.DB_USER || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'vroomsquad',
    password: process.env.DB_PASS || 'postgres',
    port: process.env.DB_PORT || 5432,
  });

  try {
    // Truncate tables and restart sequences
    await pool.query(`
      TRUNCATE TABLE 
        wallet_transactions, 
        wallets, 
        bookings, 
        reviews, 
        rides, 
        users 
      RESTART IDENTITY CASCADE;
    `);
    console.log('✅ Postgres Database tables truncated.');
  } catch (err) {
    console.error('❌ Error clearing Postgres:', err.message);
  } finally {
    await pool.end();
  }

  console.log('\nClearing Redis Cache...');
  try {
    const redisClient = redis.createClient({
      url: `redis://${process.env.REDIS_HOST || 'localhost'}:${process.env.REDIS_PORT || 6379}`
    });
    await redisClient.connect();
    await redisClient.flushAll();
    console.log('✅ Redis Cache flushed.');
    await redisClient.disconnect();
  } catch (err) {
    console.error('❌ Error clearing Redis:', err.message);
  }

  console.log('\nClearing Firebase Auth Users...');
  try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)),
      });
      const listUsersResult = await admin.auth().listUsers(1000);
      const uids = listUsersResult.users.map((userRecord) => userRecord.uid);
      if (uids.length > 0) {
        await admin.auth().deleteUsers(uids);
        console.log(`✅ Deleted ${uids.length} users from Firebase Auth.`);
      } else {
        console.log('✅ No users found in Firebase Auth.');
      }
    } else {
      console.log('⚠️ Skipping Firebase Auth clear: FIREBASE_SERVICE_ACCOUNT_JSON not found in env.');
    }
  } catch (err) {
    console.error('❌ Error clearing Firebase Auth:', err.message);
  }

  console.log('\nDone clearing data.');
  process.exit(0);
}

clearData();
