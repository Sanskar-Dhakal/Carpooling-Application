const jwt  = require('jsonwebtoken');
const pool = require('../config/database');

const setupSocket = (io) => {
  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) return next(new Error('No token'));
      socket.user = jwt.verify(token, process.env.JWT_SECRET);
      next();
    } catch { next(new Error('Invalid token')); }
  });

  io.on('connection', (socket) => {
    console.log(`🔌 connected: ${socket.user?.id}`);

    socket.on('join_ride_room', async (rideId) => {
      if (!rideId) return;
      const room = String(rideId);
      socket.join(room);
      try {
        const { rows } = await pool.query(
          `SELECT gl.lat, gl.lng, gl.recorded_at
           FROM gps_locations gl
           JOIN bookings b ON b.id = gl.booking_id
           WHERE b.ride_id = $1
           ORDER BY gl.recorded_at DESC
           LIMIT 1`,
          [room],
        );
        if (rows.length) {
          socket.emit('driver_location', {
            lat: Number(rows[0].lat),
            lng: Number(rows[0].lng),
            ts: new Date(rows[0].recorded_at).getTime(),
          });
        }
        // seed last known passenger location
        try {
          const { rows: plRows } = await pool.query(
            `SELECT gl.lat, gl.lng, gl.recorded_at, u.name AS user_name
             FROM gps_locations gl
             JOIN users u ON u.id = gl.user_id
             JOIN bookings b ON b.id = gl.booking_id
             WHERE b.ride_id = $1 AND gl.user_id <> (
               SELECT r.driver_id FROM rides r WHERE r.id = $1
             )
             ORDER BY gl.recorded_at DESC
             LIMIT 1`,
            [room],
          );
          if (plRows.length) {
            socket.emit('passenger_location', {
              lat: Number(plRows[0].lat),
              lng: Number(plRows[0].lng),
              userId: plRows[0].user_name,
              ts: new Date(plRows[0].recorded_at).getTime(),
            });
          }
        } catch (_) {}
      } catch (err) {
        console.error('GPS load error:', err.message);
      }
    });

    // passenger live location
    socket.on('passenger_location', async ({ rideId, lat, lng, userId }) => {
      if (!rideId || !Number.isFinite(Number(lat)) || !Number.isFinite(Number(lng))) return;
      const room = String(rideId);
      const uid = userId || socket.user?.id;
      io.to(room).emit('passenger_location', { lat: Number(lat), lng: Number(lng), userId: uid, ts: Date.now() });
      // persist passenger GPS
      try {
        const { rows: bookingRows } = await pool.query(
          `SELECT b.id FROM bookings b
           WHERE b.ride_id = $1 AND b.passenger_id = $2 AND b.status = 'confirmed'
           LIMIT 1`,
          [room, uid],
        );
        if (bookingRows.length) {
          await pool.query(
            `INSERT INTO gps_locations (booking_id, user_id, lat, lng) VALUES ($1, $2, $3, $4)`,
            [bookingRows[0].id, uid, Number(lat), Number(lng)],
          );
        }
      } catch (err) {
        console.error('Passenger GPS save error:', err.message);
      }
    });

    socket.on('location_update', async ({ rideId, lat, lng }) => {
      if (!rideId || !Number.isFinite(Number(lat)) || !Number.isFinite(Number(lng))) return;
      const room = String(rideId);
      io.to(room).emit('driver_location', { lat: Number(lat), lng: Number(lng), ts: Date.now() });
      // M7: persist GPS to gps_locations table
      try {
        // find the active booking for this ride (first confirmed passenger)
        const { rows } = await pool.query(
          `SELECT id FROM bookings WHERE ride_id = $1 AND status = 'confirmed' LIMIT 1`,
          [room],
        );
        if (rows.length) {
          await pool.query(
            `INSERT INTO gps_locations (booking_id, user_id, lat, lng) VALUES ($1, $2, $3, $4)`,
            [rows[0].id, socket.user.id, Number(lat), Number(lng)],
          );
        }
      } catch (err) {
        console.error('GPS save error:', err.message);
      }
    });

    socket.on('join_chat', (bookingId) => socket.join(`chat_${bookingId}`));

    socket.on('send_message', async ({ bookingId, content }) => {
      try {
        const { rows } = await pool.query(
          'INSERT INTO messages (booking_id,sender_id,content) VALUES ($1,$2,$3) RETURNING *',
          [bookingId, socket.user.id, content],
        );
        io.to(`chat_${bookingId}`).emit('new_message', rows[0]);
        // FCM background push for recipient
        try {
          const booking = await pool.query(
            `SELECT b.passenger_id, r.driver_id,
                    p.fcm_token AS passenger_fcm, d.fcm_token AS driver_fcm,
                    p.name AS passenger_name, d.name AS driver_name
             FROM bookings b
             JOIN rides r ON r.id = b.ride_id
             JOIN users p ON p.id = b.passenger_id
             JOIN users d ON d.id = r.driver_id
             WHERE b.id = $1`,
            [bookingId],
          );
          if (booking.rows.length) {
            const bk = booking.rows[0];
            const isDriver = socket.user.id === bk.driver_id;
            const recipientToken = isDriver ? bk.passenger_fcm : bk.driver_fcm;
            const senderName = isDriver ? bk.driver_name : bk.passenger_name;
            const { sendPush } = require('../modules/notifications/notification.service');
            await sendPush({
              token: recipientToken,
              title: `Message from ${senderName}`,
              body: content.length > 60 ? content.slice(0, 60) + '…' : content,
              data: { type: 'new_message', bookingId },
            });
          }
        } catch (_) {}
      } catch { socket.emit('error', { message: 'Failed to send' }); }
    });

    socket.on('mark_read', async ({ messageId, bookingId }) => {
      await pool.query('UPDATE messages SET is_read=true WHERE id=$1', [messageId]);
      io.to(`chat_${bookingId}`).emit('read_receipt', { messageId });
    });

    socket.on('disconnect', () => console.log(`🔌 disconnected: ${socket.user?.id}`));
  });
};

module.exports = setupSocket;
