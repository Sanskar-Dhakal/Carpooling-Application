const sendPush = async ({ token, title, body, data = {} }) => {
  if (!token) {
    console.log('🔔 Notification skipped: no FCM token', { title, body, data });
    return;
  }

  try {
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      const credentialsJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
      if (!credentialsJson) {
        console.log('🔔 Notification fallback: Firebase credentials missing', { title, body, data });
        return;
      }
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(credentialsJson)),
      });
    }

    await admin.messaging().send({
      token,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, String(value)])),
    });
  } catch (err) {
    console.log('🔔 Notification fallback:', err.message, { title, body, data });
  }
};

module.exports = { sendPush };
