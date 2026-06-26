const router = require('express').Router();
const pool = require('../../config/database');
const { authenticate } = require('../../middleware/auth.middleware');

// GET /api/v1/messages/:bookingId — last 50 messages for a booking
router.get('/:bookingId', authenticate, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT m.*, u.name AS sender_name
       FROM messages m
       JOIN users u ON u.id = m.sender_id
       WHERE m.booking_id = $1
       ORDER BY m.created_at ASC
       LIMIT 50`,
      [req.params.bookingId],
    );
    res.json({ messages: rows });
  } catch (e) { next(e); }
});

// PUT /api/v1/messages/:bookingId/read-all — mark all messages as read for current user
router.put('/:bookingId/read-all', authenticate, async (req, res, next) => {
  try {
    await pool.query(
      `UPDATE messages SET is_read = true
       WHERE booking_id = $1 AND sender_id != $2`,
      [req.params.bookingId, req.user.id],
    );
    res.json({ message: 'Marked as read' });
  } catch (e) { next(e); }
});

module.exports = router;
