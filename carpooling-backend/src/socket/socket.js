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

    socket.on('join_ride_room', (rideId) => socket.join(rideId));

    socket.on('location_update', ({ rideId, lat, lng }) => {
      io.to(rideId).emit('driver_location', { lat, lng, ts: Date.now() });
    });

    socket.on('join_chat', (bookingId) => socket.join(`chat_${bookingId}`));

    socket.on('send_message', async ({ bookingId, content }) => {
      try {
        const { rows } = await pool.query(
          'INSERT INTO messages (booking_id,sender_id,content) VALUES ($1,$2,$3) RETURNING *',
          [bookingId, socket.user.id, content]
        );
        io.to(`chat_${bookingId}`).emit('new_message', rows[0]);
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
